# Forest Items Support - Research Summary

## Overview
Forest items in BeamNG are NOT regular scene tree objects. They are managed by a special `ForestData` C++ class and are optimized for rendering many instances efficiently. This is why they don't appear in the scene tree like regular TSStatic objects.

## Key Findings

### 1. **Forest Item Access**
Forest items are accessed through:
- `var.forestData:getItems()` - Returns all forest items in the forest
- `var.forestData:getItem(key, position)` - Gets a specific item
- `var.forestData:getItemsCircle(pos, radius)` - Gets items in a circular area
- `var.forestData:getItemsPolygon(nodes2D)` - Gets items in a polygon

### 2. **Forest Item Properties**
Each forest item has these methods:
- `item:getData()` - Returns the ForestItemData which contains:
  - `getData().shapeFile` - The mesh file path
- `item:getPosition()` - Returns vec3 position
- `item:getTransform()` - Returns MatrixF transform (includes rotation)
- `item:getScale()` - Returns scale factor
- `item:getKey()` - Unique key identifier
- `item:getUid()` - Unique ID
- `item:getWorldBox()` - Bounding box

### 3. **Selection System**
Forest items use a separate selection system:
- `editor.selection.forestItem` - Array of selected forest items
- `editor.setForestItemSelected(forestData, key, true/false)` - Mark item as selected
- Forest items are NOT in `editor.selection.object` like regular objects

### 4. **Creating Lights for Forest Items**
To generate lights for forest items, we need to:

```lua
-- Get the forest data
local forest = extensions.core_forest.getForestObject()
local forestData = forest and forest:getData()

-- Iterate all forest items
for _, item in ipairs(forestData:getItems()) do
  local itemData = item:getData()
  local shapeFile = itemData.shapeFile
  
  -- Check if this matches our template shape file
  if shapeFile == templateShapeFile then
    local itemPos = item:getPosition()
    local itemTransform = item:getTransform()
    local itemScale = item:getScale()
    
    -- Generate lights at this position/rotation
    -- (same logic as regular TSStatic objects)
  end
end
```

## Implementation Strategy for Plugin

### Option 1: Dual Mode Selection (RECOMMENDED)
Add support for both TSStatic AND Forest items:

1. **Template Selection:**
   - If user selects a TSStatic → store shapeName
   - If user selects a Forest item → store shapeFile path

2. **Light Generation:**
   - Search scene tree for TSStatic objects (existing code)
   - ALSO search ForestData for matching shapeFile
   - Generate lights for both types

### Option 2: Separate Buttons
Add separate buttons for:
- "Get Forest Item by Selection"
- Generate lights for forest items separately

### Option 3: Auto-Detect
Automatically detect if selection is a forest item or TSStatic and handle accordingly.

## Forest Item Selection Challenge

**Problem:** Forest items cannot be selected the same way as regular objects.
- They don't appear in `editor.selection.object`
- They use `editor.selection.forestItem` instead

**Solution Options:**

### A. Detect Forest Item Selection
```lua
-- Check if forest item is selected
if editor.selection and editor.selection.forestItem and #editor.selection.forestItem > 0 then
  local forestItem = editor.selection.forestItem[1]
  local shapeFile = forestItem:getData().shapeFile
  -- Store this as template
end
```

### B. Manual Shape File Input
Add a text input field where user can paste the shape file path:
```
art/shapes/objects/lamp_post/lamp_post_01.dae
```

### C. Browse Forest Items
Show a list of all ForestItemData datablocks in the scene and let user pick one.

## Recommended Implementation

**Best approach for your plugin:**

1. **Support both TSStatic AND Forest items in the same workflow**
2. **Auto-detect selection type:**
   ```lua
   if editor.selection.object and #editor.selection.object > 0 then
     -- Handle TSStatic selection
   elseif editor.selection.forestItem and #editor.selection.forestItem > 0 then
     -- Handle Forest item selection
   end
   ```

3. **Store template as:**
   ```lua
   local selectedTemplate = {
     type = "TSStatic" or "ForestItem",
     shapeName = "...",  -- for TSStatic
     shapeFile = "...",  -- for ForestItem
   }
   ```

4. **Generate lights for both types:**
   ```lua
   -- Search TSStatic objects (existing code)
   -- PLUS search forest items:
   local forest = extensions.core_forest.getForestObject()
   if forest then
     local forestData = forest:getData()
     for _, item in ipairs(forestData:getItems()) do
       if item:getData().shapeFile == templateShapeFile then
         -- Generate lights here
       end
     end
   end
   ```

## Code Example: Getting Forest Object

```lua
local function getForestData()
  local forest = extensions.core_forest.getForestObject()
  return forest and forest:getData()
end

local function findForestItemsByShapeFile(shapeFile)
  local forestData = getForestData()
  if not forestData then return {} end
  
  local items = {}
  for _, item in ipairs(forestData:getItems()) do
    if item:getData().shapeFile == shapeFile then
      table.insert(items, item)
    end
  end
  return items
end
```

## Important Notes

1. **Forest items are more common than TSStatic** for repeating objects like trees, rocks, lamp posts
2. **Performance:** Forest items are instanced for better performance
3. **Selection:** User needs to be in Forest Editor mode to select forest items
4. **Transform:** Forest items use MatrixF transforms just like TSStatic objects
5. **Scale:** Forest items have a scale property that might affect light positioning

## Next Steps

Would you like me to:
1. **Update the plugin to support both TSStatic and Forest items?**
2. **Add a mode toggle** (TSStatic mode vs Forest Item mode)?
3. **Auto-detect** which type is selected?

The most user-friendly approach would be **auto-detection** - the plugin automatically works with whatever is selected, whether it's a TSStatic or a Forest item.
