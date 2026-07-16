@tool
extends EditorPlugin

const STORY_EDITOR_WINDOW_SCENE = preload("res://addons/story_editor/ui/story_editor_window.tscn")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"
const MENU_LABEL := "GalChat 剧情编辑器"
const RuntimeDebuggerPlugin = preload("res://addons/story_editor/core/story_runtime_debugger_plugin.gd")
const DESKTOP_WALLPAPER_HOST_MARKER := "desktop_wallpaper_host.txt"
const DESKTOP_WALLPAPER_WATCHER := "res://tools/desktop_wallpaper_exit_watcher.ps1"

var story_editor_window: Window
var story_editor: Control
var runtime_debugger_plugin: EditorDebuggerPlugin
var _was_playing_scene := false


func _enter_tree() -> void:
	_was_playing_scene = EditorInterface.is_playing_scene()
	set_process(true)
	runtime_debugger_plugin = RuntimeDebuggerPlugin.new()
	add_debugger_plugin(runtime_debugger_plugin)
	_create_story_editor_window()
	add_tool_menu_item(MENU_LABEL, _open_story_editor)


func _create_story_editor_window() -> void:
	story_editor_window = STORY_EDITOR_WINDOW_SCENE.instantiate()
	EditorInterface.get_base_control().add_child(story_editor_window)
	story_editor = story_editor_window.get_node("StoryEditorMain")
	story_editor.set_runtime_debugger_plugin(runtime_debugger_plugin)
	story_editor_window.close_requested.connect(story_editor_window.hide)


func _exit_tree() -> void:
	set_process(false)
	remove_tool_menu_item(MENU_LABEL)
	if runtime_debugger_plugin != null:
		remove_debugger_plugin(runtime_debugger_plugin)
		runtime_debugger_plugin = null
	if is_instance_valid(story_editor_window):
		story_editor_window.queue_free()


func _process(_delta: float) -> void:
	var is_playing := EditorInterface.is_playing_scene()
	if _was_playing_scene and not is_playing:
		_refresh_desktop_after_forced_stop()
	_was_playing_scene = is_playing


func _refresh_desktop_after_forced_stop() -> void:
	var marker_path := OS.get_user_data_dir().path_join(DESKTOP_WALLPAPER_HOST_MARKER)
	if not FileAccess.file_exists(marker_path):
		return
	var marker := FileAccess.open(marker_path, FileAccess.READ)
	if marker == null:
		return
	var desktop_host := marker.get_as_text().strip_edges()
	marker.close()
	DirAccess.remove_absolute(marker_path)
	if not desktop_host.is_valid_int():
		return
	var watcher_path := ProjectSettings.globalize_path(DESKTOP_WALLPAPER_WATCHER)
	var log_path := OS.get_user_data_dir().path_join("desktop_wallpaper_exit_watcher.log")
	OS.create_process("powershell.exe", [
		"-NoProfile",
		"-NonInteractive",
		"-WindowStyle", "Hidden",
		"-ExecutionPolicy", "Bypass",
		"-File", watcher_path,
		"-GameProcessId", "0",
		"-DesktopHost", desktop_host,
		"-LogPath", log_path,
	])


func _has_main_screen() -> bool:
	return false


func _open_story_editor() -> void:
	if not is_instance_valid(story_editor_window):
		_create_story_editor_window()
	if story_editor_window.visible:
		story_editor_window.grab_focus()
		return
	if story_editor.has_method("has_unsaved_changes") and story_editor.has_unsaved_changes():
		(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(story_editor_window, Vector2i(1500, 900), Vector2i(1100, 700))
		return
	story_editor_window.queue_free()
	_create_story_editor_window()
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(story_editor_window, Vector2i(1500, 900), Vector2i(1100, 700))


func _get_plugin_name() -> String:
	return "剧情编辑器"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("VisualShader", "EditorIcons")


func _get_unsaved_status(for_scene: String) -> String:
	if not for_scene.is_empty() or not is_instance_valid(story_editor):
		return ""
	if story_editor.has_method("has_unsaved_changes") and story_editor.has_unsaved_changes():
		return "剧情编辑器中有尚未保存的修改。"
	return ""


func _save_external_data() -> void:
	if is_instance_valid(story_editor) and story_editor.has_method("save_all_content"):
		story_editor.save_all_content()