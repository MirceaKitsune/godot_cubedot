# Cubedot
Cubic voxel engine for Godot

# Mods API
Mod data is stored under the mods subdirectory, active mods are loaded in alphabetical order. Mod data includes JSON definitions or model image and sound assets.

- mod/mod.json: Stores the global settings of this mod. If multiple mods are active the settings will overwrite one another in alphabetical order. Settings include:
	- name (string): An unique name for this mod.
	- seed (integer): Noise seed for the terrain generator. To get an unique world each time use -1.
	- resolution (float): The internal resolution at which the voxel system works. Units smaller than this may not exist, LOD levels act as multipliers to this value. Should be a multiple or division of two. Smaller values result in more detail but may greatly impact performance.
	- resolution_texture (integer): The scale of voxel textures relative to the voxel resolution. The maximum value is 1, textures larger than the voxel size cause out of sync mapping and are not supported.
	- layer_solid (integer): The last node layer that is solid. Nodes on layers above this will not produce any collisions.
	- mapgen (dictionary): Global map generator settings used when creating the world. Settings include:
		- size (float): The scale of the noise used by the terrain generator. Larger values result in smoother terrains and bigger caves.
		- density_up (float): The density of terrain noise increases by this amount the higher up you go. Lower values result in taller cliffs.
		- density_down (float): The density of terrain noise decreases by this amount the lower down you go. Lower values result in deeper valleys.

- mod/nodes: JSON definitions of voxel types. Each file represents an unique node. Options include:
	- name (string): The unique name of this material, eg: "dirt"
	- material (array): The material files from "mod/materials" used by this node. Different materials will generate different meshes so be mindful of the performance impact. The array contains up to six values: First entry is bottom, second is top, the following four are the sides.
	- layer (integer): The layer this material is rendered on. Faces between materials on the same layer are hidden to improve performance. This should only be non-zero for transparent surfaces of different types.
	- lod (integer): This material is ignored if a chunk is rendered beyond this resolution. Increases performance by not generating more faces at a distance. Use lower numbers if the material is less noticeable and won't look bad by popping in and out of view.
	- mapgen (dictionary): When present this material is used by the terrain generator and will appear in the world. Contains the following settings:
		- resolution_horizontal (float): Mandatory, resolution of the noise check in the X and Z axes. Higher values improve performance but reduce the terrain detail. Should be a power or division of two and never lower than the mod's minimum resolution.
		- resolution_vertical (float): Mandatory, resolution of the noise check in the Y axis.
		- height_min: Hard minimum Y position at which this node will appear. Will cause sharp cutoffs, use only when necessary in favor of density. Set to null to define no limit.
		- height_max: Hard maximum Y position at which this node will appear.
		- density_min (float): The minimum density noise must have for this material to appear. Noise increases or decreases with height whereas ground level is 0. To disable set this to null.
		- density_max (float): The maximum density noise must have.
		- top (integer): Mandatory for technical reasons, use 0 to disable. The node is repeated this number of times on the Y axis if a node was found below it. Useful to make some materials appear on top of others.
