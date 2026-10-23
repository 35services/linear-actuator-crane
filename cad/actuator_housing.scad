// Enclosed linear actuator – 3D printed housing + sliding ram around the
// 15 mm mini stepper slider (motor Ø15 × 12.5, frame 90 mm, 104 mm overall,
// M3 lead screw Ø2.9).
//
// How it works:
//   * The TRAY clamps the motor (lower half cradle) and carries the frame on a
//     narrow rib along the floor. The LID screws on top and clamps the motor
//     from above.
//   * The RAM is a rectangular sleeve around the frame. Its ceiling has a slot
//     that the slider's tall tab sits in: the slot's front end pushes the ram
//     out, a 1.75 mm filament pin (or M2 screw) behind the tab pulls it back in.
//     A slot in the ram's floor lets it slide past the frame's support rib.
//   * Tray side walls, floor and lid guide the ram, so side loads go into the
//     housing and not into the actuator's thin guide rods.
//
// Coordinates: x along the actuator, x = 0 at the motor's rear face,
// lead screw on the x axis.
//
// part = "assembly" for the overview (animate with View > Animate), or
// "tray", "lid", "ram" to export printable STLs (already in print orientation).
// Dimensions marked (photo) were read off the product photo – check with calipers.

/* [View] */
part       = "assembly";  // [assembly, tray, lid, ram]
animate    = true;
extension  = 40;          // used when animate = false, 0..stroke
show_lid   = false;       // assembly: lid hides the inside
section    = true;        // assembly: cut away the near side wall

/* [Actuator (measure yours)] */
motor_d       = 15;
motor_len     = 12.5;
overall_len   = 104;
end_plate_t   = 1.5;
frame_d       = 10;     // frame depth (into the photo) – not visible in the photo, MEASURE
frame_top     = 5.5;    // (photo) top of guide rods above screw axis
frame_bot     = -7.5;   // (photo)
plate_top     = 8.8;    // (photo) end plate
plate_bot     = -9.6;   // (photo)
feet_bot      = -9.8;   // (photo) lowest point of the sheet metal frame
slider_len    = 7.5;    // (photo) slider body length along x
slider_d      = 10;     // slider depth, MEASURE
slider_top    = 8;      // (photo) top of slider body
slider_bot    = -9.4;   // (photo)
tab_t         = 3;      // (photo) tall tab thickness along x
tab_w         = 8;      // tab width along y, MEASURE
tab_top       = 13.4;   // (photo)
tab_min       = 19;     // tab centre x when fully retracted, MEASURE
stroke        = 75;     // slider travel: 86.6 mm of thread minus the ~10 mm slider nut
                        // gives ~76 mm (photo), 75 leaves a little margin
screw_lead    = 0.5;    // M3 lead screw, single start: 172 turns counted on 86.6 mm (photo)

/* [Print] */
wall     = 2.5;   // housing walls
ram_wall = 2;
ram_roof = 4;     // ram ceiling, carries the tab slot and pin
clr      = 0.4;   // sliding clearance
pin_d    = 1.9;   // hole for 1.75 mm filament (or M2 screw)
rib_w    = 4;
insert_d     = 4.0;  // M3 heat-set insert hole at both ends (for RC ball links / studs)
insert_depth = 6;
mount_d      = 10;   // rear mounting boss
mount_len    = 8;
screw_pilot = 1.7;  // M2 self-tapping into tray ears
screw_clear = 2.4;

$fn = 48;

// ------------------------------------------------------------ derived ----

frame_x0 = motor_len;
frame_x1 = overall_len;

ext   = animate ? stroke * (0.5 - 0.5 * cos(360 * $t)) : min(max(extension, 0), stroke);
tab_x = tab_min + ext;

// ram cross section
ram_in_y  = max(frame_d, slider_d) / 2 + 0.75;
ram_out_y = ram_in_y + ram_wall;
ram_in_z0 = feet_bot - 0.5;
ram_z0    = ram_in_z0 - ram_wall;
ram_in_z1 = max(plate_top, slider_top) + 1.2;
ram_z1    = ram_in_z1 + ram_roof;

// ram along x, relative to the tab centre
pin_rel   = -tab_t / 2 - pin_d / 2 - 0.25;
ram_rear  = pin_rel - 2.5;
nose_rel  = frame_x1 + 1 - tab_min;        // inner face of the nose when retracted
nose_len  = 12;
ram_front = nose_rel + nose_len;

