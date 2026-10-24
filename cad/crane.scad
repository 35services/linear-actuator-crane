// RC crane concept – telescopic boom, luffed and extended by two enclosed mini
// stepper linear actuators (actuator_housing.scad). Rough visual model, not
// print-ready. All dimensions in mm.
//
// Option `outriggers`: two stabilizer legs at the rear that swing out beyond the wheels and
// lock, driven through bowden tubes by a third actuator lying on the deck
// (use-cases/bowden_outriggers.scad, explained in use-cases/README.md).
//
// View > Animate (FPS 10, Steps 60) to sweep the boom and telescope through
// their range. The console echoes the stroke the lift geometry needs, the
// tip-force ratio and the speeds, so you can check them before building anything.

use <actuator_housing.scad>
use <use-cases/bowden_outriggers.scad>

/* [Pose] */
animate      = true;
boom_angle   = 30;     // used when animate = false
tele_ext     = 15;     // telescope extension, used when animate = false
boom_min     = 0;      // degrees above horizontal
boom_max     = 55;
slew_angle   = 25;     // turntable rotation, just for the picture

/* [Outriggers] */
outriggers       = true;  // bowden outriggers, see use-cases/README.md
outrigger_deploy = 1;     // 0 = folded in, 1 = down; used when animate = false

/* [Boom geometry] */
outer_len    = 140;    // outer section, pivot to front end
inner_len    = 130;    // inner (sliding) section
inner_stick  = 15;     // how far the inner section sticks out when retracted
boom_tail    = 40;     // stub behind the pivot for a counterweight
boom_w       = 16;
boom_h       = 12;
wall         = 2;
attach_d     = 130;    // lift actuator attach point, distance from boom pivot along the boom
attach_drop  = 22;     // ... and below the boom axis (hanger), so the actuator clears the boom
pivot_h      = 80;     // boom pivot height above turntable
base_pivot_h = 10;     // lift actuator base pivot height above turntable (below boom pivot)
hook_drop    = 70;

/* [Speed] */
full_steps_rev = 20;   // 18° motor
step_rate      = 800;  // full steps per second the motor manages under load, see README

/* [Actuator] */
// both actuators are the same model, dimensions come from actuator_housing.scad
stroke       = act_stroke();     // 75
act_len      = act_retracted();  // 132.5, insert to insert, ram fully in
act_w        = act_width();
act_low      = -act_floor();     // housing bottom below the screw axis

/* [Vehicle] */
chassis      = [260, 130, 6];
wheel_d      = 70;
wheel_w      = 30;
turntable_d  = 70;
turntable_h  = 8;

$fn = 48;

theta = animate ? boom_min + (boom_max - boom_min) * (0.5 - 0.5 * cos(360 * $t))
                : boom_angle;
tele  = animate ? stroke * (0.5 - 0.5 * cos(720 * $t)) : min(tele_ext, stroke);
// the feet go down at the start of the cycle and fold in at its end
feet  = animate ? min(1, 4 * (0.5 - 0.5 * cos(360 * $t))) : outrigger_deploy;

// --- lift geometry in the boom plane (x forward, z up), origin = lift actuator base pivot B
P = [0, pivot_h - base_pivot_h];                  // boom pivot
function attach(a) = P + attach_d * [cos(a), sin(a)] + attach_drop * [sin(a), -cos(a)];
function dist(a) = norm(attach(a));

d_min = dist(boom_min);
d_max = dist(boom_max);
A     = attach(theta);
D     = dist(theta);
phi   = atan2(A[1], A[0]);                        // lift actuator angle

rod_len = d_min - act_len;                        // pushrod, ram -> boom
ext     = D - d_min;
lever   = abs(P[0] * A[1] - P[1] * A[0]) / D;     // perpendicular distance pivot -> actuator line

// --- telescope geometry along the boom (x from boom pivot)
inner_start0 = outer_len + inner_stick - inner_len;  // rear end of inner section, retracted
inner_start  = inner_start0 + tele;
tip_len      = inner_start + inner_len;              // pivot -> tip sheave
tele_act_x   = inner_start0 + inner_len - 4 - act_len; // telescope actuator on top of the boom,
                                                     // its ram pushes a bracket at the inner tip

// --- speed
v_act     = step_rate * act_lead() / full_steps_rev;  // mm/s
function tip_z(a, len) = pivot_h + len * sin(a);
t_lift    = (d_max - d_min) / v_act;
t_tele    = stroke / v_act;
dD_dtheta = (dist(theta + 0.5) - dist(theta - 0.5)) * 180 / PI;  // mm per radian

echo(str("Lift stroke needed: ", d_max - d_min, " mm (actuator has ", stroke, " mm), pushrod ", rod_len, " mm"));
if (d_max - d_min > stroke)
  echo("WARNING: lift geometry needs more stroke than the actuator has - reduce attach_d or the boom range");
if (rod_len < 0)
  echo("WARNING: the actuator is longer than the lift geometry allows - increase attach_d or lower the base pivot");
echo(str("Reach (pivot -> tip): ", inner_start0 + inner_len, " .. ", inner_start0 + inner_len + stroke, " mm"));
echo(str("Boom ", theta, " deg, telescope +", tele, " mm: tip force ≈ lift actuator force × ",
         lever / tip_len));
echo(str("Speed at ", step_rate, " full steps/s: actuator ", v_act, " mm/s, boom ", boom_min, "..", boom_max,
         " deg in ", t_lift, " s, telescope in ", t_tele, " s"));
