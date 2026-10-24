// Use case 1b: the same rear stabilizer legs as bowden_outriggers.scad, driven by one stepper
// through gears instead of bowden tubes. Two options, `drive`:
//
//  "worm": a worm wheel sector on each leg's upper-link hub, the two worms on one cross shaft
//          just below the pivots, inside the rear beam. One stepper turns the shaft through a
//          1:1 spur pair; left- and right-hand worms make the legs move as mirror images.
//          A worm with a small lead angle can't be turned from the wheel: the legs hold at
//          any angle, no lock needed.
//  "rack": a pinion between two racks that it drives apart (one in front of it, one behind).
//          Each rack pushes its leg out through a pushrod on a horn. At the end the pushrod
//          points through the pivot (dead centre): the leg can't push the rack back.
//
// Rough visual model like the other use cases, all in mm. Opened on its own it shows the legs
// on a see-through vehicle; View > Animate sweeps them out and in.

use <bowden_outriggers.scad>

/* [View] */
drive       = "worm";   // [worm, rack]
animate     = true;
deploy      = 1;        // 0 = folded up, 1 = out
show_ground = true;

/* [Motor: 28BYJ-48] */
motor_rpm   = 15;       // output rpm under load, bipolar on a TMC2209 maybe 20
motor_nm    = 0.05;     // output torque
pad_force   = 5;        // N per pad the drive has to press down at the end (preload)

/* [Worm] */
gear_m      = 1;        // module of all gears
wheel_r     = 12;       // worm wheel pitch radius: 24 teeth
worm_r      = 4;        // worm pitch radius, single start
worm_len    = 14;
worm_mu     = 0.2;      // friction printed PLA/PETG on PLA

/* [Rack] */
pinion_r    = 8;        // 16 teeth
horn_r      = 14;       // pushrod pin on the upper link
horn_ang    = 60;       // horn angle to the upper link
rack_h      = -22;      // rack line below the upper pivot
rod_len     = 42;       // pushrod

$fn = 32;

// ------------------------------------------------------------ geometry ----

LX  = ol_leg_x();
LT  = ol_link_t();
PU  = ol_pivot_u();
P1  = ol_P1();
HX  = LX - LT;                           // plane of the upper link (hub, worm wheel)
RX  = LX - 2 * LT - 1;                   // rack drive: horn on the back of the upper link
PX  = RX - 12;                           // pinion behind the legs, racks at PX ± pinion_r
sweep = ol_fold_ang() - ol_out_ang();
function dir2(a) = [cos(a), sin(a)];
function to3(p, s, x = HX) = [x, s * p[0], p[1]];

// worm
ratio     = 2 * wheel_r / gear_m;                       // single start
worm_turns = ratio * sweep / 360;
lead_ang  = atan(PI * gear_m / (2 * PI * worm_r));
self_lock = tan(lead_ang) < worm_mu;
eta_worm  = tan(lead_ang) / tan(lead_ang + atan(worm_mu));
leg_nm    = pad_force * ol_link_len() * cos(ol_out_ang()) / 1000;         // per leg at the end
worm_nm   = 2 * leg_nm / ratio / eta_worm;                                // both legs, at the motor
shaft_z   = P1[1] - wheel_r - worm_r;

// rack: crank (horn) and slider (rack pin) in the leg plane, pin inboard of the horn
function horn_pin(a) = P1 + horn_r * dir2(a + horn_ang);
function rack_u(a) = let(c = horn_pin(a)) c[0] - sqrt(rod_len * rod_len - pow(P1[1] + rack_h - c[1], 2));
rack_z     = P1[1] + rack_h;
rack_travel = rack_u(ol_out_ang()) - rack_u(ol_fold_ang());
pinion_deg = rack_travel / pinion_r * 180 / PI;
// angle between pushrod and horn at the end: 0° = dead centre
function rod_dir(a) = unit([rack_u(a), rack_z] - horn_pin(a));
function unit(v) = v / norm(v);
end_ang = acos(abs(rod_dir(ol_out_ang()) * unit(horn_pin(ol_out_ang()) - P1)));
// rack force at the start of the swing to lift the folded leg's own weight is small;
// at the end the dead centre gives a huge mechanical advantage
rack_n_end = 2 * pad_force;   // two legs; just a reminder that the force near dead centre is ~0 at the motor

