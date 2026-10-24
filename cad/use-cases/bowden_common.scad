// Bowden drive pieces shared by the use cases: a PTFE tube along a smooth path with the
// filament inside it, push-fit tube fittings, and the numbers to check a layout.
// A bowden drive is what a 3D printer with a bowden extruder uses: 1.75 mm filament
// in a 2 mm ID / 4 mm OD PTFE tube. Here the actuator moves the filament instead of an
// extruder, and the far end of the filament does the work. All dimensions in mm.

function tube_od()  = 4;
function tube_id()  = 2;
function fil_d()    = 1.75;
function fit_len()  = 10;     // push-fit fitting (PC4-M6 style), tube end to filament exit
function min_bend() = 20;     // smallest tube bend radius we accept: below it the PTFE tube
                              // starts to kink and the filament bends past ~4 % strain

function unit(v) = v / norm(v);

// Cubic Hermite segment from p0 (tangent t0) to p1 (tangent t1), n + 1 points
function hermite(p0, t0, p1, t1, n) = [for (i = [0 : n]) let(
  s = i / n, s2 = s * s, s3 = s2 * s)
  (2 * s3 - 3 * s2 + 1) * p0 + (s3 - 2 * s2 + s) * t0 + (-2 * s3 + 3 * s2) * p1 + (s3 - s2) * t1];

// Smooth path through waypoints [[point, direction], ...]. Each segment's end tangents are
// sized so that a planar bend comes out as a circular arc (2·tan(φ/4)/sin(φ/2) × chord for
// a turn of φ, 1 × chord for a straight or S-shaped run), times k.
function arc_k(a, b) = let(phi = acos(max(-1, min(1, unit(a) * unit(b)))))
  phi < 1 ? 1 : 2 * tan(phi / 4) / sin(phi / 2);
function tube_path(wp, n = 16, k = 1) = [for (i = [0 : len(wp) - 2]) let(
  a = wp[i], b = wp[i + 1], c = k * arc_k(a[1], b[1]) * norm(b[0] - a[0]))
  each [for (p = hermite(a[0], c * unit(a[1]), b[0], c * unit(b[1]), n)) if (p != b[0] || i == len(wp) - 2) p]];

function path_len(pts, i = 0) = i >= len(pts) - 1 ? 0 : norm(pts[i + 1] - pts[i]) + path_len(pts, i + 1);

// Smallest bend radius along the path (circumradius of each three consecutive points)
function bend_radius(a, b, c) = let(x = norm(cross(b - a, c - b)))
  x < 1e-9 ? 1e9 : norm(b - a) * norm(c - b) * norm(c - a) / (2 * x);
function min_radius(pts) = min([for (i = [1 : len(pts) - 2]) bend_radius(pts[i - 1], pts[i], pts[i + 1])]);

// Euler buckling load of a free filament length, PETG E ≈ 2 GPa, clamped in the
// fitting at one end and pinned at the other (K = 0.7)
function buckling_n(free_len) = let(E = 2000, I = PI * pow(fil_d(), 4) / 64)
  PI * PI * E * I / pow(0.7 * free_len, 2);

// Rotates +z onto direction d
module orient(d) {
  rotate([0, acos(unit(d)[2]), atan2(d[1], d[0])]) children();
}

module chain(pts, d, fn = 12) {
  for (i = [0 : len(pts) - 2])
    hull() { translate(pts[i]) sphere(d = d, $fn = fn); translate(pts[i + 1]) sphere(d = d, $fn = fn); }
}

// PTFE tube along pts with the filament inside, both visible through the tube
module bowden_tube(pts) {
  color("orange") chain(pts, fil_d(), 8);
  color("white", 0.45) chain(pts, tube_od());
}

// Free filament between two points (out of the tube), e.g. fitting -> crosshead
module filament(a, b) {
  color("orange") chain([a, b], fil_d(), 8);
}

// Push-fit fitting: the filament leaves at mouth m heading u, the tube plugs in at
// fit_back(m, u) and leaves it heading -u.
function fit_back(m, u) = m - fit_len() * unit(u);

module tube_fitting(m, u) {
  translate(fit_back(m, u)) orient(u) {
    color("dimgray") cylinder(d = 8, h = 6, $fn = 6);          // hex body
    color("silver") translate([0, 0, 6]) cylinder(d = 5.5, h = fit_len() - 6, $fn = 24);
  }
  filament(fit_back(m, u), m);
}

// Path for a tube from the back of fitting (m0, u0) to the back of fitting (m1, u1),
// through optional waypoints [[point, direction], ...] in between
function fitting_path(m0, u0, m1, u1, via = [], k = 1) =
  tube_path(concat([[fit_back(m0, u0), -u0]], via, [[fit_back(m1, u1), u1]]), k = k);
