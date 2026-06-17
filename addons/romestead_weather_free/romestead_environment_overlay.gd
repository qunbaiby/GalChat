extends Control

var environment: Node

var _drop_texture: Texture2D
var _splash_texture: Texture2D
var _cloud_shader: Shader
var _fog_shader: Shader
var _cloud_layers: Array[TextureRect] = []
var _storm_cloud_layers: Array[TextureRect] = []
var _fog_layers: Array[TextureRect] = []
var _cloud_mask_textures: Array[Texture2D] = []
var _fog_mask_textures: Array[Texture2D] = []
var _detail_noise_texture: Texture2D
var _flow_noise_texture: Texture2D
var _rain_motion_initialized := false
var _last_effect_time := 0.0
var _rain_motion_distance := 0.0
var _rain_motion_speed := 0.0

const CLOUD_MASK_FILES := [
	"sky/cloud_mask_01.png",
	"sky/cloud_mask_02.png",
	"sky/cloud_mask_03.png"
]

const FOG_MASK_FILES := [
	"sky/fog_band_01.png",
	"sky/fog_band_02.png",
	"sky/fog_band_03.png"
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_weather_assets()
	_load_atmosphere_assets()
	_setup_atmosphere_layers()


func _draw() -> void:
	if environment == null:
		return
	var rect := _target_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_update_atmosphere_layers(rect)
	_draw_clear_weather(rect)
	_draw_time_tint(rect)
	_draw_atmosphere_overlay(
		rect,
		_weather_strength("rainy"),
		_weather_strength("thunder"),
		_weather_strength("cloudy"),
		_weather_strength("overcast"),
		_weather_strength("foggy")
	)
	_draw_snow(rect, _weather_strength("snow"))
	_draw_rain(rect, _weather_strength("rainy"), _weather_strength("thunder"))
	_draw_lightning(rect)


func _load_weather_assets() -> void:
	if environment != null and environment.get("use_original_weather_assets") == false:
		return
	_drop_texture = _load_weather_texture("water_drop.png")
	_splash_texture = _load_weather_texture("water_splash.png")


func _load_atmosphere_assets() -> void:
	_cloud_shader = _load_shader("shaders/weather_cloud_layer.gdshader")
	_fog_shader = _load_shader("shaders/weather_fog_layer.gdshader")
	_cloud_mask_textures.clear()
	for file_name in CLOUD_MASK_FILES:
		_cloud_mask_textures.append(_load_weather_texture(file_name))
	_fog_mask_textures.clear()
	for file_name in FOG_MASK_FILES:
		_fog_mask_textures.append(_load_weather_texture(file_name))
	_detail_noise_texture = _load_weather_texture("sky/cloud_detail_noise.png")
	_flow_noise_texture = _load_weather_texture("sky/cloud_flow_noise.png")
	if _detail_noise_texture == null:
		_detail_noise_texture = _generate_fast_noise_texture(64, 64, 41.0, false)
	if _flow_noise_texture == null:
		_flow_noise_texture = _generate_fast_noise_texture(64, 64, 83.0, true)
	for i in range(_cloud_mask_textures.size()):
		if _cloud_mask_textures[i] == null:
			_cloud_mask_textures[i] = _generate_fast_mask_texture(128, 64, 101.0 + float(i) * 31.0, false)
	for i in range(_fog_mask_textures.size()):
		if _fog_mask_textures[i] == null:
			_fog_mask_textures[i] = _generate_fast_mask_texture(128, 64, 211.0 + float(i) * 29.0, true)


func _setup_atmosphere_layers() -> void:
	if not _cloud_layers.is_empty() or not _storm_cloud_layers.is_empty() or not _fog_layers.is_empty():
		return
	for i in range(3):
		_cloud_layers.append(_create_shader_layer(
			"CloudLayer%d" % i,
			_cloud_shader,
			_cloud_mask_textures[i % max(1, _cloud_mask_textures.size())],
			true
		))
	for i in range(3):
		_storm_cloud_layers.append(_create_shader_layer(
			"StormCloudLayer%d" % i,
			_cloud_shader,
			_cloud_mask_textures[(i + 1) % max(1, _cloud_mask_textures.size())],
			true
		))
	for i in range(3):
		_fog_layers.append(_create_shader_layer(
			"FogLayer%d" % i,
			_fog_shader,
			_fog_mask_textures[i % max(1, _fog_mask_textures.size())],
			false
		))


func _create_shader_layer(layer_name: String, shader: Shader, texture: Texture2D, behind_parent: bool) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.position = Vector2.ZERO
	layer.size = Vector2.ZERO
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.show_behind_parent = behind_parent
	layer.visible = false
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("detail_noise", _detail_noise_texture)
	material.set_shader_parameter("flow_noise", _flow_noise_texture)
	layer.material = material
	add_child(layer)
	return layer


func _update_atmosphere_layers(rect: Rect2) -> void:
	var cloudy_strength: float = _weather_strength("cloudy")
	var overcast_strength: float = _weather_strength("overcast")
	var foggy_strength: float = _weather_strength("foggy")
	var rainy_strength: float = _weather_strength("rainy")
	var thunder_strength: float = _weather_strength("thunder")
	var time_sec: float = float(environment.get("effect_time"))
	var cloud_strength: float = clamp(max(cloudy_strength, overcast_strength), 0.0, 1.0)
	var storm_strength: float = clamp(max(rainy_strength * 0.72, thunder_strength), 0.0, 1.0)
	var scroll_offset: Vector2 = _camera_uv_offset(rect, 0.015)

	for i in range(_cloud_layers.size()):
		var layer: TextureRect = _cloud_layers[i]
		layer.position = rect.position
		layer.size = rect.size
		layer.texture = _cloud_mask_textures[i % max(1, _cloud_mask_textures.size())]
		layer.visible = cloud_strength > 0.01
		_update_cloud_layer_material(layer, i, time_sec, cloud_strength, 0.0, scroll_offset)

	for i in range(_storm_cloud_layers.size()):
		var layer: TextureRect = _storm_cloud_layers[i]
		layer.position = rect.position
		layer.size = rect.size
		layer.texture = _cloud_mask_textures[(i + 1) % max(1, _cloud_mask_textures.size())]
		layer.visible = storm_strength > 0.01
		_update_cloud_layer_material(layer, i, time_sec, storm_strength, 1.0, scroll_offset * 1.6)

	for i in range(_fog_layers.size()):
		var layer: TextureRect = _fog_layers[i]
		layer.position = rect.position
		layer.size = rect.size
		layer.texture = _fog_mask_textures[i % max(1, _fog_mask_textures.size())]
		layer.visible = foggy_strength > 0.01
		_update_fog_layer_material(layer, i, time_sec, foggy_strength, _camera_uv_offset(rect, 0.028 + float(i) * 0.01))


func _update_cloud_layer_material(layer: TextureRect, layer_index: int, time_sec: float, strength: float, storminess: float, world_offset: Vector2) -> void:
	var material := layer.material as ShaderMaterial
	if material == null:
		return
	var tint: Color = Color(0.84, 0.88, 0.94, 0.0)
	var layer_alpha: float = 0.12
	var density: float = 0.46
	var softness: float = 0.2
	var band_bottom: float = 0.48
	var base_scale := Vector2(1.35, 0.9)
	var detail_scale := Vector2(3.2, 2.1)
	var flow_scale := Vector2(1.1, 0.9)
	var drift_a := Vector2(0.0036, 0.0)
	var drift_b := Vector2(-0.0021, 0.0012)
	if layer_index == 1:
		tint = Color(0.76, 0.81, 0.89, 0.0)
		layer_alpha = 0.18
		density = 0.52
		softness = 0.18
		band_bottom = 0.58
		base_scale = Vector2(1.05, 0.82)
		detail_scale = Vector2(3.8, 2.35)
		flow_scale = Vector2(1.42, 1.0)
		drift_a = Vector2(0.0046, 0.0003)
		drift_b = Vector2(-0.0028, 0.0014)
	elif layer_index == 2:
		tint = Color(0.68, 0.73, 0.82, 0.0)
		layer_alpha = 0.22
		density = 0.58
		softness = 0.16
		band_bottom = 0.64
		base_scale = Vector2(0.86, 0.72)
		detail_scale = Vector2(4.5, 2.6)
		flow_scale = Vector2(1.7, 1.14)
		drift_a = Vector2(0.0058, 0.0004)
		drift_b = Vector2(-0.0035, 0.0017)
	if storminess > 0.5:
		tint = tint.lerp(Color(0.16, 0.2, 0.28, 0.0), 0.7)
		layer_alpha += 0.1
		density += 0.08
		band_bottom = min(0.78, band_bottom + 0.08)
	material.set_shader_parameter("time_sec", time_sec)
	material.set_shader_parameter("tint_color", tint)
	material.set_shader_parameter("layer_alpha", lerp(0.0, layer_alpha, strength))
	material.set_shader_parameter("density", clamp(density + strength * 0.16, 0.0, 0.96))
	material.set_shader_parameter("softness", softness)
	material.set_shader_parameter("base_scale", base_scale)
	material.set_shader_parameter("detail_scale", detail_scale)
	material.set_shader_parameter("flow_scale", flow_scale)
	material.set_shader_parameter("drift_a", drift_a)
	material.set_shader_parameter("drift_b", drift_b)
	material.set_shader_parameter("band_top", 0.0)
	material.set_shader_parameter("band_bottom", band_bottom)
	material.set_shader_parameter("edge_breakup", lerp(0.24, 0.42, strength))
	material.set_shader_parameter("highlight", lerp(0.08, 0.03, storminess))
	material.set_shader_parameter("storminess", storminess)
	material.set_shader_parameter("world_offset", world_offset * (0.5 + float(layer_index) * 0.25))


func _update_fog_layer_material(layer: TextureRect, layer_index: int, time_sec: float, strength: float, world_offset: Vector2) -> void:
	var material := layer.material as ShaderMaterial
	if material == null:
		return
	var tint: Color = Color(0.94, 0.96, 0.98, 0.0)
	var layer_alpha: float = 0.1
	var density: float = 0.42
	var softness: float = 0.24
	var band_top: float = 0.42
	var band_bottom: float = 1.08
	var base_scale := Vector2(1.0, 0.82)
	var detail_scale := Vector2(3.0, 1.8)
	var flow_scale := Vector2(1.1, 0.8)
	var drift_a := Vector2(0.0014, 0.0)
	var drift_b := Vector2(-0.0008, 0.0006)
	if layer_index == 1:
		tint = Color(0.91, 0.94, 0.97, 0.0)
		layer_alpha = 0.15
		density = 0.48
		band_top = 0.5
		base_scale = Vector2(0.82, 0.74)
		detail_scale = Vector2(3.4, 2.0)
		flow_scale = Vector2(1.36, 0.9)
		drift_a = Vector2(0.0018, 0.0001)
		drift_b = Vector2(-0.0011, 0.0007)
	elif layer_index == 2:
		tint = Color(0.86, 0.9, 0.95, 0.0)
		layer_alpha = 0.2
		density = 0.54
		softness = 0.28
		band_top = 0.56
		base_scale = Vector2(0.72, 0.68)
		detail_scale = Vector2(4.0, 2.15)
		flow_scale = Vector2(1.58, 0.96)
		drift_a = Vector2(0.0022, 0.0002)
		drift_b = Vector2(-0.0014, 0.0009)
	material.set_shader_parameter("time_sec", time_sec)
	material.set_shader_parameter("tint_color", tint)
	material.set_shader_parameter("layer_alpha", lerp(0.0, layer_alpha, strength))
	material.set_shader_parameter("density", clamp(density + strength * 0.18, 0.0, 0.96))
	material.set_shader_parameter("softness", softness)
	material.set_shader_parameter("base_scale", base_scale)
	material.set_shader_parameter("detail_scale", detail_scale)
	material.set_shader_parameter("flow_scale", flow_scale)
	material.set_shader_parameter("drift_a", drift_a)
	material.set_shader_parameter("drift_b", drift_b)
	material.set_shader_parameter("band_top", band_top)
	material.set_shader_parameter("band_bottom", band_bottom)
	material.set_shader_parameter("world_offset", world_offset * (0.6 + float(layer_index) * 0.28))


func _draw_clear_weather(rect: Rect2) -> void:
	var cloudy_strength: float = _weather_strength("cloudy")
	var overcast_strength: float = _weather_strength("overcast")
	var foggy_strength: float = _weather_strength("foggy")
	var rainy_strength: float = _weather_strength("rainy")
	var thunder_strength: float = _weather_strength("thunder")
	var snow_strength: float = _weather_strength("snow")
	var cover_strength: float = clamp(
		cloudy_strength * 0.45 +
		overcast_strength * 0.85 +
		foggy_strength * 0.5 +
		rainy_strength * 0.75 +
		thunder_strength * 1.0 +
		snow_strength * 0.28,
		0.0,
		1.0
	)
	var clear_strength: float = 1.0 - cover_strength
	if clear_strength <= 0.01:
		return
	var hour: float = float(environment.get("current_hour"))
	var sun_peak: float = 1.0 - _smoothstep(0.0, 5.8, abs(hour - 13.0))
	if sun_peak > 0.0:
		var glow_alpha: float = sun_peak * clear_strength * 0.11
		var glow_center := Vector2(
			rect.position.x + rect.size.x * 0.78,
			rect.position.y + rect.size.y * lerp(0.09, 0.18, 1.0 - sun_peak)
		)
		var glow_radius: float = rect.size.x * lerp(0.12, 0.24, sun_peak)
		draw_circle(glow_center, glow_radius * 1.85, Color(1.0, 0.92, 0.78, glow_alpha * 0.22))
		draw_circle(glow_center, glow_radius, Color(1.0, 0.96, 0.84, glow_alpha))
		var shimmer_count: int = int(lerp(6.0, 14.0, clear_strength * sun_peak))
		for i in range(shimmer_count):
			var seed: float = 501.0 + float(i) * 17.73
			var shimmer_x: float = rect.position.x + _hash_float(seed + 0.7) * rect.size.x
			var shimmer_y: float = rect.position.y + _hash_float(seed + 1.9) * rect.size.y * 0.42
			var shimmer_w: float = lerp(36.0, 104.0, _hash_float(seed + 2.4))
			var shimmer_h: float = lerp(6.0, 14.0, _hash_float(seed + 4.1))
			var alpha: float = glow_alpha * 0.08 * lerp(0.75, 1.25, _hash_float(seed + 3.8))
			draw_rect(
				Rect2(Vector2(shimmer_x, shimmer_y), Vector2(shimmer_w, shimmer_h)),
				Color(1.0, 0.95, 0.86, alpha),
				true
			)
	var night_curve: float = float(environment.get("time_based_light_curve"))
	if night_curve > 0.18 and clear_strength > 0.22:
		var star_strength: float = night_curve * clear_strength
		var star_count: int = int(lerp(10.0, 26.0, star_strength))
		for i in range(star_count):
			var seed: float = 907.0 + float(i) * 11.41
			var twinkle: float = 0.5 + 0.5 * sin(float(environment.get("effect_time")) * lerp(0.7, 1.8, _hash_float(seed + 0.2)) + seed)
			var star_alpha: float = star_strength * 0.24 * twinkle * lerp(0.6, 1.1, _hash_float(seed + 1.6))
			var pos := Vector2(
				rect.position.x + _hash_float(seed + 2.5) * rect.size.x,
				rect.position.y + _hash_float(seed + 3.1) * rect.size.y * 0.42
			)
			draw_circle(pos, lerp(0.8, 1.6, _hash_float(seed + 4.4)), Color(0.92, 0.96, 1.0, star_alpha))
			if star_alpha > 0.035:
				draw_line(pos + Vector2(-2.0, 0.0), pos + Vector2(2.0, 0.0), Color(0.92, 0.96, 1.0, star_alpha * 0.42), 1.0)
				draw_line(pos + Vector2(0.0, -2.0), pos + Vector2(0.0, 2.0), Color(0.92, 0.96, 1.0, star_alpha * 0.42), 1.0)


func _draw_time_tint(rect: Rect2) -> void:
	var night_curve: float = float(environment.get("time_based_light_curve"))
	var weather_curve: float = float(environment.get("weather_light_curve"))
	var ambient: Color = environment.get("ambient_color")
	var cloudy_strength: float = _weather_strength("cloudy")
	var overcast_strength: float = _weather_strength("overcast")
	var foggy_strength: float = _weather_strength("foggy")
	var cloud_cover: float = clamp(cloudy_strength * 0.55 + overcast_strength * 1.0 + foggy_strength * 0.45, 0.0, 1.0)
	var darkness: float = clamp(1.0 - ((ambient.r + ambient.g + ambient.b) / 3.0), 0.0, 1.0)
	var blue_alpha: float = clamp(night_curve * 0.48 + weather_curve * 0.18 + darkness * 0.12, 0.0, 0.68)
	if blue_alpha > 0.001:
		draw_rect(rect, Color(0.025, 0.045, 0.105, blue_alpha), true)

	var hour: float = float(environment.get("current_hour"))
	var dawn: float = 1.0 - _smoothstep(0.0, 1.05, abs(hour - 5.75))
	var dusk: float = 1.0 - _smoothstep(0.0, 0.8, abs(hour - 21.8))
	var warm: float = max(dawn, dusk) * lerp(1.0, 0.35, cloud_cover)
	if warm > 0.0:
		draw_rect(rect, Color(1.0, 0.48, 0.22, warm * 0.08), true)


func _draw_atmosphere_overlay(rect: Rect2, rainy_strength: float, thunder_strength: float, cloudy_strength: float, overcast_strength: float, foggy_strength: float) -> void:
	var cloud_strength: float = clamp(max(cloudy_strength, overcast_strength), 0.0, 1.0)
	if cloud_strength > 0.01:
		var veil_alpha: float = clamp(cloudy_strength * 0.08 + overcast_strength * 0.18, 0.0, 0.28)
		if veil_alpha > 0.001:
			draw_rect(rect, Color(0.8, 0.84, 0.9, veil_alpha), true)
		var top_band_alpha: float = clamp(cloudy_strength * 0.10 + overcast_strength * 0.24, 0.0, 0.34)
		if top_band_alpha > 0.001:
			draw_rect(
				Rect2(rect.position, Vector2(rect.size.x, rect.size.y * lerp(0.32, 0.48, cloud_strength))),
				Color(0.72, 0.77, 0.86, top_band_alpha),
				true
			)

	var storm_strength: float = clamp(max(rainy_strength * 0.75, thunder_strength), 0.0, 1.0)
	if storm_strength > 0.01:
		var storm_top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * lerp(0.42, 0.58, storm_strength)))
		draw_rect(storm_top, Color(0.22, 0.26, 0.34, lerp(0.05, 0.18, storm_strength)), true)
		if thunder_strength > 0.08:
			draw_rect(rect, Color(0.18, 0.22, 0.3, thunder_strength * 0.08), true)

	if foggy_strength > 0.01:
		var fog_veil_alpha: float = clamp(foggy_strength * 0.16, 0.0, 0.22)
		draw_rect(rect, Color(0.9, 0.93, 0.96, fog_veil_alpha), true)
		draw_rect(
			Rect2(
				Vector2(rect.position.x, rect.position.y + rect.size.y * 0.56),
				Vector2(rect.size.x, rect.size.y * 0.44)
			),
			Color(0.92, 0.94, 0.97, foggy_strength * 0.12),
			true
		)