// ---------------------------------------------------------------- gears ----

// 2D spur gear outline / sector, pitch radius r, from angle a0 to a1
module gear2d(r, a0 = 0, a1 = 360) {
  n = round(2 * r / gear_m);
  step = 360 / n;
  union() {
    intersection() {
      circle(r = r - 1.25 * gear_m);
      if (a1 - a0 < 360) polygon(concat([[0, 0]], [for (t = [a0 : 5 : a1]) 2 * r * dir2(t)], [2 * r * dir2(a1)]));
    }
    for (i = [0 : n - 1]) let(t = i * step) if (t >= a0 && t <= a1)
      rotate(t) polygon([[r - 1.25 * gear_m, -0.6 * gear_m * PI / 2], [r + gear_m, -0.25 * gear_m * PI / 2],
                         [r + gear_m, 0.25 * gear_m * PI / 2], [r - 1.25 * gear_m, 0.6 * gear_m * PI / 2]]);
  }
}

// rack along +x from 0 to len, teeth up
module rack2d(len) {
  square([len, 4]);
  for (x = [0 : PI * gear_m : len]) translate([x, 4])
    polygon([[-0.6 * gear_m * PI / 2, 0], [-0.25 * gear_m * PI / 2, 2.25 * gear_m],
             [0.25 * gear_m * PI / 2, 2.25 * gear_m], [0.6 * gear_m * PI / 2, 0]]);
}

// worm along +y, centred
module worm(hand = 1) {
  rotate([-90, 0, 0]) translate([0, 0, -worm_len / 2])
    linear_extrude(worm_len, twist = hand * 360 * worm_len / (PI * gear_m), slices = 40)
      translate([0.6, 0]) circle(r = worm_r + gear_m - 0.6);
  rotate([-90, 0, 0]) cylinder(r = worm_r - 1.2, h = worm_len + 2, center = true);
}

// 28BYJ-48, shaft along +z from its front face at the origin
module byj(shaft_off = 8) {
  color("silver") translate([0, -shaft_off, -19]) cylinder(d = 28, h = 19);
  color("#3a6fd8") translate([-8.5, -shaft_off - 17.5, -18]) cube([17, 4, 16]);
  color("gold") cylinder(d = 5, h = 8);
}

// ------------------------------------------------------------- drives ----

module worm_drive(a) {
  for (s = [-1, 1]) {
    // wheel sector on the upper link: covers the part that passes the worm below the pivot
    color("orange") translate([HX, s * P1[0], P1[1]]) rotate([0, 90, 0]) rotate([0, 0, 90])
      mirror([s < 0 ? 1 : 0, 0, 0]) linear_extrude(LT, center = true)
        rotate(a) gear2d(wheel_r, -90 - ol_fold_ang() - 15, -90 - ol_out_ang() + 15);
    color("silver") translate([HX, s * PU, shaft_z]) worm(s);
    // bearing blocks to the beam
    color("dimgray") for (dy = [-11, 11]) translate([HX - 3, s * PU + dy - 2, shaft_z - 4]) cube([LX + 2 * LT + 3.5 - HX + 3, 4, 8]);
  }
  color("silver") translate([HX, 0, shaft_z]) rotate([90, 0, 0]) cylinder(d = 3, h = 2 * PU + 30, center = true);
  // 1:1 spur pair to the motor above the shaft
  for (z = [shaft_z, shaft_z + 2 * 8 * gear_m]) color("orange") translate([HX, 0, z]) rotate([90, 0, 0])
    linear_extrude(4, center = true) gear2d(8 * gear_m);
  translate([HX, 2, shaft_z + 16 * gear_m]) rotate([90, 0, 0]) rotate([0, 0, 180]) byj();
}

