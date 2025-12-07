// ---------------------------------------------------------
// THE CRYSTALLINE HELIX - OPTIMIZED POLYHEDRON VERSION
// 
// 1. Renders instantly compared to hull()
// 2. Topology is seamlessly closed (start connects to end)
// 3. Uses native vector math
// ---------------------------------------------------------

/* [Path Parameters] */
Path_Cycles = 1;       // [1:1:5] Number of full repetitions
Path_Resolution = 200; // [50:1:500] Vertices along the path (Higher is smoother)
Overall_Radius = 40;   // [20:1:100] Overall radius of the knot
Height_Amplitude = 30; // [0:1:50] Vertical wiggle amplitude

// Knot Frequencies (A and B should be co-prime)
Frequency_A = 3;       // [1:1:5] X/Y Frequency
Frequency_B = 5;       // [1:1:5] Z Frequency

/* [Tube Parameters] */
Tube_Segments = 6;     // [3:1:16] Sides of the cross-section (Low number = Crystalline look)
Tube_Base_Radius = 8;  // [1:1:15] Average tube radius
Tube_Pulse_Amplitude = 3; // [0:1:5] Radius pulsation amount
Pulse_Frequency = 8;   // [1:1:20] Radius pulsation frequency

/* [Twist] */
// For a perfect seam, this should be a multiple of 360
Axial_Twist_Degrees = 360; // [0:1:1080]

/* [View] */
Show_Control_Points = false;

// ---------------------------------------------------------
// MATHEMATICAL FUNCTIONS
// ---------------------------------------------------------

// 1. The Knot Path P(t)
function get_pos(t, R, H, fa, fb) = [
    R * cos(t * fa),
    R * sin(t * fa),
    H * cos(t * fb)
];

// 2. The Pulsating Radius r(t)
function get_radius(t, base, amp, freq) = 
    base + amp * sin(t * freq);

// 3. Matrix Math for Rotation (Axis-Angle)
function rot_matrix(angle, axis) =
    let (
        c = cos(angle), s = sin(angle), C = 1-c,
        x = axis[0], y = axis[1], z = axis[2]
    )
    [
        [x*x*C + c,   x*y*C - z*s, x*z*C + y*s],
        [y*x*C + z*s, y*y*C + c,   y*z*C - x*s],
        [z*x*C - y*s, z*y*C + x*s, z*z*C + c]
    ];

// 4. Transform a point by a matrix
function transform(p, m) = [
    p[0]*m[0][0] + p[1]*m[0][1] + p[2]*m[0][2],
    p[0]*m[1][0] + p[1]*m[1][1] + p[2]*m[1][2],
    p[0]*m[2][0] + p[1]*m[2][1] + p[2]*m[2][2]
];

// ---------------------------------------------------------
// MESH GENERATION MODULE
// ---------------------------------------------------------

module crystalline_polyhedron(
    cycles, res, R, H, fa, fb, 
    segs, r_base, r_amp, p_freq, twist
) {
    step = (cycles * 360) / res;
    
    // --- STEP 1: CALCULATE FRAMES & VERTICES ---
    // We generate a list of all vertices. 
    // Total vertices = res * segs.
    
    points = [
        for (i = [0 : res - 1]) 
            let (
                t = i * step,
                // Current Position
                pos = get_pos(t, R, H, fa, fb),
                // Next Position (for tangent)
                next_pos = get_pos(t + step, R, H, fa, fb),
                
                // Calculate Frame (Tangent, Normal, Binormal)
                tangent = (next_pos - pos) / norm(next_pos - pos),
                up = [0, 0, 1],
                // If tangent is vertical, switch up vector to Y to avoid Gimbal lock
                safe_up = (abs(tangent[2]) > 0.9) ? [0, 1, 0] : [0, 0, 1],
                axis_vec = cross(safe_up, tangent),
                // Safe axis check
                axis_norm = norm(axis_vec) < 0.0001 ? [1,0,0] : axis_vec / norm(axis_vec),
                
                // Rotation Angle to align Z with Tangent
                angle_to_tan = acos(tangent[2]),
                
                // Current Radius
                cur_r = get_radius(t, r_base, r_amp, p_freq),
                
                // Current Twist
                cur_twist = (twist * i) / res,
                
                // Pre-calculate rotation matrix for this frame
                // We rotate the cross-section to face the tangent
                mat_align = rot_matrix(angle_to_tan, axis_norm)
            )
            for (j = [0 : segs - 1]) 
                let (
                    // Initial circle point on XY plane
                    theta = (360 / segs) * j + cur_twist,
                    circle_pt = [cur_r * cos(theta), cur_r * sin(theta), 0],
                    
                    // Rotate circle point to align with path
                    aligned_pt = transform(circle_pt, mat_align)
                )
                // Translate to path position
                pos + aligned_pt
    ];

    // --- STEP 2: GENERATE FACES ---
    // We connect ring i to ring i+1.
    // The modulo operator (%) ensures the last ring connects back to the first.
    
    faces = [
        for (i = [0 : res - 1])
            for (j = [0 : segs - 1])
                let (
                    current = i * segs + j,
                    next_col = i * segs + (j + 1) % segs,
                    next_row = ((i + 1) % res) * segs + j,
                    next_row_next_col = ((i + 1) % res) * segs + (j + 1) % segs
                )
                // Quad face (two triangles)
                [current, next_col, next_row_next_col, next_row]
    ];

    // --- STEP 3: RENDER ---
    polyhedron(points = points, faces = faces, convexity = 10);
}

// ---------------------------------------------------------
// MAIN RENDER
// ---------------------------------------------------------

color([0.3, 0.7, 1.0, 0.8]) // Translucent Crystalline Blue
crystalline_polyhedron(
    cycles = Path_Cycles,
    res = Path_Resolution,
    R = Overall_Radius,
    H = Height_Amplitude,
    fa = Frequency_A,
    fb = Frequency_B,
    segs = Tube_Segments,
    r_base = Tube_Base_Radius,
    r_amp = Tube_Pulse_Amplitude,
    p_freq = Pulse_Frequency,
    twist = Axial_Twist_Degrees
);