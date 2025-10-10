-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Author: Sascha Kleinwächter (AlexKidd71)
-- Forum Profile: https://www.beamng.com/members/alexkidd71.475455

local M = {}
local im = ui_imgui
local toolWindowName = "Generate Lights"
local toolName = "Generate Lights"

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

-- Get template object from selection (TSStatic or Forest item)
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
  
  local shapePos, shapeRot
  
  if template.type == "TSStatic" then
    local shape = scenetree.findObjectById(template.id)
    if not shape then return {} end
    shapePos = vec3(shape:getPosition())
    shapeRot = quat(shape:getRotation())
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
      
      table.insert(relativeTransforms, {
        lightId = lightId,
        relativePosition = localRelativePos,
        className = light:getClassName()
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
  newLight:registerObject()
  
  -- Copy all properties from template
  newLight:assignFieldsFromObject(templateLight)
  
  newLight:setField('internalName', 0, uniqueName)
  newLight.name = uniqueName
  
  -- Get target position and rotation
  local targetPos, targetRot
  if type(targetObj) == "userdata" and targetObj.getPosition then
    targetPos = vec3(targetObj:getPosition())
    targetRot = quat(targetObj:getRotation())
  else
    targetPos = targetObj.pos
    targetRot = targetObj.rot
  end
  
  local rotatedOffset = targetRot * relativePos
  local finalLightPos = targetPos + rotatedOffset
  
  newLight:setPosition(finalLightPos)
  targetGroup:addObject(newLight.obj)
  
  log("I", "alexkidd_generate_lights", "Created " .. lightType .. " at position: " .. finalLightPos.x .. ", " .. finalLightPos.y .. ", " .. finalLightPos.z)
  
  return newLight
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

local function generateLights()
  if not selectedTemplate.type or #selectedLightIds == 0 then
    log("W", "alexkidd_generate_lights", "Need both a template object and lights selected")
    return
  end
  
  local relativeTransforms = calculateRelativeTransforms(selectedTemplate, selectedLightIds)
  if #relativeTransforms == 0 then
    log("E", "alexkidd_generate_lights", "Could not calculate relative transforms")
    return
  end
  
  local groupNumber = getNextGeneratedLightsNumber()
  local groupName = "generated_lights_" .. groupNumber
  local newGroup = createObject("SimGroup")
  newGroup:registerObject(groupName)
  scenetree.MissionGroup:addObject(newGroup)
  
  log("I", "alexkidd_generate_lights", "Created group: " .. groupName)
  
  local targetObjects = {}
  local lightsCreated = 0
  
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
          local newLight = createLightFromTemplate(
            transform.lightId,
            transform.relativePosition,
            targetShape,
            lightIndex,
            newGroup
          )
          if newLight then
            lightsCreated = lightsCreated + 1
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
          local newLight = createLightFromTemplate(
            transform.lightId,
            transform.relativePosition,
            itemData,
            lightIndex,
            newGroup
          )
          if newLight then
            lightsCreated = lightsCreated + 1
          end
        end
      end
    end
  end
  
  log("I", "alexkidd_generate_lights", "Generated " .. lightsCreated .. " lights in group " .. groupName)
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
    im.TextUnformatted("2. Select Light Object(s)")
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
    
    im.Dummy(im.ImVec2(0, 10))
    im.TextUnformatted("3. Generate Lights")
    im.Separator()
    
    -- Generate Lights button
    local canGenerate = selectedTemplate.type ~= nil and #selectedLightIds > 0
    if not canGenerate then
      im.BeginDisabled()
    end
    
    if im.Button("Generate Lights") then
      generateLights()
    end
    im.tooltip("Generate lights at all matching objects in the scene (TSStatic or Forest items)")
    
    if not canGenerate then
      im.EndDisabled()
    end
    
    im.Dummy(im.ImVec2(0, 10))
    im.Separator()
    im.TextUnformatted("Info:")
    im.TextWrapped("This tool generates lights relative to objects. Supports both TSStatic objects AND Forest items! Select a template object and its lights, then click Generate Lights.")
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
