tool
extends Reference

var _config

func init(config):
	_config = config


func export_file(file_name: String, output_folder: String, options: Dictionary) -> Dictionary:
	var exception_pattern = options.get('exception_pattern', "")
	var only_visible_layers = options.get('only_visible_layers', false)
	var output_name = file_name if options.get('output_filename') == "" else options.get('output_filename')
	var basename = _get_file_basename(output_name)
	var output_dir = output_folder.replace("res://", "./")
	var data_file = "%s/%s.json" % [output_dir, basename]
	var sprite_sheet = "%s/%s.png" % [output_dir, basename]
	var output = []
	var arguments = _export_command_common_arguments(file_name, data_file, sprite_sheet, options)

	if not only_visible_layers:
		arguments.push_front("--all-layers")

	_add_ignore_layer_arguments(file_name, arguments, exception_pattern)

	var exit_code = _execute(arguments, output)

	if exit_code != 0:
		printerr('aseprite: failed to export spritesheet')
		printerr(output)
		return {}

	return {
		'data_file': data_file.replace("./", "res://"),
		"sprite_sheet": sprite_sheet.replace("./", "res://")
	}


func export_layers(file_name: String, output_folder: String, options: Dictionary) -> Array:
	var exception_pattern = options.get('exception_pattern', "")
	var only_visible_layers = options.get('only_visible_layers', false)
	var basename = _get_file_basename(file_name)
	var output_dir = output_folder.replace("res://", "./")
	var layers = list_layers(file_name, only_visible_layers)
	var exception_regex = _compile_regex(exception_pattern)

	var output = []

	for layer in layers:
		if layer != "" and (not exception_regex or exception_regex.search(layer) == null):
			output.push_back(_export_layer(file_name, layer, output_dir, options))

	return output


func _export_layer(file_name: String, layer_name: String, output_folder: String, options: Dictionary) -> Dictionary:
	var output_prefix = options.get('output_filename', "")
	var data_file = "%s/%s%s.json" % [output_folder, output_prefix, layer_name]
	var sprite_sheet = "%s/%s%s.png" % [output_folder, output_prefix, layer_name]
	var output = []
	var arguments = _export_command_common_arguments(file_name, data_file, sprite_sheet, options)
	arguments.push_front(layer_name)
	arguments.push_front("--layer")

	var exit_code = _execute(arguments, output)

	if exit_code != 0:
		print('aseprite: failed to export layer spritesheet')
		print(output)
		return {}

	return {
		'data_file': data_file.replace("./", "res://"),
		"sprite_sheet": sprite_sheet.replace("./", "res://")
	}


func _add_ignore_layer_arguments(file_name: String, arguments: Array, exception_pattern: String):
	var layers = _get_exception_layers(file_name, exception_pattern)
	if not layers.empty():
		for l in layers:
			arguments.push_front(l)
			arguments.push_front('--ignore-layer')


func _get_exception_layers(file_name: String, exception_pattern: String) -> Array:
	var layers = list_layers(file_name)
	var regex = _compile_regex(exception_pattern)
	if regex == null:
		return []

	var exception_layers = []
	for layer in layers:
		if regex.search(layer) != null:
			exception_layers.push_back(layer)

	return exception_layers


func list_layers(file_name: String, only_visible = false) -> Array:
	var output = []
	var arguments = ["-b", "--list-layers", file_name]

	if not only_visible:
		arguments.push_front("--all-layers")

	var exit_code = _execute(arguments, output)

	if exit_code != 0:
		printerr('aseprite: failed listing layers')
		printerr(output)
		return []

	if output.empty():
		return output

	return output[0].split('\n')


func _export_command_common_arguments(source_name, data_path, spritesheet_path, options):
	var arguments = [
		"-b",
		"--list-tags",
		"--sheet-pack",
		"--data",
		data_path,
		"--format",
		"json-array",
		"--sheet",
		spritesheet_path,
		source_name
	]

	if options.get('trim_images', false):
		arguments.push_front("--trim")

	if options.get('trim_by_grid', false):
		arguments.push_front('--trim-by-grid')
	
	return arguments


func _execute(arguments, output):
	return OS.execute(_aseprite_command(), arguments, true, output, true)


func _aseprite_command() -> String:
	return _config.get_command()


func _get_file_basename(file_path: String) -> String:
	return file_path.get_file().trim_suffix('.%s' % file_path.get_extension())


func _compile_regex(pattern):
	if pattern == "":
		return

	var rgx = RegEx.new()
	if rgx.compile(pattern) == OK:
		return rgx

	printerr('exception regex error')


func test_command():
	var exit_code = OS.execute(_aseprite_command(), ['--version'], true)
	return exit_code == 0