extends Node2D
## Workbench: evidence-backed tile candidates plus a separately authored ARPG prototype.
const CELL := 32
const ORIGIN := Vector2(36, 150)
const PLAYER := preload("res://scenes/player.tscn")
var config: Dictionary
var manifest: Dictionary
var rows: Array
var enemies: Array[Dictionary] = []
var player: Node2D
var message := "Clear four training enemies, then reach the gold gate."
var hud: Label
var browser: PanelContainer
var resource_list: ItemList
var texture_view: TextureRect
var evidence: Label
var resources: Array[Dictionary] = []
var selected: int = 0
var finished := false
var editor_mode := false
var baseline_rows: Array

func _ready() -> void:
	for pair in [["move_left", KEY_A, KEY_LEFT], ["move_right", KEY_D, KEY_RIGHT], ["move_up", KEY_W, KEY_UP], ["move_down", KEY_S, KEY_DOWN], ["attack", KEY_SPACE, KEY_J], ["potion", KEY_Q, KEY_Q]]:
		InputMap.add_action(pair[0])
		for key in [pair[1], pair[2]]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(pair[0], event)
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/prototype.json"))
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/rom_manifest.json"))
	baseline_rows = config["map"].duplicate()
	rows = baseline_rows.duplicate()
	build_ui()
	reset_world()
	if "--smoke-test" in OS.get_cmdline_user_args():
		run_smoke_test.call_deferred()

func reset_world() -> void:
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	enemies.clear()
	finished = false
	message = "Clear four training enemies, then reach the gold gate."
	player = PLAYER.instantiate()
	player.world = self
	player.speed = float(config.player.speed)
	player.max_hp = int(config.player.max_hp)
	player.hp = player.max_hp
	player.attack_damage = int(config.player.damage)
	add_child(player)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var pos := ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL
			if rows[y][x] == "P":
				player.position = pos
			if rows[y][x] == "E":
				enemies.append({"pos": pos, "hp": int(config.enemy.hp)})
	queue_redraw()

func build_ui() -> void:
	var title := Label.new()
	title.position = Vector2(36, 22)
	title.text = "SHINING SOUL / RECONSTRUCTION WORKBENCH"
	title.add_theme_font_size_override("font_size", 27)
	add_child(title)
	var info := Label.new()
	info.position = Vector2(36, 65)
	info.text = "ROM: AHUJ · 8 MiB · header verified | Prototype rules + artwork are placeholders\nWASD / arrows: move · Space / J: attack · Q: potion · R: reset · Tab: ROM browser"
	add_child(info)
	hud = Label.new()
	hud.position = Vector2(36, 112)
	add_child(hud)
	var side := Label.new()
	side.position = Vector2(830, 155)
	side.size = Vector2(290, 490)
	side.text = "EDITABLE PROJECT\n\nF2: toggle level editor\nLeft click: wall / floor\nF5: save edited map\nF6: load edited map\n\nEdit data/prototype.json\nfor map and combat tuning.\n\nEdit scenes/player.tscn\nand scripts/player.gd\nfor player behavior.\n\nTab: inspect extracted\nROM tile candidates.\n\nOriginal palettes, maps,\nsprites, AI, music and\nstory are NOT restored."
	add_child(side)
	browser = PanelContainer.new()
	browser.position = Vector2(25, 135)
	browser.size = Vector2(1100, 600)
	browser.visible = false
	add_child(browser)
	var hbox := HBoxContainer.new()
	browser.add_child(hbox)
	resource_list = ItemList.new()
	resource_list.custom_minimum_size = Vector2(310, 560)
	hbox.add_child(resource_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)
	evidence = Label.new()
	evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence.custom_minimum_size = Vector2(740, 125)
	right.add_child(evidence)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	texture_view = TextureRect.new()
	texture_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.add_child(texture_view)
	for record in manifest.resources:
		if record.has("preview"):
			resources.append(record)
			resource_list.add_item("0x%06X  %s" % [record.rom_offset, "LZ77 candidate" if record.classification == "unidentified_lz77_candidate" else "RAW 4bpp"])
	resource_list.item_selected.connect(show_resource)
	if resources.size() > 0:
		resource_list.select(0)
		show_resource(0)

func show_resource(index: int) -> void:
	selected = index
	var record: Dictionary = resources[index]
	texture_view.texture = load(record.preview)
	texture_view.custom_minimum_size = texture_view.texture.get_size() * 2
	evidence.text = "ROM offset 0x%06X · %d decoded bytes\n%s\nGrayscale 4bpp interpretation. Original palette, tile order and semantic identity are unverified. Tab returns to prototype." % [record.rom_offset, record.decoded_size, record.classification]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				browser.visible = not browser.visible
			KEY_R:
				reset_world()
			KEY_F2:
				editor_mode = not editor_mode
			KEY_F5:
				var f := FileAccess.open("user://edited_map.json", FileAccess.WRITE)
				f.store_string(JSON.stringify(rows, "  "))
				message = "Saved map: " + ProjectSettings.globalize_path("user://edited_map.json")
			KEY_F6:
				if FileAccess.file_exists("user://edited_map.json"):
					var saved = JSON.parse_string(FileAccess.get_file_as_string("user://edited_map.json"))
					if valid_map(saved):
						rows = saved
						reset_world()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and editor_mode and not browser.visible:
		var cell := Vector2i((get_global_mouse_position() - ORIGIN) / CELL)
		if cell.y > 0 and cell.y < rows.size() - 1 and cell.x > 0 and cell.x < rows[cell.y].length() - 1:
			var row: String = rows[cell.y]
			if row[cell.x] in [".", "#"]:
				rows[cell.y] = row.substr(0, cell.x) + ("." if row[cell.x] == "#" else "#") + row.substr(cell.x + 1)
		queue_redraw()

