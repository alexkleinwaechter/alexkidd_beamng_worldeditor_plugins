# GitHub Copilot Instructions for Replicate Lights and Objects Plugin

## Plugin Overview
This is a BeamNG.drive World Editor plugin that generates lights and TSStatic objects at matching locations in the scene. It supports both TSStatic objects and Forest items as templates, calculating relative positions, rotations, and **scale-aware transformations** to replicate objects across the scene.

**Key Features:**
- Replicates lights (PointLight, SpotLight) and TSStatic objects
- Works with both TSStatic and Forest item templates
- **Scale-aware positioning** (automatically adjusts for scale differences)
- Supports rotated objects with correct relative positioning
- Optional: Create new SimGroup or use existing parent groups
- Full undo/redo support with proper history tracking

## Version Information
- **Current Version**: 1.1.0 (with scale support)
- **Branch**: feature/respect_scales
- **Last Updated**: October 13, 2025

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
1. ❌ **DON'T** use `setRotation()` - it doesn't exist! Use `setPosRot()` instead
2. ❌ **DON'T** call `registerObject()` before setting `shapeName` on TSStatic
3. ❌ **DON'T** forget to add created objects to the group
4. ❌ **DON'T** forget to normalize vectors/quaternions after math operations
5. ❌ **DON'T** modify template objects during generation
6. ❌ **DON'T** assume objects still exist (always check with `findObjectById`)
7. ❌ **DON'T** use `setPosition()` and `setRotation()` separately - use `setPosRot()`

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
useSimGroup = im.BoolPtr(true) -- Create new group or use existing
```

### Module Structure
```lua
-- 1. Module setup and imports
local M = {}
local im = ui_imgui

-- 2. State variables
local selectedTemplate = {...}
local selectedLightIds = {}
local selectedTSStaticIds = {}

