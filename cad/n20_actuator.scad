// Enclosed linear actuator – 3D printed housing + ram around the 12GA-N20 DC
// gear motor with an M4 × 100 mm lead screw (AliExpress, 3 / 6 / 12 V,
// 15–1000 RPM). Dimensions from the drawing in the listing, see
// docs/actuators/n20_lead_screw_drawing.jpg.
//
// How it works:
//   * Here the screw turns and the nut moves, the opposite of the stepper
//     slider in actuator_housing.scad. A standard M4 hex nut sits in a slot in
//     the RAM's piston. The square piston slides in a square channel, so the
//     nut can't turn with the screw and is pushed along it.
//   * The TRAY holds the motor in a pocket. A BULKHEAD in front of it takes the
//     gearbox's front plate, held by two M1.6 screws in the plate's own holes.
//     The LID screws on top.
//   * Both ends are hard stops: the piston hits the bulkhead when retracted and
//     the front wall when extended. A DC motor stalls there, the driver sees
//     the current rise (docs/actuator_comparison.md), and the nut never runs
//     off the end of the screw.
//   * The ram's thinner front rod runs through a guide in the front wall. The
//     wall and the lid's tongue around it keep the ram from turning, and side
//     loads go into the housing, not into the screw.
//
// Coordinates: x along the actuator, x = 0 at the gearbox's front face,
// lead screw on the x axis.
//
// part = "assembly" for the overview (animate with View > Animate), or
// "tray", "lid", "ram" to export printable STLs (already in print orientation).
// Dimensions marked (drawing) come from the listing's drawing, (est.) are
// guesses – check with calipers.

/* [View] */
part       = "assembly";  // [assembly, tray, lid, ram]
animate    = true;
extension  = 40;          // used when animate = false, 0..stroke
show_lid   = false;       // assembly: lid hides the inside
section    = true;        // assembly: cut away the near side wall

/* [Motor (measure yours)] */
gear_len   = 9;      // (drawing) gearbox, front plate to can
gear_w     = 10;     // (drawing) gearbox plates, across (y)
gear_h     = 12;     // (drawing) gearbox plates, up (z)
plate_t    = 0.7;    // (drawing) front plate
can_len    = 16;     // (drawing)
can_d      = 12.1;   // (drawing) Ø12.1 max, round top and bottom
can_flat   = 10;     // (drawing) flats on the sides
cap_len    = 1.0;    // (drawing) plastic end cap behind the can
term_len   = 2;      // (est.) solder tabs behind the end cap
boss_d     = 4;      // (est.) bearing boss on the front plate
boss_h     = 0.5;    // (est.)
hole_pitch = 9;      // (drawing) M1.6 holes in the front plate, above and below the screw
screw_len  = 100;    // (drawing) from the front plate to the tip
screw_d    = 4;      // M4
tip_d      = 3;      // (drawing) plain tip
tip_len    = 4;      // (drawing)
screw_lead = 0.7;    // M4 standard pitch, single start. The nut drawing in the listing
                     // says "M4*1": count the threads on yours and change this

/* [Nut] */
nut_af  = 7;      // M4 hex nut (DIN 934 / ISO 4032), across flats
nut_t   = 3.2;    // thickness

/* [Stroke] */
stroke  = 80;     // piston from bulkhead to front wall

/* [Print] */
wall      = 2.5;   // housing walls
clr       = 0.4;   // sliding clearance
piston_w  = 12.6;  // ram piston, square, also sets the channel (room for the counterbores)
piston_len = 10;   // carries the nut
rod_w     = 9;     // ram rod, guided by the front wall
rod_top   = 4.5;   // rod: z from the piston floor up to here (flat bottom for printing)
bore_d    = 5.4;   // clearance for the screw inside the ram
bulk_t    = 2.6;   // bulkhead in front of the gearbox
cbore_d   = 3.4;   // counterbore for the M1.6 screw heads ...
cbore_t   = 1.0;   // ... leaves 1.6 mm: M1.6 × 2.5 screws reach 0.2 mm past the plate
m16_clear = 1.8;
front_t   = 8;     // front wall, guide length for the rod
nose_out  = 5;     // ram nose sticking out of the housing when retracted
wire_room = 4;     // behind the solder tabs, for bending the wires to the cable exit
insert_d     = 4.0;  // M3 heat-set insert hole at both ends (for RC ball links / studs)
insert_depth = 6;
mount_d      = 10;   // rear mounting boss
mount_len    = 8;
screw_pilot = 1.7;  // M2 self-tapping into tray ears
screw_clear = 2.4;

$fn = 48;

// ------------------------------------------------------------ derived ----

ext = animate ? stroke * (0.5 - 0.5 * cos(360 * $t)) : min(max(extension, 0), stroke);

motor_x0 = -(gear_len + can_len);            // rear face of the can
rear_in  = motor_x0 - cap_len - term_len - wire_room;

// channel cross section: the piston plus clearance
in_y    = piston_w / 2 + clr / 2;
floor_z = -in_y;
lid_z   = in_y;
out_y   = in_y + wall;
bay_y   = can_flat / 2 + 0.15;              // motor pocket, narrower than the channel
notch_y = rod_w / 2 + clr / 2;              // front wall opening
rod_z0  = -piston_w / 2;                    // rod floor = piston floor
tongue_z = rod_top + clr / 2;               // lid tongue closes the opening above the rod

