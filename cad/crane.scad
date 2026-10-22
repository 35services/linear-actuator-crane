// RC crane concept – telescopic boom, luffed and extended by two mini stepper
// linear actuators. Rough visual model, not print-ready. All dimensions in mm.
//
// View > Animate (FPS 10, Steps 60) to sweep the boom and telescope through
// their range. The console echoes the stroke the lift geometry needs and the
// tip-force ratio, so you can check them before building anything.

/* [Pose] */
animate      = true;
boom_angle   = 30;     // used when animate = false
tele_ext     = 15;     // telescope extension, used when animate = false
boom_min     = 0;      // degrees above horizontal
boom_max     = 55;
slew_angle   = 25;     // turntable rotation, just for the picture

/* [Boom geometry] */
outer_len    = 140;    // outer section, pivot to front end
inner_len    = 130;    // inner (sliding) section
inner_stick  = 15;     // how far the inner section sticks out when retracted
boom_tail    = 40;     // stub behind the pivot for a counterweight
boom_w       = 16;
boom_h       = 12;
wall         = 2;
attach_d     = 50;     // lift actuator attach point, distance from boom pivot
pivot_h      = 80;     // boom pivot height above turntable
base_pivot_h = 10;     // lift actuator base pivot height above turntable (below boom pivot)
hook_drop    = 70;

/* [Actuator] */
stroke       = 30;     // both actuators are the same model
motor_d      = 15;
motor_len    = 15;
frame_w      = 12;
frame_h      = 10;
slider_len   = 12;

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

slider0 = motor_len + slider_len / 2 + 2;         // slider centre when fully retracted

// --- lift geometry in the boom plane (x forward, z up), origin = lift actuator base pivot B
P = [0, pivot_h - base_pivot_h];                  // boom pivot
function attach(a) = P + attach_d * [cos(a), sin(a)];
function dist(a) = norm(attach(a));

d_min = dist(boom_min);
d_max = dist(boom_max);
A     = attach(theta);
D     = dist(theta);
phi   = atan2(A[1], A[0]);                        // lift actuator angle

rod_len = d_min - slider0;                        // pushrod, slider -> boom
ext     = D - d_min;
lever   = abs(P[0] * A[1] - P[1] * A[0]) / D;     // perpendicular distance pivot -> actuator line

// --- telescope geometry along the boom (x from boom pivot)
inner_start0 = outer_len + inner_stick - inner_len;  // rear end of inner section, retracted
inner_start  = inner_start0 + tele;
tip_len      = inner_start + inner_len;              // pivot -> tip sheave
tele_act_x   = inner_start0 - slider0;               // telescope actuator base on top of the boom

echo(str("Lift stroke needed: ", d_max - d_min, " mm (actuator has ", stroke, " mm)"));
if (d_max - d_min > stroke)
  echo("WARNING: lift geometry needs more stroke than the actuator has - reduce attach_d or the boom range");
echo(str("Reach (pivot -> tip): ", inner_start0 + inner_len, " .. ", inner_start0 + inner_len + stroke, " mm"));
echo(str("Boom ", theta, " deg, telescope +", tele, " mm: tip force ≈ lift actuator force × ",
         lever / tip_len));
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
    text("ESP32+2xTMC2209", size = 3.6, halign = "center", valign = "center");
}

module mast() {
  // two cheek plates carrying the boom pivot, lift actuator sits between them
  for (y = [-1, 1]) color("orange", 0.55)
    translate([0, y * (boom_w / 2 + 3), 0]) rotate([90, 0, 0])
      linear_extrude(3, center = true)
        polygon([[-30, 0], [30, 0], [8, pivot_h + 6], [-8, pivot_h + 6]]);
  color("silver") translate([0, 0, pivot_h]) axle();
  color("silver") translate([0, 0, base_pivot_h]) axle();
}

// Boom in its own frame: x along the boom from the pivot, z up
module boom() {
  // outer section: rectangular tube, open at the front, slot on top for the telescope drive
  color("gold") difference() {
    translate([-boom_tail, -boom_w / 2, -boom_h / 2]) cube([outer_len + boom_tail, boom_w, boom_h]);
    translate([-boom_tail + 5, -boom_w / 2 + wall, -boom_h / 2 + wall])
      cube([outer_len + boom_tail, boom_w - 2 * wall, boom_h - 2 * wall]);
    translate([inner_start0 - 4, -2, 0]) cube([stroke + 8, 4, boom_h]);
  }
  // inner section
  inner_w = boom_w - 2 * wall - 0.5;
  inner_h = boom_h - 2 * wall - 0.5;
  color("khaki") translate([inner_start, -inner_w / 2, -inner_h / 2]) cube([inner_len, inner_w, inner_h]);
  // lift actuator clevis under the boom
  color("gold") translate([attach_d - 6, -boom_w / 2, -boom_h / 2 - 2]) cube([12, boom_w, 4]);
  // tip sheave
  color("silver") translate([tip_len, 0, 0]) rotate([90, 0, 0]) cylinder(d = 14, h = 4, center = true);
  // counterweight
  color("darkslategray") translate([-boom_tail, -boom_w / 2 - 2, -boom_h / 2 - 8]) cube([20, boom_w + 4, 14]);
  // telescope actuator lying on top, slider pushes the inner section through the slot
  translate([tele_act_x, 0, boom_h / 2 + frame_h / 2 + 1]) {
    actuator(tele, rod = 0);
    color("dodgerblue") translate([slider0 + tele - 2, -1.5, -frame_h / 2 - boom_h / 2 - 2])
      cube([4, 3, frame_h / 2 + boom_h / 2 + 2]);
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

// along local +x: base clevis at 0, motor, frame with lead screw, slider, optional pushrod
module actuator(extension, rod = rod_len) {
  xs = slider0 + extension;
  color("silver") rotate([90, 0, 0]) cylinder(d = 8, h = frame_w, center = true, $fn = 24); // base clevis eye
  color("#333") rotate([0, 90, 0]) cylinder(d = motor_d, h = motor_len);
  color("lightgray") difference() {
    translate([motor_len, -frame_w / 2, -frame_h / 2]) cube([stroke + slider_len + 6, frame_w, frame_h]);
    translate([motor_len + 2, -frame_w / 2 + 1.5, -frame_h / 2 + 1.5])
      cube([stroke + slider_len + 2, frame_w - 3, frame_h]);
  }
  color("goldenrod") translate([motor_len, 0, 0]) rotate([0, 90, 0]) cylinder(d = 3, h = stroke + slider_len + 4);
  color("dodgerblue") translate([xs - slider_len / 2, -frame_w / 2 + 1, -frame_h / 2 + 1]) cube([slider_len, frame_w - 2, frame_h]);
  if (rod > 0) {
    color("silver") translate([xs, 0, 0]) rotate([0, 90, 0]) cylinder(d = 4, h = rod);
    color("silver") translate([xs + rod, 0, 0]) sphere(d = 7);                   // ball link at the boom
  }
}

// --------------------------------------------------------------- scene ----

vehicle();
electronics_box();
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