-- 3. Helper functions (getForestData, quatFromMatrix, parseScale, etc.)
-- 4. Selection functions (getSelectionByClass, getSelectedForestItem)
-- 5. Transform calculation functions (WITH SCALE SUPPORT)
-- 6. Object creation functions (WITH SCALE APPLICATION)
-- 7. Main generation function
-- 8. UI rendering function
-- 9. Initialization functions
-- 10. Module exports
return M
```

## Core Functions

### Helper Functions

#### `getForestData()`
Returns the forest data object for accessing forest items.

#### `quatFromMatrix(matrix)`
Extracts a quaternion from a transformation matrix using forward and up vectors.

#### `parseScale(scaleStr)` ⭐ NEW
**Purpose**: Parse TSStatic scale field string to vec3
**Input**: String "x y z" (e.g., "2.5 2.5 2.5")
**Output**: vec3(x, y, z) or vec3(1, 1, 1) if invalid
**Usage**: 
```lua
local scaleStr = tsStatic:getField('scale', 0)
local scale = parseScale(scaleStr)  -- vec3(2.5, 2.5, 2.5)
```

#### `getNextGeneratedLightsNumber()`
Finds the highest existing "generated_lights_N" group number and returns N+1.

#### `getSelectionByClass(classNames)`
Returns array of selected object IDs filtered by class name(s).

#### `getSelectedForestItem()`
Returns the first selected forest item or nil.

### Transform Calculation Functions ⭐ SCALE-AWARE

#### `calculateRelativeTransforms(template, lightIds)`
**Purpose**: Calculate scale-normalized relative positions of lights
**Algorithm**:
1. Get template position, rotation, and **SCALE**
2. For each light:
   - Calculate world-space offset: `worldOffset = lightPos - templatePos`
   - Transform to local space: `localOffset = templateRotInverse * worldOffset`
   - **NORMALIZE by template scale**: `normalizedOffset = localOffset / templateScale`
   - Store normalized relative position

**Returns**: Array of `{lightId, relativePosition, className, parentGroup}`

**Scale Handling**:
- TSStatic: `parseScale(shape:getField('scale', 0))`
- ForestItem: `forestItem:getScale()` (returns number)

#### `calculateRelativeTransformsForTSStatic(template, tsStaticIds)`
**Purpose**: Calculate scale-normalized relative positions AND rotations of TSStatic objects
**Same as above PLUS**:
- Calculates relative rotation: `localRelativeRot = templateRotInverse * tsStaticRot`

**Returns**: Array of `{tsStaticId, relativePosition, relativeRotation, parentGroup}`

### Object Creation Functions ⭐ SCALE-AWARE

#### `createLightFromTemplate(templateLightId, relativePos, targetObj, lightIndex, targetGroup)`
**Purpose**: Create a light at target object with scale-corrected position

**Algorithm**:
1. Create and register new light object
2. Copy all properties from template using `assignFieldsFromObject()`
3. Get target position, rotation, and **SCALE**
4. **APPLY target scale**: `scaledOffset = relativePos * targetScale`
5. Transform to world space: `worldOffset = targetRot * scaledOffset`
6. Set final position: `finalPos = targetPos + worldOffset`
7. Add to target group

**Scale Handling**:
- TSStatic target: `parseScale(targetObj:getField('scale', 0))`
- ForestItem target: `vec3(scale, scale, scale)` from `targetObj.scale`

#### `createTSStaticFromTemplate(templateTSStaticId, relativePos, relativeRot, targetObj, objectIndex, targetGroup)`
**Purpose**: Create a TSStatic at target object with scale-corrected position

**Critical Steps**:
1. **MUST set `shapeName` BEFORE `registerObject()`** ⚠️
2. Register object
3. Copy properties with `assignFieldsFromObject()`
4. Restore unique name (gets overwritten by assignFieldsFromObject)
5. Get target scale and **APPLY to position**
6. Use `setPosRot()` for position and rotation (NOT separate setters!)
7. Add to target group

### Main Generation Function

#### `generateObjects()`
**Purpose**: Main orchestration function that generates all objects

**Algorithm**:
1. Validate selection (template + at least one light/TSStatic)
2. Calculate scale-normalized relative transforms for lights and TSStatic objects
3. Create SimGroup if `useSimGroup[0]` is true
4. Find all matching target objects:
   - TSStatic: Search scene tree for matching `shapeName`
   - ForestItem: Search forest data for matching `shapeFile`
5. For each target (excluding template):
   - Create all lights with scale-corrected positions
   - Create all TSStatic objects with scale-corrected positions
6. Serialize for undo/redo
7. Commit to editor history

**Target Object Discovery**:
```lua
-- TSStatic: Recursive search through scene tree
local function findShapesInGroup(group, shapeName, results)
  -- Recursively find all TSStatic objects with matching shapeName
end

-- ForestItem: Iterate through forest data
for _, item in ipairs(forestData:getItems()) do
  if tostring(itemData.shapeFile) == shapeFile then
    -- Add to results with pos, rot, and SCALE
  end
end
```

### UI Functions

#### `onEditorGui()`
**Purpose**: Renders the plugin window using ImGui

**UI Structure**:
1. **Template Selection** - Select TSStatic OR Forest item
2. **Light Selection** (Optional) - Select lights to replicate
3. **TSStatic Selection** (Optional) - Select TSStatic objects to replicate
4. **Options** - Use new folder checkbox
5. **Generate Button** - Creates all objects

**UI Patterns**:
- Use `im.BeginDisabled()` / `im.EndDisabled()` for conditional buttons
- Use `im.tooltip()` immediately after interactive elements
- Use `im.TextColored()` for status indicators (green for selected)
- Use `im.Dummy(im.ImVec2(0, 10))` for spacing
- Validate selected objects still exist (check with `findObjectById`)

## Scale Support Implementation ⭐ CRITICAL

### Problem Statement
When template and target objects have different scales, objects must be positioned correctly relative to the scaled geometry.

**Example**:
- Template with scale 2,2,2 has a light 10 units away
- Target with scale 1,1,1 should place light 5 units away (10 / 2 * 1 = 5)
- Target with scale 3,3,3 should place light 15 units away (10 / 2 * 3 = 15)

### Mathematical Formula
```
Calculation Phase (Template):
  normalizedOffset = (objectPos - templatePos) / templateScale

