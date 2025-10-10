# Generate Lights & TSStatic Objects - Usage Guide

## Quick Start

### Step 1: Select Template Object
1. In the world editor, select **ONE** object to use as your template:
   - A **TSStatic** object (any 3D mesh object in the scene), OR
   - A **Forest item** (tree, rock, etc. from the forest brush)
2. Click **"Get Object by Selection"** in the plugin window
3. The plugin will show the type and name of your template

### Step 2: Select Light Objects (Optional)
1. Select **one or more** lights that should be copied:
   - **PointLight** (omnidirectional light)
   - **SpotLight** (directional cone light)
2. Click **"Get Light(s) by Selection"** in the plugin window
3. The plugin will show how many lights are selected

### Step 3: Select TSStatic Objects to Copy (Optional)
1. Select **one or more** TSStatic objects that should be copied:
   - Any 3D mesh objects (decorations, props, signs, etc.)
   - Can be different from your template object
2. Click **"Get TSStatic(s) by Selection"** in the plugin window
3. The plugin will show how many TSStatic objects are selected

### Step 4: Generate Objects
1. Click **"Generate Lights"** button
2. The plugin will:
   - Find all objects matching your template (same shape/mesh)
   - Generate lights at each matching location
   - Generate TSStatic copies at each matching location
   - Create a group called `generated_lights_X` with all new objects

## Example Scenarios

### Scenario 1: Street Lamp with Decorative Base
**Goal**: You have street lamps throughout your map and want to add lights and decorative bases to all of them.

**Steps**:
1. Select one street lamp (your template) → Get Object by Selection
2. Place a PointLight above the lamp → Select it → Get Light(s) by Selection
3. Place a decorative base TSStatic next to the lamp → Select it → Get TSStatic(s) by Selection
4. Click Generate Lights
5. Result: All street lamps now have lights and decorative bases!

### Scenario 2: Forest Tree Decorations
**Goal**: Add mushrooms and rocks around specific tree types in your forest.

**Steps**:
1. Select a forest tree item → Get Object by Selection
2. Place mushroom and rock TSStatic objects around the tree → Select them → Get TSStatic(s) by Selection
3. Click Generate Lights
4. Result: All matching trees now have mushrooms and rocks around them!

### Scenario 3: Building Windows with Lights
**Goal**: Add lights to all window frames on identical buildings.

**Steps**:
1. Select one building TSStatic (template) → Get Object by Selection
2. Place PointLights at each window position → Select them → Get Light(s) by Selection
3. Click Generate Lights
4. Result: All identical buildings now have window lights!

### Scenario 4: Sign Posts with Lights and Information Boards
**Goal**: Complex multi-object assembly.

**Steps**:
1. Select sign post TSStatic (template) → Get Object by Selection
2. Place a SpotLight above the sign → Select it → Get Light(s) by Selection
3. Place information board and trash bin TSStatics near the sign → Select them → Get TSStatic(s) by Selection
4. Click Generate Lights
5. Result: Complete sign post assembly copied to all matching locations!

## Tips & Best Practices

### Positioning Your Objects
- **Relative positioning matters**: The plugin calculates where your lights and TSStatic objects are positioned *relative* to the template object
- **Rotation is preserved**: If you rotate a TSStatic, that rotation will be maintained at all generated copies
- **Be precise**: Use the editor's transform tools to position objects exactly where you want them

### Selection Tips
- You can select multiple lights at once (Ctrl+Click)
- You can select multiple TSStatic objects at once (Ctrl+Click)
- The template object should be selected alone (don't select multiple templates)
- Selected objects are validated - deleted objects are automatically removed from selection

### Performance Considerations
- **Large scenes**: Generating hundreds of objects may take a few seconds
- **Forest items**: Forest items are optimized for rendering many instances efficiently
- **TSStatic objects**: Each TSStatic is a full scene object with collision, so use judiciously

### Organizing Your Scene
- All generated objects are placed in a `generated_lights_X` group in MissionGroup
- Each generation creates a new numbered group (generated_lights_1, generated_lights_2, etc.)
- You can delete entire groups easily if you need to regenerate
- Generated objects have unique names with timestamps and random numbers

### Common Issues & Solutions

**Issue**: "Need both a template object and lights/TSStatic objects selected"
- **Solution**: Make sure you've selected a template AND at least lights or TSStatic objects

**Issue**: No objects are generated
- **Solution**: Check that you have other objects in the scene with the same shapeName (for TSStatic) or shapeFile (for Forest items)

**Issue**: Objects are in wrong positions
- **Solution**: Check the relative positioning of your lights/TSStatic objects to the template. Try repositioning them and regenerating.

**Issue**: Objects are rotated incorrectly
- **Solution**: Make sure your template object has the correct rotation. The plugin uses relative rotations.

## Advanced Usage

### Mixed Templates
- You can use a Forest item as a template and copy TSStatic objects to it
- You can use a TSStatic as a template and it will work with Forest items (if shapeNames match)

### Iterative Design
1. Generate objects
2. Check the result
3. Delete the generated group
4. Adjust positions/rotations of your template objects
5. Regenerate until satisfied

### Only Lights OR Only TSStatic
- You don't need to select both!
- Select only lights if you just want to add lights
- Select only TSStatic objects if you just want to copy decorations
- The plugin is flexible!

## Workflow Integration

### Best Workflow
1. **Plan your scene**: Decide where template objects should be
2. **Set up one template**: Position all lights and decorations perfectly on ONE template
3. **Generate**: Let the plugin copy to all matching objects
4. **Refine**: Make adjustments and regenerate if needed

This is much faster than manually placing lights and decorations on dozens or hundreds of objects!

## Need Help?
- Check the plugin window's "Info" section for a quick reminder
- Look at the console logs for detailed information about what the plugin is doing
- Review the generated groups in the Scene Tree to see what was created
