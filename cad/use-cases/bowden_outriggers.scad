// Use case 1: bowden outriggers. Two legs at the rear, behind the rear axle, swing out
// sideways and down beyond the wheels, like the extended stabilizer legs of LEGO 42082
// (MOC-50496). One enclosed actuator on the deck pulls two 1.75 mm PETG filaments through
// PTFE bowden tubes, like a 3D printer's bowden extruder. Rough visual model, all in mm.
//
// Opened on its own this file shows the legs on a see-through vehicle, View > Animate sweeps
// them out and in. crane.scad includes them with `use <use-cases/bowden_outriggers.scad>`,
// option `outriggers`.
//
// How a leg works (seen from behind, in the leg's plane: u = outwards from the centre line,
// v = up):
//  * PARALLELOGRAM: two 60 mm links on a bracket behind the chassis carry a vertical
//    carrier with the foot pad. The pad stays level the whole way, it never rotates.
//  * Folded, the links point up (85°): the legs stand upright behind the deck. Deployed they
//    point slightly below horizontal (-8°), so the pad's last move onto the ground is almost
//    straight down, well outside the wheels.
//  * DRIVE: the filament pulls a horn on the upper link. Deploying is a pull (the strong
//    direction for a filament), with a steady pull: the free filament gets shorter all the way.
//  * LOCK: at the end a spring pushes a pawl into a notch in the upper link's hub. The ground
//    pushes the leg up, the notch holds it on the pawl: the filament carries no load while the
//    crane works.
//  * RELEASE: the filament's end sits in a short slot in the horn. Pushing it back first runs
//    the slot's free length and lifts the pawl over a release wire, then pushes the leg up.

use <../actuator_housing.scad>
use <bowden_common.scad>

/* [Pose] */
animate     = true;
deploy      = 1;      // 0 = folded up, 1 = out and locked; used when animate = false
show_ground = true;

/* [Vehicle, as in crane.scad] */
chassis_x0 = -100;
chassis    = [260, 130, 6];
wheel_x    = [-60, 120];
wheel_d    = 70;
wheel_w    = 30;
ground_z   = -51;     // chassis bottom - 10 (axle drop) - wheel_d / 2

/* [Legs] */
leg_x     = -112;     // leg plane, behind the rear wheels (they end at x = -95)
pivot_u   = 44;       // bracket pivots from the centre line
pivot_v   = -6;       // upper pivot height (chassis top = 0), the lower one link_gap below
link_gap  = 12;
link_len  = 60;
fold_ang  = 85;       // links folded up
out_ang   = -8;       // links deployed: slightly below horizontal, the pad moves down at the end
preload   = 1;        // the pad would go this far below the ground: tyres and links take it up
pad       = [22, 16, 4];   // foot pad, x × u × thickness
link_t    = 3;        // link plates, side by side in x

/* [Drive and lock] */
horn_r    = 14;       // filament pin distance from the upper pivot
horn_ang  = 170;      // horn angle to the upper link
tube_end  = [-24, 24]; // filament exit relative to the upper pivot, [u, v]: inboard, clear of the folded leg
slot_len  = 4;        // lost motion in the horn for the pawl release
pawl_ang  = -150;     // pawl tip direction from the upper pivot
hub_r     = 7;        // notched hub on the upper link

/* [Actuator] */
act_y     = 49;       // on the deck, beside the electronics box
stow_nose = 0;        // ram nose (pointing backwards) with the legs folded
fil_dz    = 4;        // the two filaments on the crosshead, above and below the screw axis
fit_gap   = 3;        // crosshead to fitting with the legs folded
arch_r    = 30;       // the tube comes down into the leg's tube end in a quarter circle of this radius
arch_far  = 42;       // ... the same for the tube to the far leg, which comes in from the inboard side
tube_k    = 1.0;

$fn = 32;

// ------------------------------------------------------------ geometry ----

