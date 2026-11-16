// ---------------------------------------------------------
// FLAME PLUMES – POLYHEDRON VERSION
// ---------------------------------------------------------
// A flame as one closed surface: a lobed cross-section that swells, narrows to a point and twists
// faster towards the tip, so each lobe licks upward like a tongue of flame. Inspired by the flame
// sculpture in Jochen Kerdels' "Mastering OpenSCAD" (example 7); the method and code here are
// different.

/* [General Settings] */
total_height = 180; // [40:1:400]
// Tongues of flame round the plume
number_of_strands = 5; // [1:1:12]
// Rings from the base to the tip
slices_per_strand = 60; // [10:1:200]
// Points round each ring
ring_points = 120; // [24:6:360]

/* [Shape Geometry] */
// Base half-widths in X and Y
base_radius_x = 30;
base_radius_y = 26;
// Turns of twist from the base to the tip
rotations = 1; // [0:0.25:4]
// How deep the gaps between tongues cut in, as a fraction of the radius
lobe_depth = 0.45; // [0:0.05:0.9]
// How much the plume swells above its base before narrowing
swell = 0.6; // [0:0.05:1.5]

/* [Colors] */
flame_color = [1, 0.45, 0];

// ---------------------------------------------------------
// SURFACE
// ---------------------------------------------------------

// Envelope at height fraction v in [0, 1]: swells, then narrows to a point at the tip.
function envelope(v, swell) = pow(1 - v, 0.7) * (1 + swell * sin(180 * v));

// Twist at height fraction v, in degrees: slow at the base, quickening towards the tip.
function twist(v, turns) = 360 * turns * pow(v, 1.6);

// A point on the surface at height fraction v and angle a.
function surface_point(v, a, h, rx, ry, k, depth, swell, turns) =
  let (
    lobes = k < 2 ? 1 : 1 - depth + depth * (0.5 + 0.5 * cos(k * (a - twist(v, turns)))),
    r = envelope(v, swell) * lobes
  ) [rx * r * cos(a), ry * r * sin(a), h * v];

module flame_plumes(
  h = 180, rx = 30, ry = 26, k = 5, slices = 60, ring = 120, depth = 0.45, swell = 0.6, turns = 1
) {
  assert(h > 0 && rx > 0 && ry > 0, "flame_plumes: total_height and the base radii have to be more than 0");
  assert(depth >= 0 && depth < 1, "flame_plumes: lobe_depth has to be at least 0 and less than 1");
  assert(slices >= 2 && ring >= 3, "flame_plumes: it needs at least 2 slices and 3 ring points");

  // Rings 0 .. slices - 1 (the tip itself is a single point), then the tip, then the base centre.
  rings = [
    for (i = [0:slices - 1]) for (j = [0:ring - 1])
      surface_point(i / slices, 360 * j / ring, h, rx, ry, k, depth, swell, turns),
  ];
  tip = len(rings);
  base = tip + 1;
  points = concat(rings, [[0, 0, h], [0, 0, 0]]);

  function at(i, j) = i * ring + (j % ring);

  faces = concat(
    // sides, clockwise as seen from outside
    [for (i = [0:slices - 2]) for (j = [0:ring - 1]) [at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)]],
    // fan to the tip
    [for (j = [0:ring - 1]) [at(slices - 1, j), tip, at(slices - 1, j + 1)]],
    // flat base
    [for (j = [0:ring - 1]) [at(0, j), at(0, j + 1), base]]
  );

  polyhedron(points=points, faces=faces, convexity=10);
}

// ---------------------------------------------------------
// RENDER
// ---------------------------------------------------------

color(flame_color)
  flame_plumes(
    h=total_height,
    rx=base_radius_x,
    ry=base_radius_y,
    k=number_of_strands,
    slices=slices_per_strand,
    ring=ring_points,
    depth=lobe_depth,
    swell=swell,
    turns=rotations
  );