func valid_map(value: Variant) -> bool:
	if not value is Array or value.size() != baseline_rows.size():
		return false
	for row in value:
		if not row is String or row.length() != baseline_rows[0].length():
			return false
	return true

func _process(delta: float) -> void:
	player.visible = not browser.visible
	if not browser.visible and not editor_mode and player.hp > 0:
		for enemy in enemies:
			if enemy.hp <= 0:
				continue
			var displacement: Vector2 = player.position - enemy.pos
			if displacement.length() < 230 and displacement.length() > 23:
				var step: Vector2 = displacement.normalized() * float(config.enemy.speed) * delta
				if walkable(enemy.pos + Vector2(step.x, 0)):
					enemy.pos.x += step.x
				if walkable(enemy.pos + Vector2(0, step.y)):
					enemy.pos.y += step.y
			if displacement.length() < 25:
				player.hurt(int(config.enemy.contact_damage))
		if alive_count() == 0 and tile_at(player.position) == "G":
			finished = true
			message = "Prototype complete. This does not establish original-game fidelity."
	hud.text = "HP %d/%d    Potions %d    XP %d    Enemies %d    %s" % [player.hp, player.max_hp, player.potions, player.experience, alive_count(), "LEVEL EDITOR" if editor_mode else "PLAY"]
	queue_redraw()

func tile_at(point: Vector2) -> String:
	var local := point - ORIGIN
	if local.x < 0 or local.y < 0:
		return "#"
	var cell := Vector2i(local / CELL)
	if cell.y >= rows.size() or cell.x >= rows[cell.y].length():
		return "#"
	return rows[cell.y][cell.x]

func walkable(point: Vector2) -> bool:
	for corner in [Vector2(-8, -8), Vector2(8, -8), Vector2(-8, 8), Vector2(8, 8)]:
		if tile_at(point + corner) == "#":
			return false
	return true

func alive_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.hp > 0:
			count += 1
	return count

func attack(at: Vector2, direction: Vector2, damage: int, reach: float) -> void:
	for enemy in enemies:
		var difference: Vector2 = enemy.pos - at
		if enemy.hp > 0 and difference.length() <= reach and (difference.length() < 15 or direction.dot(difference.normalized()) > 0.1):
			enemy.hp -= damage
			if enemy.hp <= 0:
				player.experience += int(config.enemy.experience)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 768)), Color("101925"))
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var tile: String = rows[y][x]
			var rect := Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2.ONE * CELL)
			var floor_color := Color("2e4144") if (x + y) % 2 == 0 else Color("33484a")
			draw_rect(rect, Color("596977") if tile == "#" else floor_color)
			if tile == "#":
				draw_rect(Rect2(rect.position, Vector2(32, 5)), Color("8291a0"))
			if tile == "G":
				draw_rect(rect.grow(-5), Color("e9bc67") if alive_count() == 0 else Color("766548"))
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var pos: Vector2 = enemy.pos
		draw_circle(pos + Vector2(0, 5), 13, Color("b06075"))
		draw_circle(pos + Vector2(-4, 0), 2, Color("ffe4aa"))
		draw_circle(pos + Vector2(4, 0), 2, Color("ffe4aa"))
		draw_rect(Rect2(pos + Vector2(-13, -15), Vector2(26, 3)), Color("34232d"))
		draw_rect(Rect2(pos + Vector2(-13, -15), Vector2(26.0 * maxf(0, float(enemy.hp)) / float(config.enemy.hp), 3)), Color("ed8a91"))
	draw_string(ThemeDB.fallback_font, Vector2(36, 675), message, HORIZONTAL_ALIGNMENT_LEFT, 1080, 16, Color("d5dfeb"))
	draw_string(ThemeDB.fallback_font, Vector2(36, 718), "Evidence: analysis/rom_report.json | Candidate assets: assets/extracted | Original game logic not yet recovered", HORIZONTAL_ALIGNMENT_LEFT, 1080, 15, Color("8dabb8"))

func run_smoke_test() -> void:
	assert(manifest.header.game_code == "AHUJ")
	assert(manifest.header.header_checksum_valid)
	assert(resources.size() > 0)
	assert(alive_count() == 4)
	assert(walkable(player.position))
	var before: Vector2 = player.position
	Input.action_press("move_right")
	player._process(0.05)
	Input.action_release("move_right")
	assert(player.position.x > before.x)
	editor_mode = true
	before = player.position
	Input.action_press("move_right")
	player._process(0.05)
	Input.action_release("move_right")
	assert(player.position == before)
	editor_mode = false
	assert(not walkable(ORIGIN + Vector2(16, 16)))
	var first: Vector2 = enemies[0].pos
	attack(first, Vector2.DOWN, 999, 1)
	assert(alive_count() == 3)
	assert(player.experience == 10)
	player.hurt(8)
	assert(player.hp == 92)
	show_resource(0)
	assert(texture_view.texture != null)
	assert(valid_map(rows))
	print("SMOKE PASS: ROM manifest, textures, player movement, editor pause, collision, enemy damage, XP, player damage, map validation")
	get_tree().quit(0)