Application Phase (Target):
  finalPos = targetPos + (normalizedOffset * targetScale)
```

### Scale Data Sources

| Object Type | Method | Format | Notes |
|-------------|--------|--------|-------|
| TSStatic | `obj:getField('scale', 0)` | String "x y z" | Parse with `parseScale()` |
| ForestItem | `forestItem:getScale()` | Number (uniform) | Convert to vec3(n, n, n) |

### Implementation Checklist
When modifying transform logic:
- [ ] Get template scale in calculation phase
- [ ] Divide by template scale to normalize
- [ ] Get target scale in application phase
- [ ] Multiply by target scale before rotation
- [ ] Support both TSStatic and ForestItem scales
- [ ] Handle non-uniform scales (x≠y≠z)

## Undo/Redo System

### Architecture
Uses BeamNG's `editor/api/objectHistoryActions` API for proper undo/redo support.

**Action Data Structure**:
```lua
{
  createdObjectIds = {},      -- Array of created object IDs
  groupId = number or nil,    -- SimGroup ID if using shared group
  serializedObjects = {},     -- Lazy serialization for undo
  serializedData = {},        -- Group serialization if using SimGroup
  isSimSet = boolean,         -- True if serializing a group
  parentGroupIds = {}         -- Parent groups for individual objects
}
```

### Functions
- `generateObjectsUndo(data)` - Deletes created objects
- `generateObjectsRedo(data)` - Restores deleted objects

**Performance Optimization**:
- Serialize on-demand (only when undo is triggered)
- Group serialization for SimGroup mode
- Individual serialization for parent group mode

## Error Handling and Logging

### Log Levels
```lua
log("I", "alexkidd_generate_lights", "Info message")
log("W", "alexkidd_generate_lights", "Warning message")
log("E", "alexkidd_generate_lights", "Error message")
```

### Common Error Conditions
1. No template selected
2. No lights/TSStatic objects selected
3. Template object no longer exists
4. Failed to create object
5. Failed to calculate transforms

**Always validate**:
- Object existence before access
- Forest data availability
- Transform calculations result in valid data

## Testing Checklist

### Basic Functionality
- [ ] TSStatic template with lights only
- [ ] TSStatic template with TSStatic objects only
- [ ] TSStatic template with both lights and TSStatic objects
- [ ] Forest item template with lights
- [ ] Forest item template with TSStatic objects
- [ ] Forest item template with both

### Scale Support ⭐ CRITICAL
- [ ] Template scale 1,1,1 → Target scale 1,1,1 (baseline)
- [ ] Template scale 2,2,2 → Target scale 1,1,1 (scale down)
- [ ] Template scale 1,1,1 → Target scale 2,2,2 (scale up)
- [ ] Template scale 2,3,4 → Target scale 1,1,1 (non-uniform)
- [ ] ForestItem scales (uniform float values)
- [ ] Mixed: TSStatic template → ForestItem targets with scale
- [ ] Mixed: ForestItem template → TSStatic targets with scale

### Advanced Scenarios
- [ ] Rotated template objects (90°, 180°, arbitrary angles)
- [ ] Rotated target objects
- [ ] Large scale generation (30+ targets)
- [ ] Undo/redo functionality
- [ ] Multiple lights + multiple TSStatic objects simultaneously
- [ ] Objects in different parent groups

### Edge Cases
- [ ] Template scale 0.1,0.1,0.1 (very small)
- [ ] Template scale 10,10,10 (very large)
- [ ] Template object deleted during operation
- [ ] Empty selection
- [ ] No matching targets found

## Extension Guidelines

### Adding New Features
1. Follow existing function naming patterns
2. Add state variables at module top if needed
3. Create separate calculation and creation functions
4. Update UI with proper labels and tooltips
5. Add logging for user feedback
6. **Ensure scale support is maintained**
7. Test with both TSStatic and Forest item templates
8. Document in this file

### Performance Considerations
- Avoid unnecessary calculations (check selection empty first)
- Use local variables for frequently accessed data
- Batch operations when possible
- Log progress for large operations (30+ objects)
- Use `editor.setDirty()` only once at the end
- Lazy serialization for undo/redo (serialize on-demand)

### Common Pitfalls to Avoid
1. ❌ **Ignoring scale** - Always use scale-aware transforms
2. ❌ Using `setRotation()` - Use `setPosRot()` instead
3. ❌ Setting shapeName after registerObject - Do it BEFORE
4. ❌ Forgetting to add objects to group
5. ❌ Not normalizing quaternions after operations
6. ❌ Modifying template objects during generation
7. ❌ Assuming objects exist without checking
8. ❌ Using separate position/rotation setters

## Dependencies

### Required Extensions
- `ui_imgui` - UI rendering
- `extensions.core_forest` - Forest item access
- `editor` - Editor API and selection
- `scenetree` - Scene graph access
- `editor/api/objectHistoryActions` - Undo/redo support

### Optional Dependencies
- `core_terrain` - If adding terrain height alignment features

## API Reference

### BeamNG Editor API
```lua
-- Selection
editor.selection.object          -- Array of selected object IDs
editor.selection.forestItem      -- Array of selected forest items

