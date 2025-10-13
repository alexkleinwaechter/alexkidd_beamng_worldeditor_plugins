-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Author: Sascha Kleinwächter (AlexKidd71)
-- Forum Profile: https://www.beamng.com/members/alexkidd71.475455

local M = {}
local im = ui_imgui
local toolWindowName = "Replicate Lights and Objects v1.3.0"
local toolName = "Replicate Lights and Objects"

-- State variables
local selectedTemplate = {
  type = nil,
  id = nil,
  shapeName = nil,
  shapeFile = nil,
  displayName = nil,
  position = nil
}
local selectedLightIds = {}
local selectedTSStaticIds = {}
local useSimGroup = im.BoolPtr(true)

-- Helper function to get forest data
local function getForestData()
  local forest = extensions.core_forest.getForestObject()
  return forest and forest:getData()
end

-- Helper function to extract quaternion from matrix
local function quatFromMatrix(matrix)
  local fwd = matrix:getColumn(1):normalized()
  local up = matrix:getColumn(2):normalized()
  return quatFromDir(fwd, up)
end

-- Helper function to parse scale from string "x y z" to vec3
local function parseScale(scaleStr)
  if not scaleStr or scaleStr == "" then
    return vec3(1, 1, 1)
  end
  local x, y, z = scaleStr:match("([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)")
  if x and y and z then
    return vec3(tonumber(x) or 1, tonumber(y) or 1, tonumber(z) or 1)
  end
  return vec3(1, 1, 1)
end

-- Helper function to get the highest existing generated_lights group number
local function getNextGeneratedLightsNumber()
  local highestNumber = 0
  local missionGroup = scenetree.MissionGroup
  if not missionGroup then return 1 end
  
  for i = 0, missionGroup:getCount() - 1 do
    local childId = missionGroup:idAt(i)
    local child = scenetree.findObjectById(childId)
    if child then
      local name = child:getName()
      local number = string.match(name, "^generated_lights_(%d+)$")
      if number then
        highestNumber = math.max(highestNumber, tonumber(number))
      end
    end
  end
  
  return highestNumber + 1
end

-- Helper function to get selection and filter by class
local function getSelectionByClass(classNames)
  local ids = {}
  if editor.selection and editor.selection.object then
    for _, id in ipairs(editor.selection.object) do
      local obj = scenetree.findObjectById(id)
      if obj then
        local className = obj:getClassName()
        if not classNames or arrayFindValueIndex(classNames, className) then
          table.insert(ids, id)
        end
      end
    end
  end
  return ids
end

-- Helper function to check if a forest item is selected
local function getSelectedForestItem()
  if editor.selection and editor.selection.forestItem and #editor.selection.forestItem > 0 then
    return editor.selection.forestItem[1]
  end
  return nil
end

-- Load the objectHistoryActions API for proper undo/redo
local objectHistoryActions = require("editor/api/objectHistoryActions")()