func _draw_cloud_layer(rect: Rect2, time: float, strength: float, layer_index: int) -> void:
	var count: int = 6
	var width_min: float = rect.size.x * 0.18
	var width_max: float = rect.size.x * 0.42
	var height_min: float = rect.size.y * 0.05
	var height_max: float = rect.size.y * 0.12
	var y_min: float = rect.size.y * 0.02
	var y_max: float = rect.size.y * 0.28
	var drift_min: float = 3.0
	var drift_max: float = 8.0
	var alpha_min: float = 0.04
	var alpha_max: float = 0.11
	var tint: Color = Color(0.86, 0.89, 0.94, 1.0)
	var seed_offset: float = 31.7
	if layer_index == 1:
		count = 9
		width_min = rect.size.x * 0.24
		width_max = rect.size.x * 0.52
		height_min = rect.size.y * 0.06
		height_max = rect.size.y * 0.14
		y_min = rect.size.y * 0.06
		y_max = rect.size.y * 0.34
		drift_min = 4.0
		drift_max = 10.0
		alpha_min = 0.05
		alpha_max = 0.13
		tint = Color(0.82, 0.86, 0.93, 1.0)
		seed_offset = 141.0
	elif layer_index == 2:
		count = 5
		width_min = rect.size.x * 0.34
		width_max = rect.size.x * 0.66
		height_min = rect.size.y * 0.08
		height_max = rect.size.y * 0.17
		y_min = rect.size.y * 0.1
		y_max = rect.size.y * 0.38
		drift_min = 6.0
		drift_max = 14.0
		alpha_min = 0.06
		alpha_max = 0.16
		tint = Color(0.76, 0.81, 0.89, 1.0)
		seed_offset = 271.0
	for i in range(count):
		var seed: float = seed_offset + float(i) * 19.13
		var drift: float = time * lerp(drift_min, drift_max, _hash_float(seed + 1.7))
		var cloud_width: float = lerp(width_min, width_max, _hash_float(seed + 2.1))
		var cloud_height: float = lerp(height_min, height_max, _hash_float(seed + 8.6))
		var x: float = rect.position.x + fposmod(_hash_float(seed + 4.3) * (rect.size.x + cloud_width * 1.4) + drift, rect.size.x + cloud_width * 1.4) - cloud_width * 0.2
		var y: float = rect.position.y + lerp(y_min, y_max, _hash_float(seed + 6.4))
		var alpha: float = lerp(alpha_min, alpha_max, strength) * lerp(0.7, 1.15, _hash_float(seed + 3.9))
		var skew: float = lerp(-cloud_width * 0.08, cloud_width * 0.08, _hash_float(seed + 10.4))
		_draw_cloud_sheet(Vector2(x, y), cloud_width, cloud_height, skew, tint * Color(1.0, 1.0, 1.0, alpha), alpha * 0.4, false)


