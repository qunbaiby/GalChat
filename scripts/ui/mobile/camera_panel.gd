extends Control

signal camera_closed

@onready var close_btn: Button = $Overlay/CloseBtn
@onready var capture_btn: Button = $Overlay/CaptureBtn
@onready var action_row: HBoxContainer = $Overlay/ActionRow
@onready var cancel_btn: Button = $Overlay/ActionRow/CancelBtn
@onready var save_btn: Button = $Overlay/ActionRow/SaveBtn
@onready var flash_rect: ColorRect = $FlashRect
@onready var preview_rect: TextureRect = $PreviewRect

var captured_image: Image = null

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)
    capture_btn.pressed.connect(_on_capture_pressed)
    cancel_btn.pressed.connect(_on_cancel_pressed)
    save_btn.pressed.connect(_on_save_pressed)

func show_panel() -> void:
    show()
    _reset_ui()

func _reset_ui() -> void:
    capture_btn.show()
    action_row.hide()
    preview_rect.hide()
    preview_rect.texture = null
    captured_image = null

func _on_close_pressed() -> void:
    hide()
    camera_closed.emit()

func _on_capture_pressed() -> void:
    capture_btn.hide()
    
    # 隐藏Overlay以截取纯净画面
    $Overlay.hide()
    
    # 等待渲染更新
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    
    var viewport = get_viewport()
    var tex = viewport.get_texture()
    captured_image = tex.get_image()
    
    # 恢复UI
    $Overlay.show()
    
    # 模拟闪光灯效果
    flash_rect.show()
    flash_rect.modulate.a = 1.0
    var tween = create_tween()
    tween.tween_property(flash_rect, "modulate:a", 0.0, 0.3)
    tween.tween_callback(func(): flash_rect.hide())
    
    if captured_image:
        # 显示预览
        var preview_tex = ImageTexture.create_from_image(captured_image)
        preview_rect.texture = preview_tex
        preview_rect.show()
        
    action_row.show()

func _on_cancel_pressed() -> void:
    _reset_ui()

func _on_save_pressed() -> void:
    if captured_image:
        var dir_path = "user://saves/photos"
        if not DirAccess.dir_exists_absolute(dir_path):
            DirAccess.make_dir_recursive_absolute(dir_path)
            
        var time_str = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
        var file_path = dir_path + "/photo_" + time_str + ".png"
        
        captured_image.save_png(file_path)
        print("照片已保存至: ", file_path)
        
    _on_close_pressed()
