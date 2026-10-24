// Enclosed linear actuator around a 28BYJ-48 geared stepper (bipolar mod) and a T8 lead
// screw – the cheap variant of actuator_housing.scad, built the same way.
//
// How it works:
//   * The motor is clamped between the TRAY and the LID, its two mounting ears sit in slots.
//     It only turns the screw: a printed COUPLER joins its 5 mm D-shaft to the T8 screw.
//   * A 688 ball bearing (8 x 16 x 5) in a wall right in front of the coupler carries all
//     axial load. The coupler (behind) and a printed COLLAR (in front) clamp the screw to the
//     bearing's inner ring, so the motor's plastic gearbox never sees push or pull.
//   * A standard T8 flange nut is screwed to the rear face of the RAM, a square printed bar
//     that slides in the housing. The square stops it from turning.
//   * Same mounting as the slider version: M3 heat-set inserts at both ends for RC ball links,
//     lid screwed on through side ears (shared modules in actuator_common.scad).
//
// Coordinates: x along the actuator, x = 0 at the motor's front face (shaft side), lead
// screw on the x axis. The motor's shaft is 8 mm off its centre, so the motor hangs below.
//
// part = "assembly" for the overview (animate with View > Animate), or "tray", "lid", "ram",
// "coupler", "collar" to export printable STLs (already in print orientation).
// "collide" shows the intersection of the moving parts with the housing at `extension`
// (empty = no collision).

include <actuator_common.scad>

/* [View] */
part      = "assembly";  // [assembly, tray, lid, ram, coupler, collar, collide]
animate   = true;
extension = 40;          // used when animate = false, 0..stroke
show_lid  = false;       // assembly: lid hides the inside
section   = true;        // assembly: cut away the near side

/* [28BYJ-48 (measure yours)] */
byj_d      = 28;     // can diameter
byj_h      = 19;     // can depth behind the mounting face
shaft_off  = 8;      // shaft axis above the can axis
ear_span   = 35;     // mounting hole distance
ear_tab_d  = 7;      // round ends of the mounting flange
ear_t      = 0.8;    // flange thickness, at the front face
shaft_d    = 5;
shaft_flat = 3;      // across the two flats
shaft_len  = 10;     // shaft end from the front face
boss_h     = 1.5;    // shaft boss in front of the face
cap_w      = 17;     // blue wire cover on the can's side, opposite the shaft
cap_r      = 17.5;   // its outer edge from the can axis

/* [Lead screw and parts] */
stroke        = 75;
screw_d       = 8;      // T8
lead          = 8;      // mm per turn: T8x8 (4 start) fast, T8x2 slow and strong
nut_flange_d  = 22;     // standard T8 brass flange nut
nut_flange_t  = 3.5;
nut_body_d    = 10.2;
nut_len       = 15;     // flange included
nut_hole_r    = 8;      // flange holes on a 16 mm circle
bearing_od    = 16;     // 688ZZ
bearing_w     = 5;
coupler_d     = 14;
collar_d      = 16;
collar_len    = 7;
shoulder_d    = 10;     // coupler/collar shoulder that touches only the bearing's inner ring

/* [Home sensor] */
// A small magnet in the ram and a hall sensor (A3144 or similar, TO-92) under the floor
// mark the retracted end - works with any driver, also with the ULN2003 board.
home_sensor = true;
magnet_d    = 5;     // 5 x 2 mm neodymium disc
magnet_h    = 2;
magnet_x    = 6;     // from the ram's rear face
hall_w      = 4.6;   // TO-92 body
hall_t      = 3.0;
floor_skin  = 0.6;   // plastic left between sensor and magnet

/* [Speed estimate] */
rpm        = 20;     // 28BYJ-48 output after the bipolar mod, about 15-25 rpm
torque_nm  = 0.05;   // output torque at that speed, bipolar
efficiency = 0.35;   // trapezoid screw with brass nut