P1 = [pivot_u, pivot_v];
P2 = [pivot_u, pivot_v - link_gap];
function dir2(a) = [cos(a), sin(a)];
function link_ang(d) = fold_ang + (out_ang - fold_ang) * d;
function q1(a) = P1 + link_len * dir2(a);
function q2(a) = P2 + link_len * dir2(a);
carrier_h = q2(out_ang)[1] - (ground_z - preload) - pad[2];     // carrier below the lower link end
function pad_v(a) = q2(a)[1] - carrier_h - pad[2];               // pad bottom
function pin2(a)  = P1 + horn_r * dir2(a + horn_ang);
T2 = P1 + tube_end;
function free2(a) = norm(pin2(a) - T2);

travel = free2(link_ang(0)) - free2(link_ang(1));
trans_ok = min([for (i = [0 : 40]) let(a = link_ang(i / 40), v = unit(T2 - pin2(a)),
                                         r = unit(pin2(a) - P1)) acos(abs(v * r))]);
mouth2 = unit(unit(pin2(link_ang(0)) - T2) + unit(pin2(link_ang(1)) - T2));
swing  = max([for (i = [0 : 40]) acos(unit(pin2(link_ang(i / 40)) - T2) * mouth2)]);
lowest = min([for (i = [0 : 40]) pad_v(link_ang(i / 40))]);
pad_u_out = q2(out_ang)[0];
// the pad's last 10 mm before the ground: how much of it is sideways
last_side = abs(q2(out_ang)[0] - q2(out_ang + 10)[0]);
last_down = abs(q2(out_ang)[1] - q2(out_ang + 10)[1]);

// [u, v] in the leg plane -> vehicle coordinates for side s = ±1
function to3(p, s, dx = 0) = [leg_x + dx, s * p[0], p[1]];

// --- actuator on the deck (or dz higher, e.g. on top of another actuator), ram pointing backwards
function act_z(dz) = dz - act_floor();                                 // screw axis
x_ins  = stow_nose + act_retracted() + travel;                         // rear insert (front end)
function nose_x(e) = x_ins - act_retracted() - e;
mouth_x = stow_nose - fit_gap;                                          // fittings behind the crosshead
function act_mouth(s, ay, dz) = [mouth_x, ay, act_z(dz) + s * fil_dz];
function leg_mouth(s) = to3(T2, s);
function leg_dir(s)   = [0, s * mouth2[0], mouth2[1]];
// Each tube climbs to an arch over its leg and comes down into the tube end from above.
// The tube to the far leg crosses behind the deck on the way.
function tube_wp(s, ay, dz) = let(far = ay != 0 && sign(ay) != s,
                                 bk = fit_back(leg_mouth(s), leg_dir(s)),          // tube end at the leg
                                 apex = [bk[0] + arch_r, bk[1], bk[2] + arch_r])   // quarter circle down into it
  fitting_path(act_mouth(s, ay, dz), [1, 0, 0], leg_mouth(s), leg_dir(s),
               // far tube: sweeps across behind the deck and arches down into its leg from the inboard side
               far ? [[[bk[0], bk[1] - s * arch_far, bk[2] + arch_far], [0, s, 0]]]
                   : [[apex, [-1, 0, 0]]], k = tube_k);

// ---------------------------------------------------------------- parts ----

module bar2d(a, b, w) { hull() { translate(a) circle(d = w); translate(b) circle(d = w); } }

// leg-plane 2D -> 3D at x = leg_x + dx, plates t thick
module plane(s, dx, t) {
  mirror([0, s < 0 ? 1 : 0, 0]) translate([leg_x + dx, 0, 0]) rotate([90, 0, 90])
    linear_extrude(t, center = true) children();
}