// housing
in_y   = ram_out_y + clr;
out_y  = in_y + wall;
floor_z = ram_z0 - clr / 2;
lid_z   = ram_z1 + clr;
rear_in = -5;                       // room behind the motor for the wires
front_x = frame_x1 + 4;             // inner end of the guide length
house_x0 = rear_in - wall;
house_x1 = front_x + 4;
ear_w    = 5;
ear_xs   = [house_x0 + 4, (house_x0 + house_x1) / 2, house_x1 - 4];

rear_end = house_x0 - mount_len;
cable_y  = mount_d / 2 + 3;          // cable exit beside the rear boss

retracted = (tab_min + ram_front) - rear_end;
echo(str("End to end: ", retracted, " mm retracted, ", retracted + stroke, " mm extended (stroke ", stroke, " mm), plus ball links"));
echo(str("Ram guide overlap at full extension: ", house_x1 - (tab_min + stroke + ram_rear), " mm"));
echo(str("Housing: ", house_x1 - rear_end, " × ", 2 * out_y, " × ", lid_z + wall - floor_z + wall, " mm"));
if (tab_min + ram_rear < motor_len + 0.3)
  echo("WARNING: ram rear end hits the motor when retracted - increase tab_min");
if (tab_min + stroke + tab_t / 2 > frame_x1 - end_plate_t)
  echo("WARNING: slider reaches the end plate - reduce stroke");

// ---------------------------------------------------- reference model ----

module mini_actuator(e) {
  tx = tab_min + e;
  color("silver") rotate([0, 90, 0]) cylinder(d = motor_d, h = motor_len);
  // frame: two guide rods, lead screw, end plate, bottom sheet
  color("lightgray") {
    for (z = [frame_top - 1, frame_bot + 1])
      translate([frame_x0, 0, z]) rotate([0, 90, 0]) cylinder(d = 2, h = frame_x1 - frame_x0);
    translate([frame_x1 - end_plate_t, -frame_d / 2, plate_bot]) cube([end_plate_t, frame_d, plate_top - plate_bot]);
    translate([frame_x0, -frame_d / 2, feet_bot]) cube([frame_x1 - frame_x0, frame_d, 1]);
  }
  color("goldenrod") translate([frame_x0, 0, 0]) rotate([0, 90, 0]) cylinder(d = 2.9, h = frame_x1 - frame_x0);
  color("white") {
    translate([tx + tab_t / 2 - slider_len, -slider_d / 2, slider_bot]) cube([slider_len, slider_d, slider_top - slider_bot]);
    translate([tx - tab_t / 2, -tab_w / 2, slider_bot]) cube([tab_t, tab_w, tab_top - slider_bot]);
  }
  color("orange") translate([rear_in, cable_y, -4]) rotate([0, -90, 0]) cylinder(d = 3, h = 8);  // wires
}

// ---------------------------------------------------------------- ram ----

// in its own frame: x relative to the tab centre
module ram() {
  difference() {
    union() {
      translate([ram_rear, -ram_out_y, ram_z0]) cube([ram_front - ram_rear, 2 * ram_out_y, ram_z1 - ram_z0]);
    }
    // hollow inside, open at the rear
    translate([ram_rear - 1, -ram_in_y, ram_in_z0]) cube([nose_rel - ram_rear + 1, 2 * ram_in_y, ram_in_z1 - ram_in_z0]);
    // ceiling slot for the slider tab, open at the rear, front end pushes the tab
    translate([ram_rear - 1, -(tab_w / 2 + 0.3), ram_in_z1 - 1]) cube([tab_t / 2 + 0.15 - ram_rear + 1, tab_w + 0.6, ram_roof + 2]);
    // floor slot for the support rib
    translate([ram_rear - 1, -(rib_w / 2 + 0.4), ram_z0 - 1]) cube([nose_rel - ram_rear + 1, rib_w + 0.8, ram_wall + 2]);
    // retaining pin behind the tab
    translate([pin_rel, 0, (ram_in_z1 + tab_top) / 2]) rotate([90, 0, 0]) cylinder(d = pin_d, h = 2 * ram_out_y + 2, center = true);
    // M3 heat-set insert for the ball link
    translate([ram_front - insert_depth, 0, 0]) rotate([0, 90, 0]) cylinder(d = insert_d, h = insert_depth + 1);
  }
}

// ------------------------------------------------------------- housing ----

module motor_bore() {
  translate([-1, 0, 0]) rotate([0, 90, 0]) cylinder(d = motor_d + 0.3, h = motor_len + 1.5);
}

