// Use case 1: bowden outriggers. One enclosed actuator lies flat under the chassis and
// pushes two 1.75 mm PETG filaments through PTFE bowden tubes, like a 3D printer's bowden
// extruder. At the far end each filament swings a hinged foot down into the ground;
// pulled back, the feet fold flat under the chassis. Rough visual model, all in mm.
//
// Opened on its own this file shows the outriggers under the vehicle (chassis drawn
// see-through), View > Animate sweeps them in and out. crane.scad includes them with
// `use <use-cases/bowden_outriggers.scad>`, option `outriggers`.
//
// How a foot works (seen from the side, front to the right):
//  * The arm hangs on a hinge under the chassis edge. Folded, it points forwards, flat
//    under the chassis (stow_ang = 180°).
//  * A horn on the arm carries the filament pin. Pushing the filament swings the arm down
//    and 10° past straight down (down_ang = 280°) against a stop.
//  * Past straight down the vehicle's weight pushes the arm further, into the stop, not
//    back up: the foot locks over centre and the filament carries no load.
//  * Pulling the filament swings it back over centre and up. The heavy move (out of the
//    locked position) is a pull, so the filament is in tension, not buckling.
// Angles and the horn are in the arm's plane: u = backwards, v = up, hinge at the origin.

use <../actuator_housing.scad>
use <bowden_common.scad>

/* [Pose] */
animate  = true;
deploy   = 1;        // 0 = folded in, 1 = down; used when animate = false
show_ground = true;

/* [Vehicle, as in crane.scad] */
chassis_x0 = -100;
chassis    = [260, 130, 6];
wheel_x    = [-60, 120];
wheel_d    = 70;
wheel_w    = 30;
ground_z   = -51;    // chassis bottom - 10 (axle drop) - wheel_d / 2

/* [Feet] */
foot_x    = 40;      // hinge position along the chassis, between the wheels
hinge_y   = 58;      // arm plane from the centre line (wheels start at 67)
hinge_z   = -12;     // hinge height (chassis bottom at -6)
stow_ang  = 180;     // arm direction folded in (pointing forwards), degrees from backwards
down_ang  = 280;     // deployed: 10° past straight down, locks over centre
preload   = 1;       // the toe would reach this far below the ground: tyres compress
toe_d     = 8;
arm_t     = 5;       // arm plate thickness
horn_r    = 12;      // filament pin distance from the hinge
horn_ang  = 15;      // horn angle to the arm
tube_end  = [-19, 0]; // filament exit relative to the hinge, [u, v]: 19 mm ahead of it
pin_dy    = -6;      // pin and filament run this far beside the arm (inwards)

/* [Actuator] */
act_x     = -95;     // rear insert of the actuator
act_y0    = 0;       // default position across the chassis
fil_dz    = 4;       // the two filaments on the crosshead, above and below the screw axis,
                     // so each tube has the full width for its U-turn to the foot
fit_gap   = 3;       // crosshead to fitting at full travel

$fn = 32;

// --- foot geometry in the arm's plane
arm_len = (hinge_z - ground_z + preload - toe_d / 2) / -sin(down_ang);
function arm_ang(d) = stow_ang + (down_ang - stow_ang) * d;
function pin2(a)    = horn_r * [cos(a + horn_ang), sin(a + horn_ang)];
function free2(a)   = norm(pin2(a) - tube_end);                 // free filament, tube end -> pin
function trans2(a)  = let(v = pin2(a) - tube_end) acos((v * pin2(a)) / (norm(v) * horn_r));
function toe_z(a)   = hinge_z + arm_len * sin(a) - toe_d / 2;

travel   = free2(down_ang) - free2(stow_ang);                   // ram travel stowed -> down
trans_ok = min([for (i = [0 : 40]) let(m = trans2(arm_ang(i / 40))) min(m, 180 - m)]);
lift     = toe_z(down_ang) - min([for (i = [0 : 40]) toe_z(arm_ang(i / 40))]);
// the tube end points along the average filament direction, the free filament swings
// ± swing degrees about it as the arm turns
mouth2   = unit(unit(pin2(stow_ang) - tube_end) + unit(pin2(down_ang) - tube_end));
swing    = max([for (i = [0 : 40]) let(v = unit(pin2(arm_ang(i / 40)) - tube_end)) acos(v * mouth2)]);

// [u, v] in the arm's plane -> vehicle coordinates for side s = ±1, in the pin plane
function to3(v, s) = [foot_x - v[0], s * (hinge_y + pin_dy), hinge_z + v[1]];

// --- actuator, flat under the chassis, tray floor screwed to the chassis' underside
act_z    = -chassis[2] + act_floor();                           // screw axis
function nose_x(e) = act_x + act_retracted() + e;
mouth_x  = nose_x(travel) + 4 + fit_gap;                        // actuator-side fittings

function foot_mouth(s) = to3(tube_end, s);
function foot_dir(s)   = [-mouth2[0], 0, mouth2[1]];
function act_mouth(s, ay) = [mouth_x, ay, act_z + s * fil_dz];
// the tubes turn back in a U in front of the actuator
function tube_wp(s, ay) = let(
  b0 = fit_back(act_mouth(s, ay), [-1, 0, 0]), b1 = fit_back(foot_mouth(s), foot_dir(s)),
  r  = abs(b1[1] - b0[1]) / 2)
  fitting_path(act_mouth(s, ay), [-1, 0, 0], foot_mouth(s), foot_dir(s),
               [[[max(b0[0], b1[0]) + r, (b0[1] + b1[1]) / 2, (b0[2] + b1[2]) / 2], [0, s, 0]]], k = 1.15);

