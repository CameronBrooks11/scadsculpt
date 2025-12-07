// --------------------------------------------------------------
// Parametric Flame Sculpture
// Modified from: https://mastering-openscad.eu/buch/example_07/
// --------------------------------------------------------------

/* [General Settings] */
total_height = 180;
number_of_strands = 5; // [1:1:12]
slices_per_strand = 40; // [10:1:100]

/* [Shape Geometry] */
base_radius_x = 20; // bottom width in X
base_radius_y = 12; // bottom width in Y
rotations = 1; // number of spiral turns

/* [Tapering & Distortion] */
// "fatness" of the curve
taper_steepness = 0.20; // [0.1:0.05:1.0]
// where thick → thin transition is centered
taper_transition = 0.25; // [0.05:0.05:0.9]
// accelerates upward rise near the tip
height_distortion = 0.7; // [0.0:0.1:1.0]

/* [Scaling] */
start_scale = [1.0, 1.0]; // [0.01:0.01:2.0]
end_scale = [0.05, 0.05]; // [0.01:0.01:2.0]

/* [Colors] */
flame_color_bottom = [1, 0.5, 0]; // orange
flame_color_top = [1, 0, 0]; // red

// ---------------------------------------------------------
// HELPERS
// ---------------------------------------------------------

// Sigmoid for smooth tapering along [0,1]
function sigmoid(x, steep, trans) =
  let (
    inc = 1.0 - pow(steep, 0.1),
    start_pt = -trans / inc
  ) 1 / (1 + exp(-(x / inc + start_pt)));

// Angle between two vectors
function angle_between(v1, v2) =
  acos((v1 * v2) / (norm(v1) * norm(v2)));

// ---------------------------------------------------------
// FLAME SCULPTURE
// ---------------------------------------------------------

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

  // ---- path data along the spiral ----

  s_factors = [
    for (i = [0:slices]) let (
      u = i / slices
    ) 1 - sigmoid(u, taper_params[0], taper_params[1]),
  ];

  rot_inc = 360 * turns / slices;

  positions = [
    for (i = [0:slices]) let (
      u = i / slices
    ) [
        cos(i * rot_inc) * radius[0],
        sin(i * rot_inc) * radius[1],
        pow(u, distortion) * height,
    ],
  ];

  // relative path vectors (for orientation)
  rel_pos = concat(
    [positions[0]],
    [for (i = [1:slices]) positions[i] - positions[i - 1]]
  );

  // rotation about axis taking +Z into rel_pos[i]
  path_angles = concat(
    [0],
    [for (i = [1:slices - 1]) angle_between([0, 0, 1], rel_pos[i])],
    [0]
  );

  path_axes = concat(
    [[0, 0, 1]],
    [for (i = [1:slices - 1]) cross([0, 0, 1], rel_pos[i])],
    [[0, 0, 1]]
  );

  // ---- single flame strand ----
  module single_flame() {

    module segment_slice(i) {
      // interpolate 2D scale between start/end
      s = s_factors[i];
      sx = scaling_range[0][0] * s + scaling_range[1][0] * (1 - s);
      sy = scaling_range[0][1] * s + scaling_range[1][1] * (1 - s);

      translate(positions[i])
        rotate(a=path_angles[i], v=path_axes[i])
          // thin extrude to turn 2D shape into 3D hull segments
          linear_extrude(height=0.01)
            scale([sx, sy])
              children(0);
    }

    // hull between successive slices for smooth volume
    for (i = [1:slices]) {
      blend = i / slices;
      c_mixed = flame_color_bottom * (1 - blend) + flame_color_top * blend;

      color(c_mixed)
        hull() {
          segment_slice(i - 1) children(0);
          segment_slice(i) children(0);
        }
    }
  }

  // ---- multiple rotated strands ----
  for (s = [0:strands - 1]) {
    angle_offset = 360 / strands * s;

    rotate([0, 0, angle_offset])
      translate([-radius[0], 0, 0]) // offset from center
        single_flame()
          children(0);
  }
}

// ---------------------------------------------------------
// RENDER
// ---------------------------------------------------------

flame_sculpture(
  height=total_height,
  strands=number_of_strands,
  slices=slices_per_strand,
  radius=[base_radius_x, base_radius_y],
  scaling_range=[start_scale, end_scale],
  taper_params=[taper_steepness, taper_transition],
  distortion=height_distortion,
  turns=rotations
) {
  // you can swap this for square(), text(), or import()
  circle(d=60, $fn=40);
}
