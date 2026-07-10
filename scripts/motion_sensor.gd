extends Node
## Motion (autoload)
## 기기의 "정지 상태"를 플랫폼에 상관없이 추상화한다.
##
## 3단 폴백:
##   1) 네이티브(안드로이드/iOS): 자이로스코프 + 중력벡터
##   2) 웹 모바일: JavaScript DeviceMotion 이벤트 (iOS는 사용자 제스처로 권한 요청)
##   3) 데스크톱/웹 데스크톱: 마우스 움직임 = 손떨림  (지금 바로 페이지에서 테스트 가능)
##
## 외부에는 두 개의 정규화된 값만 노출한다:
##   get_sway()  -> -1.0 ~ 1.0  (좌우 기울기/흔들림, 부호 있음)
##   get_shake() ->  0.0 ~ 1.0  (전체 흔들림의 세기)

signal calibrated

# 접근성(수전증 대응): 낮을수록 관대함(허용 범위 큼). 게임에서 난이도로 조절.
var sensitivity: float = 1.0

var _sway: float = 0.0
var _shake: float = 0.0

# 센서 드리프트/평소 손떨림 보정용 기준값
var _baseline: float = 0.0
var _tilt_baseline: float = 0.0     # 편안하게 잡은 각도 = '수평(0)'
var _calibrating: bool = false
var _calib_time: float = 0.0
var _calib_accum: float = 0.0
var _calib_tilt_accum: float = 0.0
var _calib_samples: int = 0

# 데스크톱 마우스 폴백
var _mouse_vel: Vector2 = Vector2.ZERO
var _mouse_tilt: float = 0.0

var _web: bool = false
var _web_listener_ready: bool = false