// The leg's moving and fixed parts, without the tube end. bowden = false leaves out the horn,
// the pawl and the tube end post: outriggers_geared.scad drives the same legs with gears.
module leg_parts(s, a, locked, bowden = true) {
  // bracket cheek on the chassis side of the links: both pivots, the tube end post, the pawl pivot
  color("dimgray") plane(s, 2 * link_t + 2, 3) {
    bar2d(P1, P2, 10);
    bar2d(P2, [pivot_u - 14, pivot_v - link_gap], 8);
    if (bowden) {
      bar2d(P1, T2 + [0, 2], 6);
      bar2d(P1, P1 + 13 * dir2(pawl_ang + 30), 6);
    }
  }
  // links, side by side
  color("orange") {
    plane(s, -link_t, link_t) difference() {
      union() {
        bar2d(P1, q1(a), 7);
        circle(r = hub_r);
        if (bowden) bar2d(P1, pin2(a), 6);          // horn
      }
      if (bowden) {
        // notch for the pawl
        rotate(pawl_ang - out_ang + a) translate([hub_r - 1.5, -1.5]) square([3, 3]);
        // lost-motion slot for the filament end
        translate(pin2(a)) rotate(atan2((T2 - pin2(a))[1], (T2 - pin2(a))[0])) translate([-1, -0.9]) square([slot_len, 1.8]);
      }
    }
    plane(s, link_t, link_t) { bar2d(P2, q2(a), 7); circle(d = 7); }
  }
  // carrier with the pad, always vertical
  color("goldenrod") plane(s, 0, link_t) bar2d(q1(a), [q2(a)[0], q2(a)[1] - carrier_h + 2], 6);
  color("#333") translate(to3([q2(a)[0], pad_v(a)], s) - [pad[0] / 2, s > 0 ? pad[1] / 2 : pad[1] / 2, 0])
    cube([pad[0], pad[1], pad[2]]);
  // pawl with its spring: in the notch when locked, on the hub's rim otherwise
  if (bowden) {
    r = locked ? hub_r - 1.5 : hub_r + 0.2;
    piv = P1 + 13 * dir2(pawl_ang + 30);
    tip = P1 + r * dir2(pawl_ang);
    color("silver") plane(s, -link_t, link_t) bar2d(piv, tip, 2.5);
    color("silver") translate(to3(piv, s)) rotate([0, 90, 0]) cylinder(d = 2, h = 4 * link_t + 6, center = true, $fn = 12);
    color("red") plane(s, -2 * link_t, 0.8) bar2d(piv + 4 * dir2(pawl_ang + 120), tip + 6 * dir2(pawl_ang + 120), 1);   // spring
  }
  // pins
  color("silver") for (p = [P1, P2, q1(a), q2(a)]) translate(to3(p, s)) rotate([0, 90, 0])
    cylinder(d = 3, h = 3 * link_t + 6, center = true, $fn = 12);
}

module leg(s, a, locked) {
  leg_parts(s, a, locked);
  // tube end and the free filament to the horn pin
  tube_fitting(leg_mouth(s), leg_dir(s));
  filament(leg_mouth(s), to3(pin2(a), s));
}

// Tubes and tube-end fittings of both legs, for collision checks
module tubes_and_ends(ay = act_y, dz = 0) {
  for (s = [-1, 1]) { tube_fitting(leg_mouth(s), leg_dir(s)); bowden_tube(tube_wp(s, ay, dz)); }
}

// Rear beam carrying both bracket cheeks, bolted under the chassis
module rear_beam() {
  bx0 = leg_x + 2 * link_t + 3.5;
  color("dimgray") translate([bx0, -pivot_u - 4, pivot_v - link_gap - 5])
    cube([chassis_x0 - bx0 + 20, 2 * pivot_u + 8, link_gap + 5 - pivot_v - chassis[2] + 0.01]);
}

// See-through chassis, wheels and ground, for the stand-alone views
module vehicle_scene(ground = true) {
  color("dimgray", 0.3) translate([chassis_x0, -chassis[1] / 2, -chassis[2]]) cube(chassis);
  for (x = wheel_x, y = [-1, 1])
    color("#222", 0.5) translate([x, y * (chassis[1] / 2 + wheel_w / 2 + 2), -chassis[2] - 10])
      rotate([90, 0, 0]) cylinder(d = wheel_d, h = wheel_w, center = true);
  if (ground) color("tan", 0.4) translate([chassis_x0 - 40, -130, ground_z - 1]) cube([chassis[0] + 60, 260, 1]);
}