func _draw_storm_cloud_layer(rect: Rect2, time: float, strength: float, layer_index: int) -> void:
	var count: int = 6
	var width_min: float = rect.size.x * 0.26
	var width_max: float = rect.size.x * 0.54
	var height_min: float = rect.size.y * 0.08
	var height_max: float = rect.size.y * 0.17
	var y_min: float = rect.size.y * 0.02
	var y_max: float = rect.size.y * 0.22
	var drift_min: float = 8.0
	var drift_max: float = 20.0
	var alpha_min: float = 0.07
	var alpha_max: float = 0.2
	var base_color: Color = Color(0.2, 0.24, 0.32, 1.0)
	var seed_offset: float = 2201.0
	if layer_index == 1:
		count = 8
		width_min = rect.size.x * 0.34
		width_max = rect.size.x * 0.68
		height_min = rect.size.y * 0.1
		height_max = rect.size.y * 0.2
		y_min = rect.size.y * 0.04
		y_max = rect.size.y * 0.26
		alpha_min = 0.09
		alpha_max = 0.24
		base_color = Color(0.18, 0.22, 0.3, 1.0)
		seed_offset = 2321.0
	elif layer_index == 2:
		count = 4
		width_min = rect.size.x * 0.46
		width_max = rect.size.x * 0.86
		height_min = rect.size.y * 0.12
		height_max = rect.size.y * 0.24
		y_min = rect.size.y * 0.08
		y_max = rect.size.y * 0.3
		alpha_min = 0.1
		alpha_max = 0.28
		base_color = Color(0.14, 0.18, 0.26, 1.0)
		seed_offset = 2451.0
	for i in range(count):
		var seed: float = seed_offset + float(i) * 14.89
		var drift: float = time * lerp(drift_min, drift_max, _hash_float(seed + 0.5))
		var cloud_width: float = lerp(width_min, width_max, _hash_float(seed + 1.7))
		var cloud_height: float = lerp(height_min, height_max, _hash_float(seed + 7.4))
		var x: float = rect.position.x + fposmod(_hash_float(seed + 2.6) * (rect.size.x + cloud_width * 1.4) + drift, rect.size.x + cloud_width * 1.4) - cloud_width * 0.22
		var y: float = rect.position.y + lerp(y_min, y_max, _hash_float(seed + 4.3))
		var alpha: float = lerp(alpha_min, alpha_max, strength) * lerp(0.75, 1.18, _hash_float(seed + 5.1))
		var skew: float = lerp(-cloud_width * 0.12, cloud_width * 0.12, _hash_float(seed + 9.5))
		_draw_cloud_sheet(Vector2(x, y), cloud_width, cloud_height, skew, base_color * Color(1.0, 1.0, 1.0, alpha), alpha * 0.62, true)