func _ready() -> void:
	_web = OS.has_feature("web")
	# 자이로/가속도 값을 자주 갱신
	set_process(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_vel += event.relative


func _process(delta: float) -> void:
	var raw_shake: float = 0.0
	var target_tilt: float = 0.0
	var have_tilt: bool = false

	# --- 1) 네이티브 센서 ---
	var gravity: Vector3 = Input.get_gravity()
	if gravity.length() > 0.1:
		target_tilt = clampf(gravity.x / 9.8, -1.0, 1.0)
		have_tilt = true
		raw_shake = maxf(raw_shake, Input.get_gyroscope().length() * 0.55)

	# --- 2) 웹: DeviceOrientation(기울기 각도) + DeviceMotion(흔들림 세기) ---
	# 기울기는 가속도(ax, 노이즈 큼) 대신 orientation.gamma(깨끗한 각도)로 읽는다.
	if _web and _web_listener_ready:
		var packed: String = str(JavaScriptBridge.eval(
			"(function(m){return m?(m.gamma+','+m.ax+','+m.rate+','+m.ho):'e';})(window.__babelMotion)", true))
		if packed != "e" and packed.find(",") != -1:
			var parts: PackedStringArray = packed.split(",")
			var gamma: float = float(parts[0])   # 좌우 기울기(도), -90..90
			var ax: float = float(parts[1])
			var rate: float = float(parts[2])
			var has_orient: bool = int(parts[3]) == 1
			if has_orient:
				target_tilt = clampf(gamma / 40.0, -1.0, 1.0)
				have_tilt = true
			elif absf(ax) > 0.01:
				target_tilt = clampf(ax / 9.8, -1.0, 1.0)
				have_tilt = true
			raw_shake = maxf(raw_shake, rate * 0.008)

	# --- 3) 데스크톱 마우스 폴백 (항상 함께 반영) ---
	var mouse_speed: float = _mouse_vel.length()
	if mouse_speed > 0.0:
		raw_shake = maxf(raw_shake, mouse_speed * 0.03)
		_mouse_tilt = clampf(_mouse_tilt + _mouse_vel.x * 0.004, -1.0, 1.0)
	# 마우스를 가만히 두면 기울기는 서서히 0으로 복귀
	_mouse_tilt = move_toward(_mouse_tilt, 0.0, delta * 1.5)
	if not have_tilt:
		target_tilt = _mouse_tilt
	_mouse_vel = Vector2.ZERO

	raw_shake = clampf(raw_shake, 0.0, 3.0)

	# --- 보정(Calibration) ---
	if _calibrating:
		_calib_accum += raw_shake
		_calib_tilt_accum += target_tilt
		_calib_samples += 1
		_calib_time -= delta
		if _calib_time <= 0.0:
			var n := maxf(1.0, float(_calib_samples))
			_baseline = _calib_accum / n
			_tilt_baseline = _calib_tilt_accum / n
			_calibrating = false
			calibrated.emit()

	# 기준값(드리프트/평소 떨림)을 뺀 순수 흔들림
	var effective: float = maxf(0.0, raw_shake - _baseline) * sensitivity
	# 편안한 각도를 0으로 삼은 상대 기울기
	var rel_tilt: float = clampf((target_tilt - _tilt_baseline) * sensitivity, -1.0, 1.0)

	# 부드럽게 스무딩
	_sway = lerpf(_sway, rel_tilt, 0.15)
	_shake = lerpf(_shake, clampf(effective, 0.0, 1.0), 0.2)


## "당신의 가장 편안한 자세로 기기를 잡으세요" — 평소 손떨림/드리프트를 0점으로 잡는다.
func start_calibration(duration: float = 1.5) -> void:
	_calibrating = true
	_calib_time = duration
	_calib_accum = 0.0
	_calib_tilt_accum = 0.0
	_calib_samples = 0


func is_calibrating() -> bool:
	return _calibrating


## iOS Safari는 DeviceMotion/DeviceOrientation에 사용자 제스처 기반 권한이 필요하다.
## 보정 화면의 "센서 켜기" 버튼에서 호출한다.
func request_web_permission() -> void:
	if not _web or _web_listener_ready:
		return
	_web_listener_ready = true
	var js: String = """
	(function(){
	  if (window.__babelMotionInit) return;
	  window.__babelMotionInit = true;
	  window.__babelMotion = {gamma:0, ax:0, rate:0, ho:0};
	  function attachOrient(){
	    window.addEventListener('deviceorientation', function(e){
	      if (e.gamma === null || e.gamma === undefined) return;
	      window.__babelMotion.gamma = e.gamma;   // 좌우 기울기(도)
	      window.__babelMotion.ho = 1;
	    }, true);
	  }
	  function attachMotion(){
	    window.addEventListener('devicemotion', function(e){
	      var a = e.accelerationIncludingGravity || e.acceleration || {x:0};
	      var r = e.rotationRate || {alpha:0,beta:0,gamma:0};
	      window.__babelMotion.ax = a.x || 0;
	      window.__babelMotion.rate = Math.sqrt(
	        (r.alpha||0)*(r.alpha||0)+(r.beta||0)*(r.beta||0)+(r.gamma||0)*(r.gamma||0));
	    }, true);
	  }
	  // DeviceOrientation 권한(iOS 13+)
	  if (typeof DeviceOrientationEvent !== 'undefined'
	      && typeof DeviceOrientationEvent.requestPermission === 'function') {
	    DeviceOrientationEvent.requestPermission()
	      .then(function(s){ if (s === 'granted') attachOrient(); })
	      .catch(function(){});
	  } else {
	    attachOrient();
	  }
	  // DeviceMotion 권한(iOS 13+)
	  if (typeof DeviceMotionEvent !== 'undefined'
	      && typeof DeviceMotionEvent.requestPermission === 'function') {
	    DeviceMotionEvent.requestPermission()
	      .then(function(s){ if (s === 'granted') attachMotion(); })
	      .catch(function(){});
	  } else {
	    attachMotion();
	  }
	})();
	"""
	JavaScriptBridge.eval(js, true)


func get_sway() -> float:
	return _sway


func get_shake() -> float:
	return _shake