// Leg geometry for other files (`use` only shares functions and modules, not variables)
function ol_leg_x()     = leg_x;
function ol_link_t()    = link_t;
function ol_pivot_u()   = pivot_u;
function ol_P1()        = P1;
function ol_fold_ang()  = fold_ang;
function ol_out_ang()   = out_ang;
function ol_link_ang(d) = link_ang(d);
function ol_link_len()  = link_len;
function ol_hub_r()     = hub_r;
function ol_ground_z()  = ground_z;
function ol_chassis_x0() = chassis_x0;
function ol_chassis_h() = chassis[2];

// The whole outrigger set at deploy d (0 = folded, 1 = out and locked)
// ay: the actuator's position across the deck; dz: its height, e.g. stacked on another actuator
module bowden_outriggers(d, ay = act_y, dz = 0) {
  a = link_ang(d);
  az = act_z(dz);
  e = free2(a) - free2(link_ang(1));                              // ram extension
  rear_beam();
  for (s = [-1, 1]) leg(s, a, d > 0.999);

  translate([x_ins, ay, az]) rotate([0, 0, 180]) enclosed_actuator(e);
  // crosshead on the ram nose, one filament above and one below
  color("orange") translate([nose_x(e) - 4, ay - 5, az - fil_dz - 3]) cube([4, 10, 2 * fil_dz + 6]);
  // fitting holder
  color("dimgray") translate([mouth_x - 8, ay - 6, dz]) cube([6, 12, az - dz + fil_dz + 5]);
  for (s = [-1, 1]) {
    m0 = act_mouth(s, ay, dz);
    tube_fitting(m0, [1, 0, 0]);
    filament(m0, [nose_x(e) - 2, ay, az + s * fil_dz]);
    bowden_tube(tube_wp(s, ay, dz));
  }
  outrigger_report(ay, dz);
}

module outrigger_report(ay = act_y, dz = 0) {
  echo(str("Outriggers: ram travel ", travel, " mm of the actuator's ", act_stroke(),
           " mm (pull = legs out), filament to horn never below ", trans_ok, "°"));
  echo(str("Outriggers: free filament at the leg ", free2(link_ang(1)), " .. ", free2(link_ang(0)),
           " mm, pushing it back buckles at ≈ ", buckling_n(free2(link_ang(0))), " N; swings ±", swing,
           "° at the tube end"));
  echo(str("Outriggers: pads at ±", pad_u_out, " mm from the centre line (wheels end at ",
           chassis[1] / 2 + wheel_w + 2, "), ", chassis_x0 - leg_x, " mm behind the chassis"));
  echo(str("Outriggers: last 10° before locking the pad moves ", last_down, " mm down and ",
           last_side, " mm sideways; never below the ground by more than ", ground_z - lowest, " mm"));
  echo(str("Outriggers: actuator on the deck, ", dz, " mm up, at y = ", ay));
  for (s = [-1, 1]) let(p = tube_wp(s, ay, dz))
    echo(str("Outriggers: tube ", s > 0 ? "right" : "left", " ", path_len(p), " mm, tightest bend r = ",
             min_radius(p), " mm", min_radius(p) < min_bend() ? str("  WARNING: tighter than ", min_bend()) : ""));
  if (travel > act_stroke())
    echo("WARNING: the legs need more travel than the actuator has - reduce horn_r");
}

// --------------------------------------------------------------- scene ----

d = animate ? 0.5 - 0.5 * cos(360 * $t) : deploy;
scene = true;   // false: draw nothing, for files that include this one (collision checks)

if (scene) {
  vehicle_scene(show_ground);
  bowden_outriggers(d);
}
