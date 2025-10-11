# Replicate Lights and Objects

A BeamNG.drive editor extension that automatically replicates lights and TSStatic objects relative to template shapes throughout your map.

## Features
- Copy lights and objects positioned relative to a template shape
- Works with both TSStatic objects and Forest items as templates
- Batch generation across all matching shapes in the scene
- Full undo/redo support
- Flexible grouping options

## Installation
Place `alexkiddGenerateLights.lua` in:
```
BeamNG.drive/lua/ge/extensions/editor/
```

## Quick Start

1. **Open the tool** - In the World Editor, go to Windows menu → "Replicate Lights and Objects"

2. **Set up your template** - Place lights/objects around one instance of your shape (e.g., a streetlight model with a PointLight)

3. **Select template** - Click the shape, then "Get Object by Selection"

4. **Select objects to replicate** - Multi-select your lights/TSStatic objects, click respective "Get by Selection" buttons

5. **Generate** - Click generate to create copies at all matching shapes in your map

## Example Use Cases
- Street lighting along roads with identical lamp posts
- Window lights for buildings using the same model
- Decorative objects around repeated environment pieces
- Forest item illumination

## Options
- **Use New Folder** - Groups generated objects in a numbered folder for easy management

## Author
Sascha Kleinwächter (AlexKidd71)
