// ---------------------------------------------------------
// THE HYPER-GARGOYLE (OPTIMIZED POLYHEDRON VERSION)
// ---------------------------------------------------------

/* [Master Parameters] */
Path_Resolution = 400; // [100:10:1000] Points along each path
Total_Height = 150; // [50:1:300] Overall height

/* [Spine (P1) Parameters - The Thunder-Marrow] */
Spine_Radius = 30; // Overall spiral radius
Spine_Freq_A = 4; // Spiral frequency (X/Y)
Spine_Freq_B = 6; // Height oscillation frequency (Z)
Spine_Tube_Base = 6; // Base thickness of the spine tube
Spine_Pulse_Freq = 10; // How fast the spine radius pulsates

/* [Ribs (P2 & P3) Parameters - The Circuit-Vines] */
Rib_Offset_Radius = 15; // Distance from spine center
Rib_Wrap_Freq = 3; // Wraps around the spine
Rib_Tube_Base = 4;
Rib_Pulse_Freq = 15;

/* [Resolution] */
Tube_Sides = 12; // [4:1:24] Cross-section polygon detail

// ---------------------------------------------------------
// MATH HELPER FUNCTIONS
// ---------------------------------------------------------

// 1. Spine Path Function
function get_spine_pos(t, R, H_max, FA, FB) =
  [
    R * cos(t * FA),
    R * sin(t * FA),
    // Continuous rise (H_max * t/360) + Sine wobble
    (H_max * t / 360) + (10 * sin(t * FB)),
  ];

// 2. Pulsating Radius Function
function get_pulse_r(t, base, freq) =
  base + (base * 0.4) * sin(t * freq);

