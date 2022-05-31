extends Node

# Active mods to be scanned and loaded, currently static
const mods_active = ["default"]

# Data structures indexed by name
var settings: Dictionary
var nodes: Dictionary
var materials: Dictionary

func _get_files_json(path: String):
	var file = File.new()
	var json = JSON.new()
	file.open(path, File.READ)
	json.parse(file.get_as_text())
	return json.get_data()

func _get_files(directory: String):
	var list = []
	for mod in mods_active:
		var path = "res://mods/" + mod + "/" + directory
		var dir = Directory.new()
		if dir.open(path) == OK:
			dir.list_dir_begin()
			for f in dir.get_files():
				list.append({ name = f.split(".")[0], path = path + "/" + f })
			dir.list_dir_end()
	return list

func _init():
	# Combine the global settings of active mods
	for i in mods_active:
		var mod_setttings = _get_files_json("res://mods/" + i + "/mod.json")
		for s in mod_setttings:
			settings[s] = mod_setttings[s]

	# Node definitions
	var nodes_files = _get_files("nodes")
	for i in nodes_files:
		var node = _get_files_json(i.path)
		nodes[node.name] = node

	# Material definitions
	var material_files = _get_files("materials")
	for i in material_files:
		materials[i.name] = load(i.path)