/* [Print] */
wall          = 2.5;
clr           = 0.4;
ram_w         = 24;     // square ram, holds the nut flange
guide_overlap = 25;     // ram length still in the housing at full extension
insert_d      = 4.0;    // M3 heat-set insert
insert_depth  = 6;
mount_d       = 10;
mount_len     = 8;
nose_len      = 12;
screw_pilot   = 1.7;    // M2 self-tapping into tray ears
screw_clear   = 2.4;
m3_pilot      = 2.5;    // M3 self-tapping (nut flange, grub screws)
ear_w         = 5;

$fn = 48;

// ------------------------------------------------------------ derived ----

ext = animate ? stroke * (0.5 - 0.5 * cos(360 * $t)) : min(max(extension, 0), stroke);

motor_z   = -shaft_off;              // can axis
lip       = 1.5;                     // bearing wall lips in front of and behind the bearing
coupler_x0 = boss_h + 0.3;
wall_x0   = 18.3;                    // bearing wall
bear_x0   = wall_x0 + lip;
bear_x1   = bear_x0 + bearing_w;
wall_x1   = bear_x1 + lip;
coupler_x1 = wall_x0 - 0.3;          // coupler body ends here, its shoulder reaches the bearing
collar_x1 = bear_x1 + lip + 0.3 + collar_len;
nut_x0    = collar_x1 + 1;           // nut flange rear face, retracted
ram_x0    = nut_x0 + nut_flange_t;   // ram rear face, retracted
screw_x0  = shaft_len + 1;
screw_x1  = nut_x0 + stroke + nut_len + 1;

// housing cross sections
in_y    = ram_w / 2 + clr;           // ram guide
out_y   = in_y + wall;
floor_z = -in_y;
lid_z   = in_y;
can_r   = byj_d / 2 + 0.3;
m_in_y  = can_r;                     // motor block
m_out_y = m_in_y + wall;
m_floor = motor_z - cap_r - 0.5;
ear_y   = ear_span / 2 + ear_tab_d / 2 + 0.4;   // ear slot half width

house_x0 = -byj_h - 0.5 - wall;
house_x1 = ram_x0 + stroke + guide_overlap;
rear_end = house_x0 - mount_len;
ram_len  = house_x1 + 2 + nose_len - ram_x0;
ram_front_rel = ram_len;

ear_xs   = [ram_x0, (ram_x0 + house_x1) / 2, house_x1 - 4];
m_ear_x  = (house_x0 + 0) / 2 - 2;

retracted = ram_x0 + ram_len - rear_end;
speed     = rpm * lead / 60;
force     = 2 * PI * torque_nm * efficiency / (lead / 1000);

echo(str("End to end: ", retracted, " mm retracted, ", retracted + stroke, " mm extended (stroke ", stroke, " mm), plus ball links"));
echo(str("Housing: ", house_x1 - rear_end, " mm long, ram section ", 2 * out_y, " x ", 2 * out_y,
         " mm, motor block ", 2 * m_out_y, " wide, ", lid_z + wall - (m_floor - wall), " high"));
echo(str("Lead screw T8 x ", lead, ": ", screw_x1 - screw_x0, " mm long. Speed ≈ ", speed, " mm/s at ", rpm,
         " rpm, force ≈ ", force, " N"));
echo(str("Steps: 2048 full steps per screw turn = ", 2048 / lead, " full steps per mm"));
if (nut_x0 + stroke + nut_len > screw_x1)
  echo("WARNING: the screw is too short for the stroke");

// ---------------------------------------------------- reference parts ----

module byj48() {
  color("silver") {
    translate([-byj_h, 0, motor_z]) rotate([0, 90, 0]) cylinder(d = byj_d, h = byj_h);
    // mounting flange with the two ears, at the front face
    translate([-ear_t, 0, motor_z]) rotate([0, 90, 0]) linear_extrude(ear_t) difference() {
      hull() for (s = [-1, 1]) translate([0, s * ear_span / 2]) circle(d = ear_tab_d);
      for (s = [-1, 1]) translate([0, s * ear_span / 2]) circle(d = 4.2);
    }
  }
  color("#3a6fd8") translate([-byj_h + 1, -cap_w / 2, motor_z - cap_r]) cube([byj_h - 2, cap_w, cap_r - byj_d / 2 + 1]);
  color("gold") {
    rotate([0, 90, 0]) cylinder(d = 9, h = boss_h);
    rotate([0, 90, 0]) intersection() {
      cylinder(d = shaft_d, h = shaft_len);
      translate([-shaft_d, -shaft_flat / 2, 0]) cube([2 * shaft_d, shaft_flat, shaft_len]);
    }
  }
  color("orange") translate([-byj_h / 2, 0, m_floor + 0.5]) cylinder(d = 4, h = 4);  // wires
}