function rack_pin(s, a) = [PX + s * pinion_r, s * (PU + rack_u(a)), rack_z];
module pushrod(s, a) {
  // on a pin behind the horn, so it passes behind the horn's hub and the pivot pin
  hull() { translate(rack_pin(s, a)) sphere(d = 4); translate(to3(horn_pin(a), s, RX - 3.5)) sphere(d = 4); }
  translate(to3(horn_pin(a), s, RX - 1.75)) rotate([0, 90, 0]) cylinder(d = 2.5, h = 3.5, center = true, $fn = 12);
}

module rack_drive(a) {
  for (s = [-1, 1]) {
    pin = rack_pin(s, a);
    // rack: from its pin inwards across the pinion
    color("silver") translate([pin[0] + (s > 0 ? 2.25 : -2.25), pin[1], rack_z]) rotate([0, 0, s > 0 ? -90 : 90])
      rotate([0, 0, 0]) translate([0, s > 0 ? 0 : 0, -2]) linear_extrude(4) mirror([0, 1, 0]) rack2d(rack_travel + 34);
    // pushrod from the rack pin to the horn
    color("goldenrod") pushrod(s, a);
    // horn on the back of the upper link
    h = horn_pin(a);
    color("orange") hull() { translate(to3(P1, s, RX)) rotate([0, 90, 0]) cylinder(d = 7, h = 2, center = true);
                             translate(to3(h, s, RX)) rotate([0, 90, 0]) cylinder(d = 6, h = 2, center = true); }
  }
  color("orange") translate([PX, 0, rack_z - 2]) linear_extrude(4) gear2d(pinion_r);
  // guide housing for pinion and racks, behind the legs, hanging from the beam
  color("dimgray", 0.35) translate([PX - pinion_r - 7, -PU + 8, rack_z - 4]) cube([2 * pinion_r + 14, 2 * PU - 16, 8]);
  // motor above the pinion, shaft pointing down into it
  translate([PX, 0, rack_z + 10]) rotate([180, 0, 0]) byj();
}

module geared_outriggers(d) {
  a = ol_link_ang(d);
  rear_beam();
  for (s = [-1, 1]) leg_parts(s, a, false, bowden = false);
  if (drive == "worm") worm_drive(a); else rack_drive(a);
  geared_report();
}

module geared_report() {
  if (drive == "worm") {
    echo(str("Worm: 1:", ratio, ", ", worm_turns, " turns of the shaft for the full swing, ",
             worm_turns / motor_rpm * 60, " s at ", motor_rpm, " rpm"));
    echo(str("Worm: lead angle ", lead_ang, "°, ", self_lock ? "self-locking" : "NOT self-locking",
             " at µ = ", worm_mu, ", efficiency ", eta_worm));
    echo(str("Worm: pressing both pads with ", pad_force, " N needs ", worm_nm, " Nm at the motor (28BYJ: ≈ ",
             motor_nm, ")", worm_nm > motor_nm ? "  WARNING: more than the motor has - less preload or a bigger ratio" : ""));
  } else {
    echo(str("Rack: each rack moves ", rack_travel, " mm, the pinion turns ", pinion_deg, "°, ",
             pinion_deg / 360 / motor_rpm * 60, " s at ", motor_rpm, " rpm"));
    echo(str("Rack: pushrod to horn at the end ", end_ang, "° off dead centre (0 = locked)"));
  }
}

// --------------------------------------------------------------- scene ----

d = animate ? 0.5 - 0.5 * cos(360 * $t) : deploy;
scene = true;   // false: draw nothing, for files that include this one (collision checks)
if (scene) {
  vehicle_scene(show_ground);
  geared_outriggers(d);
}
