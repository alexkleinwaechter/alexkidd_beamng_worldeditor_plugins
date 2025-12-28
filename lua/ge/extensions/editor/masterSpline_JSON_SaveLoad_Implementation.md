# Master Spline Editor - JSON Save/Load Implementation Guide

## Overview
This document describes how to implement JSON save/load functionality for the BeamNG Master Spline Editor. The implementation allows saving and loading master splines along with all their linked splines (Road, Mesh, Assembly, Decal types) with full cross-session compatibility.

## Problem Statement
The Master Spline Editor needed the ability to:
1. Save master splines and all linked splines to a JSON file
2. Load them back in a new session
3. Handle cross-session issues where scene objects persist in the level file but Lua arrays are empty
4. Prevent duplicate scene objects when loading

## Files Modified

### 1. `lua/ge/extensions/editor/masterSpline.lua`
Main editor UI and logic file. Changes:
- Added Save button to serialize master splines + linked splines to JSON
- Added Load button with recursive vec3 conversion and "clear all before load" approach
- Removed `[link]` prefix from linked spline names (now "Road Spline 1" instead of "[link] Road Spline 1")
- **v1.8**: Save now captures all decal positions at top level of JSON
- **v1.8**: Load now performs position-based decal cleanup before restoring decal splines
- **v1.8**: Added `decalSplineLink.updateDirtyDecalSplines()` call after load

### 2. `lua/ge/extensions/editor/roadSpline/groupMgr.lua`
Fixed folder naming in `addGroupToGroupArray()` to use `group.id` instead of random UUID.

### 3. `lua/ge/extensions/editor/meshSpline/splineMgr.lua`
Fixed folder naming in `setMeshSpline()` to use `spline.id` instead of random UUID.

### 4. `lua/ge/extensions/editor/assemblySpline/splineMgr.lua`
Fixed folder naming in `setAssemblySpline()` to use `spline.id` instead of random UUID.

---

## Implementation Steps

### Step 1: Add `restoreJumpTable` to Module Constants

Near the top of `masterSpline.lua`, find where `serializeJumpTable` and other jump tables are required from `jumpTables.lua`. Add `restoreJumpTable`:

```lua
local serializeJumpTable = require('/lua/ge/extensions/editor/masterSpline/jumpTables').serializeJumpTable
local restoreJumpTable = require('/lua/ge/extensions/editor/masterSpline/jumpTables').restoreJumpTable
local setLinkJumpTable = require('/lua/ge/extensions/editor/masterSpline/jumpTables').setLinkJumpTable
local removeJumpTable = require('/lua/ge/extensions/editor/masterSpline/jumpTables').removeJumpTable
```

### Step 2: Add Recursive vec3 Conversion Function

Add this helper function to convert plain `{x, y, z}` tables back to proper `vec3` objects. Place it in a utility section of the file:

```lua
-- Recursively converts tables with x,y,z keys to vec3 objects.
-- JSON serialization loses vec3 methods, this restores them.
local function convertToVec3Recursive(tbl)
  if type(tbl) ~= 'table' then return tbl end
  
  -- Check if this table looks like a vec3 (has x, y, z and exactly 3 keys)
  if tbl.x ~= nil and tbl.y ~= nil and tbl.z ~= nil then
    local keyCount = 0
    for _ in pairs(tbl) do keyCount = keyCount + 1 end
    if keyCount == 3 then
      return vec3(tbl.x, tbl.y, tbl.z)
    end
  end
  
  -- Recurse into nested tables
  for k, v in pairs(tbl) do
    if type(v) == 'table' then
      tbl[k] = convertToVec3Recursive(v)
    end
  end
  
  return tbl
end
```

### Step 3: Implement Save Button

In the ImGui UI section (inside `onEditorGui` function), add the Save button. Place it in the toolbar area:

```lua
if im.Button("Save JSON") then
  -- Build linked splines data
  local linkedSplinesData = {}
  for i = 1, #_linkedSplines do
    local ls = _linkedSplines[i]
    local serializeFunc = serializeJumpTable[ls.type]
    if serializeFunc then
      linkedSplinesData[#linkedSplinesData + 1] = {
        type = ls.type,
        data = serializeFunc(ls)
      }
    end
  end
  
  -- Build save data structure
  local saveData = {
    masterSplines = _masterSplines,
    linkedSplines = linkedSplinesData
  }
  
  -- Write to file
  local savePath = "/gameplay/masterSpline/savedSplines.json"
  jsonWriteFile(savePath, saveData, true)
  editor.logInfo("Master Splines saved to: " .. savePath)
end
```

