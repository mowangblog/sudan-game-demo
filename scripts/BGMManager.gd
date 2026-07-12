# BGMManager.gd — AutoLoad 单例，统一管理背景音乐
# 负责：① 切场景/切曲时的交叉淡入淡出；② 全局音量控制。
# 用法：
#   BGM.play(load("res://assets/bgm/main_menu.ogg"))   # 切到某首（与当前交叉淡变）
#   BGM.set_volume(0.6)                                 # 设置音量 0..1（设置面板调用）

extends Node

const FADE_SECONDS := 1.2     # 淡入淡出时长(秒)
const SILENT_DB := -60.0      # 静音对应的音量(db，避免 linear_to_db(0)=-INF)

var _current: AudioStreamPlayer = null
var _current_stream: AudioStream = null
var _in_tween: Tween = null
var volume: float = 1.0       # 0..1，由设置面板控制；单例持有，菜单设置对游戏生效

func _db() -> float:
	if volume > 0.0:
		return linear_to_db(volume)
	return SILENT_DB

# 播放指定音轨；若已在播同一首则忽略。会自动与“当前正在播的曲”做交叉淡入淡出。
func play(stream: AudioStream, fade: float = FADE_SECONDS) -> void:
	if stream == null:
		return
	if _current != null and _current.playing and _current_stream == stream:
		return   # 同一首正在播，不重复触发
	# 新播放器：从静音起，淡入
	var new_p = AudioStreamPlayer.new()
	new_p.stream = stream
	new_p.stream.loop = true
	new_p.volume_db = SILENT_DB
	add_child(new_p)
	new_p.play()
	if _in_tween != null and _in_tween.is_valid():
		_in_tween.kill()
	_in_tween = create_tween()
	_in_tween.tween_property(new_p, "volume_db", _db(), fade)
	# 旧播放器：淡出后释放（不与新曲交叠、不泄漏）
	var old = _current
	if old != null:
		var out = create_tween()
		out.tween_property(old, "volume_db", SILENT_DB, fade)
		out.tween_callback(func():
			if is_instance_valid(old):
				old.stop()
				old.queue_free()
		)
	_current = new_p
	_current_stream = stream

# 设置音量 0..1；若正在淡入则终止淡入、直接落到目标音量（避免 tween 覆盖）。
func set_volume(v: float) -> void:
	volume = clamp(v, 0.0, 1.0)
	if _current != null and is_instance_valid(_current):
		if _in_tween != null and _in_tween.is_valid():
			_in_tween.kill()
		_current.volume_db = _db()
