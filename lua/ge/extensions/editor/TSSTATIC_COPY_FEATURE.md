# TSStatic Copy Feature - Implementation Summary

## Overview
The Generate Lights plugin has been extended to support copying TSStatic objects in addition to generating lights. Now you can select both lights AND TSStatic objects as templates, and they will all be generated at matching target locations with correct position and rotation.

## What's New

### Feature: Copy TSStatic Objects
- **Select TSStatic templates**: Just like lights, you can now select one or more TSStatic objects to be copied
- **Relative positioning**: TSStatic objects maintain their relative position to the template object
- **Relative rotation**: TSStatic objects maintain their relative rotation to the template object
- **Works with both modes**: Supports both TSStatic and Forest item templates

## How It Works

### Workflow Example
```
1. Select template object (e.g., a lamp post - TSStatic or Forest item)
2. Select lights that should be copied (e.g., PointLight at top of lamp)
3. Select TSStatic objects that should be copied (e.g., decorative base, sign, etc.)
4. Click "Generate Lights" - all objects are generated at matching locations
```

### Use Cases
- **Street lamps**: Generate both the light AND decorative elements (bases, signs, etc.)
- **Building decorations**: Copy architectural details along with lights
- **Forest item enhancement**: Add TSStatic decorations around forest items
- **Complex prop assembly**: Build multi-part props that get copied together

## Technical Implementation

### New Code Additions

#### 1. State Management
```lua
local selectedTSStaticIds = {}  -- Stores selected TSStatic objects to copy
```

#### 2. Relative Transform Calculation
```lua
calculateRelativeTransformsForTSStatic(template, tsStaticIds)
```
- Calculates both relative position AND rotation
- Works with both TSStatic and Forest item templates
- Uses quaternion math for accurate rotation handling

#### 3. TSStatic Object Creation
```lua
createTSStaticFromTemplate(templateTSStaticId, relativePos, relativeRot, targetObj, objectIndex, targetGroup)
```
- Creates new TSStatic objects
- Copies all properties from template using `assignFieldsFromObject()`
- Applies relative position: `finalPos = targetPos + (targetRot * relativePos)`
- Applies relative rotation: `finalRot = targetRot * relativeRot`
- Adds to generated objects group

#### 4. Generation Logic
- Extended `generateLights()` to handle both lights and TSStatic objects
- Iterates through all matching targets
- Generates both lights and TSStatic objects at each target location
- Reports count of both object types created

#### 5. UI Updates
- Added Step 3: "Select TSStatic Object(s) to Copy (Optional)"
- New button: "Get TSStatic(s) by Selection"
- Shows count of selected TSStatic objects
- Updated tooltips and info text
- Generate button enabled if lights OR TSStatic objects are selected

### Key Technical Details

#### Rotation Handling
The plugin correctly handles rotation for TSStatic objects:
```lua
-- Calculate relative rotation
local localRelativeRot = shapeRotInverse * tsStaticRot

-- Apply at target
local finalRot = targetRot * relativeRot
```

This ensures that if your template TSStatic is rotated relative to the template object, the copied TSStatic will maintain that same relative rotation at each target.

#### Object Properties
All TSStatic properties are copied, including:
- `shapeName` (the 3D model)
- `scale`
- `collisionType`
- `decalType`
- Material properties
- Any custom fields

### Code Quality
- Follows existing code style and naming conventions
- Clean separation of concerns (separate function for TSStatic)
- Proper error handling and logging
- No code duplication - reuses existing infrastructure
- Maintains backward compatibility

## Testing Recommendations

1. **Basic Test**: 
   - Select a lamp post TSStatic as template
   - Select a light and a small decorative TSStatic
   - Generate and verify both are created at all matching lamp posts

2. **Rotation Test**:
   - Create a template with rotated TSStatic objects
   - Verify rotations are correct at generated locations

3. **Forest Item Test**:
   - Use a Forest item as template
   - Add TSStatic decorations
   - Verify they generate at all matching forest items

4. **Large Scale Test**:
   - Generate multiple objects across many targets
   - Check performance and scene organization

## Future Enhancement Ideas
- Add scale variation options for generated objects
- Support for other object types (DecalRoad, River, etc.)
- Random offset/rotation options
- Preview mode before generation
- Undo support for batch operations
