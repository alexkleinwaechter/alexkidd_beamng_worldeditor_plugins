# GitHub Copilot Instructions for Generate Lights Plugin

## Plugin Overview
This is a BeamNG.drive World Editor plugin that generates lights and TSStatic objects at matching locations in the scene. It supports both TSStatic objects and Forest items as templates, calculating relative positions and rotations to replicate objects across the scene.

## Code Style and Conventions

### Naming Conventions
- **Functions**: Use camelCase with descriptive names (e.g., `calculateRelativeTransforms`, `createLightFromTemplate`)
- **Local functions**: Prefix with `local function` for all module-private functions
- **Variables**: Use camelCase (e.g., `selectedTemplate`, `relativeTransforms`)
- **State variables**: Declare at module top level after imports
- **Constants**: Use descriptive names (e.g., `toolWindowName`, `toolName`)

### Lua Patterns
- Always use `local` for variables and functions unless they need to be exported
- Use `M` table for module exports: `M.onEditorGui = onEditorGui`
- Prefer `ipairs()` for array iteration, `pairs()` for table iteration
- Use early returns for error conditions
- Always check for nil before using objects: `if not obj then return end`

### BeamNG API Patterns
- **Object Creation**: `local obj = createObject("ClassName")` → set fields → `obj:registerObject(name)`
- **Position/Rotation**: Use `setPosRot(x, y, z, quat.x, quat.y, quat.z, quat.w)` not separate setters
- **Scene Objects**: Always use `scenetree.findObjectById(id)` to get objects
- **Quaternions**: Use `quat()` constructor, `quatFromMatrix()` for transforms
- **Vectors**: Use `vec3()` constructor for positions

### Critical BeamNG Rules
1. **TSStatic Creation**: MUST set `shapeName` field BEFORE calling `registerObject()`
2. **Object Transforms**: Use `setPosRot()` for position+rotation, not `setPosition()` + `setRotation()`
3. **Property Copying**: Use `assignFieldsFromObject()` to copy all properties
4. **Forest Items**: Access via `extensions.core_forest.getForestObject():getData():getItems()`
5. **Selection**: Lights/objects in `editor.selection.object`, Forest items in `editor.selection.forestItem`

## Architecture

### State Management
```lua
-- Template object (TSStatic or Forest item)
selectedTemplate = {
  type = "TSStatic" | "ForestItem" | nil,
  id = number,
  shapeName = string (for TSStatic),
  shapeFile = string (for Forest items),
  displayName = string,
  position = vec3 (for Forest items)
}

-- Selected objects to copy
selectedLightIds = {}        -- Array of light object IDs
selectedTSStaticIds = {}     -- Array of TSStatic object IDs
```

### Core Functions

#### Transform Calculations
- `calculateRelativeTransforms(template, lightIds)` - Calculate light positions relative to template
- `calculateRelativeTransformsForTSStatic(template, tsStaticIds)` - Calculate TSStatic positions AND rotations relative to template
- Both functions work with TSStatic OR Forest item templates

#### Object Creation
- `createLightFromTemplate(templateId, relativePos, targetObj, index, group)` - Create light at target
- `createTSStaticFromTemplate(templateId, relativePos, relativeRot, targetObj, index, group)` - Create TSStatic at target

#### Generation Logic
- `generateObjects()` - Main generation function:
  1. Calculate relative transforms (optional for lights, optional for TSStatic)
  2. Find all matching objects in scene
  3. For each matching object, create lights and/or TSStatic objects
  4. Add all to a numbered group (generated_lights_N)

### UI Patterns
- Use `im_imgui` (imported as `im`) for all UI
- Always wrap in `editor.beginWindow()` / `editor.endWindow()`
- Use `im.tooltip()` immediately after interactive elements
- Use `im.BeginDisabled()` / `im.EndDisabled()` for conditional buttons
- Use `im.TextColored()` for status indicators
- Use `im.Dummy(im.ImVec2(0, 10))` for spacing

### Error Handling
- Log errors with `log("E", "alexkidd_generate_lights", message)`
- Log info with `log("I", "alexkidd_generate_lights", message)`
- Log warnings with `log("W", "alexkidd_generate_lights", message)`
- Always validate objects exist before using them
- Use early returns for error conditions

## Common Patterns