### Step 4: Implement Load Button

Add the Load button next to the Save button. The load process:
1. Clears ALL existing splines first (prevents duplicates)
2. Restores linked splines with vec3 conversion
3. Restores master splines
4. Re-establishes links between them
5. Triggers immediate scene object regeneration

```lua
im.SameLine()
if im.Button("Load JSON") then
  local loadPath = "/gameplay/masterSpline/savedSplines.json"
  local loadedData = jsonReadFile(loadPath)
  
  if loadedData then
    -- Step 4a: Clear ALL existing splines first (prevents duplicates)
    local existingSplines = splineMgr.getMasterSplines()
    for i = #existingSplines, 1, -1 do
      splineMgr.unlinkAllSplines(existingSplines[i])
    end
    splineMgr.removeAllMasterSplines()
    
    -- Step 4b: Prepare data for restoration
    local masterSplinesData = loadedData.masterSplines or loadedData  -- Backward compatibility
    local linkedSplinesData = loadedData.linkedSplines or {}
    local oldIdToNewId = {}  -- Maps old linked spline IDs to new IDs
    
    -- Step 4c: Pre-process linked splines with vec3 conversion
    for i = 1, #linkedSplinesData do
      local lsData = linkedSplinesData[i]
      if lsData.data then
        -- Deep vec3 conversion for nested structures
        lsData.data = convertToVec3Recursive(lsData.data)
        
        -- Clear stale scene-specific IDs
        lsData.data.sceneTreeFolderId = nil
        if lsData.data.layers then
          for j = 1, #lsData.data.layers do
            local layer = lsData.data.layers[j]
            if layer then
              layer.decalRoadIds = nil
              layer.decalRoadId = nil
            end
          end
        end
      end
    end
    
    -- Step 4d: Restore linked splines first
    for i = 1, #linkedSplinesData do
      local lsData = linkedSplinesData[i]
      local restoreFunc = restoreJumpTable[lsData.type]
      if restoreFunc and lsData.data then
        local oldId = lsData.id
        local restoredSpline = restoreFunc(lsData.data)
        if restoredSpline then
          oldIdToNewId[oldId] = restoredSpline.id
        end
      end
    end
    
    -- Step 4e: Restore master splines
    for i = 1, #masterSplinesData do
      local ms = splineMgr.deserializeMasterSpline(masterSplinesData[i])
      splineMgr.addToMasterSplineArray(ms)
      
      -- Re-link layers to linked splines using new IDs
      for j = 1, #ms.layers do
        local layer = ms.layers[j]
        if layer.linkedSplineId then
          local newLinkedId = oldIdToNewId[layer.linkedSplineId]
          if newLinkedId then
            layer.linkedSplineId = newLinkedId
            if layer.linkType and setLinkJumpTable[layer.linkType] then
              setLinkJumpTable[layer.linkType](newLinkedId, ms.id, true)
            end
            layer.isDirty = true
          end
        end
      end
      ms.isDirty = true
    end
    
    -- Step 4f: Force update all dirty linked splines to regenerate scene objects
    roadSplineLink.updateDirtyGroups()
    meshSplineLink.updateDirtyMeshSplines()
    assemblySplineLink.updateDirtyAssemblySplines()
    editor.refreshSceneTreeWindow()
    
    editor.logInfo("Master Splines loaded from: " .. loadPath)
  else
    editor.logWarn("Failed to load: " .. loadPath)
  end
end
```

**Important Design Decision - No GUID-Based Cleanup:**
We intentionally do NOT scan scene objects to delete orphaned items based on GUIDs. While this was considered, it was rejected because:
- It would delete ANY scene objects whose names contain matching GUIDs
- This includes splines created manually by users who never intended to use the JSON save/load feature
- Instead, we clear ALL existing splines in Lua before loading, which safely removes only splines managed by the editor

---

## Key Technical Challenges & Solutions

### Challenge 1: vec3 Serialization
**Problem**: JSON converts `vec3` objects to plain `{x, y, z}` tables, losing methods like `:distance()`, `:xyz()`, `:setSub2()`.

**Solution**: Recursive `convertToVec3Recursive()` function that detects tables with exactly 3 keys (x, y, z) and converts them back to proper `vec3` objects.

### Challenge 2: Deeply Nested vec3 (Assembly Spline)
**Problem**: Assembly Spline's `moleculeDescription` contains nested vec3 in `attachPos`, `forward`, `up`, `freedomAxes` arrays.