func _draw_cloud_sheet(top_left: Vector2, width: float, height: float, skew: float, color: Color, shadow_alpha: float, stormy: bool) -> void:
	var x: float = top_left.x
	var y: float = top_left.y
	var body := PackedVector2Array([
		Vector2(x, y + height * 0.24),
		Vector2(x + width * 0.2, y),
		Vector2(x + width * 0.84, y + height * 0.04),
		Vector2(x + width + skew, y + height * 0.3),
		Vector2(x + width * 0.9 + skew * 0.5, y + height * 0.72),
		Vector2(x + width * 0.28, y + height),
		Vector2(x - width * 0.06, y + height * 0.74)
	])
	draw_colored_polygon(body, color)
	var underside_color: Color = Color(0.56, 0.62, 0.72, shadow_alpha)
	if stormy:
		underside_color = Color(0.08, 0.11, 0.17, shadow_alpha)
	var underside := PackedVector2Array([
		Vector2(x + width * 0.06, y + height * 0.58),
		Vector2(x + width * 0.42, y + height * 0.48),
		Vector2(x + width * 0.88 + skew * 0.35, y + height * 0.58),
		Vector2(x + width * 0.82 + skew * 0.22, y + height * 0.82),
		Vector2(x + width * 0.24, y + height * 0.92)
	])
	draw_colored_polygon(underside, underside_color)
	var highlight_alpha: float = color.a * (0.12 if stormy else 0.2)
	var highlight := PackedVector2Array([
		Vector2(x + width * 0.1, y + height * 0.26),
		Vector2(x + width * 0.34, y + height * 0.1),
		Vector2(x + width * 0.72, y + height * 0.12),
		Vector2(x + width * 0.58, y + height * 0.34),
		Vector2(x + width * 0.18, y + height * 0.36)
	])
	draw_colored_polygon(highlight, Color(0.98, 0.99, 1.0, highlight_alpha))


func _draw_fog_layer(rect: Rect2, time: float, strength: float, layer_index: int) -> void:
	var count: int = 8
	var radius_min: float = rect.size.x * 0.12
	var radius_max: float = rect.size.x * 0.28
	var y_min: float = rect.size.y * 0.18
	var y_max: float = rect.size.y * 0.9
	var sway_scale: float = rect.size.x * 0.04
	var alpha_min: float = 0.03
	var alpha_max: float = 0.085
	var base_color: Color = Color(0.96, 0.97, 0.98, 1.0)
	var seed_offset: float = 117.3
	if layer_index == 1:
		count = 10
		radius_min = rect.size.x * 0.16
		radius_max = rect.size.x * 0.34
		y_min = rect.size.y * 0.3
		y_max = rect.size.y * 0.96
		sway_scale = rect.size.x * 0.055
		alpha_min = 0.04
		alpha_max = 0.1
		base_color = Color(0.92, 0.95, 0.97, 1.0)
		seed_offset = 317.3
	elif layer_index == 2:
		count = 6
		radius_min = rect.size.x * 0.22
		radius_max = rect.size.x * 0.4
		y_min = rect.size.y * 0.52
		y_max = rect.size.y * 1.02
		sway_scale = rect.size.x * 0.07
		alpha_min = 0.06
		alpha_max = 0.12
		base_color = Color(0.88, 0.91, 0.95, 1.0)
		seed_offset = 517.3
	for i in range(count):
		var seed: float = seed_offset + float(i) * 23.71
		var sway: float = sin(time * lerp(0.08, 0.22, _hash_float(seed + 0.7)) + seed) * sway_scale
		var radius: float = lerp(radius_min, radius_max, _hash_float(seed + 3.8))
		var x: float = rect.position.x + _hash_float(seed + 6.5) * rect.size.x + sway
		var y: float = rect.position.y + lerp(y_min, y_max, _hash_float(seed + 9.3))
		var alpha: float = lerp(alpha_min, alpha_max, strength) * lerp(0.7, 1.2, _hash_float(seed + 2.4))
		draw_circle(Vector2(x, y), radius, base_color * Color(1.0, 1.0, 1.0, alpha))
		draw_circle(Vector2(x + radius * 0.7, y + radius * 0.04), radius * 0.72, Color(0.9, 0.93, 0.96, alpha * 0.82))
		draw_circle(Vector2(x - radius * 0.68, y + radius * 0.06), radius * 0.64, Color(0.88, 0.91, 0.95, alpha * 0.68))


