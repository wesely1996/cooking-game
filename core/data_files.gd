class_name DataFiles
extends RefCounted
## Small helpers for reading the JSON content files under res://data.


## Parses a JSON file. Returns null (and logs an error) when the file is
## missing or invalid.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data file not found: %s" % path)
		return null
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		push_error("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Lists the files in a directory with the given extension, sorted by name.
static func list_files(dir_path: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(extension):
			result.append(dir_path.path_join(file_name))
	result.sort()
	return result