### Getting Selection by Class
```lua
local function getSelectionByClass(classNames)
  local ids = {}
  if editor.selection and editor.selection.object then
    for _, id in ipairs(editor.selection.object) do
      local obj = scenetree.findObjectById(id)
      if obj and arrayFindValueIndex(classNames, obj:getClassName()) then
        table.insert(ids, id)
      end
    end
  end
  return ids
end
```

### Quaternion Math
```lua
-- Get inverse rotation
local rotInverse = quat(rotation)
rotInverse:inverse()

-- Calculate relative rotation
local relativeRot = rotInverse * objectRot

-- Apply relative rotation
local finalRot = targetRot * relativeRot

-- Rotate vector by quaternion
local rotatedVector = rotation * vector
```

### Finding Objects in Scene
```lua
-- Recursive search through groups
local function findShapesInGroup(group, shapeName, results)
  for i = 0, group.obj:getCount() - 1 do
    local child = scenetree.findObjectById(group.obj:idAt(i))
    if child and child:getClassName() == "TSStatic" then
      if child:getField('shapeName', 0) == shapeName then
        table.insert(results, child)
      end
    elseif child.obj and type(child.obj.getCount) == "function" then
      findShapesInGroup(child, shapeName, results)
    end
  end
end
```

## Testing Checklist
When modifying the plugin, always test:
1. ✅ TSStatic template with lights only
2. ✅ TSStatic template with TSStatic objects only
3. ✅ TSStatic template with both lights and TSStatic objects
4. ✅ Forest item template with lights
5. ✅ Forest item template with TSStatic objects
6. ✅ Forest item template with both
7. ✅ Rotation correctness (rotated template objects)
8. ✅ Large scale generation (30+ targets)
9. ✅ Clear button functionality
10. ✅ Error handling (no template, no objects selected, etc.)

## Extension Guidelines
When adding new features:
1. Follow the existing function naming pattern
2. Add state variables at module top if needed
3. Create separate calculation and creation functions
4. Update UI with proper labels and tooltips
5. Add logging for user feedback
6. Update documentation markdown files
7. Test with both TSStatic and Forest item templates

## Performance Considerations
- Avoid unnecessary calculations (check if selection is empty first)
- Use local variables for frequently accessed data
- Batch operations when possible
- Log progress for large operations
- Use `editor.setDirty()` only once at the end of generation

## Common Pitfalls to Avoid
1. ❌ Don't use `setRotation()` - it doesn't exist! Use `setPosRot()` instead
2. ❌ Don't call `registerObject()` before setting `shapeName` on TSStatic
3. ❌ Don't forget to add created objects to the group
4. ❌ Don't forget to normalize vectors/quaternions after math operations
5. ❌ Don't modify template objects during generation
6. ❌ Don't assume objects still exist (always check with `findObjectById`)
7. ❌ Don't use `setPosition()` and `setRotation()` separately - use `setPosRot()`

## Dependencies
- `ui_imgui` - UI rendering
- `extensions.core_forest` - Forest item access
- `editor` - Editor API and selection
- `scenetree` - Scene graph access
- `core_terrain` - Terrain height (if needed for alignment)

## Module Structure
```lua
-- 1. Module setup and imports
local M = {}
local im = ui_imgui

-- 2. State variables
local selectedTemplate = {...}
local selectedLightIds = {}
local selectedTSStaticIds = {}

-- 3. Helper functions (getForestData, quatFromMatrix, etc.)
-- 4. Selection functions (getSelectionByClass, getTemplateFromSelection)
-- 5. Transform calculation functions
-- 6. Object creation functions
-- 7. Main generation function
-- 8. UI rendering function
-- 9. Initialization functions
-- 10. Module exports
return M
```

## Documentation
Keep these markdown files updated:
- `CHANGELOG_v2.md` - Version history and major changes
- `FOREST_ITEMS_RESEARCH.md` - Forest items technical details
- `TSSTATIC_COPY_FEATURE.md` - TSStatic copy feature documentation
- `USAGE_GUIDE.md` - User-facing usage instructions
- `UPDATE_OPTIONAL_GENERATION.md` - Optional generation feature docs
- `COPILOT_INSTRUCTIONS.md` - This file

## Version History Note
Always update changelog when making significant changes. Format:
```markdown
## Version X.Y - Feature Name
- Added: New feature description
- Fixed: Bug fix description
- Changed: Modification description
```