func _draw_snow(rect: Rect2, strength: float) -> void:
	strength = clamp(strength, 0.0, 1.0)
	if strength <= 0.01:
		return
	var alpha: float = clamp(strength * 0.28, 0.0, 0.36)
	draw_rect(rect, Color(0.72, 0.84, 1.0, alpha * 0.18), true)
	draw_rect(
		Rect2(
			Vector2(rect.position.x, rect.position.y + rect.size.y * 0.72),
			Vector2(rect.size.x, rect.size.y * 0.28)
		),
		Color(0.88, 0.93, 1.0, strength * 0.08),
		true
	)
	var time: float = float(environment.get("effect_time"))
	var density: float = clamp(_env_float("snow_density", 1.0), 0.2, 3.0)
	var flake_size: float = clamp(_env_float("snowflake_size", 1.8), 0.4, 3.5)
	var drift: float = clamp(_env_float("snow_drift_strength", 22.0), 0.0, 80.0)
	var fall_speed: float = clamp(_env_float("snow_fall_speed", 95.0), 20.0, 260.0)
	var depth_feel: float = clamp(_env_float("snow_depth_feel", 0.85), 0.0, 1.0)
	var direction: Vector2 = _env_vector2("snow_fall_direction", Vector2(-0.12, 1.0))
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var base_count: int = int(lerp(34.0, 150.0, strength) * density)
	var scroll_offset: Vector2 = _precipitation_scroll_offset(rect)
	_draw_snow_layer(rect, strength, base_count, time, direction, scroll_offset, flake_size, drift, fall_speed, depth_feel, 0)
	_draw_snow_layer(rect, strength, base_count, time, direction, scroll_offset, flake_size, drift, fall_speed, depth_feel, 1)
	_draw_snow_layer(rect, strength, base_count, time, direction, scroll_offset, flake_size, drift, fall_speed, depth_feel, 2)


func _draw_snow_layer(rect: Rect2, strength: float, base_count: int, time: float, direction: Vector2, scroll_offset: Vector2, flake_size: float, drift: float, fall_speed: float, depth_feel: float, layer_index: int) -> void:
	var layer_count_factor: float = 0.9
	var size_factor: float = 0.55
	var speed_factor: float = 0.45
	var drift_factor: float = 0.35
	var alpha_factor: float = 0.34
	var parallax: float = lerp(0.55, 0.24, depth_feel)
	var glow: float = 0.0
	var seed_offset: float = 0.0
	if layer_index == 1:
		layer_count_factor = 0.78
		size_factor = 1.0
		speed_factor = 0.82
		drift_factor = 0.75
		alpha_factor = 0.62
		parallax = 1.0
		seed_offset = 371.0
	elif layer_index == 2:
		layer_count_factor = 0.32
		size_factor = lerp(1.35, 2.15, depth_feel)
		speed_factor = lerp(0.96, 1.42, depth_feel)
		drift_factor = lerp(0.82, 1.35, depth_feel)
		alpha_factor = lerp(0.54, 0.82, depth_feel)
		parallax = lerp(1.05, 1.32, depth_feel)
		glow = clamp(_env_float("snow_foreground_glow", 0.55), 0.0, 1.0) * depth_feel
		seed_offset = 913.0
	var count: int = max(1, int(float(base_count) * layer_count_factor))
	var margin: float = 56.0 + flake_size * size_factor * 22.0
	var travel_w: float = rect.size.x + margin * 2.0
	var travel_h: float = rect.size.y + margin * 2.0
	for i in range(count):
		var seed: float = seed_offset + float(i) * 19.371
		var local: float = _hash_float(seed)
		var speed_scale: float = lerp(0.55, 1.28, _hash_float(seed + 8.1))
		var sway_phase: float = time * lerp(0.35, 1.05, local) + seed
		var sway: float = sin(sway_phase) * drift * drift_factor * lerp(0.25, 1.0, _hash_float(seed + 2.0))
		var travel: float = time * fall_speed * speed_factor * speed_scale
		var x: float = rect.position.x + fposmod(_hash_float(seed + 4.7) * travel_w + direction.x * travel + sway - scroll_offset.x * parallax, travel_w) - margin
		var y: float = rect.position.y + fposmod(_hash_float(seed + 81.2) * travel_h + direction.y * travel - scroll_offset.y * parallax, travel_h) - margin
		var radius: float = flake_size * size_factor * lerp(0.62, 1.45, _hash_float(seed + 3.0))
		var flake_alpha: float = clamp(lerp(0.24, 0.78, strength) * alpha_factor * lerp(0.58, 1.0, local), 0.0, 0.88)
		var pos := Vector2(x, y)
		if glow > 0.01 and radius > 1.4:
			draw_circle(pos, radius * lerp(2.0, 3.4, glow), Color(0.82, 0.92, 1.0, flake_alpha * 0.18 * glow))
		draw_circle(pos, radius, Color(0.9, 0.96, 1.0, flake_alpha))
		if radius > 1.2:
			draw_circle(pos, radius * 0.42, Color(1.0, 1.0, 1.0, flake_alpha * 0.78))
		if layer_index == 2 and radius > 2.2:
			var sparkle_alpha: float = flake_alpha * 0.32 * glow
			draw_line(pos + Vector2(-radius * 0.9, 0.0), pos + Vector2(radius * 0.9, 0.0), Color(1.0, 1.0, 1.0, sparkle_alpha), 1.0)
			draw_line(pos + Vector2(0.0, -radius * 0.9), pos + Vector2(0.0, radius * 0.9), Color(1.0, 1.0, 1.0, sparkle_alpha), 1.0)


