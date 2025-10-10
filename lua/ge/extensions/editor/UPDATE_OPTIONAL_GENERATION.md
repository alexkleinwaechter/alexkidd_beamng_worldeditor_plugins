# Update: Optional Lights and TSStatic Generation

## Overview
Both lights AND TSStatic objects are now **optional**! You can generate:
- ✅ Lights only
- ✅ TSStatic objects only
- ✅ Both lights and TSStatic objects together

## Changes Made

### 1. Renamed Function
- `generateLights()` → `generateObjects()` (more accurate name)

### 2. Optional Generation Logic
The function now checks if objects are selected before calculating transforms:

```lua
-- Calculate relative transforms only if objects are selected
if #selectedLightIds > 0 then
  relativeTransforms = calculateRelativeTransforms(selectedTemplate, selectedLightIds)
end

if #selectedTSStaticIds > 0 then
  relativeTSStaticTransforms = calculateRelativeTransformsForTSStatic(selectedTemplate, selectedTSStaticIds)
end
```

This means:
- If no lights selected → `relativeTransforms` is empty table → no lights generated
- If no TSStatic selected → `relativeTSStaticTransforms` is empty table → no TSStatic generated
- The loops automatically handle empty tables (just iterate 0 times)

### 3. Updated UI Labels
- **Step 2**: "Select Light Object(s) **(Optional)**"
- **Step 3**: "Select TSStatic Object(s) to Copy **(Optional)**"

Both steps now clearly marked as optional!

### 4. Added Clear Buttons
New buttons to clear selections without selecting new objects:
- **"Clear Lights"** - Clear light selection
- **"Clear TSStatic"** - Clear TSStatic selection

These appear next to the "Get by Selection" buttons for quick clearing.

### 5. Dynamic Button Text
The generate button text now changes based on what's selected:

| Lights Selected | TSStatic Selected | Button Text |
|----------------|-------------------|-------------|
| ✅ Yes | ✅ Yes | "Generate Lights & TSStatic Objects" |
| ✅ Yes | ❌ No | "Generate Lights" |
| ❌ No | ✅ Yes | "Generate TSStatic Objects" |
| ❌ No | ❌ No | Button disabled |

### 6. Dynamic Tooltip
The tooltip also updates to show exactly what will be generated:
- "Generate 2 light(s) and 3 TSStatic object(s) at all matching locations"
- "Generate 1 light(s) at all matching locations"
- "Generate 5 TSStatic object(s) at all matching locations"

### 7. Updated Info Text
New info text reflects the flexibility:
> "This tool generates lights and/or TSStatic objects relative to template objects. Supports both TSStatic objects AND Forest items! Select a template object, then select lights and/or TSStatic objects to copy. **At least one type must be selected.**"

## Usage Examples

### Example 1: Lights Only
1. Select template object
2. Select lights
3. Click "Generate Lights"
4. Result: Only lights are generated ✅

### Example 2: TSStatic Only
1. Select template object
2. Select TSStatic objects (skip lights)
3. Click "Generate TSStatic Objects"
4. Result: Only TSStatic objects are generated ✅

### Example 3: Both
1. Select template object
2. Select lights
3. Select TSStatic objects
4. Click "Generate Lights & TSStatic Objects"
5. Result: Both lights and TSStatic objects are generated ✅

### Example 4: Change Mind
1. Select template object
2. Select lights
3. Decide you don't want lights → Click "Clear Lights"
4. Select TSStatic objects
5. Click "Generate TSStatic Objects"
6. Result: Only TSStatic objects are generated ✅

## Benefits

### Flexibility
- Use the tool for different purposes without separate plugins
- Quick workflow changes (just clear one selection type)

### Clear Feedback
- Button text tells you exactly what will be generated
- Tooltip shows counts
- No confusion about what will happen

### User-Friendly
- Optional labels make it clear nothing is required except template
- Clear buttons for quick changes
- Dynamic UI adapts to your selections

### Code Quality
- Cleaner logic (explicit checks for selections)
- No duplicate calculations
- Better function naming

## Technical Details

### Empty Table Handling
The Lua `for` loops gracefully handle empty tables:
```lua
for transformIndex, transform in ipairs(relativeTransforms) do
  -- If relativeTransforms is empty {}, this never executes
end
```

This means we don't need special `if` checks in the generation loops - they just work!

### Performance
- Only calculates transforms for selected object types
- No wasted computation on empty selections
- Efficient iteration

## Backward Compatibility
- Existing usage patterns still work (selecting both types)
- No breaking changes
- Just adds more flexibility