echo(str("Hook rises ", tip_z(boom_max, inner_start0 + inner_len) - tip_z(boom_min, inner_start0 + inner_len),
         " mm (telescope in), on average ", (tip_z(boom_max, inner_start0 + inner_len) - tip_z(boom_min, inner_start0 + inner_len)) / t_lift,
         " mm/s; right now ", tip_len * cos(theta) * v_act / dD_dtheta, " mm/s"));
if (inner_start0 < wall + 2)
  echo("WARNING: inner section too long for the outer section - reduce inner_len");

// ---------------------------------------------------------------- parts ----

module axle(len = 34) { rotate([90, 0, 0]) cylinder(d = 4, h = len, center = true); }

module vehicle() {
  color("dimgray", 0.6) translate([-chassis[0] / 2 + 30, -chassis[1] / 2, -chassis[2]]) cube(chassis);
  for (x = [-chassis[0] / 2 + 70, chassis[0] / 2 - 10], y = [-1, 1])
    color("#222") translate([x, y * (chassis[1] / 2 + wheel_w / 2 + 2), -chassis[2] - 10])
      rotate([90, 0, 0]) cylinder(d = wheel_d, h = wheel_w, center = true);
}

module electronics_box() {
  color("steelblue") translate([-95, -30, 0]) cube([50, 60, 25]);
  color("white") translate([-70, 0, 25]) linear_extrude(0.6)
    text(outriggers ? "ESP32+3xTMC2209" : "ESP32+2xTMC2209", size = 3.6, halign = "center", valign = "center");
}

module mast() {
  // two cheek plates carrying the boom pivot, lift actuator sits between them
  for (y = [-1, 1]) color("orange", 0.55)
    translate([0, y * (act_w / 2 + 2.5), 0]) rotate([90, 0, 0])
      linear_extrude(3, center = true)
        polygon([[-30, 0], [30, 0], [8, pivot_h + 6], [-8, pivot_h + 6]]);
  color("silver") translate([0, 0, pivot_h]) axle(act_w + 8);
  color("silver") translate([0, 0, base_pivot_h]) axle(act_w + 8);
}

// Boom in its own frame: x along the boom from the pivot, z up
module boom() {
  // outer section: rectangular tube, open at the front, slot on top for the telescope drive
  color("gold") difference() {
    translate([-boom_tail, -boom_w / 2, -boom_h / 2]) cube([outer_len + boom_tail, boom_w, boom_h]);
    translate([-boom_tail + 5, -boom_w / 2 + wall, -boom_h / 2 + wall])
      cube([outer_len + boom_tail, boom_w - 2 * wall, boom_h - 2 * wall]);
  }
  // inner section
  inner_w = boom_w - 2 * wall - 0.5;
  inner_h = boom_h - 2 * wall - 0.5;
  color("khaki") translate([inner_start, -inner_w / 2, -inner_h / 2]) cube([inner_len, inner_w, inner_h]);
  // hanger under the boom carrying the lift actuator's ball link
  color("gold") hull() {
    translate([attach_d - 14, -boom_w / 2, -boom_h / 2 - 1]) cube([28, boom_w, 1]);
    translate([attach_d, 0, -attach_drop]) rotate([90, 0, 0]) cylinder(d = 8, h = boom_w, center = true);
  }
  // tip sheave
  color("silver") translate([tip_len, 0, 0]) rotate([90, 0, 0]) cylinder(d = 14, h = 4, center = true);
  // counterweight
  color("darkslategray") translate([-boom_tail, -boom_w / 2 - 2, -boom_h / 2 - 8]) cube([20, boom_w + 4, 14]);
  // telescope actuator lying on top, its ram pushes a bracket at the tip of the inner section
  translate([tele_act_x, 0, boom_h / 2 + act_low + 0.5]) {
    actuator(tele, rod = 0);
    color("khaki") translate([act_len + tele, -4, -act_low - boom_h / 2 + wall])
      cube([4, 8, act_low + boom_h / 2 - wall + 4]);
  }
}

module hook() {
  color("black") translate([0, 0, -hook_drop]) cylinder(d = 0.8, h = hook_drop);
  color("red") translate([0, 0, -hook_drop]) {
    translate([0, 0, -5]) cube([8, 4, 10], center = true);
    translate([0, 0, -14]) rotate([90, 0, 0])
      rotate_extrude(angle = 270) translate([5, 0]) circle(d = 2.5);
  }
}

// along local +x: rear insert at 0, enclosed actuator, optional pushrod from the ram
module actuator(extension, rod = rod_len) {
  enclosed_actuator(extension);
  if (rod > 0) {
    color("silver") translate([act_len + extension, 0, 0]) rotate([0, 90, 0]) cylinder(d = 3, h = rod);
    color("silver") translate([act_len + extension + rod, 0, 0]) sphere(d = 7);  // ball link at the boom
  }
}

// --------------------------------------------------------------- scene ----

vehicle();
electronics_box();
if (outriggers) bowden_outriggers(feet);
rotate([0, 0, slew_angle]) {
  color("dimgray") cylinder(d = turntable_d, h = turntable_h);
  translate([0, 0, turntable_h]) {
    mast();
    translate([0, 0, pivot_h]) rotate([0, -theta, 0]) boom();
    translate([0, 0, base_pivot_h]) rotate([0, -phi, 0])
      actuator(ext);
    // hook hangs straight down from the tip
    translate([tip_len * cos(theta), 0, pivot_h + tip_len * sin(theta)]) hook();
  }
}
