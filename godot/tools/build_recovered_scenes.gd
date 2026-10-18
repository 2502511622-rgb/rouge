extends SceneTree
## Generate native editable Godot nodes, not an embedded emulator or flat screenshot.
func _initialize() -> void:
	for scene_name in ["village", "title", "dialogue"]:
		build_scene(scene_name)
	quit(0)

func build_scene(scene_name: String) -> void:
	var base := "res://assets/verified/" + scene_name + "/"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "scene.json"))
	var root := Node2D.new()
	root.name = "Recovered_" + scene_name
	root.set_meta("source", "mGBA VRAM/OAM/palette snapshot; frame reconstruction, not game logic")
	root.set_meta("pixel_comparison", data.comparison)
	var label := Label.new()
	label.name = "Status"
	label.position = Vector2(30, 12)
	label.text = "ORIGINAL " + scene_name.to_upper() + " / editable tile layers + sprites / static verified checkpoint"
	root.add_child(label)
	label.owner = root
	var guide := Label.new()
	guide.name = "Guide"
	guide.position = Vector2(30, 718)
	guide.text = "1: Village    2: Title    3: Dialogue    P: Placeholder prototype\nOpen Viewport/Screen/BG nodes to edit native tilemaps; OBJ nodes contain separate original sprites. Gameplay is not ported."
	root.add_child(guide)
	guide.owner = root
	var container := SubViewportContainer.new()
	container.name = "Viewport"
	container.position = Vector2(96, 60)
	container.size = Vector2(960, 640)
	container.stretch = true
	container.stretch_shrink = 4
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(container)
	container.owner = root
	var viewport := SubViewport.new()
	viewport.name = "Screen"
	viewport.size = Vector2i(240, 160)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	viewport.owner = root
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.size = Vector2(240,160)
	# Backdrop color is stored from actual palette entry 0, not guessed from screenshot.
	var pal: Array = data.backdrop
	backdrop.color = Color(float(pal[0])/255, float(pal[1])/255, float(pal[2])/255)
	backdrop.z_index = -100
	viewport.add_child(backdrop)
	backdrop.owner = root
	for layer in data.layers:
		var tiles := TileSet.new()
		tiles.tile_size = Vector2i(8,8)
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load(base + layer.atlas)
		atlas.texture_region_size = Vector2i(8,8)
		tiles.add_source(atlas, 0)
		var map := TileMapLayer.new()
		map.name = "BG%d" % int(layer.bg)
		map.tile_set = tiles
		map.position = -Vector2(layer.scroll[0], layer.scroll[1])
		map.z_index = -int(layer.priority) * 10 - int(layer.bg)
		map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		map.set_meta("rom_semantics", "Loaded GBA text BG; no collision or world coordinates inferred")
		viewport.add_child(map)
		map.owner = root
		for y in range(layer.height_tiles):
			for x in range(layer.width_tiles):
				var cell = layer.grid[y][x]
				if cell == null:
					continue
				var coords := Vector2i(int(cell[0]), int(cell[1]))
				if not atlas.has_tile(coords):
					atlas.create_tile(coords)
				var flags := 0
				if cell[2]:
					flags |= TileSetAtlasSource.TRANSFORM_FLIP_H
				if cell[3]:
					flags |= TileSetAtlasSource.TRANSFORM_FLIP_V
				# BGs repeat; populate one extra copy where the captured viewport wraps.
				for dx in [0, int(layer.width_tiles)]:
					for dy in [0, int(layer.height_tiles)]:
						map.set_cell(Vector2i(x+dx,y+dy), 0, coords, flags)
	for object in data.objects:
		var sprite := Sprite2D.new()
		sprite.name = "OBJ_%03d" % int(object.oam_index)
		sprite.centered = false
		sprite.texture = load(base + object.image)
		sprite.position = Vector2(object.position[0],object.position[1])
		sprite.z_index = -int(object.priority) * 10 + 5
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.set_meta("oam_attributes", object)
		# Lower OAM index wins: later nodes at equal z draw on top.
		viewport.add_child(sprite)
		viewport.move_child(sprite, 1 + data.layers.size())
		sprite.owner = root
	root.set_script(load("res://scripts/recovered_scene.gd"))
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed,"res://scenes/recovered_" + scene_name + ".tscn") == OK)
	print("Saved native scene: ", scene_name, " layers=",data.layers.size()," sprites=",data.objects.size())
	root.free()