module tray() {
  difference() {
    union() {
      // shell
      translate([house_x0, -out_y, floor_z - wall]) cube([house_x1 - house_x0, 2 * out_y, lid_z - floor_z + wall]);
      // screw ears, with a 45° gusset so they print without support
      for (x = ear_xs, s = [-1, 1]) hull() {
        translate([x - ear_w / 2, s > 0 ? out_y - 0.01 : -out_y - ear_w + 0.01, lid_z - 4]) cube([ear_w, ear_w, 4]);
        translate([x - ear_w / 2, s > 0 ? out_y - 0.01 : -out_y - 0.01, lid_z - 4 - ear_w]) cube([ear_w, 0.02, 1]);
      }
      // rear mounting boss, sloped down to the floor so it prints without support
      hull() {
        translate([rear_end, 0, 0]) rotate([0, 90, 0]) cylinder(d = mount_d, h = mount_len + 0.01);
        translate([house_x0 - 0.01, -mount_d / 2, floor_z - wall]) cube([0.01, mount_d, 1]);
        translate([rear_end, -mount_d / 2, floor_z - wall + (mount_len)]) cube([mount_len, mount_d, 0.01]);
      }
    }
    // inside, open at the front (ram exit) and at the top (lid)
    translate([rear_in, -in_y, floor_z]) cube([house_x1 - rear_in + 1, 2 * in_y, lid_z - floor_z + 1]);
    // cable exit
    translate([house_x0 - 1, cable_y, -4]) rotate([0, 90, 0]) cylinder(d = 5, h = wall + 2);
    for (x = ear_xs, s = [-1, 1])
      translate([x, s * (out_y + ear_w / 2), lid_z - 5]) cylinder(d = screw_pilot, h = 6);
    translate([rear_end - 1, 0, 0]) rotate([0, 90, 0]) cylinder(d = insert_d, h = insert_depth + 1);
  }
  // lower motor cradle
  difference() {
    translate([0, -in_y, floor_z - 0.01]) cube([motor_len, 2 * in_y, -floor_z]);
    motor_bore();
  }
  // frame support rib, passes through the ram's floor slot
  translate([frame_x0, -rib_w / 2, floor_z - 0.01]) cube([frame_x1 - frame_x0, rib_w, feet_bot - floor_z]);
}

module lid() {
  difference() {
    union() {
      translate([house_x0, -out_y, lid_z]) cube([house_x1 - house_x0, 2 * out_y, wall]);
      for (x = ear_xs, s = [-1, 1])
        translate([x - ear_w / 2, s > 0 ? out_y - 0.01 : -out_y - ear_w + 0.01, lid_z]) cube([ear_w, ear_w, wall]);
      // upper motor cradle
      translate([0, -in_y + 0.2, 0.3]) cube([motor_len, 2 * in_y - 0.4, lid_z]);
    }
    motor_bore();
    for (x = ear_xs, s = [-1, 1])
      translate([x, s * (out_y + ear_w / 2), lid_z - 1]) cylinder(d = screw_clear, h = wall + 2);
  }
}

// ------------------------------------------------- for other models ----
// The closed actuator (lid on) with the rear insert at x = 0 and the ram at extension e.
// crane.scad pulls it in with `use <actuator_housing.scad>`.

function act_retracted() = retracted;   // insert to insert, ram fully in
function act_stroke()    = stroke;
function act_lead()      = screw_lead;
function act_width()     = 2 * (out_y + ear_w);
function act_floor()     = floor_z - wall;  // bottom of the housing below the screw axis

module enclosed_actuator(e) {
  translate([-rear_end, 0, 0]) {
    mini_actuator(e);
    color("tomato") translate([tab_min + e, 0, 0]) ram();
    color("steelblue") { tray(); lid(); }
  }
}

// ---------------------------------------------------------------- scene ----

// removes everything on the near side (y < -y_keep) for the section view
module near_side_cut(y_keep) {
  translate([house_x0 - 50, -50, -50]) cube([house_x1 - house_x0 + 300, 50 - y_keep + 0.01, 100]);
}

if (part == "tray") {
  translate([0, 0, -(floor_z - wall)]) tray();
} else if (part == "lid") {
  rotate([180, 0, 0]) translate([0, 0, -(lid_z + wall)]) lid();
} else if (part == "ram") {
  translate([0, 0, ram_out_y]) rotate([90, 0, 0]) ram();   // on its side: slots print as walls
} else {
  mini_actuator(ext);
  color("tomato") difference() {
    translate([tab_x, 0, 0]) ram();
    if (section) near_side_cut(ram_in_y);
  }
  color("dimgray") translate([tab_x + pin_rel, 0, (ram_in_z1 + tab_top) / 2])
    rotate([90, 0, 0]) cylinder(d = 1.75, h = 2 * ram_out_y, center = true);
  color("steelblue", 0.9) difference() {
    tray();
    if (section) near_side_cut(in_y);
  }
  if (show_lid) color("steelblue", 0.5) lid();
}
