# Cubedot
Cubic voxel engine for Godot

# Mods API
Mod data is stored under the mods subdirectory, active mods are loaded in alphabetical order. Mod data includes JSON definitions or model image and sound assets.

- mod/mod.json: Stores the global settings of this mod. If multiple mods are active the settings will overwrite one another in alphabetical order. Settings include:
	- name: An unique name for this mod.
	- resolution: The internal resolution at which the voxel system works. Units smaller than this may not exist, LOD levels act as multipliers to this value. Should be a multiple or division of two. Smaller values result in more detail but may greatly impact performance.
	- generate_size: The scale of the noise used by the terrain generator. Larger values result in smoother terrains and bigger caves.
	- generate_density_up: The density of terrain noise increases by this amount the higher up you go. Lower values result in taller cliffs.
	- generate_density_down: The density of terrain noise decreases by this amount the lower down you go. Lower values result in deeper valleys.

- mod/nodes: JSON definitions of voxel types. Each file represents an unique node. Options include:
	- name: The unique name of this material, eg: "dirt"
	- material: The material file from "mod/materials" used by this node. Different materials will generate different meshes so be mindful of the performance impact.
	- layer: The layer this material is rendered on. Faces between materials on the same layer are hidden to improve performance. This should only be non-zero for transparent surfaces of different types.
	- lod: This material is ignored if a chunk is rendered beyond this resolution. Increases performance by not generating more faces at a distance. Use lower numbers if the material is less noticeable and won't look bad by popping in and out of view.
	- generate: When present this material is used by the terrain generator and will appear in the world. Contains the following settings:
		- resolution_horizontal: Mandatory, resolution of the noise check in the X and Z axes. Higher values improve performance but reduce the terrain detail. Should be a power or division of two and never lower than the mod's minimum resolution.
		- resolution_vertical: Mandatory, resolution of the noise check in the Y axis.
		- density_min: The minimum density noise must have for this material to appear. Noise increases or decreases with height while ground level is 0.
		- density_max: The maximum density noise must have.
		- offset: The Y position of the density check is offset by this number of grid units. Useful to make some materials appear on top of other surfaces which should have identical density settings.