// 3. Matrix: Align Z-axis to Vector
function align_z_matrix(target_vec) =
  let (
    u = target_vec / norm(target_vec),
    v = [0, 0, 1],
    axis = cross(v, u),
    len = norm(axis)
  ) len < 0.00001 ? [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
  : let (
    c = v * u,
    s = len,
    C = 1 - c,
    x = axis[0] / s,
    y = axis[1] / s,
    z = axis[2] / s
  ) [
      [x * x * C + c, x * y * C - z * s, x * z * C + y * s],
      [y * x * C + z * s, y * y * C + c, y * z * C - x * s],
      [z * x * C - y * s, z * y * C + x * s, z * z * C + c],
  ];

// 4. Transform Point by Matrix
function transform(p, m) =
  [
    p[0] * m[0][0] + p[1] * m[0][1] + p[2] * m[0][2],
    p[0] * m[1][0] + p[1] * m[1][1] + p[2] * m[1][2],
    p[0] * m[2][0] + p[1] * m[2][1] + p[2] * m[2][2],
  ];

// ---------------------------------------------------------
// TUBE GENERATOR MODULE
// ---------------------------------------------------------
// ---------------------------------------------------------
// POLYHEDRON GENERATOR (FIXED WITH CAPS)
// ---------------------------------------------------------

module render_tube_from_path(path_points, radii_list, sides) {
    
    count = len(path_points);
    
    // 1. Generate Vertices (Same as before)
    // -----------------------------------
    vertices = [
        for (i = [0 : count - 1])
            let (
                pos = path_points[i],
                next_pos = (i < count - 1) ? path_points[i+1] : path_points[i] + (path_points[i] - path_points[i-1]),
                tangent = next_pos - pos,
                mat = align_z_matrix(tangent),
                r = radii_list[i]
            )
            for (j = [0 : sides - 1])
                let (
                    theta = j * 360 / sides,
                    local_pt = [r * cos(theta), r * sin(theta), 0],
                    aligned_pt = transform(local_pt, mat)
                )
                pos + aligned_pt
    ];

    // 2. Generate Side Faces (Same as before, stops at count - 2)
    // -----------------------------------------------------------
    faces_sides = [
        for (i = [0 : count - 2])
            for (j = [0 : sides - 1])
                let (
                    curr = i * sides + j,
                    next_col = i * sides + (j + 1) % sides,
                    next_row = (i + 1) * sides + j,
                    next_row_next_col = (i + 1) * sides + (j + 1) % sides
                )
                [curr, next_col, next_row_next_col, next_row]
    ];
    
    // 3. Generate End Caps (NEW LOGIC)
    // --------------------------------
    
    // We need a central point for both the start and end caps to form a fan of triangles.
    // The central points are added to the *end* of the vertices list.
    
    // Calculate the position of the center point for the start cap (index 0)
    start_center_pos = path_points[0];
    
    // Calculate the position of the center point for the end cap (index count-1)
    end_center_pos = path_points[count-1];

    // Total vertices before adding caps
    vert_count = len(vertices);

    // Append the two center vertices to the list
    vertices_capped = concat(vertices, [start_center_pos], [end_center_pos]);

    // Generate Cap Faces (Triangles)
    faces_caps = [
        // A. Start Cap (Connects Ring 0 to the first new center point)
        for (j = [0 : sides - 1])
            let (
                idx_curr = j,
                idx_next = (j + 1) % sides,
                idx_center = vert_count // Index of the start_center_pos
            )
            // Winding order is crucial for correct face normals
            [idx_center, idx_next, idx_curr],

        // B. End Cap (Connects Ring count-1 to the second new center point)
        for (j = [0 : sides - 1])
            let (
                idx_curr = (count - 1) * sides + j,
                idx_next = (count - 1) * sides + (j + 1) % sides,
                idx_center = vert_count + 1 // Index of the end_center_pos
            )
            // Winding order for the end cap is usually reversed
            [idx_center, idx_curr, idx_next]
    ];


    // 4. Final Render
    // ----------------
    polyhedron(
        points = vertices_capped, 
        faces = concat(faces_sides, faces_caps), 
        convexity = 10
    );
}
// ---------------------------------------------------------
// MAIN LOGIC
// ---------------------------------------------------------

module generate_hyper_gargoyle() {

  T_max = 360;
  step = T_max / Path_Resolution;

  // --- A. CALCULATE SPINE DATA ---
  // We calculate the spine positions AND its orientation matrix for every point.
  // We need the matrix to correctly attach the Ribs later.

  spine_data = [
    for (i = [0:Path_Resolution]) let (
      t = i * step,
      pos = get_spine_pos(t, Spine_Radius, Total_Height, Spine_Freq_A, Spine_Freq_B),

      // Calculate next pos for tangent
      next_t = (i + 1) * step,
      next_pos = get_spine_pos(next_t, Spine_Radius, Total_Height, Spine_Freq_A, Spine_Freq_B),
      tangent = next_pos - pos,

      // Matrix that represents the spine's local orientation
      mat = align_z_matrix(tangent),

      // Radius for the spine itself
      r = get_pulse_r(t, Spine_Tube_Base, Spine_Pulse_Freq)
    ) [pos, mat, r, t], // Store everything in a tuple
  ];

  // --- B. GENERATE PATH ARRAYS ---

  // 1. Extract Spine Path & Radii
  p1_points = [for (d = spine_data) d[0]];
  p1_radii = [for (d = spine_data) d[2]];

  // 2. Calculate Rib Paths (P2 & P3)
  // The ribs are offsets calculated in the Spine's Local Frame
  p2_data = [
    for (d = spine_data) let (
      center = d[0],
      mat = d[1],
      t = d[3],

      // Calculate rotational angle for the rib winding
      angle = t * Rib_Wrap_Freq,

      // Create offset vector on the local XY plane
      local_offset = [Rib_Offset_Radius * cos(angle), Rib_Offset_Radius * sin(angle), 0],

      // Transform offset by Spine's matrix so it aligns with the curve
      world_offset = transform(local_offset, mat)
    ) [center + world_offset, get_pulse_r(t, Rib_Tube_Base, Rib_Pulse_Freq)],
  ];

  p3_data = [
    for (d = spine_data) let (
      center = d[0],
      mat = d[1],
      t = d[3],
      // 180 degree offset for the second rib
      angle = t * Rib_Wrap_Freq + 180,
      local_offset = [Rib_Offset_Radius * cos(angle), Rib_Offset_Radius * sin(angle), 0],
      world_offset = transform(local_offset, mat)
    ) [center + world_offset, get_pulse_r(t, Rib_Tube_Base, Rib_Pulse_Freq)],
  ];

  // Separate points/radii for cleaner function calls
  p2_points = [for (d = p2_data) d[0]];
  p2_radii = [for (d = p2_data) d[1]];

  p3_points = [for (d = p3_data) d[0]];
  p3_radii = [for (d = p3_data) d[1]];

  // --- C. RENDER ---

  // 1. Thunder-Marrow (Spine)
  color("crimson")
    render_tube_from_path(p1_points, p1_radii, Tube_Sides);

  // 2. Circuit-Vine A (Rib 1)
  color("chartreuse")
    render_tube_from_path(p2_points, p2_radii, Tube_Sides);

  // 3. Circuit-Vine B (Rib 2)
  color("gold")
    render_tube_from_path(p3_points, p3_radii, Tube_Sides);
}

// ---------------------------------------------------------
// RENDER CALL
// ---------------------------------------------------------

generate_hyper_gargoyle();
