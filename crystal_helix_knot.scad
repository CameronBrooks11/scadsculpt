// ---------------------------------------------------------
// THE CRYSTALLINE HELIX – POLYHEDRON VERSION
// ---------------------------------------------------------

/* [Path Parameters] */
path_cycles = 1; // [1:1:5] Number of full repetitions
path_resolution = 200; // [50:1:500] Vertices along the path (Higher is smoother)
overall_radius = 40; // [20:1:100] Overall radius of the knot
height_amplitude = 30; // [0:1:50] Vertical wiggle amplitude

// Knot Frequencies (A and B should be co-prime)
frequency_a = 3; // [1:1:5] X/Y Frequency
frequency_b = 5; // [1:1:5] Z Frequency

/* [Tube Parameters] */
tube_segments = 6; // [3:1:16] Sides of the cross-section (Low = more crystalline)
tube_base_radius = 8; // [1:1:15] Average tube radius
tube_pulse_amplitude = 3; // [0:1:5] Radius pulsation amount
pulse_frequency = 8; // [1:1:20] Radius pulsation frequency

/* [Twist] */
// For a perfect seam, this should be a multiple of 360
axial_twist_degrees = 360; // [0:1:1080]

/* [View] */
show_control_points = false;

// ---------------------------------------------------------
// MATH FUNCTIONS
// ---------------------------------------------------------

// Knot path position P(t)
function get_pos(t, r, h, fa, fb) =
  [
    r * cos(t * fa),
    r * sin(t * fa),
    h * cos(t * fb),
  ];

// Pulsating tube radius r(t)
function get_radius(t, base, amp, freq) =
  base + amp * sin(t * freq);

// Axis-angle rotation matrix
function rot_matrix(angle, axis) =
  let (
    c = cos(angle),
    s = sin(angle),
    C = 1 - c,
    x = axis[0],
    y = axis[1],
    z = axis[2]
  ) [
      [x * x * C + c, x * y * C - z * s, x * z * C + y * s],
      [y * x * C + z * s, y * y * C + c, y * z * C - x * s],
      [z * x * C - y * s, z * y * C + x * s, z * z * C + c],
  ];

// Transform point by 3×3 matrix
function transform(p, m) =
  [
    p[0] * m[0][0] + p[1] * m[0][1] + p[2] * m[0][2],
    p[0] * m[1][0] + p[1] * m[1][1] + p[2] * m[1][2],
    p[0] * m[2][0] + p[1] * m[2][1] + p[2] * m[2][2],
  ];

// ---------------------------------------------------------
// MESH GENERATION
// ---------------------------------------------------------

module crystalline_polyhedron(
  cycles,
  res,
  r,
  h,
  fa,
  fb,
  segs,
  r_base,
  r_amp,
  p_freq,
  twist
) {
  step = (cycles * 360) / res;

  // Vertex rings
  points = [
    for (i = [0:res - 1]) let (
      t = i * step,
      pos = get_pos(t, r, h, fa, fb),
      pos_n = get_pos(t + step, r, h, fa, fb),
      tangent = (pos_n - pos) / norm(pos_n - pos),
      up = [0, 0, 1],
      safe_up = (abs(tangent[2]) > 0.9) ? [0, 1, 0] : up,
      axis_vec = cross(safe_up, tangent),
      axis_norm = norm(axis_vec) < 1e-4 ? [1, 0, 0] : axis_vec / norm(axis_vec),
      angle_to_tan = acos(tangent[2]),
      cur_r = get_radius(t, r_base, r_amp, p_freq),
      cur_twist = (twist * i) / res,
      mat_align = rot_matrix(angle_to_tan, axis_norm)
    ) for (j = [0:segs - 1]) let (
      theta = (360 / segs) * j + cur_twist,
      circle_pt = [cur_r * cos(theta), cur_r * sin(theta), 0],
      aligned = transform(circle_pt, mat_align)
    ) pos + aligned,
  ];

  // Quad faces between rings
  faces = [
    for (i = [0:res - 1]) for (j = [0:segs - 1]) let (
      a = i * segs + j,
      b = i * segs + (j + 1) % segs,
      c = ( (i + 1) % res) * segs + (j + 1) % segs,
      d = ( (i + 1) % res) * segs + j
    ) [a, b, c, d],
  ];

  polyhedron(points=points, faces=faces, convexity=10);
}

// ---------------------------------------------------------
// MAIN RENDER
// ---------------------------------------------------------

color([0.3, 0.7, 1.0, 0.8]) // Translucent crystalline blue
  crystalline_polyhedron(
    cycles=path_cycles,
    res=path_resolution,
    r=overall_radius,
    h=height_amplitude,
    fa=frequency_a,
    fb=frequency_b,
    segs=tube_segments,
    r_base=tube_base_radius,
    r_amp=tube_pulse_amplitude,
    p_freq=pulse_frequency,
    twist=axial_twist_degrees
  );
