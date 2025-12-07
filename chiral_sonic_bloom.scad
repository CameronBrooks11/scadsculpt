// ---------------------------------------------------------
// THE CHIRAL SONIC BLOOM – POLYHEDRON VERSION
// ---------------------------------------------------------

/* [Path Parameters] */
path_resolution = 360; // [100:20:1000]
major_radius = 60; // [20:1:150]
minor_radius = 20; // [5:1:60]
radial_freq = 3; // [1:1:10]
height_freq = 5; // [1:1:12]
height_amp = 25; // [0:1:80]

/* [Tube Parameters] */
tube_sides = 16; // [3:1:32]
tube_base_r = 6; // [2:1:15]
tube_pulse_amp = 2; // [0:1:8]
tube_pulse_freq = 9; // [1:1:20]

/* [Twist] */
mobius_twist_turns = 1.0; // [0:0.1:5.0]

/* [View] */
show_wireframe = false;

// ---------------------------------------------------------
// MATH HELPERS
// ---------------------------------------------------------

// Parametric path position (radius + vertical modulation)
function get_pos(t, r_maj, r_min, r_f, h_a, h_f) =
  let (
    r = r_maj + r_min * sin(t * r_f),
    z = h_a * sin(t * h_f)
  ) [r * cos(t), r * sin(t), z];

// Tube radius modulation along path
function get_tube_r(t, base, amp, f) = base + amp * sin(t * f);

// Rotation matrix aligning +Z to a vector
function align_z_matrix(vt) =
  let (
    u = vt / norm(vt),
    v0 = [0, 0, 1],
    ax = cross(v0, u),
    ln = norm(ax)
  ) ln < 1e-5 ? [
      [1, 0, 0],
      [0, 1, 0],
      [0, 0, 1],
    ]
  : let (
    c = v0 * u,
    s = ln,
    C = 1 - c,
    x = ax[0] / s,
    y = ax[1] / s,
    z = ax[2] / s
  ) [
      [x * x * C + c, x * y * C - z * s, x * z * C + y * s],
      [y * x * C + z * s, y * y * C + c, y * z * C - x * s],
      [z * x * C - y * s, z * y * C + x * s, z * z * C + c],
  ];

// Apply 3×3 matrix to a point
function transform(p, m) =
  [
    p[0] * m[0][0] + p[1] * m[0][1] + p[2] * m[0][2],
    p[0] * m[1][0] + p[1] * m[1][1] + p[2] * m[1][2],
    p[0] * m[2][0] + p[1] * m[2][1] + p[2] * m[2][2],
  ];

// ---------------------------------------------------------
// POLYHEDRON GENERATOR
// ---------------------------------------------------------

module sonic_bloom_polyhedron(
  res,
  sides,
  r_maj,
  r_min,
  r_f,
  h_a,
  h_f,
  t_base,
  t_amp,
  t_f,
  twists
) {
  step = 360 / res;
  ang_per_side = 360 / sides;

  // ---- vertex rings ----
  points = [
    for (i = [0:res - 1]) let (
      t = i * step,
      pos = get_pos(t, r_maj, r_min, r_f, h_a, h_f),
      pos_n = get_pos(t + step, r_maj, r_min, r_f, h_a, h_f),
      tangent = pos_n - pos,
      mat = align_z_matrix(tangent),
      tr = get_tube_r(t, t_base, t_amp, t_f),
      twist = 360 * twists * (i / res)
    ) for (j = [0:sides - 1]) let (
      theta = j * ang_per_side + twist,
      local = [tr * cos(theta), tr * sin(theta), 0]
    ) pos + transform(local, mat),
  ];

  // ---- faces ----
  faces = [
    for (i = [0:res - 1]) for (j = [0:sides - 1]) let (
      i0 = i * sides + j,
      i1 = i * sides + (j + 1) % sides,
      i2 = ( (i + 1) % res) * sides + (j + 1) % sides,
      i3 = ( (i + 1) % res) * sides + j
    ) [i0, i1, i2, i3],
  ];

  polyhedron(points=points, faces=faces, convexity=10);
}

// ---------------------------------------------------------
// RENDER
// ---------------------------------------------------------

color([1, 0.55, 0.2, 0.8])
  sonic_bloom_polyhedron(
    res=path_resolution,
    sides=tube_sides,
    r_maj=major_radius,
    r_min=minor_radius,
    r_f=radial_freq,
    h_a=height_amp,
    h_f=height_freq,
    t_base=tube_base_r,
    t_amp=tube_pulse_amp,
    t_f=tube_pulse_freq,
    twists=mobius_twist_turns
  );