**Solution**: Made the vec3 conversion recursive to handle arbitrary nesting depth.

### Challenge 3: Stale Scene-Specific IDs
**Problem**: `sceneTreeFolderId` and `decalRoadIds` reference scene objects that may not exist in a new session.

**Solution**: Clear these fields before restoring splines:
```lua
ms.sceneTreeFolderId = nil
ms.decalRoadIds = nil
```

### Challenge 4: Cross-Session Duplicate Objects
**Problem**: Scene objects (DecalRoads, SimGroups) persist in the level file across sessions, but Lua arrays are empty on startup. Loading could create duplicates.

**Solution**: Clear ALL existing splines before loading:
```lua
local existingSplines = splineMgr.getMasterSplines()
for i = #existingSplines, 1, -1 do
  splineMgr.unlinkAllSplines(existingSplines[i])
end
splineMgr.removeAllMasterSplines()
```

**Why NOT GUID-based cleanup:** We considered scanning scene objects by GUID and deleting orphans, but this was rejected because it would delete ANY objects with matching GUIDs - including splines created manually by users who never intended to use JSON save/load. The current approach is safe because it only affects splines currently tracked in Lua.

**Trade-off**: If users manually delete splines from the Lua editor but orphaned scene objects remain in the level file, those orphans won't be cleaned up automatically. Users can manually delete them from the Scene Tree if needed.

### Challenge 5: Inconsistent Folder Naming Across Spline Types
**Problem**: Some spline functions used random UUIDs for folder names instead of the spline's own ID. This broke GUID-based cleanup because folder names didn't match spline IDs.

**Solution**: Fixed folder naming in all spline types to consistently use `spline.id`:

**roadSpline/groupMgr.lua** - `addGroupToGroupArray()`:
```lua
-- Before (wrong):
local folderNameId = Engine.generateUUID()

-- After (correct):
local folderNameId = group.id or Engine.generateUUID()
```

**meshSpline/splineMgr.lua** - `setMeshSpline()`:
```lua
local folderNameId = spline.id or Engine.generateUUID()
```

**assemblySpline/splineMgr.lua** - `setAssemblySpline()`:
```lua
local folderNameId = spline.id or Engine.generateUUID()
```

### Challenge 6: Linked Splines Not Visible After Load
**Problem**: After JSON load, linked splines (especially Road Spline) weren't visible because their scene objects (DecalRoads, meshes) weren't regenerated. The `isDirty` flag was set, but the update functions only run in each tool's `onEditorGui`.

**Solution**: After loading, explicitly call the update functions for all linked spline types:
```lua
-- Force update all dirty linked splines to regenerate their scene objects.
roadSplineLink.updateDirtyGroups()
meshSplineLink.updateDirtyMeshSplines()
assemblySplineLink.updateDirtyAssemblySplines()
decalSplineLink.updateDirtyDecalSplines()  -- Added for decal splines

-- Refresh the scene tree to show the new objects.
editor.refreshSceneTreeWindow()
```

### Challenge 7: Decal Spline Cross-Session Duplicates
**Problem**: Unlike other spline types (Road, Mesh, Assembly) that store scene objects in the scenetree, Decal Splines store their decal instances in a separate `decals.json` via `decalPersistMan`. This means:
1. Decal instances persist across sessions in `decals.json`, not the scenetree
2. ID-based cleanup doesn't work because decal instances don't have our spline GUIDs
3. Loading the same JSON twice creates duplicate decal instances at the same positions

**Solution**: Position-based decal cleanup. Save all decal positions when creating the JSON, then on load, delete any existing decals at those positions before restoring.

**Save Phase** - Capture decal positions at top level:
```lua
-- Build decal positions array from ALL current decal instances
local decalPositions = {}
local decalCount = editor.getDecalInstanceVecSize()
for i = 0, decalCount - 1 do
  local decalInst = editor.getDecalInstance(i)
  if decalInst and decalInst.position then
    table.insert(decalPositions, {
      x = decalInst.position.x,
      y = decalInst.position.y,
      z = decalInst.position.z
    })
  end
end
```

