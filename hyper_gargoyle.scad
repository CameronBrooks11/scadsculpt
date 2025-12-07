// ---------------------------------------------------------
// THE HYPER-GARGOYLE – POLYHEDRON VERSION
// ---------------------------------------------------------

/* [Master Parameters] */
path_resolution = 400; // [100:10:1000] Points along each path
total_height = 150; // [50:1:300] Overall height

/* [Spine (P1) Parameters – The Thunder-Marrow] */
spine_radius = 30;
spine_freq_xy = 4; // Spiral frequency (X/Y)
spine_freq_z = 6; // Height oscillation frequency (Z)
spine_tube_base = 6; // Base thickness of the spine tube
spine_pulse_freq = 10; // Spine radius pulsation frequency

/* [Ribs (P2 & P3) Parameters – The Circuit-Vines] */
rib_offset_radius = 15; // Distance from spine center
rib_wrap_freq = 3; // Wraps around the spine
rib_tube_base = 4;
rib_pulse_freq = 15;

/* [Resolution] */
tube_sides = 12; // [4:1:24] Cross-section polygon detail

// ---------------------------------------------------------
// MATH HELPERS
// ---------------------------------------------------------

// Spine path position: helical rise + vertical wobble
function get_spine_pos(t, r, h_max, f_xy, f_z) =
  [
    r * cos(t * f_xy),
    r * sin(t * f_xy),
    (h_max * t / 360) + 10 * sin(t * f_z),
  ];

// Pulsating radius (fraction of base)
function get_pulse_r(t, base, f) =
  base + base * 0.4 * sin(t * f);

// Rotation matrix aligning +Z to a target vector
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

// Apply 3×3 matrix to point
function transform(p, m) =
  [
    p[0] * m[0][0] + p[1] * m[0][1] + p[2] * m[0][2],
    p[0] * m[1][0] + p[1] * m[1][1] + p[2] * m[1][2],
    p[0] * m[2][0] + p[1] * m[2][1] + p[2] * m[2][2],
  ];

// ---------------------------------------------------------
// TUBE POLYHEDRON FROM A PATH
// ---------------------------------------------------------

module render_tube_from_path(path_points, radii_list, sides) {

  count = len(path_points);
  ang_step = 360 / sides;

  // ---- vertices along the path ----
  vertices = [
    for (i = [0:count - 1]) let (
      pos = path_points[i],
      pos_next = i < count - 1 ? path_points[i + 1]
      : path_points[i] + (path_points[i] - path_points[i - 1]),
      tangent = pos_next - pos,
      mat = align_z_matrix(tangent),
      r = radii_list[i]
    ) for (j = [0:sides - 1]) let (
      theta = j * ang_step,
      local = [r * cos(theta), r * sin(theta), 0]
    ) pos + transform(local, mat),
  ];

  // ---- side faces (quads between rings) ----
  faces_sides = [
    for (i = [0:count - 2]) for (j = [0:sides - 1]) let (
      curr = i * sides + j,
      next_col = i * sides + (j + 1) % sides,
      next_row = (i + 1) * sides + j,
      next_row_next = (i + 1) * sides + (j + 1) % sides
    ) [curr, next_col, next_row_next, next_row],
  ];

  // ---- end caps (fan from ring centers) ----
  start_center_pos = path_points[0];
  end_center_pos = path_points[count - 1];

  vert_count = len(vertices);

  vertices_capped = concat(
    vertices,
    [start_center_pos],
    [end_center_pos]
  );

  faces_caps = [
    // start cap
    for (j = [0:sides - 1]) let (
      idx_curr = j,
      idx_next = (j + 1) % sides,
      idx_center = vert_count
    ) [idx_center, idx_next, idx_curr],

    // end cap
    for (j = [0:sides - 1]) let (
      idx_curr = (count - 1) * sides + j,
      idx_next = (count - 1) * sides + (j + 1) % sides,
      idx_center = vert_count + 1
    ) [idx_center, idx_curr, idx_next],
  ];

  polyhedron(
    points=vertices_capped,
    faces=concat(faces_sides, faces_caps),
    convexity=10
  );
}

// ---------------------------------------------------------
// MAIN GEOMETRY
// ---------------------------------------------------------

module generate_hyper_gargoyle() {

  t_max = 360;
  step = t_max / path_resolution;

  // ---- spine data: position, frame, radius, parameter ----
  spine_data = [
    for (i = [0:path_resolution]) let (
      t = i * step,
      pos = get_spine_pos(
        t, spine_radius, total_height,
        spine_freq_xy, spine_freq_z
      ),
      pos_next = get_spine_pos(
        t + step, spine_radius, total_height,
        spine_freq_xy, spine_freq_z
      ),
      tangent = pos_next - pos,
      mat = align_z_matrix(tangent),
      r = get_pulse_r(t, spine_tube_base, spine_pulse_freq)
    ) [pos, mat, r, t],
  ];

  // ---- extract spine path and radii ----
  p1_points = [for (d = spine_data) d[0]];
  p1_radii = [for (d = spine_data) d[2]];

  // ---- ribs: offset in spine-local frame ----
  p2_data = [
    for (d = spine_data) let (
      center = d[0],
      mat = d[1],
      t = d[3],
      angle = t * rib_wrap_freq,
      local_offset = [
        rib_offset_radius * cos(angle),
        rib_offset_radius * sin(angle),
        0,
      ],
      world_offset = transform(local_offset, mat)
    ) [center + world_offset, get_pulse_r(t, rib_tube_base, rib_pulse_freq)],
  ];

  p3_data = [
    for (d = spine_data) let (
      center = d[0],
      mat = d[1],
      t = d[3],
      angle = t * rib_wrap_freq + 180,
      local_offset = [
        rib_offset_radius * cos(angle),
        rib_offset_radius * sin(angle),
        0,
      ],
      world_offset = transform(local_offset, mat)
    ) [center + world_offset, get_pulse_r(t, rib_tube_base, rib_pulse_freq)],
  ];

  p2_points = [for (d = p2_data) d[0]];
  p2_radii = [for (d = p2_data) d[1]];

  p3_points = [for (d = p3_data) d[0]];
  p3_radii = [for (d = p3_data) d[1]];

  // ---- render: spine + two ribs ----
  color("crimson")
    render_tube_from_path(p1_points, p1_radii, tube_sides);

  color("chartreuse")
    render_tube_from_path(p2_points, p2_radii, tube_sides);

  color("gold")
    render_tube_from_path(p3_points, p3_radii, tube_sides);
}

// ---------------------------------------------------------
// RENDER CALL
// ---------------------------------------------------------

generate_hyper_gargoyle();
