# Master Spline Editor - JSON Save/Load User Guide

## Overview

With this mod the Master Spline Editor now supports saving and loading your spline configurations to JSON files. This allows you to:

- **Backup** your spline work before making changes
- **Share** spline configurations between projects or with others
- **Restore** splines in one of your next modding sessions

This mod is a temporary solution until we get official support for that feature.

---

## New Features

### Save Button
Saves all Master Splines and their linked splines (Road, Mesh, Assembly, Decal) to a JSON file.

### Load Button
Loads Master Splines and linked splines from a JSON file, replacing the current configuration.

---

## How to Use

### Saving Splines

1. Open the **Master Spline Editor** in the World Editor
2. Create or modify your Master Splines and linked splines as usual
3. Click the **Save** button (disk icon) in the toolbar
4. Choose a location and filename for your JSON file
5. Your splines are now saved!

### Loading Splines

1. Open the **Master Spline Editor** in the World Editor
2. Click the **Load** button (folder icon) in the toolbar
3. Navigate to your saved JSON file and select it
4. All splines will be restored, including:
   - Master Spline positions and settings
   - All linked Road Splines with their DecalRoad layers
   - All linked Mesh Splines with their mesh configurations
   - All linked Assembly Splines with their molecule setups
   - All linked Decal Splines

---

## ⚠️ Important Warnings

This mod replaces original lua game files and is based on the **0.38.1** version of BeamNG. It can break with every hotfix or update!

### DO NOT Rename Scene Tree Folders!

Each spline creates a folder in the Scene Tree with a specific naming format:

```
[Spline Name] - [UUID]
```

For example:
- `Road Spline 1 - 8dcaa210-f99d-40a8-a3eb-4313d14a39e7`
- `Mesh Spline 1 - 6f4510bc-200c-4bfd-8c96-7e09e6e903c1`
- `Assembly Spline 1 - 6b11738c-caca-44a8-bd6c-4936ccc1aa01`

**⚠️ WARNING: Do NOT rename these folders or remove the UUID portion!**

The UUID (the long string of letters and numbers after the dash) is critical for:
- Proper cleanup when loading JSON files
- Preventing duplicate objects across sessions
- Maintaining links between Master Splines and their children

If you rename these folders, loading a JSON file may create duplicate objects or fail to clean up old objects properly.

### What You CAN Safely Change

✅ Rename splines using the spline editor's rename function (this updates the folder name correctly)
✅ Move spline folders to different locations in the Scene Tree hierarchy
✅ Delete splines using the spline editor's delete function

### What You Should AVOID

❌ Manually renaming folders in the Scene Tree
❌ Removing the UUID from folder names

---

## Cross-Session Compatibility

The save/load system is designed to work across game sessions:

1. **Save** your splines
2. **Close** the game completely
3. **Restart** the game and load the same map
4. **Load** your JSON file - it will work correctly!

The system automatically:
- Prevents duplicate DecalRoads, meshes, and assembly objects for splines managed by the json file.

---

## Troubleshooting

### Problem: Splines don't appear after loading
**Solution**: The splines are loaded but may need a moment to regenerate. If they still don't appear, try:
1. Select a different tool and come back to Master Spline Editor
2. Or use `Ctrl+L` to reload Lua (last resort)

### Problem: Duplicate objects in Scene Tree after loading
**Possible causes**:
- The folder names were manually renamed (UUIDs removed)
- The JSON file was edited and IDs were changed

**Solution**: 
1. Delete all the duplicate folders manually in Scene Tree
2. Load the JSON file again
3. Don't rename folders in the future

### Problem: Linked splines missing after load
**Solution**: Check that:
1. The linked spline data exists in the JSON file
2. The link relationships are preserved (linkedSplineId fields)
3. The correct spline type is specified

### Problem: Road Spline DecalRoads not visible
**Solution**: The system now forces an update after loading. If still not visible:
1. Select the Road Spline in the editor
2. Make a small change (move a node slightly)
3. This triggers a refresh

---

## JSON File Location

By default, JSON files are saved to and loaded from your BeamNG user folder:
```
%LocalAppData%/BeamNG.drive/current/levels/[map_name]/
```

You can choose any location when saving/loading.

---

## Technical Notes

- JSON files preserve all spline data including positions, widths, materials, and settings
- The `id` field in each spline is a UUID that uniquely identifies it
- Scene tree folders are named with these UUIDs for proper tracking
- Loading replaces ALL current splines managed by the json file (it's a full replacement, not a merge)

---