**Load Phase** - Delete decals at saved positions before restore:
```lua
local decalPositions = loaded.decalPositions or {}
if #decalPositions > 0 then
  -- Build lookup set for fast position matching
  local posSet = {}
  for _, pos in ipairs(decalPositions) do
    local key = string.format("%.3f,%.3f,%.3f", pos.x, pos.y, pos.z)
    posSet[key] = true
  end
  
  -- Delete matching decal instances (iterate backwards)
  local decalCount = editor.getDecalInstanceVecSize()
  for i = decalCount - 1, 0, -1 do
    local decalInst = editor.getDecalInstance(i)
    if decalInst and decalInst.position then
      local key = string.format("%.3f,%.3f,%.3f", 
        decalInst.position.x, decalInst.position.y, decalInst.position.z)
      if posSet[key] then
        editor.deleteDecalInstance(decalInst)
      end
    end
  end
end
```

**Why Position-Based?**
- Decal instances are created/managed by the decal system, not our spline editor
- They don't carry our GUIDs or any custom metadata we can use for identification
- Position is the only reliable way to identify "these are the decals from our saved splines"
- Uses exact floating-point match (%.3f precision) which works because positions don't change

**Important**: Decal positions are saved once at the top level of the JSON, not per decal spline entry. This captures all decal instances that exist when saving, regardless of which decal spline they belong to.

---

## JSON File Structure

```json
{
  "masterSplines": [
    {
      "guid": "unique-guid-string",
      "positions": [{"x": 0, "y": 0, "z": 0}, ...],
      "ribPoints": [...],
      "linkedSplineGuid": "linked-spline-guid",
      ...
    }
  ],
  "linkedSplines": [
    {
      "type": "roadSpline",
      "data": {
        "guid": "linked-spline-guid",
        ...
      }
    },
    {
      "type": "assemblySpline",
      "data": {
        "guid": "...",
        "moleculeDescription": {
          "attachPos": {"x": 0, "y": 0, "z": 0},
          ...
        }
      }
    },
    {
      "type": "decalSpline",
      "data": {
        "guid": "...",
        ...
      }
    }
  ],
  "decalPositions": [
    {"x": 123.456, "y": 789.012, "z": 34.567},
    {"x": 124.567, "y": 790.123, "z": 35.678},
    ...
  ]
}
```

**Note on `decalPositions`**: This is a flat array of ALL decal instance positions that existed when saving. It's used for position-based cleanup on load to prevent duplicate decals. This is stored at the top level (not per decal spline) because all decal instances need to be captured regardless of which spline created them.

---

## Dependencies

- `jumpTables.lua`: Must have `serializeJumpTable`, `restoreJumpTable`, `setLinkJumpTable`, `removeJumpTable`
- BeamNG globals: `vec3()`, `jsonWriteFile()`, `jsonReadFile()`, `scenetree`
- Editor: `editor.logInfo()`, `editor.logWarn()`

---

## Testing Checklist

1. [ ] Save with no splines - should create empty JSON
2. [ ] Save with master splines only
3. [ ] Save with master splines + Road Spline links
4. [ ] Save with master splines + Mesh Spline links
5. [ ] Save with master splines + Assembly Spline links (tests nested vec3)
6. [ ] Save with master splines + Decal Spline links
7. [ ] Load in same session - should replace existing
8. [ ] Load in new session (restart game) - should work without duplicates
9. [ ] Load twice in same session - should not create duplicates
10. [ ] Verify spline positions are correct after load
11. [ ] Verify linked spline relationships are restored
12. [ ] Verify scene objects are properly created (SimGroups, DecalRoads)
13. [ ] **Decal Test**: Save with Decal Spline links, restart game, load - no duplicate decals
14. [ ] **Decal Test**: Load same JSON twice in session - decals not duplicated

---

## Version History

- **v1.0** (December 2024): Initial implementation with Save/Load buttons
- **v1.1**: Added recursive vec3 conversion for nested structures
- **v1.2**: Added GUID-based scene object cleanup for cross-session compatibility
- **v1.3**: Fixed scenetree API usage (getAllObjects returns names, not IDs)
- **v1.4**: Fixed folder naming consistency across all spline types (roadSpline, meshSpline, assemblySpline)
- **v1.5**: Added explicit update calls after load to regenerate scene objects immediately
- **v1.6**: **REMOVED GUID-based cleanup** - was dangerous as it could delete user's manually-created splines. Now uses "clear all before load" approach instead.
- **v1.7**: Removed `[link]` prefix from linked spline names (now just "Road Spline 1", "Mesh Spline 1", etc.)
- **v1.8**: **Decal Spline cross-session fix** - Added position-based decal cleanup. Decals don't use scenetree (they use `decals.json` via `decalPersistMan`), so we save all decal positions in the JSON and use position matching to delete old decals before restoring. Added `decalSplineLink.updateDirtyDecalSplines()` call after load.