// ram, in its own frame: u = 0 at the piston's rear face
ram_x0  = bulk_t;                           // piston rear face when retracted (on the bulkhead)
front_x = ram_x0 + piston_len + stroke;     // inner face of the front wall
house_x0 = rear_in - wall;
house_x1 = front_x + front_t;
ram_len = max(screw_len + 1 + insert_depth + 1.5 - ram_x0,   // screw tip stays clear of the insert
              house_x1 + nose_out - ram_x0);
nut_u   = piston_len / 2;
bore_end = ram_len - insert_depth - 1.5;

ear_w  = 5;
ear_xs = [house_x0 + ear_w / 2, (house_x0 + house_x1) / 2, house_x1 - 4];
rear_end = house_x0 - mount_len;
cable_x  = motor_x0 - cap_len - term_len / 2;

retracted = (ram_x0 + ram_len) - rear_end;
nut_front = ram_x0 + nut_u + nut_t / 2 + stroke;   // at full extension
echo(str("End to end: ", retracted, " mm retracted, ", retracted + stroke, " mm extended (stroke ", stroke, " mm), plus ball links"));
echo(str("Housing: ", house_x1 - rear_end, " × ", 2 * out_y, " × ", lid_z + wall - floor_z + wall, " mm, ram ", ram_len, " mm"));
echo(str("Ram inside the housing at full extension: ", house_x1 - (ram_x0 + stroke), " mm"));
echo(str("Nut ", screw_len - tip_len - nut_front, " mm from the end of the thread at full extension"));
if (nut_front > screw_len - tip_len - 1)
  echo("WARNING: the nut runs off the thread at full extension - reduce stroke");
if (bore_d < screw_d + 1)
  echo("WARNING: the ram's bore rubs on the screw");

// ---------------------------------------------------- reference model ----

module hex_nut() {
  difference() {
    rotate([0, 90, 0]) cylinder(d = nut_af / cos(30), h = nut_t, center = true, $fn = 6);
    rotate([0, 90, 0]) cylinder(d = screw_d, h = nut_t + 1, center = true);
  }
}

module n20_motor() {
  // can with flats, end cap, solder tabs
  color("silver") intersection() {
    translate([motor_x0, 0, 0]) rotate([0, 90, 0]) cylinder(d = can_d, h = can_len);
    translate([motor_x0, -can_flat / 2, -can_d / 2]) cube([can_len, can_flat, can_d]);
  }
  color("dimgray") translate([motor_x0 - cap_len, -can_flat / 2 + 1, -4]) cube([cap_len + 0.01, can_flat - 2, 8]);
  color("goldenrod") for (s = [-1, 1])
    translate([motor_x0 - cap_len - term_len, -1, s * 3 - 0.75]) cube([term_len + 0.01, 2, 1.5]);
  // gearbox: two brass plates, spacers, gears in between
  color("burlywood") for (x = [-plate_t, -gear_len])
    translate([x, -gear_w / 2, -gear_h / 2]) cube([plate_t, gear_w, gear_h]);
  color("burlywood") for (y = [-1, 1], z = [-1, 1])
    translate([-gear_len, y * (gear_w / 2 - 1), z * (gear_h / 2 - 1)]) rotate([0, 90, 0]) cylinder(d = 1.5, h = gear_len);
  color("gray") for (z = [-2.5, 2.5])
    translate([-gear_len + 1.5 + (z > 0 ? 3 : 0), 0, z]) rotate([0, 90, 0]) cylinder(d = 6, h = 1.5);
  color("burlywood") rotate([0, 90, 0]) cylinder(d = boss_d, h = boss_h);
  // lead screw with a plain tip
  color("lightsteelblue") {
    rotate([0, 90, 0]) cylinder(d = screw_d, h = screw_len - tip_len);
    translate([screw_len - tip_len, 0, 0]) rotate([0, 90, 0]) cylinder(d = tip_d, h = tip_len);
  }
  color("orange") translate([cable_x, 0, 0]) rotate([-90, 0, 0]) cylinder(d = 2.5, h = out_y + 6);  // wires
}

// ---------------------------------------------------------------- ram ----

module ram() {
  difference() {
    union() {
      translate([0, -piston_w / 2, -piston_w / 2]) cube([piston_len, piston_w, piston_w]);
      translate([piston_len - 0.01, -rod_w / 2, rod_z0]) cube([ram_len - piston_len + 0.01, rod_w, rod_top - rod_z0]);
    }
    // screw bore, from the rear into the rod
    translate([-1, 0, 0]) rotate([0, 90, 0]) cylinder(d = bore_d, h = bore_end + 1);
    // nut slot, open at the top: the nut drops in, flats against the slot walls
    hull() for (z = [0, piston_w])
      translate([nut_u, 0, z]) rotate([0, 90, 0])
        cylinder(d = (nut_af + 0.3) / cos(30), h = nut_t + 0.3, center = true, $fn = 6);
    // M3 heat-set insert for the ball link
    translate([ram_len - insert_depth, 0, 0]) rotate([0, 90, 0]) cylinder(d = insert_d, h = insert_depth + 1);
  }
}