func _draw_rain(rect: Rect2, rain_strength: float, thunder_strength: float) -> void:
	var strength: float = clamp(rain_strength + thunder_strength, 0.0, 1.0)
	var effect_time: float = float(environment.get("effect_time"))
	var heavy: float = clamp(thunder_strength * 1.35, 0.0, 1.0)
	var motion_strength: float = _smoothstep(0.0, 0.7, strength)
	var precipitation_strength: float = _smoothstep(0.08, 0.82, strength)
	var target_fall_speed: float = lerp(220.0, 620.0, motion_strength)
	target_fall_speed = lerp(target_fall_speed, 1080.0, heavy)
	var motion_distance: float = _update_rain_motion(target_fall_speed, effect_time)
	if strength <= 0.01:
		return
	draw_rect(rect, Color(0.32, 0.38, 0.48, strength * 0.028), true)
	draw_rect(
		Rect2(
			Vector2(rect.position.x, rect.position.y + rect.size.y * 0.68),
			Vector2(rect.size.x, rect.size.y * 0.32)
		),
		Color(0.7, 0.78, 0.9, strength * 0.028),
		true
	)
	_draw_rain_veil(rect, effect_time, motion_distance, strength, heavy)
	_draw_ground_rain_mist(rect, effect_time, strength, heavy)
	var drop_count: int = int(lerp(18.0, 170.0, precipitation_strength) + heavy * 44.0)
	var direction: Vector2 = _env_vector2("rain_fall_direction", Vector2(-0.28, 1.0))
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var scroll_offset: Vector2 = _precipitation_scroll_offset(rect)
	_draw_rain_layer(rect, motion_distance, precipitation_strength, heavy, direction, scroll_offset, drop_count, 0)
	_draw_rain_layer(rect, motion_distance, precipitation_strength, heavy, direction, scroll_offset, drop_count, 1)
	_draw_rain_layer(rect, motion_distance, precipitation_strength, heavy, direction, scroll_offset, drop_count, 2)

	var splash_count: int = int(lerp(0.0, 22.0, precipitation_strength) + heavy * 10.0)
	for i in range(splash_count):
		var seed: float = float(i) * 27.91
		var phase: float = fposmod(effect_time * lerp(4.0, 8.0, _hash_float(seed)) + _hash_float(seed + 5.0), 1.0)
		if phase > 0.34:
			continue
		var pos := Vector2(
			rect.position.x + _hash_float(seed + 2.0) * rect.size.x,
			rect.position.y + lerp(rect.size.y * 0.55, rect.size.y, _hash_float(seed + 3.0))
		)
		var splash_alpha: float = (1.0 - phase / 0.34) * precipitation_strength * (0.18 + heavy * 0.14)
		if _splash_texture != null:
			draw_texture_rect(_splash_texture, Rect2(pos, Vector2(10.0, 10.0)), false, Color(0.55, 0.65, 0.85, splash_alpha))
		else:
			draw_circle(pos, 1.5, Color(0.55, 0.65, 0.85, splash_alpha))


func _draw_rain_layer(rect: Rect2, motion_distance: float, strength: float, heavy: float, direction: Vector2, scroll_offset: Vector2, base_drop_count: int, layer_index: int) -> void:
	var count: int = base_drop_count
	var speed_factor: float = 0.78
	var length_factor: float = 0.78
	var alpha_min: float = 0.12
	var alpha_max: float = 0.28
	var width: float = 1.0
	var parallax: float = 0.72
	var color: Color = Color(0.46, 0.58, 0.8, 1.0)
	var seed_offset: float = 0.0
	if layer_index == 1:
		count = int(float(base_drop_count) * 0.85)
		speed_factor = 1.0
		length_factor = 1.0
		alpha_min = 0.16
		alpha_max = 0.45
		parallax = 1.0
		color = Color(0.52, 0.64, 0.86, 1.0)
		seed_offset = 400.0
	elif layer_index == 2:
		count = int(lerp(10.0, 58.0, strength + heavy * 0.4))
		speed_factor = 1.18
		length_factor = 1.46
		alpha_min = 0.08
		alpha_max = 0.24
		width = 1.2
		parallax = 1.12
		color = Color(0.8, 0.9, 1.0, 1.0)
		seed_offset = 900.0
	var streak_length: float = maxf(1.0, (_env_float("rain_streak_length", 38.0) + heavy * 18.0) * length_factor)
	var streak: Vector2 = direction * streak_length
	var margin: float = maxf(96.0, streak_length * 3.0)
	var travel_w: float = rect.size.x + margin * 2.0
	var travel_h: float = rect.size.y + margin * 2.0
	for i in range(max(1, count)):
		var seed: float = seed_offset + float(i) * 13.371
		var speed_scale: float = lerp(0.75, 1.35, _hash_float(seed + 8.1))
		var travel: float = motion_distance * speed_factor * speed_scale
		var flutter: float = sin(motion_distance * lerp(0.01, 0.022, _hash_float(seed + 6.9)) + seed) * lerp(1.2, 6.0, heavy) * (0.4 + float(layer_index) * 0.35)
		var x: float = rect.position.x + fposmod(_hash_float(seed + 4.7) * travel_w + direction.x * travel + flutter - scroll_offset.x * parallax, travel_w) - margin
		var y: float = rect.position.y + fposmod(_hash_float(seed + 81.2) * travel_h + direction.y * travel - scroll_offset.y * parallax, travel_h) - margin
		var field_strength: float = _rain_density_field(
			Vector2(
				fposmod(x - rect.position.x + margin, travel_w) / maxf(1.0, travel_w),
				fposmod(y - rect.position.y + margin, travel_h) / maxf(1.0, travel_h)
			),
			motion_distance,
			heavy,
			layer_index
		)
		if field_strength <= 0.12 and _hash_float(seed + 15.6) > field_strength * 2.6:
			continue
		var alpha: float = (lerp(alpha_min, alpha_max, strength) + heavy * (0.12 if layer_index < 2 else 0.08)) * lerp(0.42, 1.22, field_strength)
		var pos := Vector2(x, y)
		var start_factor: float = lerp(0.38, 0.54, _hash_float(seed + 1.4))
		var end_factor: float = lerp(0.46, 0.72, _hash_float(seed + 2.1))
		if layer_index == 2:
			start_factor = lerp(0.26, 0.42, _hash_float(seed + 1.4))
			end_factor = lerp(0.58, 0.84, _hash_float(seed + 2.1))
		var local_streak: Vector2 = streak * lerp(0.58, 1.3 + heavy * 0.22, _hash_float(seed + 12.2)) * lerp(0.8, 1.18, field_strength)
		var local_width: float = width * lerp(0.82, 1.26, field_strength)
		draw_line(pos - local_streak * start_factor, pos + local_streak * end_factor, color * Color(1.0, 1.0, 1.0, alpha), local_width)


func _draw_rain_veil(rect: Rect2, effect_time: float, motion_distance: float, strength: float, heavy: float) -> void:
	var band_count: int = int(lerp(10.0, 24.0, strength + heavy * 0.25))
	var base_direction: Vector2 = _env_vector2("rain_fall_direction", Vector2(-0.28, 1.0)).normalized()
	for i in range(max(1, band_count)):
		var seed: float = 1301.0 + float(i) * 11.73
		var x_ratio: float = _hash_float(seed + 0.7)
		var width_px: float = lerp(rect.size.x * 0.045, rect.size.x * 0.12, _hash_float(seed + 2.1))
		var y_shift: float = sin(effect_time * lerp(0.1, 0.24, _hash_float(seed + 3.8)) + seed) * rect.size.y * 0.03
		var density: float = _rain_density_field(Vector2(x_ratio, 0.34 + _hash_float(seed + 5.2) * 0.4), motion_distance, heavy * 0.75, -1)
		if density <= 0.18:
			continue
		var alpha: float = strength * lerp(0.012, 0.055, density) * lerp(0.8, 1.25, heavy)
		var top: Vector2 = Vector2(rect.position.x + x_ratio * rect.size.x, rect.position.y - rect.size.y * 0.08 + y_shift)
		var bottom: Vector2 = top + base_direction * rect.size.y * lerp(0.42, 0.72, _hash_float(seed + 7.1))
		draw_line(top, bottom, Color(0.62, 0.72, 0.84, alpha), width_px)