-- Scene Tree
scenetree.MissionGroup           -- Root scene group
scenetree.findObjectById(id)    -- Find object by ID

-- Object Creation
createObject(className)          -- Create new object instance
obj:registerObject(name)         -- Register in scene tree
obj:assignFieldsFromObject(src)  -- Copy all fields from source

-- Transform
obj:getPosition()                -- Returns vec3
obj:getRotation()                -- Returns quat
obj:setPosRot(x,y,z,qx,qy,qz,qw) -- Set position and rotation

-- Fields
obj:getField(name, index)        -- Get field value (returns string)
obj:setField(name, index, value) -- Set field value

-- History
editor.history:commitAction(name, data, undoFn, redoFn)
editor.setDirty()                -- Mark level as modified
```

### Forest API
```lua
extensions.core_forest.getForestObject()  -- Get forest object
forestObject:getData()                     -- Get forest data
forestData:getItems()                      -- Get array of items

-- Forest Item
item:getKey()           -- Unique identifier
item:getPosition()      -- Returns vec3
item:getTransform()     -- Returns matrix
item:getScale()         -- Returns float (uniform scale)
item:getData()          -- Returns item data with shapeFile
```

## Version History

### v1.1.0 - Scale Support (October 13, 2025)
- ✅ Added `parseScale()` helper function
- ✅ Updated `calculateRelativeTransforms()` with scale normalization
- ✅ Updated `calculateRelativeTransformsForTSStatic()` with scale normalization
- ✅ Updated `createLightFromTemplate()` with scale application
- ✅ Updated `createTSStaticFromTemplate()` with scale application
- ✅ Supports TSStatic scale field "x y z" format
- ✅ Supports ForestItem uniform scale
- ✅ Handles non-uniform scales correctly
- ✅ Backwards compatible (scale 1,1,1 behaves as before)

### Earlier Versions
- v1.0.x - TSStatic object copying support
- v0.9.x - Forest item template support
- v0.8.x - Initial light replication functionality

## Future Enhancement Ideas
- [ ] Add scale override option in UI
- [ ] Support for TerrainBlock templates
- [ ] Height alignment to terrain
- [ ] Batch processing with progress bar
- [ ] Save/load template configurations
- [ ] Random offset/rotation variations
- [ ] Filtering by object properties (material, etc.)
- [ ] Preview mode before generation
- [ ] Export generated object list

## Contact and Support
- **Author**: Sascha Kleinwächter (AlexKidd71)
- **Forum**: https://www.beamng.com/members/alexkidd71.475455
- **License**: bCDDL v1.1

---

**Last Updated**: October 13, 2025
**Branch**: feature/respect_scales
**Status**: ✅ Production Ready with Scale Support
