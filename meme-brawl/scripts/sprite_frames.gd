extends RefCounted
## Extract complete, individually transparent poses. No shared-atlas sampling at
## draw time: a sword crossing a nominal cell remains part of its owner frame.

const MANIFEST = "res://assets/art/frame_manifest.json"
const PREFIX = "res://assets/art/"
static var manifest: Dictionary = {}
static var raw_sources: Dictionary = {}
static var cache: Dictionary = {}

static func data() -> Dictionary:
	if manifest.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		assert(parsed is Dictionary and parsed.get("version",0) == 1,"Sprite frame manifest missing or invalid")
		manifest = parsed
	return manifest

static func get_frame(sheet: String, index: int) -> Dictionary:
	var key := sheet+":"+str(index)
	if cache.has(key): return cache[key]
	var sheet_data: Dictionary = data().sheets[sheet]
	var frame: Dictionary = sheet_data.frames[index]
	if not raw_sources.has(sheet):
		if FileAccess.file_exists(PREFIX+sheet):
			assert(FileAccess.get_sha256(PREFIX+sheet) == sheet_data.sha256,"Atlas content changed; rebuild frame_manifest.json")
		var source: Texture2D = load(PREFIX+sheet)
		var image := source.get_image()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		assert(image.get_width() == int(sheet_data.width) and image.get_height() == int(sheet_data.height),"Atlas dimensions changed; rebuild frame manifest")
		raw_sources[sheet] = image.get_data()
	var rgba: PackedByteArray = raw_sources[sheet]
	var pixels := PackedByteArray()
	var box: Array = frame.box
	var runs: Array = frame.runs
	for n in range(0,runs.size(),3):
		var destination := int(runs[n])*4
		var length := int(runs[n+1])*4
		var source := int(runs[n+2])*4
		assert(destination >= pixels.size(),"Frame pixel runs overlap")
		pixels.resize(destination)
		pixels.append_array(rgba.slice(source,source+length))
	pixels.resize(int(box[2])*int(box[3])*4)
	var isolated := Image.create_from_data(int(box[2]),int(box[3]),false,Image.FORMAT_RGBA8,pixels)
	var r: Array = frame.reference
	var result := {"texture":ImageTexture.create_from_image(isolated),
		"box":Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3])),
		"reference":Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])),"attachments":[]}
	var visual_box: Rect2 = result.box
	for vertices in frame.get("attachments",[]):
		var points := PackedVector2Array()
		for point in vertices:
			var at := Vector2(float(point[0]),float(point[1]))
			points.append(at)
			visual_box = visual_box.expand(at)
		result.attachments.append(points)
	result["visual_box"] = visual_box
	cache[key] = result
	return result

static func battle_rect(frame: Dictionary, destination: Rect2) -> Rect2:
	var box: Rect2 = frame.box
	var reference: Rect2 = frame.reference
	return Rect2(destination.position+(box.position-reference.position)/reference.size*destination.size,
		box.size/reference.size*destination.size)

static func fit_rect(frame: Dictionary, destination: Rect2) -> Rect2:
	var box: Rect2 = frame.box
	var visual_box: Rect2 = frame.visual_box
	var factor := minf(destination.size.x/visual_box.size.x,destination.size.y/visual_box.size.y)
	return Rect2(destination.position+(destination.size-visual_box.size*factor)*Vector2(0.5,1)+(box.position-visual_box.position)*factor,box.size*factor)

static func attachments(frame: Dictionary, destination: Rect2, fit := false) -> Array:
	var output: Array = []
	var reference: Rect2 = frame.reference
	var visual_box: Rect2 = frame.visual_box
	var factor := minf(destination.size.x/visual_box.size.x,destination.size.y/visual_box.size.y)
	var origin := destination.position+(destination.size-visual_box.size*factor)*Vector2(0.5,1)
	for polygon in frame.attachments:
		var points := PackedVector2Array()
		for point in polygon:
			points.append(origin+(point-visual_box.position)*factor if fit else destination.position+(point-reference.position)/reference.size*destination.size)
		output.append(points)
	return output

static func prewarm() -> void:
	for sheet in data().sheets:
		var frames: Array = data().sheets[sheet].frames
		for index in range(frames.size()): get_frame(sheet,index)
