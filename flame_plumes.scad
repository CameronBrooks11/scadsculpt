// --------------------------------------------------------------
// Parametric Flame Sculpture
// Modified from: https://mastering-openscad.eu/buch/example_07/
// --------------------------------------------------------------

/* [General Settings] */
Total_Height = 180;
Number_of_Strands = 5; // [1:1:12]
Slices_Per_Strand = 40; // [10:1:100]

/* [Shape Geometry] */
// How wide the spiral is at the bottom in X
Base_Radius_X = 20;
// How wide the spiral is at the bottom in Y
Base_Radius_Y = 12;

// How many times the flame spirals around
Rotations = 1;

/* [Tapering & Distortion] */
// Controls the "fatness" of the flame curve
Taper_Steepness = 0.20; // [0.1:0.05:1.0]
// Where the transition from thick to thin happens
Taper_Transition = 0.25; // [0.05:0.05:0.9]
// Distorts height to make the tip accelerate upwards
Height_Distortion = 0.7; // [0.0:0.1:1.0]

/* [Scaling] */
Start_Scale = [1.0, 1.0]; // [0.01:0.01:2.0]
End_Scale = [0.05, 0.05]; // [0.01:0.01:2.0]

/* [Colors] */
Flame_Color_Bottom = [1, 0.5, 0]; // Orange
Flame_Color_Top = [1, 0, 0]; // Red

module flame_sculpture(
  height = 180,
  strands = 3,
  slices = 40,
  radius = [20, 12], // [x, y]
  scaling_range = [[1, 1], [0.1, 0.1]], // [start, end]
  taper_params = [0.2, 0.35], // [steepness, transition]
  distortion = 0.7,
  turns = 1
) {

  // 1. Calculate Path Data
  // ----------------------

  // Sigmoid function for organic tapering
  function sigmoid(x, steep, trans) =
    let (
      inc = 1.0 - pow(steep, 0.1),
      start_pt = -trans / inc
    ) 1 / (1 + exp(-(x / inc + start_pt)));

  // Generate scaling factors for every slice
  s_factors = [
    for (i = [0:slices]) 1.0 - sigmoid(i / slices, taper_params[0], taper_params[1]),
  ];

  // Generate XYZ positions for the spiral
  rot_inc = 360 * turns / slices;
  positions = [
    for (i = [0:slices]) [
      cos(i * rot_inc) * radius[0],
      sin(i * rot_inc) * radius[1],
      pow(i / slices, distortion) * height,
    ],
  ];

  // Calculate rotation angles (Axis-Angle approach)
  // We calculate the vector between current and previous point
  rel_pos = concat(
    [positions[0]],
    [for (i = [1:slices]) positions[i] - positions[i - 1]]
  );

  // Calculate the angle required to point Z-up towards the path vector
  // Using native OpenSCAD vector math
  function angle_between(v1, v2) =
    acos((v1 * v2) / (norm(v1) * norm(v2)));

  path_angles = concat(
    [0],
    [for (i = [1:slices - 1]) angle_between([0, 0, 1], rel_pos[i])],
    [0]
  );

  path_axes = concat(
    [[0, 0, 1]], // Default axis
    [for (i = [1:slices - 1]) cross([0, 0, 1], rel_pos[i])],
    [[0, 0, 1]]
  );

  // 2. The Single Flame Module
  // --------------------------
  module single_flame() {

    module segment_slice(i) {
      translate(positions[i])
        rotate(a=path_angles[i], v=path_axes[i])
          // Tiny extrusion ensures 2D children become 3D hulls
          linear_extrude(height=0.01)
            scale(
              [
                scaling_range[0][0] * s_factors[i] + scaling_range[1][0] * (1.0 - s_factors[i]),
                scaling_range[0][1] * s_factors[i] + scaling_range[1][1] * (1.0 - s_factors[i]),
              ]
            )
              children(0);
    }

    // Sequential Hull Loop
    for (i = [1:slices]) {
      // Calculate color blending
      blend = i / slices;
      c_mixed = Flame_Color_Bottom * (1 - blend) + Flame_Color_Top * blend;

      color(c_mixed)
        hull() {
          segment_slice(i - 1) children(0);
          segment_slice(i) children(0);
        }
    }
  }

  // 3. Generate Strands
  // -------------------
  for (s = [0:strands - 1]) {
    angle_offset = (360 / strands) * s;

    rotate([0, 0, angle_offset])
      translate([-radius[0], 0, 0]) // Offset from center
        single_flame()
          children(0);
  }
}

// ---------------------------------------------------------
// RENDER
// ---------------------------------------------------------

flame_sculpture(
  height=Total_Height,
  strands=Number_of_Strands,
  slices=Slices_Per_Strand,
  radius=[Base_Radius_X, Base_Radius_Y],
  scaling_range=[Start_Scale, End_Scale],
  taper_params=[Taper_Steepness, Taper_Transition],
  distortion=Height_Distortion,
  turns=Rotations
) {
  // You can swap this for square(), text(), or import()
  circle(d=60, $fn=40);
}