func _draw_ground_rain_mist(rect: Rect2, effect_time: float, strength: float, heavy: float) -> void:
	var mist_strength: float = clamp(strength * 0.7 + heavy * 0.35, 0.0, 1.0)
	if mist_strength <= 0.02:
		return
	draw_rect(
		Rect2(
			Vector2(rect.position.x, rect.position.y + rect.size.y * 0.76),
			Vector2(rect.size.x, rect.size.y * 0.24)
		),
		Color(0.74, 0.8, 0.88, mist_strength * 0.032),
		true
	)
	var puff_count: int = int(lerp(5.0, 11.0, mist_strength))
	for i in range(puff_count):
		var seed: float = 1703.0 + float(i) * 23.17
		var radius: float = lerp(rect.size.x * 0.08, rect.size.x * 0.18, _hash_float(seed + 0.6))
		var x: float = rect.position.x + _hash_float(seed + 1.8) * rect.size.x
		var y: float = rect.position.y + rect.size.y * lerp(0.82, 0.97, _hash_float(seed + 3.2))
		y += sin(effect_time * lerp(0.16, 0.34, _hash_float(seed + 4.7)) + seed) * rect.size.y * 0.012
		var alpha: float = mist_strength * lerp(0.018, 0.06, _hash_float(seed + 6.3))
		draw_circle(Vector2(x, y), radius, Color(0.78, 0.83, 0.9, alpha))
		draw_circle(Vector2(x + radius * 0.56, y + radius * 0.04), radius * 0.72, Color(0.8, 0.85, 0.92, alpha * 0.76))
		draw_circle(Vector2(x - radius * 0.48, y + radius * 0.06), radius * 0.62, Color(0.74, 0.8, 0.88, alpha * 0.58))


func _rain_density_field(normalized_pos: Vector2, motion_distance: float, heavy: float, layer_index: int) -> float:
	var u: float = fposmod(normalized_pos.x, 1.0)
	var v: float = fposmod(normalized_pos.y, 1.0)
	var drift: float = motion_distance * 0.00008
	var band_noise: float = _tile_noise(u * 0.9 + drift, v * 0.55 + float(layer_index + 2) * 0.13, 91.0 + float(layer_index) * 13.0, true)
	var breakup_noise: float = _tile_noise(u * 2.4 - drift * 1.8, v * 1.6, 141.0 + float(layer_index) * 9.0, false)
	var vertical_bias: float = lerp(0.86, 1.08 + heavy * 0.1, _smoothstep(0.08, 0.9, v))
	return clamp((band_noise * 0.72 + breakup_noise * 0.28) * vertical_bias, 0.0, 1.0)


func _draw_lightning(rect: Rect2) -> void:
	var flash: float = float(environment.get("lightning_flash"))
	if flash <= 0.001:
		return
	var alpha: float = pow(flash, 1.7) * 0.74
	draw_rect(rect, Color(1.0, 1.0, 1.0, alpha), true)
	var bolt_alpha: float = alpha * 0.8
	if bolt_alpha > 0.02:
		var time: float = float(environment.get("effect_time"))
		var base_seed: float = floor(time * 3.0) * 31.0 + 77.0
		var start_x: float = rect.position.x + _hash_float(base_seed + 0.1) * rect.size.x * 0.7 + rect.size.x * 0.15
		var current := Vector2(start_x, rect.position.y)
		var segments: int = 6
		for i in range(segments):
			var next := current + Vector2(
				lerp(-22.0, 22.0, _hash_float(base_seed + float(i) * 3.1)),
				rect.size.y * lerp(0.06, 0.12, _hash_float(base_seed + float(i) * 2.7))
			)
			draw_line(current, next, Color(1.0, 1.0, 1.0, bolt_alpha), 2.0)
			draw_line(current, next, Color(0.7, 0.86, 1.0, bolt_alpha * 0.55), 4.0)
			current = next
		if current.y < rect.position.y + rect.size.y * 0.76:
			var tail := Vector2(current.x + lerp(-12.0, 12.0, _hash_float(base_seed + 99.0)), rect.position.y + rect.size.y * 0.82)
			draw_line(current, tail, Color(1.0, 1.0, 1.0, bolt_alpha * 0.9), 2.0)
			draw_line(current, tail, Color(0.7, 0.86, 1.0, bolt_alpha * 0.45), 4.0)


func _weather_strength(weather_id: String) -> float:
	if environment != null and environment.has_method("get_weather_strength"):
		return float(environment.call("get_weather_strength", weather_id))
	return 0.0


func _env_float(property_name: String, fallback: float) -> float:
	if environment == null:
		return fallback
	var value: Variant = environment.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _env_vector2(property_name: String, fallback: Vector2) -> Vector2:
	if environment == null:
		return fallback
	var value: Variant = environment.get(property_name)
	if value is Vector2:
		return value as Vector2
	return fallback


func _env_bool(property_name: String, fallback: bool) -> bool:
	if environment == null:
		return fallback
	var value: Variant = environment.get(property_name)
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback


func _precipitation_scroll_offset(rect: Rect2) -> Vector2:
	if not _env_bool("anchor_precipitation_to_world", true):
		return Vector2.ZERO
	if environment == null or not environment.has_method("get_camera_world_rect"):
		return Vector2.ZERO
	var world_rect_value: Variant = environment.call("get_camera_world_rect")
	if not (world_rect_value is Rect2):
		return Vector2.ZERO
	var world_rect: Rect2 = world_rect_value as Rect2
	if world_rect.size.x <= 0.001 or world_rect.size.y <= 0.001:
		return Vector2.ZERO
	var scale := Vector2(rect.size.x / world_rect.size.x, rect.size.y / world_rect.size.y)
	return Vector2(world_rect.position.x * scale.x, world_rect.position.y * scale.y)


func _camera_uv_offset(rect: Rect2, strength: float) -> Vector2:
	if environment == null or not environment.has_method("get_camera_world_rect"):
		return Vector2.ZERO
	var world_rect_value: Variant = environment.call("get_camera_world_rect")
	if not (world_rect_value is Rect2):
		return Vector2.ZERO
	var world_rect: Rect2 = world_rect_value as Rect2
	if world_rect.size.x <= 0.001 or world_rect.size.y <= 0.001 or rect.size.x <= 0.001 or rect.size.y <= 0.001:
		return Vector2.ZERO
	return Vector2(
		world_rect.position.x / world_rect.size.x,
		world_rect.position.y / world_rect.size.y
	) * strength