module bearing() {
  color("#aaa") translate([bear_x0, 0, 0]) rotate([0, 90, 0]) difference() {
    cylinder(d = bearing_od, h = bearing_w);
    translate([0, 0, -1]) cylinder(d = screw_d, h = bearing_w + 2);
  }
}

module lead_screw() {
  color("goldenrod") translate([screw_x0, 0, 0]) rotate([0, 90, 0]) cylinder(d = screw_d, h = screw_x1 - screw_x0);
}

module nut(e) {
  color("#c9a227") translate([nut_x0 + e, 0, 0]) rotate([0, 90, 0]) difference() {
    union() {
      cylinder(d = nut_flange_d, h = nut_flange_t);
      cylinder(d = nut_body_d, h = nut_len);
    }
    translate([0, 0, -1]) cylinder(d = screw_d, h = nut_len + 2);
  }
}

// ------------------------------------------------------- printed parts ----

// coupler: 5 mm D-shaft behind, T8 screw in front, shoulder on the bearing's inner ring
module coupler() {
  difference() {
    union() {
      translate([coupler_x0, 0, 0]) rotate([0, 90, 0]) cylinder(d = coupler_d, h = coupler_x1 - coupler_x0);
      translate([coupler_x1 - 0.01, 0, 0]) rotate([0, 90, 0]) cylinder(d = shoulder_d, h = bear_x0 - coupler_x1 + 0.01);
    }
    // D-shaft
    translate([coupler_x0 - 1, 0, 0]) rotate([0, 90, 0]) intersection() {
      cylinder(d = shaft_d + 0.2, h = shaft_len - coupler_x0 + 1.5);
      translate([-shaft_d, -(shaft_flat + 0.2) / 2, 0]) cube([2 * shaft_d, shaft_flat + 0.2, shaft_len]);
    }
    // screw
    translate([screw_x0 - 0.5, 0, 0]) rotate([0, 90, 0]) cylinder(d = screw_d + 0.15, h = bear_x0 - screw_x0 + 1);
    // M3 grub screws: one on the shaft flat, one on the screw
    for (x = [(coupler_x0 + shaft_len) / 2, (screw_x0 + coupler_x1) / 2])
      translate([x, 0, 0]) cylinder(d = m3_pilot, h = coupler_d);
  }
}

// collar in front of the bearing, shoulder on the inner ring
module collar() {
  x0 = bear_x1 + 0.01;
  difference() {
    union() {
      translate([x0, 0, 0]) rotate([0, 90, 0]) cylinder(d = shoulder_d, h = lip + 0.3);
      translate([x0 + lip + 0.3, 0, 0]) rotate([0, 90, 0]) cylinder(d = collar_d, h = collar_len);
    }
    translate([x0 - 1, 0, 0]) rotate([0, 90, 0]) cylinder(d = screw_d + 0.15, h = collar_len + lip + 3);
    translate([x0 + lip + 0.3 + collar_len / 2, 0, 0]) cylinder(d = m3_pilot, h = collar_d);
  }
}

