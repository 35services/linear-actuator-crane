// Illustration: where the DIAG jumper wire goes on the carrier PCB.
// A section of the board around driver #0 with a mock TMC2209 StepStick plugged in.
// The module's DIAG pin is not part of the 16-pin socket, so a short Dupont wire
// connects it to the single socket J12 ("DIAG") next to the driver. Driver #1 -> J13.
//
// Coordinates follow the PCB (pcb/generate_pcb.py) with KiCad's y flipped.
// Not to scale in every detail - the module is a generic mock.

$fn = 24;

pitch      = 2.54;
board_t    = 1.6;
socket_h   = 8.5;     // female header height
spacer_h   = 2.5;     // plastic spacer of the module's male pins
module_pcb = 1.6;

drv_x  = 14;          // driver #0 pad 1 (KiCad x)
drv_y  = 16;          // driver #0 pad 1 (KiCad y)
row    = 12.7;        // StepStick row spacing
j12    = [14, 11];    // DIAG socket J12
diag   = [17.5, 15.0];// DIAG pin on the mock module (position differs between brands)

z_socket_top = board_t + socket_h;
z_module     = z_socket_top + spacer_h;
z_module_top = z_module + module_pcb;

function k(p) = [p[0], -p[1]];                 // KiCad -> OpenSCAD (y up)
function k3(p, z) = [p[0], -p[1], z];

module label(txt, size = 1.6, h = 0.4) {
  linear_extrude(h) text(txt, size = size, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
}

// --- carrier board section
module board() {
  color("#2f5a2f") translate([4, -40, 0]) cube([32, 34, board_t]);
  color("white") translate([0, 0, board_t]) {
    translate(k([j12[0] - 3.6, j12[1]])) label("DIAG", 1.2, 0.05);
    translate(k([j12[0], j12[1] - 2.6])) label("J12", 1.2, 0.05);
    translate(k([drv_x + row / 2, drv_y + 21.5])) label("TMC2209 #0  LIFT", 1.3, 0.05);
  }
}

// pin 1 at the origin, further pins towards KiCad +y
module female_socket(n) {
  color("#1a1a1a") translate([-pitch / 2, -(n - 1) * pitch - pitch / 2, board_t]) difference() {
    cube([pitch, n * pitch, socket_h]);
    for (i = [0 : n - 1]) translate([pitch / 2 - 0.5, i * pitch + pitch / 2 - 0.5, socket_h - 3]) cube([1, 1, 4]);
  }
}

// --- mock TMC2209 StepStick
module stepstick() {
  // pins + spacers
  for (c = [0, row], i = [0 : 7]) translate(k([drv_x + c, drv_y + i * pitch])) {
    color("gold") translate([0, 0, z_socket_top - 6]) cylinder(d = 0.64 * 1.4, h = 6 + spacer_h + module_pcb + 1, $fn = 4);
    color("#111") translate([-pitch / 2, -pitch / 2, z_socket_top]) cube([pitch, pitch, spacer_h]);
  }
  // pcb
  color("#5b2a86") translate([drv_x - 1.25, -(drv_y - 1.5 + 20.3), z_module]) cube([15.2, 20.3, module_pcb]);
  // heatsink
  color("#c8c8cc") translate([drv_x + 2.1, -(drv_y + 4 + 9), z_module_top]) {
    cube([9, 9, 1.5]);
    for (i = [0 : 4]) translate([i * 2.05, 0, 0]) cube([0.8, 9, 5.5]);
  }
  // potentiometer (current setting for standalone mode - unused with UART)
  color("#3a6fd8") translate(k3([drv_x + 6.35, drv_y + 15.6], z_module_top)) translate([-1.6, -1.6, 0]) cube([3.2, 3.2, 1.6]);
  color("white") translate(k3([drv_x + 6.35, drv_y + 15.6], z_module_top + 1.6)) rotate(45) cube([2.4, 0.4, 0.2], center = true);
  // silkscreen on the module
  color("white") translate([0, 0, z_module_top]) {
    translate(k([diag[0] + 2.8, diag[1] + 0.2])) label("DIAG", 1.0, 0.05);
    translate(k([drv_x + 6.35, drv_y + 18.6])) label("VREF", 0.8, 0.05);
  }
  // the DIAG pin, standing up on top of the module
  color("gold") translate(k3(diag, z_module_top)) translate([-0.32, -0.32, 0]) cube([0.64, 0.64, 6]);
}

// --- Dupont jumper wire: female end on the DIAG pin, male end in J12
function bez(p0, p1, p2, p3, t) = pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * pow(t, 2) * p2 + pow(t, 3) * p3;

module wire(points, d = 1.2) {
  for (i = [0 : len(points) - 2]) hull() {
    translate(points[i]) sphere(d = d, $fn = 12);
    translate(points[i + 1]) sphere(d = d, $fn = 12);
  }
}

module dupont_housing(pos, h = 14) {
  color("#222") translate(pos - [1.25, 1.25, 0]) cube([2.5, 2.5, h]);
}

module jumper() {
  f_bottom = z_module_top + 2.5;                // female housing slid over the DIAG pin
  m_bottom = z_socket_top;                      // male housing sits on top of J12
  top_f = k3(diag, f_bottom + 14);
  top_m = k3(j12, m_bottom + 14);
  dupont_housing(k3(diag, f_bottom));
  dupont_housing(k3(j12, m_bottom));
  color("gold") translate(k3(j12, m_bottom - 6)) translate([-0.32, -0.32, 0]) cube([0.64, 0.64, 6.5]);
  color("#f2c500") wire([for (t = [0 : 0.05 : 1.001])
    bez(top_f, top_f + [0, 0, 12], top_m + [-6, 0, 16], top_m, t)]);
}

board();
translate(k(j12)) female_socket(1);
for (c = [0, row]) translate(k([drv_x + c, drv_y])) female_socket(8);
stepstick();
jumper();

// callout
color("#d62828") translate([6, -4, 38]) rotate([70, 0, -60]) linear_extrude(0.4)
  text("DIAG -> J12", size = 2.2, halign = "center", font = "Liberation Sans:style=Bold");
