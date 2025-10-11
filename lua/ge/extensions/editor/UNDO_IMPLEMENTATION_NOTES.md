# Undo System Implementation for Generate Lights Plugin

## Overview
This document describes the undo functionality added to the `alexkiddGenerateLights.lua` plugin. The implementation provides an undo function without a redo function, as the plugin can be used repeatedly with any selection to regenerate objects as needed.

## Implementation Details

### 1. Undo Function: `generateObjectsUndo(data)`
**Purpose**: Removes all generated objects when the user presses Ctrl+Z (undo)

**What it does**:
- Deletes all created objects by their IDs
- Removes the generated SimGroup folder if one was created
- Clears the editor selection
- Logs the undo action

### 2. Why No Redo Function?
As requested, this implementation does NOT include a redo function because:
- The plugin can be used as often as needed with any selection
- Users can simply run the plugin again to regenerate objects
- This keeps the implementation simpler and more straightforward
- No need to store complex recreation parameters

### 3. Data Storage Structure
The `actionData` object only stores what's needed for undo:

```lua
actionData = {
  createdObjectIds = {},      -- IDs of all created objects
  groupId = nil               -- ID of the SimGroup if created
}
```

This is much simpler than storing full recreation parameters.

### 4. Integration with BeamNG Undo System
The action is committed to the editor's history using:
```lua
editor.history:commitAction(actionName, actionData, generateObjectsUndo)
```

Note: The redo function parameter is omitted (or can be passed as `nil`).

This registers the action with BeamNG's native undo system, which:
- Appears in the Edit menu
- Works with Ctrl+Z keyboard shortcut
- Maintains proper undo history
- Integrates with other editor operations

### 5. Dynamic Action Naming
The undo action name changes based on what was created:
- "Generate X Lights" - if only lights were created
- "Generate X TSStatic Objects" - if only TSStatics were created
- "Generate X Lights and Y TSStatic Objects" - if both were created

This makes the undo history more informative.

## Key Features

### ✓ Works for both TSStatic and Forest Item templates
The system tracks all generated objects regardless of the template type.

### ✓ Handles individual and group-based organization
- If "Use New Folder" is checked: Removes the created SimGroup
- If unchecked: Removes objects from their individual parent groups

### ✓ Clean undo behavior
When undoing:
- All generated objects are removed
- The generated SimGroup is removed if it was created
- No orphaned objects remain in the scene tree

### ✓ No redo needed
Users can simply run the plugin again with their desired settings instead of using redo.

## Testing Recommendations

1. **Basic Undo**: 
   - Generate lights/objects
   - Press Ctrl+Z (should remove all)
   - The plugin is ready to use again

2. **Multiple Operations**:
   - Generate lights from one template
   - Generate objects from another template
   - Undo both operations in reverse order

3. **Mixed Operations**:
   - Generate lights
   - Make other editor changes
   - Undo should work correctly through the history

4. **Group vs No Group**:
   - Test with "Use New Folder" checked
   - Test with "Use New Folder" unchecked
   - Verify proper cleanup in both cases

## Notes

- No redo function is implemented as per requirements
- The undo system only affects generated objects, not the template objects
- The system uses BeamNG's native undo stack, so it integrates seamlessly with other editor operations
- To "redo", simply run the plugin again with your selections

## Advantages of This Approach

1. **Simpler Implementation**: No need to store complex recreation parameters
2. **More Flexible**: Users can change settings between generations
3. **Less Memory**: Minimal data stored in undo history
4. **Clear Intent**: Undo removes, plugin regenerates - clean separation of concerns