// ram in its own frame: x from its rear face
module ram() {
  difference() {
    translate([0, -ram_w / 2, -ram_w / 2]) cube([ram_len, ram_w, ram_w]);
    // nut body, then clearance for the screw
    translate([-1, 0, 0]) rotate([0, 90, 0]) cylinder(d = nut_body_d + 0.4, h = nut_len - nut_flange_t + 1.5);
    translate([-1, 0, 0]) rotate([0, 90, 0]) cylinder(d = screw_d + 1.2, h = ram_len - nose_len + 1);
    // M3 screws for the nut flange
    for (s = [-1, 1]) translate([-1, s * nut_hole_r, 0]) rotate([0, 90, 0]) cylinder(d = m3_pilot, h = 11);
    // M3 heat-set insert for the ball link
    translate([ram_len - insert_depth, 0, 0]) rotate([0, 90, 0]) cylinder(d = insert_d, h = insert_depth + 1);
    // magnet for the home sensor, in the bottom face
    if (home_sensor) translate([magnet_x, 0, -ram_w / 2 - 1]) cylinder(d = magnet_d + 0.2, h = magnet_h + 1.1);
  }
}

// ------------------------------------------------------------- housing ----

module motor_pocket() {
  translate([-byj_h - 0.5, 0, motor_z]) rotate([0, 90, 0]) cylinder(r = can_r, h = byj_h + 0.51);
  translate([-byj_h - 0.5, -m_in_y, motor_z]) cube([byj_h + 0.51, 2 * m_in_y, lid_z - motor_z + 1]);
  translate([-byj_h - 0.5, -cap_w / 2 - 0.5, m_floor]) cube([byj_h + 0.51, cap_w + 1, motor_z - m_floor]);
  // mounting flange slot
  translate([-ear_t - 0.2, -ear_y, motor_z - ear_tab_d / 2 - 0.4]) cube([ear_t + 0.4, 2 * ear_y, ear_tab_d + 0.8]);
  // shaft boss and coupler
  translate([-0.5, 0, 0]) rotate([0, 90, 0]) cylinder(d = coupler_d + 2, h = 2);
}

module bearing_cut() {
  translate([bear_x0 - 0.05, 0, 0]) rotate([0, 90, 0]) cylinder(d = bearing_od + 0.15, h = bearing_w + 0.1);
  translate([wall_x0 - 1, 0, 0]) rotate([0, 90, 0]) cylinder(d = shoulder_d + 2, h = wall_x1 - wall_x0 + 2);
}

module tray() {
  difference() {
    union() {
      // ram section and motor block
      translate([0, -out_y, floor_z - wall]) cube([house_x1, 2 * out_y, lid_z - floor_z + wall]);
      translate([house_x0, -m_out_y, m_floor - wall]) cube([-house_x0 + 0.01, 2 * m_out_y, lid_z - m_floor + wall]);
      // bosses around the flange slots, sloped 45° into the wall below so they print without support
      hull() {
        translate([-ear_t - 0.2 - wall, -ear_y - wall, motor_z - ear_tab_d / 2 - 0.4 - wall])
          cube([ear_t + 0.4 + 2 * wall, 2 * (ear_y + wall), ear_tab_d + 0.8 + 2 * wall]);
        translate([-ear_t - 0.2 - wall, -m_out_y, motor_z - ear_tab_d / 2 - 0.4 - wall - (ear_y + wall - m_out_y)])
          cube([ear_t + 0.4 + 2 * wall, 2 * m_out_y, 0.01]);
      }
      for (x = ear_xs, s = [-1, 1]) tray_ear(x, s, out_y, lid_z, ear_w);
      for (s = [-1, 1]) tray_ear(m_ear_x, s, m_out_y, lid_z, ear_w);
      rear_boss(rear_end, house_x0, m_floor - wall, mount_d, mount_len);
    }
    // ram guide, coupler chamber
    translate([0, -in_y, floor_z]) cube([house_x1 + 1, 2 * in_y, lid_z - floor_z + 1]);
    motor_pocket();
    // wires out through the floor under the blue cover
    translate([-byj_h / 2, 0, m_floor - wall - 1]) cylinder(d = 6, h = wall + 2);
    for (x = ear_xs, s = [-1, 1]) ear_hole(x, s, out_y, lid_z - 5, screw_pilot, 6, ear_w);
    for (s = [-1, 1]) ear_hole(m_ear_x, s, m_out_y, lid_z - 5, screw_pilot, 6, ear_w);
    insert_hole_rear(rear_end, insert_d, insert_depth);
    // hall sensor pocket from below, under the magnet when retracted
    if (home_sensor)
      translate([ram_x0 + magnet_x - hall_w / 2 - 0.2, -hall_w / 2 - 0.2, floor_z - wall - 1])
        cube([hall_w + 0.4, hall_w + 0.4, wall - floor_skin + 1]);
  }
  // lower half of the bearing wall
  difference() {
    translate([wall_x0, -in_y - 0.01, floor_z - 0.01]) cube([wall_x1 - wall_x0, 2 * in_y + 0.02, -floor_z + 0.01]);
    bearing_cut();
  }
}

