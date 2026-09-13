extends Node

## What the game opens into: the title beat, then the room behind the door.
##
## The room is built when the door starts to open, not before — a room running
## behind a menu is a room whose timer is already going. It is held until the
## door is through, so the timer starts on the cut, which is what the spec asks
## for.

const MAIN := "res://game/main.tscn"

var _title: TitleScreen = null
var _layer: CanvasLayer = null
var _game: Node = null
var _dim: ColorRect = null
var _fresh := false


func _ready() -> void:
	var visuals := GameVisuals.load_table()
	_size_window(visuals)
	UiScale.apply(get_window(), visuals)
	_layer = CanvasLayer.new()
	_layer.name = "Title"
	_layer.layer = 10
	add_child(_layer)

	# The room fades in behind the door rather than snapping on: this sits over
	# the room and under the title, and lifts as the door opens.
	_dim = ColorRect.new()
	_dim.name = "RoomDim"
	_dim.color = visuals.colour("title.bg")
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	var under := CanvasLayer.new()
	under.name = "RoomDimLayer"
	under.layer = 5
	add_child(under)
	under.add_child(_dim)

	_title = TitleScreen.new()
	_title.name = "TitleScreen"
	_title.setup(visuals, SaveData.load_or_new())
	_title.start_requested.connect(_on_start)
	_layer.add_child(_title)


## The same sizing the room does: the UI is drawn at 1920x1080 and stretched to
## the window, so a small window renders all of it small.
func _size_window(visuals: GameVisuals) -> void:
	if OS.has_feature("mobile"):
		return
	var window := get_window()
	if window == null:
		return
	var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
	var wanted := UiScale.window_size(screen.size, visuals)
	if wanted == window.size:
		return
	window.size = wanted
	window.position = screen.position + (screen.size - wanted) / 2


func _process(delta: float) -> void:
	if _title == null:
		return
	_title.advance(delta)
	if _game == null and _title.room_wanted():
		_build_game()
	if _game != null:
		_game.held = not _title.exit_finished()
		_dim.visible = true
		_dim.color.a = clampf(1.0 - _title.room_alpha(), 0.0, 1.0)
	if _title.exit_finished():
		_title.queue_free()
		_layer.queue_free()
		_title = null
		if _dim != null:
			_dim.get_parent().queue_free()
			_dim = null


func _on_start(fresh: bool) -> void:
	_fresh = fresh
	_title.begin_exit()


func _build_game() -> void:
	if _fresh:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	_game = (load(MAIN) as PackedScene).instantiate()
	add_child(_game)
	move_child(_game, 0)