// ------------------------------------------------------------- housing ----

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
        translate([rear_end, -mount_d / 2, floor_z - wall + mount_len]) cube([mount_len, mount_d, 0.01]);
      }
    }
    // wire room behind the motor
    translate([rear_in, -in_y, floor_z]) cube([motor_x0 - rear_in + 0.01, 2 * in_y, lid_z - floor_z + 1]);
    // motor pocket, as wide as the can's flats
    translate([motor_x0, -bay_y, floor_z]) cube([-motor_x0 + 0.01, 2 * bay_y, lid_z - floor_z + 1]);
    // channel for the piston, between the bulkhead and the front wall
    translate([bulk_t, -in_y, floor_z]) cube([front_x - bulk_t, 2 * in_y, lid_z - floor_z + 1]);
    // front wall: opening for the rod, open at the top (the lid's tongue closes it)
    translate([front_x - 1, -notch_y, floor_z]) cube([front_t + 2, 2 * notch_y, lid_z - floor_z + 1]);
    // bulkhead: screw and boss, M1.6 screws with counterbored heads on the ram side
    translate([-1, 0, 0]) rotate([0, 90, 0]) cylinder(d = max(boss_d, screw_d) + 1.5, h = bulk_t + 2);
    for (z = [-1, 1] * hole_pitch / 2) {
      translate([-1, 0, z]) rotate([0, 90, 0]) cylinder(d = m16_clear, h = bulk_t + 2);
      translate([bulk_t - cbore_t, 0, z]) rotate([0, 90, 0]) cylinder(d = cbore_d, h = cbore_t + 1);
    }
    // cable exit through the side wall, behind the motor
    translate([cable_x, 0, 0]) rotate([-90, 0, 0]) cylinder(d = 4, h = out_y + 1);
    for (x = ear_xs, s = [-1, 1])
      translate([x, s * (out_y + ear_w / 2), lid_z - 5]) cylinder(d = screw_pilot, h = 6);
    translate([rear_end - 1, 0, 0]) rotate([0, 90, 0]) cylinder(d = insert_d, h = insert_depth + 1);
  }
}

module lid() {
  difference() {
    union() {
      translate([house_x0, -out_y, lid_z]) cube([house_x1 - house_x0, 2 * out_y, wall]);
      for (x = ear_xs, s = [-1, 1])
        translate([x - ear_w / 2, s > 0 ? out_y - 0.01 : -out_y - ear_w + 0.01, lid_z]) cube([ear_w, ear_w, wall]);
      // tongue: closes the front wall's opening above the rod
      translate([front_x + 0.2, -notch_y + 0.1, tongue_z]) cube([front_t - 0.2, 2 * notch_y - 0.2, lid_z - tongue_z + 0.01]);
    }
    for (x = ear_xs, s = [-1, 1])
      translate([x, s * (out_y + ear_w / 2), lid_z - 1]) cylinder(d = screw_clear, h = wall + 2);
  }
}

// ------------------------------------------------- for other models ----
// The closed actuator (lid on) with the rear insert at x = 0 and the ram at
// extension e. Same interface as actuator_housing.scad, so a model can switch
// actuators by changing its `use <...>` line.

function act_retracted() = retracted;   // insert to insert, ram fully in
function act_stroke()    = stroke;
function act_lead()      = screw_lead;
function act_width()     = 2 * (out_y + ear_w);
function act_floor()     = floor_z - wall;  // bottom of the housing below the screw axis
function act_top()       = lid_z + wall;    // top of the lid above the screw axis

module enclosed_actuator(e) {
  translate([-rear_end, 0, 0]) {
    n20_motor();
    color("dimgray") translate([ram_x0 + e + nut_u, 0, 0]) hex_nut();
    color("tomato") translate([ram_x0 + e, 0, 0]) ram();
    color("steelblue") { tray(); lid(); }
  }
}

// ---------------------------------------------------------------- scene ----

// removes everything on the near side (y < -y_keep) for the section view
module near_side_cut(y_keep) {
  translate([rear_end - 50, -50, -50]) cube([house_x1 - rear_end + 300, 50 - y_keep + 0.01, 100]);
}

if (part == "tray") {
  translate([0, 0, -(floor_z - wall)]) tray();
} else if (part == "lid") {
  rotate([180, 0, 0]) translate([0, 0, -(lid_z + wall)]) lid();
} else if (part == "ram") {
  translate([0, 0, -rod_z0]) ram();   // standing on its flat floor, nut slot up
} else if (part == "assembly") {
  n20_motor();
  color("dimgray") translate([ram_x0 + ext + nut_u, 0, 0]) hex_nut();
  color("tomato") difference() {
    translate([ram_x0 + ext, 0, 0]) ram();
    if (section) near_side_cut(0);
  }
  color("steelblue", 0.9) difference() {
    tray();
    if (section) near_side_cut(0);
  }
  if (show_lid) color("steelblue", 0.5) lid();
}
