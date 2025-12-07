// ---------------------------------------------------------
// THE CHIRAL SONIC BLOOM - OPTIMIZED POLYHEDRON VERSION
// 
// 1. Instant rendering (Polyhedron vs Hull).
// 2. Seamless loop topology (Start connects to End).
// 3. Mathematical precision.
// ---------------------------------------------------------

/* [Path Parameters] */
Path_Resolution = 360; // [100:20:1000] Higher = Smoother path
Major_Radius = 60; // [20:1:150] Base radius
Minor_Radius = 20; // [5:1:60] Radial oscillation amplitude
Radial_Freq = 3; // [1:1:10] Radial "breathing" count
Height_Freq = 5; // [1:1:12] Vertical oscillation count
Height_Amp = 25; // [0:1:80] Z oscillation amplitude

/* [Tube Parameters] */
Tube_Sides = 16; // [3:1:32] Cross-section resolution
Tube_Base_R = 6; // [2:1:15] Average thickness
Tube_Pulse_Amp = 2; // [0:1:8] Thickness pulsing amount
Tube_Pulse_Freq = 9; // [1:1:20] Thickness pulsing frequency

/* [Twist] */
Mobius_Twist_Turns = 1.0; // [0:0.1:5.0] Rotations along the path

/* [View] */
Show_Wireframe = false; // Toggle to see the mesh structure

// ---------------------------------------------------------
// MATH HELPER FUNCTIONS
// ---------------------------------------------------------

// 1. Calculate Path Position P(t)
function get_pos(t, R_maj, R_min, R_freq, H_amp, H_freq) =
  let (
    // Modulated Radius
    R = R_maj + R_min * sin(t * R_freq),
    // Modulated Height
    Z = H_amp * sin(t * H_freq)
  ) [R * cos(t), R * sin(t), Z];

// 2. Calculate Tube Radius r(t)
function get_tube_r(t, base, amp, freq) =
  base + amp * sin(t * freq);

// 3. Rotation Matrix (Align Z-axis to Vector)
// Generates a 3x3 matrix to rotate [0,0,1] to point towards 'target_vec'
function align_z_matrix(target_vec) =
  let (
    u = target_vec / norm(target_vec), // Target unit vector
    v = [0, 0, 1], // Source vector
    axis = cross(v, u),
    len = norm(axis)
  )
  // If target is already Z (parallel), return Identity, else rotate
  len < 0.00001 ? [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
  : let (
    c = v * u, // Dot product (cos angle)
    s = len, // Sin angle
    C = 1 - c,
    x = axis[0] / s,
    y = axis[1] / s,
    z = axis[2] / s // Normalized axis components
  ) [
      [x * x * C + c, x * y * C - z * s, x * z * C + y * s],
      [y * x * C + z * s, y * y * C + c, y * z * C - x * s],
      [z * x * C - y * s, z * y * C + x * s, z * z * C + c],
  ];

// 4. Matrix Transformation
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
  R_maj,
  R_min,
  R_freq,
  H_amp,
  H_freq,
  T_base,
  T_amp,
  T_freq,
  twists
) {
  step = 360 / res;

  // --- STEP 1: GENERATE VERTICES ---
  // We create a flattened list of all points. 
  // Structure: Ring 0 [pt0..ptN], Ring 1 [pt0..ptN], ...

  points = [
    for (i = [0:res - 1]) let (
      t = i * step,

      // 1. Path Calculation
      pos = get_pos(t, R_maj, R_min, R_freq, H_amp, H_freq),

      // 2. Look-Ahead for Tangent
      // We calculate next position to determine the direction the tube faces
      next_t = (i + 1) * step,
      next_pos = get_pos(next_t, R_maj, R_min, R_freq, H_amp, H_freq),
      tangent = next_pos - pos,

      // 3. Orientation Matrix
      // Create a rotation matrix that points Z towards the tangent
      mat = align_z_matrix(tangent),

      // 4. Current Tube Radius
      r = get_tube_r(t, T_base, T_amp, T_freq),

      // 5. Twist Phase
      twist_angle = 360 * twists * (i / res)
    )
    // Inner loop: Generate the ring of points for this slice
    for (j = [0:sides - 1]) let (
      // Angle around the tube cross-section
      theta = (j * 360 / sides) + twist_angle,

      // Create point on XY plane (before 3D placement)
      // Note: We create it on XY, treating Z as the "forward" direction of the tube
      local_pt = [r * cos(theta), r * sin(theta), 0],

      // Rotate point to match path direction
      aligned_pt = transform(local_pt, mat)
    )
    // Translate to actual path position
    pos + aligned_pt,
  ];

  // --- STEP 2: GENERATE FACES ---
  // Connect the dots. We use Modulo (%) to wrap the end back to the start.

  faces = [
    for (i = [0:res - 1]) for (j = [0:sides - 1]) let (
      // Indices for the current quad
      // Current Ring
      idx_curr = i * sides + j,
      idx_curr_next = i * sides + (j + 1) % sides,

      // Next Ring (Wrap 'i' back to 0 at the end)
      idx_next = ( (i + 1) % res) * sides + j,
      idx_next_next = ( (i + 1) % res) * sides + (j + 1) % sides
    )
    // Define the Quad (Two triangles or one 4-point face)
    // Winding order matters for face normal (outside vs inside)
    [idx_curr, idx_curr_next, idx_next_next, idx_next],
  ];

  // --- STEP 3: OUTPUT MESH ---
  polyhedron(points=points, faces=faces, convexity=10);
}

// ---------------------------------------------------------
// RENDER CALL
// ---------------------------------------------------------

// Warm translucent amber/orange
color([1.0, 0.55, 0.2, 0.8])
  sonic_bloom_polyhedron(
    res=Path_Resolution,
    sides=Tube_Sides,
    R_maj=Major_Radius,
    R_min=Minor_Radius,
    R_freq=Radial_Freq,
    H_amp=Height_Amp,
    H_freq=Height_Freq,
    T_base=Tube_Base_R,
    T_amp=Tube_Pulse_Amp,
    T_freq=Tube_Pulse_Freq,
    twists=Mobius_Twist_Turns
  );