// ---------------------------------------------------------------- parts ----

// The arm in 2D, pointing along +u from the hinge at the origin
module arm2d() {
  hull() { circle(d = 9); translate([arm_len, 0]) circle(d = toe_d); }
  hull() { circle(d = 9); rotate(horn_ang) translate([horn_r, 0]) circle(d = 6); }
}

// [u, v] plane -> x = -u, z = v, extruded along y
module arm_plane() { mirror([1, 0, 0]) rotate([90, 0, 0]) children(); }

// One foot with its hinge bracket and tube end, for side s at arm angle a
module foot(s, a) {
  mirror([0, s < 0 ? 1 : 0, 0]) translate([foot_x, hinge_y, hinge_z]) {
    color("orange") arm_plane() linear_extrude(arm_t, center = true) rotate(a) arm2d();
    // horn pin, sticking out inwards to the filament
    p = pin2(a);
    color("silver") translate([-p[0], 1, p[1]]) rotate([90, 0, 0]) cylinder(d = 3, h = -pin_dy + 1);
    // hinge bracket outside the arm, with the stop the deployed arm rests on
    color("dimgray") {
      translate([-8, arm_t / 2 + 0.5, 0]) cube([16, 3, -chassis[2] - hinge_z]);
      translate([0, arm_t / 2 + 0.5, 0]) rotate([-90, 0, 0]) cylinder(d = 9, h = 3);
      stop = down_ang + 32;
      translate([-10 * cos(stop), arm_t / 2 + 3.5, 10 * sin(stop)]) rotate([90, 0, 0])
        cylinder(d = 3, h = arm_t + 3.5);
    }
    color("silver") rotate([90, 0, 0]) cylinder(d = 3, h = arm_t + 6, center = true);
    // tube end holder from the chassis
    color("dimgray") translate([-tube_end[0] - 4, pin_dy - 3, tube_end[1] + 3])
      cube([8, 6, -chassis[2] - hinge_z - tube_end[1] - 3]);
  }
  // tube end fitting and the free filament to the horn pin
  tube_fitting(foot_mouth(s), foot_dir(s));
  filament(foot_mouth(s), to3(pin2(a), s));
}

// The whole outrigger set at deploy d (0 = folded, 1 = down), actuator at y = ay
module bowden_outriggers(d, ay = act_y0) {
  a = arm_ang(d);
  e = free2(a) - free2(stow_ang);                                // ram extension
  for (s = [-1, 1]) foot(s, a);

  translate([act_x, ay, act_z]) rotate([180, 0, 0]) enclosed_actuator(e);
  // crosshead on the ram nose, one filament above and one below
  color("orange") translate([nose_x(e), ay - 5, act_z - fil_dz - 3]) cube([4, 10, 2 * fil_dz + 6]);
  // fitting holder from the chassis
  color("dimgray") translate([mouth_x + 2, ay - 6, act_z - fil_dz - 5])
    cube([6, 12, -chassis[2] - act_z + fil_dz + 5]);

  for (s = [-1, 1]) {
    m0 = act_mouth(s, ay);
    tube_fitting(m0, [-1, 0, 0]);
    filament([nose_x(e) + 2, ay, act_z + s * fil_dz], m0);
    bowden_tube(tube_wp(s, ay));
  }
  outrigger_report(ay);
}

module outrigger_report(ay) {
  echo(str("Outriggers: ram travel ", travel, " mm of the actuator's ", act_stroke(),
           " mm, filament to horn angle never below ", trans_ok, "°"));
  echo(str("Outriggers: free filament at the foot ", free2(stow_ang), " .. ", free2(down_ang),
           " mm, buckles at ≈ ", buckling_n(free2(down_ang)), " N; swings ±", swing, "° at the tube end"));
  echo(str("Outriggers: toes at ±", hinge_y, " mm from the centre line, arm ", arm_len,
           " mm; lifts the vehicle ", lift, " mm going over centre"));
  for (s = [-1, 1]) let(p = tube_wp(s, ay))
    echo(str("Outriggers: tube ", s > 0 ? "right" : "left", " ", path_len(p), " mm, tightest bend r = ",
             min_radius(p), " mm", min_radius(p) < min_bend() ? str("  WARNING: tighter than ", min_bend()) : ""));
  if (travel > act_stroke())
    echo("WARNING: the feet need more travel than the actuator has - reduce horn_r");
}

// --------------------------------------------------------------- scene ----

d = animate ? 0.5 - 0.5 * cos(360 * $t) : deploy;

color("dimgray", 0.3) translate([chassis_x0, -chassis[1] / 2, -chassis[2]]) cube(chassis);
for (x = wheel_x, y = [-1, 1])
  color("#222", 0.5) translate([x, y * (chassis[1] / 2 + wheel_w / 2 + 2), -chassis[2] - 10])
    rotate([90, 0, 0]) cylinder(d = wheel_d, h = wheel_w, center = true);
if (show_ground) color("tan", 0.4) translate([chassis_x0 - 20, -110, ground_z - 1]) cube([chassis[0] + 40, 220, 1]);
bowden_outriggers(d);
