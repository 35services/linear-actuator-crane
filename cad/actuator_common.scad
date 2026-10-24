// Shared pieces of the 3D printed actuator housings, used by actuator_housing.scad
// (15 mm stepper slider) and actuator_28byj.scad (28BYJ-48 with lead screw).
// Conventions of both: x along the actuator, the screw on the x axis, the housing is a
// TRAY (open at the top) with a LID screwed on through side ears, the RAM slides inside.

// Screw ear on the side of the tray (side = -1 / 1), top at z_top, with a 45° gusset below
// so it prints without support.
module tray_ear(x, side, out_y, z_top, w = 5, h = 4) {
  hull() {
    translate([x - w / 2, side > 0 ? out_y - 0.01 : -out_y - w + 0.01, z_top - h]) cube([w, w, h]);
    translate([x - w / 2, side > 0 ? out_y - 0.01 : -out_y - 0.01, z_top - h - w]) cube([w, 0.02, 1]);
  }
}

// The matching flat ear on the lid, from z up by t
module lid_ear(x, side, out_y, z, t, w = 5) {
  translate([x - w / 2, side > 0 ? out_y - 0.01 : -out_y - w + 0.01, z]) cube([w, w, t]);
}

// Vertical hole through an ear, from z up by h
module ear_hole(x, side, out_y, z, d, h, w = 5) {
  translate([x, side * (out_y + w / 2), z]) cylinder(d = d, h = h);
}

// Rear mounting boss on the screw axis, from rear_end to the rear wall at x_wall, sloped
// down to the bottom of the housing (z_bottom) so it prints without support.
module rear_boss(rear_end, x_wall, z_bottom, d, len) {
  hull() {
    translate([rear_end, 0, 0]) rotate([0, 90, 0]) cylinder(d = d, h = len + 0.01);
    translate([x_wall - 0.01, -d / 2, z_bottom]) cube([0.01, d, 1]);
    translate([rear_end, -d / 2, z_bottom + len]) cube([len, d, 0.01]);
  }
}

// Hole for an M3 heat-set insert on the x axis, opening towards -x at x
module insert_hole_rear(x, d, depth) {
  translate([x - 1, 0, 0]) rotate([0, 90, 0]) cylinder(d = d, h = depth + 1);
}

// Removes everything on the near side (y < -y_keep) for section views
module section_cut(x0, x1, y_keep) {
  translate([x0 - 50, -50, -50]) cube([x1 - x0 + 300, 50 - y_keep + 0.01, 100]);
}