-- Undo function: deletes all created objects using proper API
local function generateObjectsUndo(data)
  if data.groupId then
    -- Delete the group (which includes all children)
    objectHistoryActions.deleteObjectRedo({objectId = data.groupId})
  else
    -- Serialize objects on-demand before deleting (only when needed for undo)
    if not data.serializedObjects then
      data.serializedObjects = {}
      for _, id in ipairs(data.createdObjectIds) do
        local obj = Sim.findObjectById(id)
        if obj then
          table.insert(data.serializedObjects, "[" .. obj:serializeForEditor(true, -1, "") .. "]")
        end
      end
    end
    
    -- Delete objects individually
    for _, id in ipairs(data.createdObjectIds) do
      objectHistoryActions.deleteObjectRedo({objectId = id})
    end
  end
  editor.clearObjectSelection()
  log("I", "alexkidd_generate_lights", "Undone: Removed " .. (data.groupId and "group" or #data.createdObjectIds .. " objects"))
end

-- Redo function: recreates all objects using proper API
local function generateObjectsRedo(data)
  if data.groupId then
    -- Restore the group (which includes all children)
    objectHistoryActions.deleteObjectUndo({objectId = data.groupId, serializedData = data.serializedData, isSimSet = true})
  else
    -- Restore objects individually using serialized data
    for i, id in ipairs(data.createdObjectIds) do
      if data.serializedObjects and data.serializedObjects[i] then
        objectHistoryActions.deleteObjectUndo({objectId = id, serializedData = data.serializedObjects[i]})
      end
    end
  end
  log("I", "alexkidd_generate_lights", "Redone: Restored " .. (data.groupId and "group" or #data.createdObjectIds .. " objects"))
end
local function getTemplateFromSelection()
  -- Check for TSStatic selection
  local tsStaticSelection = getSelectionByClass({"TSStatic"})
  if #tsStaticSelection > 0 then
    local obj = scenetree.findObjectById(tsStaticSelection[1])
    if obj then
      local shapeName = obj:getField('shapeName', 0)
      if shapeName and shapeName ~= "" then
        -- Extract just the filename from the path
        local shapeFileName = shapeName:match("([^/]+)$") or shapeName
        return {
          type = "TSStatic",
          id = tsStaticSelection[1],
          shapeName = shapeName,
          shapeFile = nil,
          displayName = shapeFileName
        }
      end
    end
  end
  
  -- Check for Forest item selection
  local forestItem = getSelectedForestItem()
  if forestItem then
    local itemData = forestItem:getData()
    if itemData and itemData.shapeFile then
      local shapeFilePath = tostring(itemData.shapeFile)
      -- Extract just the filename from the path
      local shapeFileName = shapeFilePath:match("([^/]+)$") or shapeFilePath
      return {
        type = "ForestItem",
        id = forestItem:getKey(),
        shapeName = nil,
        shapeFile = shapeFilePath,
        displayName = shapeFileName,
        position = vec3(forestItem:getPosition())
      }
    end
  end
  
  return nil
end

-- Calculate relative transforms of lights relative to the shape
local function calculateRelativeTransforms(template, lightIds)
  if not template or not template.type then return {} end
  
  local shapePos, shapeRot, shapeScale
  
  if template.type == "TSStatic" then
    local shape = scenetree.findObjectById(template.id)
    if not shape then return {} end
    shapePos = vec3(shape:getPosition())
    shapeRot = quat(shape:getRotation())
    -- Get scale from TSStatic
    local scaleStr = shape:getField('scale', 0)
    shapeScale = parseScale(scaleStr)
  elseif template.type == "ForestItem" then
    local forestData = getForestData()
    if not forestData then return {} end
    
    local forestItem = nil
    for _, item in ipairs(forestData:getItems()) do
      if item:getKey() == template.id then
        forestItem = item
        break
      end
    end
    
    if not forestItem then return {} end
    
    shapePos = vec3(forestItem:getPosition())
    local transform = forestItem:getTransform()
    shapeRot = quatFromMatrix(transform)
    -- Get scale from Forest item (uniform scale - convert to vec3)
    local uniformScale = forestItem:getScale()
    shapeScale = vec3(uniformScale, uniformScale, uniformScale)
  else
    return {}
  end
  
  local relativeTransforms = {}
  local shapeRotInverse = quat(shapeRot)
  shapeRotInverse:inverse()
  
  for _, lightId in ipairs(lightIds) do
    local light = scenetree.findObjectById(lightId)
    if light then
      local lightPos = vec3(light:getPosition())
      local worldRelativePos = lightPos - shapePos
      local localRelativePos = shapeRotInverse * worldRelativePos
      
      -- Normalize by template scale (divide by scale to get scale-independent position)
      localRelativePos = vec3(
        localRelativePos.x / shapeScale.x,
        localRelativePos.y / shapeScale.y,
        localRelativePos.z / shapeScale.z
      )
      
      -- Get the parent group of this light
      local parentGroupId = tonumber(light:getField("parentGroup", 0))
      local parentGroup = scenetree.findObjectById(parentGroupId) or scenetree.MissionGroup
      
      table.insert(relativeTransforms, {
        lightId = lightId,
        relativePosition = localRelativePos,
        className = light:getClassName(),
        parentGroup = parentGroup
      })
    end
  end
  
  return relativeTransforms
end

-- Calculate relative transforms of TSStatic objects relative to the shape
local function calculateRelativeTransformsForTSStatic(template, tsStaticIds)
  if not template or not template.type then return {} end
  
  local shapePos, shapeRot, shapeScale
  
  if template.type == "TSStatic" then
    local shape = scenetree.findObjectById(template.id)
    if not shape then return {} end
    shapePos = vec3(shape:getPosition())
    shapeRot = quat(shape:getRotation())
    -- Get scale from TSStatic
    local scaleStr = shape:getField('scale', 0)
    shapeScale = parseScale(scaleStr)
  elseif template.type == "ForestItem" then
    local forestData = getForestData()
    if not forestData then return {} end
    
    local forestItem = nil
    for _, item in ipairs(forestData:getItems()) do
      if item:getKey() == template.id then
        forestItem = item
        break
      end
    end
    
    if not forestItem then return {} end
    
    shapePos = vec3(forestItem:getPosition())
    local transform = forestItem:getTransform()
    shapeRot = quatFromMatrix(transform)
    -- Get scale from Forest item (uniform scale - convert to vec3)
    local uniformScale = forestItem:getScale()
    shapeScale = vec3(uniformScale, uniformScale, uniformScale)
  else
    return {}
  end
  
  local relativeTransforms = {}
  local shapeRotInverse = quat(shapeRot)
  shapeRotInverse:inverse()
  
  for _, tsStaticId in ipairs(tsStaticIds) do
    local tsStatic = scenetree.findObjectById(tsStaticId)
    if tsStatic then
      local tsStaticPos = vec3(tsStatic:getPosition())
      local tsStaticRot = quat(tsStatic:getRotation())
      local worldRelativePos = tsStaticPos - shapePos
      local localRelativePos = shapeRotInverse * worldRelativePos
      
      -- Normalize by template scale (divide by scale to get scale-independent position)
      localRelativePos = vec3(
        localRelativePos.x / shapeScale.x,
        localRelativePos.y / shapeScale.y,
        localRelativePos.z / shapeScale.z
      )
      
      -- Calculate relative rotation
      local localRelativeRot = shapeRotInverse * tsStaticRot
      
      -- Get the parent group of this TSStatic
      local parentGroupId = tonumber(tsStatic:getField("parentGroup", 0))
      local parentGroup = scenetree.findObjectById(parentGroupId) or scenetree.MissionGroup
      
      table.insert(relativeTransforms, {
        tsStaticId = tsStaticId,
        relativePosition = localRelativePos,
        relativeRotation = localRelativeRot,
        parentGroup = parentGroup
      })
    end
  end
  
  return relativeTransforms
end

-- Create a light from template at target object
local function createLightFromTemplate(templateLightId, relativePos, targetObj, lightIndex, targetGroup)
  local templateLight = scenetree.findObjectById(templateLightId)
  local lightType = templateLight:getClassName()
  
  local newLight = createObject(lightType)
  if not newLight then
    log("E", "alexkidd_generate_lights", "Failed to create " .. lightType)
    return nil
  end
  
  local uniqueName = "generated_" .. string.lower(lightType) .. "_" .. lightIndex .. "_" .. os.time() .. "_" .. math.random(100, 999)
  newLight.name = uniqueName
  newLight:setField('internalName', 0, uniqueName)
  newLight:registerObject(uniqueName)
  
  -- Copy all properties from template
  newLight:assignFieldsFromObject(templateLight)
  
  newLight:setField('internalName', 0, uniqueName)
  newLight.name = uniqueName
  
  -- Get target position, rotation, and scale (AFTER copying fields)
  local targetPos, targetRot, targetScale
  if type(targetObj) == "userdata" and targetObj.getPosition then
    -- TSStatic target
    targetPos = vec3(targetObj:getPosition())
    targetRot = quat(targetObj:getRotation())
    local scaleStr = targetObj:getField('scale', 0)
    targetScale = parseScale(scaleStr)
  else
    -- Forest item target (from itemData)
    targetPos = targetObj.pos
    targetRot = targetObj.rot
    targetScale = targetObj.scale and vec3(targetObj.scale, targetObj.scale, targetObj.scale) or vec3(1, 1, 1)
  end
  
  -- Apply target scale to the relative position
  local scaledRelativePos = vec3(
    relativePos.x * targetScale.x,
    relativePos.y * targetScale.y,
    relativePos.z * targetScale.z
  )
  
  local rotatedOffset = targetRot * scaledRelativePos
  local finalLightPos = targetPos + rotatedOffset
  
  newLight:setPosition(finalLightPos)
  
  -- Add to target group AFTER everything else
  targetGroup:addObject(newLight.obj)
  
  log("I", "alexkidd_generate_lights", "Created " .. lightType .. " at position: " .. finalLightPos.x .. ", " .. finalLightPos.y .. ", " .. finalLightPos.z)
  
  return newLight.obj:getId()
end

-- Create a TSStatic from template at target object
local function createTSStaticFromTemplate(templateTSStaticId, relativePos, relativeRot, targetObj, objectIndex, targetGroup)
  local templateTSStatic = scenetree.findObjectById(templateTSStaticId)
  
  local newTSStatic = createObject("TSStatic")
  if not newTSStatic then
    log("E", "alexkidd_generate_lights", "Failed to create TSStatic")
    return nil
  end
  
  -- Set shapeName BEFORE registering the object (required for TSStatic)
  local shapeName = templateTSStatic:getField('shapeName', 0)
  if shapeName and shapeName ~= "" then
    newTSStatic:setField('shapeName', 0, shapeName)
  end
  
  local uniqueName = "generated_tsstatic_" .. objectIndex .. "_" .. os.time() .. "_" .. math.random(100, 999)
  newTSStatic.name = uniqueName
  newTSStatic:setField('internalName', 0, uniqueName)
  newTSStatic:registerObject(uniqueName)
  
  -- Copy all properties from template (this will overwrite some fields, so we set them again after)
  newTSStatic:assignFieldsFromObject(templateTSStatic)
  
  -- Restore unique name after copying fields
  newTSStatic:setField('internalName', 0, uniqueName)
  newTSStatic.name = uniqueName
  
  -- Get target position, rotation, and scale (AFTER copying fields)
  local targetPos, targetRot, targetScale
  if type(targetObj) == "userdata" and targetObj.getPosition then
    -- TSStatic target
    targetPos = vec3(targetObj:getPosition())
    targetRot = quat(targetObj:getRotation())
    local scaleStr = targetObj:getField('scale', 0)
    targetScale = parseScale(scaleStr)
  else
    -- Forest item target (from itemData)
    targetPos = targetObj.pos
    targetRot = targetObj.rot
    targetScale = targetObj.scale and vec3(targetObj.scale, targetObj.scale, targetObj.scale) or vec3(1, 1, 1)
  end
  
  -- Apply target scale to the relative position
  local scaledRelativePos = vec3(
    relativePos.x * targetScale.x,
    relativePos.y * targetScale.y,
    relativePos.z * targetScale.z
  )
  
  -- Apply relative position and rotation
  local rotatedOffset = targetRot * scaledRelativePos
  local finalPos = targetPos + rotatedOffset
  local finalRot = targetRot * relativeRot
  
  newTSStatic:setPosRot(finalPos.x, finalPos.y, finalPos.z, finalRot.x, finalRot.y, finalRot.z, finalRot.w)
  
  -- Add to target group AFTER everything else
  targetGroup:addObject(newTSStatic.obj)
  newTSStatic:setField('internalName', 0, uniqueName)
  newTSStatic.name = uniqueName
  
  log("I", "alexkidd_generate_lights", "Created TSStatic at position: " .. finalPos.x .. ", " .. finalPos.y .. ", " .. finalPos.z)
  
  return newTSStatic.obj:getId()
end

-- Find all forest items matching a shape file
local function findForestItemsByShapeFile(shapeFile)
  local forestData = getForestData()
  if not forestData then return {} end
  
  local items = {}
  for _, item in ipairs(forestData:getItems()) do
    local itemData = item:getData()
    if itemData and tostring(itemData.shapeFile) == shapeFile then
      local transform = item:getTransform()
      table.insert(items, {
        pos = vec3(item:getPosition()),
        rot = quatFromMatrix(transform),
        scale = item:getScale()
      })
    end
  end
  return items
end

local function generateObjects()
  if not selectedTemplate.type or (#selectedLightIds == 0 and #selectedTSStaticIds == 0) then
    log("W", "alexkidd_generate_lights", "Need a template object and at least one light or TSStatic object selected")
    return
  end
  
  local relativeTransforms = {}
  local relativeTSStaticTransforms = {}
  
  -- Calculate relative transforms only if objects are selected
  if #selectedLightIds > 0 then
    relativeTransforms = calculateRelativeTransforms(selectedTemplate, selectedLightIds)
  end
  
  if #selectedTSStaticIds > 0 then
    relativeTSStaticTransforms = calculateRelativeTransformsForTSStatic(selectedTemplate, selectedTSStaticIds)
  end
  
  if #relativeTransforms == 0 and #relativeTSStaticTransforms == 0 then
    log("E", "alexkidd_generate_lights", "Could not calculate relative transforms")
    return
  end
  
  -- Determine target group strategy
  local useSharedGroup = useSimGroup[0]
  local sharedTargetGroup = nil
  local groupName = nil
  
  if useSharedGroup then
    -- Create a new folder/group for all objects
    local groupNumber = getNextGeneratedLightsNumber()
    groupName = "generated_lights_" .. groupNumber
    local newGroup = createObject("SimGroup")
    newGroup:registerObject(groupName)
    scenetree.MissionGroup:addObject(newGroup)
    sharedTargetGroup = newGroup
    log("I", "alexkidd_generate_lights", "Created group: " .. groupName)
  else
    log("I", "alexkidd_generate_lights", "Using individual source object parent groups")
  end
  
  -- Prepare undo data (only need to track created objects for deletion)
  local actionData = {
    createdObjectIds = {},
    groupId = useSharedGroup and sharedTargetGroup:getId() or nil
  }
  
  local targetObjects = {}
  local lightsCreated = 0
  local tsStaticsCreated = 0
  
  if selectedTemplate.type == "TSStatic" then
    local function findShapesInGroup(group, shapeName, results)
      if not group or not group.obj then return end
      if type(group.obj.getCount) ~= "function" then return end
      
      for i = 0, group.obj:getCount() - 1 do
        local childId = group.obj:idAt(i)
        local child = scenetree.findObjectById(childId)
        
        if child then
          if child:getClassName() == "TSStatic" then
            local childShapeName = child:getField('shapeName', 0)
            if childShapeName == shapeName then
              table.insert(results, child)
            end
          elseif child.obj and type(child.obj.getCount) == "function" then
            findShapesInGroup(child, shapeName, results)
          end
        end
      end
    end
    
    if scenetree.MissionGroup then
      findShapesInGroup(scenetree.MissionGroup, selectedTemplate.shapeName, targetObjects)
    end
    
    log("I", "alexkidd_generate_lights", "Found " .. #targetObjects .. " TSStatic objects with shapeName: " .. selectedTemplate.shapeName)
    
    for shapeIndex, targetShape in ipairs(targetObjects) do
      if targetShape:getId() ~= selectedTemplate.id then
        for transformIndex, transform in ipairs(relativeTransforms) do
          local lightIndex = (shapeIndex - 1) * #relativeTransforms + transformIndex
          -- Use shared group or individual parent group
          local targetGroup = useSharedGroup and sharedTargetGroup or transform.parentGroup
          
          local lightId = createLightFromTemplate(
            transform.lightId,
            transform.relativePosition,
            targetShape,
            lightIndex,
            targetGroup
          )
          if lightId then
            lightsCreated = lightsCreated + 1
            table.insert(actionData.createdObjectIds, lightId)
          end
        end
        
        for transformIndex, transform in ipairs(relativeTSStaticTransforms) do
          local objectIndex = (shapeIndex - 1) * #relativeTSStaticTransforms + transformIndex
          -- Use shared group or individual parent group
          local targetGroup = useSharedGroup and sharedTargetGroup or transform.parentGroup
          
          local tsStaticId = createTSStaticFromTemplate(
            transform.tsStaticId,
            transform.relativePosition,
            transform.relativeRotation,
            targetShape,
            objectIndex,
            targetGroup
          )
          if tsStaticId then
            tsStaticsCreated = tsStaticsCreated + 1
            table.insert(actionData.createdObjectIds, tsStaticId)
          end
        end
      end
    end
    
  elseif selectedTemplate.type == "ForestItem" then
    targetObjects = findForestItemsByShapeFile(selectedTemplate.shapeFile)
    
    log("I", "alexkidd_generate_lights", "Found " .. #targetObjects .. " Forest items with shapeFile: " .. selectedTemplate.shapeFile)
    
    for itemIndex, itemData in ipairs(targetObjects) do
      local distance = selectedTemplate.position and itemData.pos:distance(selectedTemplate.position) or math.huge
      local isTemplateItem = distance < 0.01
      if isTemplateItem then
        log("I", "alexkidd_generate_lights", "Skipping template forest item at position: " .. tostring(itemData.pos))
      end
      if not isTemplateItem then
        for transformIndex, transform in ipairs(relativeTransforms) do
          local lightIndex = (itemIndex - 1) * #relativeTransforms + transformIndex
          -- Use shared group or individual parent group
          local targetGroup = useSharedGroup and sharedTargetGroup or transform.parentGroup
          
          local lightId = createLightFromTemplate(
            transform.lightId,
            transform.relativePosition,
            itemData,
            lightIndex,
            targetGroup
          )
          if lightId then
            lightsCreated = lightsCreated + 1
            table.insert(actionData.createdObjectIds, lightId)
          end
        end
        
        for transformIndex, transform in ipairs(relativeTSStaticTransforms) do
          local objectIndex = (itemIndex - 1) * #relativeTSStaticTransforms + transformIndex
          -- Use shared group or individual parent group
          local targetGroup = useSharedGroup and sharedTargetGroup or transform.parentGroup
          
          local tsStaticId = createTSStaticFromTemplate(
            transform.tsStaticId,
            transform.relativePosition,
            transform.relativeRotation,
            itemData,
            objectIndex,
            targetGroup
          )
          if tsStaticId then
            tsStaticsCreated = tsStaticsCreated + 1
            table.insert(actionData.createdObjectIds, tsStaticId)
          end
        end
      end
    end
  end
  
  -- Serialize objects for undo/redo system
  if useSharedGroup and sharedTargetGroup then
    -- Serialize the whole group with all its children
    local grp = Sim.upcast(sharedTargetGroup.obj)
    local serializeData = {}
    
    local function serializeRecursively(fn, parent, tbl)
      parent = Sim.upcast(parent)
      tbl.json = "[" .. parent:serializeForEditor(true, -1, "group") .. "]"
      tbl.objectId = parent:getID()
      tbl.children = {}
      for i = 0, parent:size() - 1 do
        local chd = parent:at(i)
        if chd then
          local childTbl = {
            objectId = chd:getID(),
            json = "[" .. chd:serializeForEditor(true, -1, "") .. "]",
          }
          table.insert(tbl.children, childTbl)
        end
      end
    end
    
    serializeRecursively(serializeRecursively, grp, serializeData)
    actionData.serializedData = serializeData
    actionData.isSimSet = true
  else
    -- For individual objects, don't pre-serialize - serialize on-demand during undo/redo
    -- This is much faster for large numbers of objects
    actionData.parentGroupIds = {}
    for _, id in ipairs(actionData.createdObjectIds) do
      local obj = scenetree.findObjectById(id)
      if obj then
        local parentGroupId = tonumber(obj:getField("parentGroup", 0))
        table.insert(actionData.parentGroupIds, parentGroupId)
      end
    end
  end
  
  -- Commit to undo history with redo function
  local groupDisplayName = useSharedGroup and (groupName or "generated group") or "source object parent groups"
  local actionName = "Generate Lights and TSStatic Objects"
  if lightsCreated > 0 and tsStaticsCreated == 0 then
    actionName = "Generate " .. lightsCreated .. " Lights"
  elseif tsStaticsCreated > 0 and lightsCreated == 0 then
    actionName = "Generate " .. tsStaticsCreated .. " TSStatic Objects"
  else
    actionName = "Generate " .. lightsCreated .. " Lights and " .. tsStaticsCreated .. " TSStatic Objects"
  end
  
  editor.history:commitAction(actionName, actionData, generateObjectsUndo, generateObjectsRedo)
  
  log("I", "alexkidd_generate_lights", "Generated " .. lightsCreated .. " lights and " .. tsStaticsCreated .. " TSStatic objects in " .. groupDisplayName)
  editor.setDirty()
end

-- UI rendering
local function onEditorGui()
  if editor.beginWindow(toolWindowName, toolName) then
    -- Check if selected objects still exist
    if selectedTemplate.type == "TSStatic" and selectedTemplate.id then
      if not scenetree.findObjectById(selectedTemplate.id) then
        selectedTemplate = {type = nil, id = nil, shapeName = nil, shapeFile = nil, displayName = nil, position = nil}
      end
    end
    
    for i = #selectedLightIds, 1, -1 do
      if not scenetree.findObjectById(selectedLightIds[i]) then
        table.remove(selectedLightIds, i)
      end
    end
    
    for i = #selectedTSStaticIds, 1, -1 do
      if not scenetree.findObjectById(selectedTSStaticIds[i]) then
        table.remove(selectedTSStaticIds, i)
      end
    end
    
    im.TextUnformatted("1. Select Template Object")
    im.Separator()
    
    -- Display selected template
    local templateStr = "none"
    if selectedTemplate.type then
      templateStr = selectedTemplate.displayName or "Unknown"
      im.TextColored(im.ImVec4(0.5, 1, 0.5, 1), "Type: " .. selectedTemplate.type)
    end
    im.TextUnformatted("Selected Template: ")
    im.SameLine()
    im.TextWrapped(templateStr)
    
    -- Get Object by Selection button
    if im.Button("Get Object by Selection") then
      local template = getTemplateFromSelection()
      if template then
        selectedTemplate = template
        log("I", "alexkidd_generate_lights", "Selected " .. template.type .. ": " .. (template.shapeName or template.shapeFile))
      else
        log("W", "alexkidd_generate_lights", "No valid TSStatic or Forest item selected")
      end
    end
    im.tooltip("Select a TSStatic object OR a Forest item in the world editor, then click this button")
    
    im.Dummy(im.ImVec2(0, 10))
    im.TextUnformatted("2. Select Light Object(s) (Optional)")
    im.Separator()
    
    -- Display selected lights
    local lightsStr = "none"
    if #selectedLightIds > 0 then
      lightsStr = #selectedLightIds .. " light(s) selected"
    end
    im.TextUnformatted("Selected Lights: " .. lightsStr)
    
    -- Get Light(s) by Selection button
    if im.Button("Get Light(s) by Selection") then
      local selection = getSelectionByClass({"PointLight", "SpotLight"})
      if #selection > 0 then
        selectedLightIds = selection
        log("I", "alexkidd_generate_lights", "Selected " .. #selectedLightIds .. " lights")
      else
        log("W", "alexkidd_generate_lights", "No PointLight or SpotLight objects selected")
      end
    end
    im.tooltip("Select one or more PointLight or SpotLight objects in the world editor, then click this button")
    
    im.SameLine()
    if im.Button("Clear Lights") then
      selectedLightIds = {}
      log("I", "alexkidd_generate_lights", "Cleared light selection")
    end
    im.tooltip("Clear the current light selection")
    
    im.Dummy(im.ImVec2(0, 10))
    im.TextUnformatted("3. Select TSStatic Object(s) to Copy (Optional)")
    im.Separator()
    
    -- Display selected TSStatic objects
    local tsStaticsStr = "none"
    if #selectedTSStaticIds > 0 then
      tsStaticsStr = #selectedTSStaticIds .. " TSStatic object(s) selected"
    end
    im.TextUnformatted("Selected TSStatic Objects: " .. tsStaticsStr)
    
    -- Get TSStatic(s) by Selection button
    if im.Button("Get TSStatic(s) by Selection") then
      local selection = getSelectionByClass({"TSStatic"})
      if #selection > 0 then
        selectedTSStaticIds = selection
        log("I", "alexkidd_generate_lights", "Selected " .. #selectedTSStaticIds .. " TSStatic objects")
      else
        log("W", "alexkidd_generate_lights", "No TSStatic objects selected")
      end
    end
    im.tooltip("Select one or more TSStatic objects in the world editor, then click this button")
    
    im.SameLine()
    if im.Button("Clear TSStatic") then
      selectedTSStaticIds = {}
      log("I", "alexkidd_generate_lights", "Cleared TSStatic selection")
    end
    im.tooltip("Clear the current TSStatic selection")
    
    im.Dummy(im.ImVec2(0, 10))
    im.TextUnformatted("4. Options")
    im.Separator()
    
    im.Checkbox("Use New Folder", useSimGroup)
    im.tooltip("If checked, creates a new 'generated_lights_X' folder. If unchecked, places objects in the same group as the template object.")
    
    im.Dummy(im.ImVec2(0, 10))
    im.TextUnformatted("5. Generate Objects")
    im.Separator()
    
    -- Generate button with dynamic text
    local canGenerate = selectedTemplate.type ~= nil and (#selectedLightIds > 0 or #selectedTSStaticIds > 0)
    if not canGenerate then
      im.BeginDisabled()
    end
    
    -- Dynamic button text based on what's selected
    local buttonText = "Generate Objects"
    if #selectedLightIds > 0 and #selectedTSStaticIds > 0 then
      buttonText = "Generate Lights & TSStatic Objects"
    elseif #selectedLightIds > 0 then
      buttonText = "Generate Lights"
    elseif #selectedTSStaticIds > 0 then
      buttonText = "Generate TSStatic Objects"
    end
    
    if im.Button(buttonText) then
      generateObjects()
    end
    
    -- Dynamic tooltip based on what's selected
    local tooltipText = "Generate selected objects at all matching locations in the scene"
    if #selectedLightIds > 0 and #selectedTSStaticIds > 0 then
      tooltipText = "Generate " .. #selectedLightIds .. " light(s) and " .. #selectedTSStaticIds .. " TSStatic object(s) at all matching locations"
    elseif #selectedLightIds > 0 then
      tooltipText = "Generate " .. #selectedLightIds .. " light(s) at all matching locations"
    elseif #selectedTSStaticIds > 0 then
      tooltipText = "Generate " .. #selectedTSStaticIds .. " TSStatic object(s) at all matching locations"
    end
    im.tooltip(tooltipText)
    
    if not canGenerate then
      im.EndDisabled()
    end
    
    im.Dummy(im.ImVec2(0, 10))
    im.Separator()
    im.TextUnformatted("Info:")
    im.TextWrapped("This tool generates lights and/or TSStatic objects relative to template objects. Supports both TSStatic objects AND Forest items! Select a template object, then select lights and/or TSStatic objects to copy. At least one type must be selected.")
  end
  editor.endWindow()
end

-- Menu item callback
local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

-- Initialize the plugin
local function onEditorInitialized()
  editor.addWindowMenuItem(toolName, onWindowMenuItem)
  editor.registerWindow(toolWindowName, im.ImVec2(420, 400))
  log("I", "alexkidd_generate_lights", "Plugin initialized")
end

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M
