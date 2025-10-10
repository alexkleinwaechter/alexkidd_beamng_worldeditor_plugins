# Generate Lights Plugin - Forest Items Update

## 🎉 Version 2.0 - Now Supports Forest Items!

### What Changed

The plugin has been completely updated to support **BOTH** TSStatic objects AND Forest items with automatic detection!

### New Features

1. **Auto-Detection** 
   - Automatically detects whether you selected a TSStatic or Forest item
   - No mode switching needed - it just works!

2. **Forest Item Support**
   - Finds all forest items by shapeFile matching
   - Correctly handles forest item transforms and rotations
   - Works with instanced forest objects

3. **Unified Workflow**
   - Same simple 3-step process for both types
   - UI shows which type you selected
   - Generate lights for all matching objects (TSStatic or Forest) in one click

### Technical Improvements

#### New Functions Added:
- `getForestData()` - Access the Forest C++ object
- `quatFromMatrix(matrix)` - Extract quaternion rotation from transform matrix
- `getSelectedForestItem()` - Check if a forest item is selected
- `getTemplateFromSelection()` - Auto-detect TSStatic or Forest item selection
- `findForestItemsByShapeFile(shapeFile)` - Find all matching forest items
- `calculateRelativeTransforms()` - Updated to handle both types
- `createLightFromTemplate()` - Updated to handle both types
- `generateLights()` - Completely rewritten to support both types

#### Data Structure Changes:
```lua
-- Old:
selectedShapeId = 123

-- New:
selectedTemplate = {
  type = "TSStatic" or "ForestItem",
  id = ...,
  shapeName = "...",  -- for TSStatic
  shapeFile = "...",  -- for Forest items
  displayName = "..."
}
```

### How It Works

#### Step 1: Template Detection
When you click "Get Object by Selection":
1. First checks for TSStatic selection
2. If none, checks for Forest item selection
3. Stores appropriate identifiers (shapeName or shapeFile)

#### Step 2: Light Positioning
The plugin calculates light positions relative to the template using:
- Quaternion rotation math (works for both types)
- Local coordinate space conversion
- Transform matrix handling for forest items

#### Step 3: Light Generation
When you click "Generate Lights":
- **For TSStatic:** Searches scene tree for matching shapeName
- **For Forest items:** Searches ForestData for matching shapeFile
- Creates lights with correct positioning for ALL found objects

### Usage Examples

#### Example 1: TSStatic Lamp Posts
```
1. Select a TSStatic lamp post
2. Select its lights
3. Generate → Creates lights for all TSStatic lamp posts
```

#### Example 2: Forest Item Lamp Posts  
```
1. Select a Forest item lamp post (must be in Forest Editor mode)
2. Select its lights
3. Generate → Creates lights for all forest lamp posts
```

#### Example 3: Mixed Scene
If you have BOTH TSStatic and Forest item lamp posts:
- Select the TSStatic version → generates lights for TSStatic objects
- Select the Forest version → generates lights for Forest objects
- Run twice to cover both!

### UI Changes

The plugin now shows:
- **Type indicator:** Shows "Type: TSStatic" or "Type: ForestItem" in green
- **Better descriptions:** Updated tooltips and info text
- **Flexible selection:** Works with either type automatically

### Compatibility

✅ **Backward Compatible:** Still works perfectly with TSStatic objects
✅ **Forward Compatible:** Now also works with Forest items
✅ **Mixed Scenes:** Can handle scenes with both types

### Known Limitations

1. **Forest Item Selection:** Must be in Forest Editor transform tool mode to select forest items
2. **Separate Generation:** TSStatic and Forest items require separate generation runs (not a bug, by design)
3. **Light Objects:** Lights themselves must still be regular scene objects (PointLight/SpotLight)

### Performance Notes

- Forest item searching is very fast (C++ level iteration)
- No performance impact on TSStatic workflow
- Handles thousands of forest items efficiently

### What's NOT Changed

- Light selection still works the same
- Group naming unchanged (generated_lights_1, _2, etc.)
- No new dependencies
- Still just one file!

## Migration Guide

If you were using v1.0:
- **No changes needed!** The plugin is fully backward compatible
- Your existing TSStatic workflows work exactly the same
- Just enjoy the new forest item support as a bonus feature!

## Testing Checklist

✅ TSStatic objects still work
✅ Forest items now work
✅ Auto-detection works
✅ UI shows correct type
✅ Lights positioned correctly for both types
✅ Group creation works
✅ Error handling for missing selections

---

**Version:** 2.0  
**Date:** October 9, 2025  
**Author:** Sascha Kleinwächter (AlexKidd71)