module lid() {
  difference() {
    union() {
      translate([0, -out_y, lid_z]) cube([house_x1, 2 * out_y, wall]);
      translate([house_x0, -m_out_y, lid_z]) cube([-house_x0 + 0.01, 2 * m_out_y, wall]);
      for (x = ear_xs, s = [-1, 1]) lid_ear(x, s, out_y, lid_z, wall, ear_w);
      for (s = [-1, 1]) lid_ear(m_ear_x, s, m_out_y, lid_z, wall, ear_w);
      // upper half of the bearing wall
      translate([wall_x0, -in_y + 0.2, 0.2]) cube([wall_x1 - wall_x0, 2 * in_y - 0.4, lid_z]);
      // rib that presses the motor into its cradle
      translate([-byj_h + 1, -6, motor_z + byj_d / 2 + 0.3]) cube([byj_h - 2, 12, lid_z - motor_z - byj_d / 2]);
    }
    bearing_cut();
    for (x = ear_xs, s = [-1, 1]) ear_hole(x, s, out_y, lid_z - 1, screw_clear, wall + 2, ear_w);
    for (s = [-1, 1]) ear_hole(m_ear_x, s, m_out_y, lid_z - 1, screw_clear, wall + 2, ear_w);
  }
}

// ------------------------------------------------- for other models ----
// The closed actuator (lid on) with the rear insert at x = 0 and the ram at extension e.

function byj_retracted() = retracted;
function byj_stroke()    = stroke;
function byj_lead()      = lead;
function byj_width()     = 2 * (m_out_y + ear_w);
function byj_floor()     = m_floor - wall;

module byj_actuator(e) {
  translate([-rear_end, 0, 0]) {
    byj48(); bearing(); lead_screw(); nut(e);
    color("tomato") translate([ram_x0 + e, 0, 0]) ram();
    color("orange") { coupler(); collar(); }
    color("steelblue") { tray(); lid(); }
  }
}

// ---------------------------------------------------------------- scene ----

module moving(e) {
  nut(e);
  translate([ram_x0 + e, 0, 0]) ram();
}

if (part == "tray") {
  translate([0, 0, -(m_floor - wall)]) tray();
} else if (part == "lid") {
  rotate([180, 0, 0]) translate([0, 0, -(lid_z + wall)]) lid();
} else if (part == "ram") {
  translate([0, 0, ram_w / 2]) rotate([90, 0, 0]) ram();   // on its side
} else if (part == "coupler") {
  rotate([0, -90, 0]) translate([-coupler_x0, 0, 0]) coupler();  // standing on the motor end
} else if (part == "collar") {
  rotate([0, 90, 0]) translate([-(collar_x1), 0, 0]) collar();   // standing on its big face
} else if (part == "collide") {
  // every overlap between parts that must not touch, at this extension
  intersection() { moving(ext); union() { tray(); lid(); coupler(); collar(); bearing(); } }
  intersection() { byj48(); union() { tray(); lid(); coupler(); } }
  intersection() { union() { coupler(); collar(); }  union() { tray(); lid(); } }
  intersection() { bearing(); union() { tray(); lid(); } }
} else {
  byj48();
  bearing();
  lead_screw();
  nut(ext);
  color("orange") { coupler(); collar(); }
  color("tomato") difference() {
    translate([ram_x0 + ext, 0, 0]) ram();
    if (section) section_cut(house_x0, house_x1, 0);
  }
  color("steelblue", 0.9) difference() {
    tray();
    if (section) section_cut(house_x0, house_x1, 0);
  }
  if (show_lid) color("steelblue", 0.5) lid();
}