func _update_rain_motion(target_speed: float, effect_time: float) -> float:
	if not _rain_motion_initialized:
		_rain_motion_initialized = true
		_last_effect_time = effect_time
		_rain_motion_speed = target_speed
		return _rain_motion_distance
	var delta: float = effect_time - _last_effect_time
	_last_effect_time = effect_time
	if delta < 0.0:
		delta = 0.0
	elif delta > 0.25:
		delta = 0.25
	var blend: float = 1.0 - exp(-delta * 8.0)
	_rain_motion_speed = lerp(_rain_motion_speed, target_speed, blend)
	_rain_motion_distance += _rain_motion_speed * delta
	return _rain_motion_distance


func _load_shader(relative_path: String) -> Shader:
	var script := get_script() as Script
	if script == null:
		return null
	var shader_path := "%s/%s" % [script.resource_path.get_base_dir(), relative_path]
	if not ResourceLoader.exists(shader_path):
		return null
	var resource := load(shader_path)
	if resource is Shader:
		return resource as Shader
	return null


func _generate_cloud_mask_texture(width: int, height: int, seed: float) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var v: float = float(y) / float(max(1, height - 1))
		var top_fade: float = 1.0 - _smoothstep(0.34, 0.98, v)
		for x in range(width):
			var u: float = float(x) / float(max(1, width - 1))
			var density: float = 0.0
			for i in range(9):
				var local_seed: float = seed + float(i) * 17.31
				var center := Vector2(
					_hash_float(local_seed + 0.3),
					lerp(0.18, 0.62, _hash_float(local_seed + 1.9))
				)
				var radius_x: float = lerp(0.12, 0.28, _hash_float(local_seed + 2.6))
				var radius_y: float = lerp(0.08, 0.18, _hash_float(local_seed + 3.8))
				var dx: float = (u - center.x) / radius_x
				var dy: float = (v - center.y) / radius_y
				var dist: float = sqrt(dx * dx + dy * dy)
				density += 1.0 - _smoothstep(0.52, 1.0, dist)
			density = clamp(density / 3.5, 0.0, 1.0)
			var breakup: float = _tile_noise(u, v, seed * 0.071, false)
			var alpha: float = clamp((density * 0.78 + breakup * 0.32) * top_fade, 0.0, 1.0)
			image.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))
	return ImageTexture.create_from_image(image)


func _generate_fog_mask_texture(width: int, height: int, seed: float) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var v: float = float(y) / float(max(1, height - 1))
		var vertical_band: float = _smoothstep(0.24, 0.68, v)
		for x in range(width):
			var u: float = float(x) / float(max(1, width - 1))
			var density: float = 0.0
			for i in range(8):
				var local_seed: float = seed + float(i) * 13.73
				var center := Vector2(
					_hash_float(local_seed + 0.5),
					lerp(0.48, 0.9, _hash_float(local_seed + 2.2))
				)
				var radius_x: float = lerp(0.18, 0.34, _hash_float(local_seed + 3.0))
				var radius_y: float = lerp(0.06, 0.12, _hash_float(local_seed + 4.6))
				var dx: float = (u - center.x) / radius_x
				var dy: float = (v - center.y) / radius_y
				var dist: float = sqrt(dx * dx + dy * dy)
				density += 1.0 - _smoothstep(0.46, 1.0, dist)
			density = clamp(density / 3.0, 0.0, 1.0)
			var veil: float = _tile_noise(u, v, seed * 0.043, true)
			var alpha: float = clamp((density * 0.64 + veil * 0.46) * vertical_band, 0.0, 1.0)
			image.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))
	return ImageTexture.create_from_image(image)


func _generate_tile_noise_texture(width: int, height: int, seed: float, fluid: bool) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var v: float = float(y) / float(max(1, height - 1))
		for x in range(width):
			var u: float = float(x) / float(max(1, width - 1))
			var value: float = _tile_noise(u, v, seed, fluid)
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return ImageTexture.create_from_image(image)


func _generate_fast_noise_texture(width: int, height: int, seed: float, fluid: bool) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var v: float = float(y) / float(max(1, height - 1))
		for x in range(width):
			var u: float = float(x) / float(max(1, width - 1))
			var value: float = 0.5 + 0.22 * sin(TAU * (u * 1.7 + v * 1.3 + seed * 0.013))
			if fluid:
				value += 0.14 * cos(TAU * (u * 2.6 - v * 1.9 + seed * 0.021))
			image.set_pixel(x, y, Color(clamp(value, 0.0, 1.0), clamp(value, 0.0, 1.0), clamp(value, 0.0, 1.0), 1.0))
	return ImageTexture.create_from_image(image)


func _generate_fast_mask_texture(width: int, height: int, seed: float, is_fog: bool) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var v: float = float(y) / float(max(1, height - 1))
		var vertical_fade: float = 1.0 - _smoothstep(0.32, 0.96, v)
		if is_fog:
			vertical_fade = _smoothstep(0.18, 0.82, v)
		for x in range(width):
			var u: float = float(x) / float(max(1, width - 1))
			var wave_a: float = 0.5 + 0.5 * sin(TAU * (u * 1.2 + seed * 0.017))
			var wave_b: float = 0.5 + 0.5 * cos(TAU * (u * 2.1 - v * 0.8 + seed * 0.011))
			var alpha: float = clamp((wave_a * 0.55 + wave_b * 0.45) * vertical_fade, 0.0, 1.0)
			image.set_pixel(x, y, Color(alpha, alpha, alpha, alpha))
	return ImageTexture.create_from_image(image)


func _tile_noise(u: float, v: float, seed: float, fluid: bool) -> float:
	var value: float = 0.5
	value += 0.22 * sin(TAU * (u * 2.0 + v * 1.0 + seed * 0.13))
	value += 0.16 * sin(TAU * (u * 5.0 - v * 3.0 + seed * 0.27))
	value += 0.1 * sin(TAU * (u * 9.0 + v * 7.0 + seed * 0.41))
	if fluid:
		value += 0.08 * cos(TAU * (u * 4.0 + v * 6.0 + seed * 0.33))
		value += 0.06 * cos(TAU * (u * 11.0 - v * 2.0 + seed * 0.19))
	return clamp(value, 0.0, 1.0)


func _hash_float(value: float) -> float:
	var raw: float = sin(value * 12.9898 + 78.233) * 43758.5453
	return raw - floor(raw)


func _load_weather_texture(file_name: String) -> Texture2D:
	if environment != null and environment.has_method("get_weather_asset_path"):
		return _load_texture_from_file(str(environment.call("get_weather_asset_path", file_name)))
	var script := get_script() as Script
	if script != null:
		return _load_texture_from_file("%s/assets/weather/%s" % [script.resource_path.get_base_dir(), file_name])
	return null


func _load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path)
		if imported is Texture2D:
			return imported
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if abs(edge1 - edge0) < 0.00001:
		return 1.0 if value >= edge1 else 0.0
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _target_rect() -> Rect2:
	var parent_control := get_parent() as Control
	if parent_control != null:
		return Rect2(Vector2.ZERO, parent_control.size)
	if environment != null and environment.has_method("get_overlay_target_rect"):
		var rect_value: Variant = environment.call("get_overlay_target_rect")
		if rect_value is Rect2:
			var target_rect := rect_value as Rect2
			if target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
				return target_rect
	return Rect2()

