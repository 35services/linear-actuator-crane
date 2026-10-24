// Use case 2: the crane from crane.scad, but the actuators stay on the vehicle. Both lie
// flat on the chassis and work the boom through bowden tubes – 1.75 mm PETG filament in
// PTFE tubes, as on a 3D printer's bowden extruder. Nothing on the boom but the boom.
// Rough visual model, not print-ready. All dimensions in mm.
//
// The filaments only ever pull, so they can't buckle:
//  * Luffing: the filament runs from the head of an A-frame behind the boom pivot to a
//    yoke on the boom, like a real crane's luffing rope. Pulling it raises the boom, the
//    boom's own weight lowers it when the actuator pays the filament out again.
//  * Telescope: a constant-force spring (a tape-measure spring) on the front of the outer
//    section pulls the inner section out. The filament pulls it back in against the spring.
// The actuators point backwards; their tubes bend straight up behind them and reach the
// slewing upper through a free service loop behind the mast. That limits the slew, like an
// RC crane with its wires on the outside. The electronics box moves to the front of the deck
// to make room for the loop.
//
// Option `outriggers` adds the bowden outriggers (bowden_outriggers.scad); their actuator
// sits on top of the luffing actuator, the deck is full.
//
// View > Animate (FPS 10, Steps 60). The console echoes the stroke each line needs, the
// tip-force ratio, the speeds and the tube lengths and bends.

use <../actuator_housing.scad>
use <bowden_common.scad>
use <bowden_outriggers.scad>

/* [Pose] */
animate      = true;
boom_angle   = 30;     // used when animate = false
tele_ext     = 15;     // telescope extension, used when animate = false
boom_min     = 0;      // degrees above horizontal
boom_max     = 55;
slew_angle   = 25;     // turntable rotation, just for the picture

/* [Outriggers] */
outriggers       = true;
outrigger_deploy = 1;  // 0 = folded in, 1 = down; used when animate = false

/* [Boom geometry] */
outer_len    = 140;    // outer section, pivot to front end
inner_len    = 130;    // inner (sliding) section
inner_stick  = 15;     // how far the inner section sticks out when retracted
boom_tail    = 40;     // stub behind the pivot for a counterweight
boom_w       = 16;
boom_h       = 12;
wall         = 2;
pivot_h      = 80;     // boom pivot height above turntable
hook_drop    = 70;

/* [Luffing line] */
head         = [-15, 60];  // A-frame head (luffing line exit) relative to the boom pivot, [x, z]
yoke_d       = 125;        // yoke on the boom, distance from the pivot
yoke_h       = 14;         // its cross pin above the boom axis

/* [Telescope line] */
pin_dx       = 6;          // pin on the inner section, from its rear end, up through a slot
line_z       = boom_h / 2 + 4;  // telescope line and spring tape height above the boom axis
ret_fit_x    = -2;         // retract line fitting on top of the boom, right over the pivot:
                           // there it hardly moves when the boom luffs
spring_x     = outer_len - 6;   // constant-force spring drum on the front

/* [Speed] */
full_steps_rev = 20;   // 18° motor
step_rate      = 800;  // full steps per second the motor manages under load, see README

/* [Actuators] */
stroke       = act_stroke();     // 75
act_len      = act_retracted();  // 132.5
act_w        = act_width();
deck_y       = 49;     // both actuators flat on the deck, either side of the turntable
act_x        = 160;    // their rear inserts, at the front: the rams point backwards
act_z        = -act_floor();     // screw axis above the deck
fit_gap      = 3;      // crosshead to fitting at full stroke
tube_up      = 22;     // radius the tubes bend upwards with behind the actuators

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
feet  = animate ? min(1, 4 * (0.5 - 0.5 * cos(360 * $t))) : outrigger_deploy;

// --- luffing geometry in the boom plane (x forward, z up), origin = boom pivot
function yoke(a) = yoke_d * [cos(a), sin(a)] + yoke_h * [-sin(a), cos(a)];
function luff_len(a) = norm(yoke(a) - head);
luff_need = luff_len(boom_min) - luff_len(boom_max);
Y     = yoke(theta);
L     = luff_len(theta);
lever = abs(head[0] * Y[1] - head[1] * Y[0]) / L;   // perpendicular distance pivot -> luffing line
e_luff = L - luff_len(boom_max);                    // ram out = boom down

// --- telescope geometry along the boom (x from boom pivot)
inner_start0 = outer_len + inner_stick - inner_len;  // rear end of inner section, retracted
inner_start  = inner_start0 + tele;
tip_len      = inner_start + inner_len;              // pivot -> tip sheave
pin_x        = inner_start + pin_dx;
e_tele       = tele;                                 // ram out = telescope out (spring pulls)

// --- speed
v_act     = step_rate * act_lead() / full_steps_rev;  // mm/s
function tip_z(a, len) = pivot_h + len * sin(a);
t_lift    = luff_need / v_act;
t_tele    = stroke / v_act;
dL_dtheta = (luff_len(theta - 0.5) - luff_len(theta + 0.5)) * 180 / PI;  // mm per radian

// --- frames: turntable frame = origin on the turntable top, slewed; boom frame = from the pivot
function slew(p) = [p[0] * cos(slew_angle) - p[1] * sin(slew_angle),
                    p[0] * sin(slew_angle) + p[1] * cos(slew_angle), p[2] + turntable_h];
function slew_dir(d) = slew(d) - [0, 0, turntable_h];
function boom_pt(q) = [q[0] * cos(theta) - q[2] * sin(theta), q[1], pivot_h + q[0] * sin(theta) + q[2] * cos(theta)];
function boom_dir(q) = boom_pt(q) - boom_pt([0, 0, 0]);

// --- actuators on the deck: luffing at +deck_y, telescope at -deck_y, rams backwards
function nose_x(e) = act_x - act_len - e;
mouth_x  = nose_x(stroke) - 4 - fit_gap;
luff_m   = [mouth_x, deck_y, act_z];
tele_m   = [mouth_x, -deck_y, act_z];

// --- tube ends on the crane (vehicle frame, all slewed)
H        = [head[0], 0, pivot_h + head[1]];                        // turntable frame
head_u   = unit([Y[0] - head[0], 0, Y[1] - head[1]]);              // luffing line direction
head_m   = slew(H);
head_d   = slew_dir(head_u);
ret_m    = slew(boom_pt([ret_fit_x, 0, line_z]));
ret_d    = slew_dir(boom_dir([1, 0, 0]));

// The tubes bend upwards behind the actuators and climb behind the mast in a free loop
// (vehicle frame, they don't follow the slew): the luffing tube comes up to the A-frame
// head from behind, the telescope tube onto the boom over the pivot.
head_fb  = H - fit_len() * head_u;                                 // head fitting, tube end
head_in  = unit([0.4, 0, 1]);                                      // tube heading into the bend
function deck_wp(s, lean = 0) = [
  [[mouth_x - fit_len() - tube_up, s * deck_y, act_z + tube_up], [0, -s * lean, 1]]];
// the last bend into the head fitting as an arc of radius head_r: an arc's chord runs
// along the sum of its two end directions
head_r   = 25;
head_phi = acos(head_in * head_u);
head_a   = head_fb - 2 * head_r * sin(head_phi / 2) * unit(head_in + head_u);
luff_path = fitting_path(luff_m, [1, 0, 0], head_m, head_d, concat(deck_wp(1), [
  [slew(head_a), slew_dir(head_in)]]));
// the telescope tube leans inwards a little as it starts to climb, its fitting is close
tele_path = fitting_path(tele_m, [1, 0, 0], ret_m, ret_d, deck_wp(-1, 0.2));

echo(str("Luffing line: shortens ", luff_need, " mm from ", boom_min, " to ", boom_max,
         " deg (actuator has ", stroke, " mm)"));
if (luff_need > stroke)
  echo("WARNING: the luffing line needs more stroke than the actuator has - move the yoke closer to the pivot");
echo(str("Reach (pivot -> tip): ", inner_start0 + inner_len, " .. ", inner_start0 + inner_len + stroke, " mm"));
echo(str("Boom ", theta, " deg, telescope +", tele, " mm: tip force ≈ luffing line tension × ",
         lever / tip_len, " (PETG filament holds ≈ 100 N)"));
echo(str("Speed at ", step_rate, " full steps/s: actuator ", v_act, " mm/s, boom ", boom_min, "..", boom_max,
         " deg in ", t_lift, " s, telescope in ", t_tele, " s; hook right now ",
         tip_len * cos(theta) * v_act / dL_dtheta, " mm/s"));
echo(str("Luffing tube ", path_len(luff_path), " mm, tightest bend r = ", min_radius(luff_path),
         " mm; telescope tube ", path_len(tele_path), " mm, tightest bend r = ", min_radius(tele_path), " mm"));
if (min(min_radius(luff_path), min_radius(tele_path)) < min_bend())
  echo(str("WARNING: a tube bends tighter than ", min_bend(), " mm"));
if (pin_x + 3 > spring_x - 6)
  echo("WARNING: the telescope pin reaches the spring drum - reduce the stroke");

// ---------------------------------------------------------------- parts ----

module axle(len = 34) { rotate([90, 0, 0]) cylinder(d = 4, h = len, center = true); }

module vehicle() {
  color("dimgray", 0.6) translate([-chassis[0] / 2 + 30, -chassis[1] / 2, -chassis[2]]) cube(chassis);
  for (x = [-chassis[0] / 2 + 70, chassis[0] / 2 - 10], y = [-1, 1])
    color("#222") translate([x, y * (chassis[1] / 2 + wheel_w / 2 + 2), -chassis[2] - 10])
      rotate([90, 0, 0]) cylinder(d = wheel_d, h = wheel_w, center = true);
}

module electronics_box() {   // at the front here: the tubes' loop needs the space behind the turntable
  color("steelblue") translate([60, -30, 0]) cube([50, 60, 25]);
  color("white") translate([85, 0, 25]) linear_extrude(0.6)
    text(outriggers ? "ESP32+3xTMC2209" : "ESP32+2xTMC2209", size = 3.6, halign = "center", valign = "center");
}

// An actuator flat on the deck at y, its crosshead and the fitting the filament runs into
module deck_actuator(y, e) {
  translate([act_x, y, act_z]) rotate([0, 0, 180]) enclosed_actuator(e);
  color("orange") translate([nose_x(e) - 4, y - 4, act_z - 4]) cube([4, 8, 8]);
  color("dimgray") translate([mouth_x - 8, y - 6, 0]) cube([6, 12, act_z + 5]);
  tube_fitting([mouth_x, y, act_z], [1, 0, 0]);
  filament([nose_x(e) - 2, y, act_z], [mouth_x, y, act_z]);
}

module mast() {
  // two cheek plates carrying the boom pivot
  for (y = [-1, 1]) color("orange", 0.55)
    translate([0, y * (act_w / 2 + 2.5), 0]) rotate([90, 0, 0])
      linear_extrude(3, center = true)
        polygon([[-30, 0], [30, 0], [8, pivot_h + 6], [-8, pivot_h + 6]]);
  color("silver") translate([0, 0, pivot_h]) axle(act_w + 8);
  // A-frame: rear legs from the turntable, front legs from the cheek plates, to the head
  for (y = [-1, 1]) color("orange") {
    hull() { translate([-28, y * 14, 0]) sphere(d = 5); translate([head[0], y * 5, pivot_h + head[1]]) sphere(d = 5); }
    hull() { translate([-4, y * (act_w / 2 + 2.5), pivot_h + 4]) sphere(d = 4);
             translate([head[0], y * 5, pivot_h + head[1]]) sphere(d = 4); }
  }
  color("silver") translate([head[0], 0, pivot_h + head[1]]) axle(14);
}

// Boom in its own frame: x along the boom from the pivot, z up
module boom() {
  // outer section: rectangular tube, open at the front, slot on top for the telescope pin
  color("gold") difference() {
    translate([-boom_tail, -boom_w / 2, -boom_h / 2]) cube([outer_len + boom_tail, boom_w, boom_h]);
    translate([-boom_tail + 5, -boom_w / 2 + wall, -boom_h / 2 + wall])
      cube([outer_len + boom_tail, boom_w - 2 * wall, boom_h - 2 * wall]);
    translate([inner_start0 + pin_dx - 3, -2, 0]) cube([stroke + 6, 4, boom_h]);
  }
  // inner section with its pin up through the slot
  inner_w = boom_w - 2 * wall - 0.5;
  inner_h = boom_h - 2 * wall - 0.5;
  color("khaki") {
    translate([inner_start, -inner_w / 2, -inner_h / 2]) cube([inner_len, inner_w, inner_h]);
    translate([pin_x - 1.5, -1.5, 0]) cube([3, 3, line_z + 2]);
    translate([pin_x, 0, line_z]) axle(8);
  }
  // luffing yoke: a cheek either side, the line ties to the cross pin over the boom
  for (y = [-1, 1]) color("gold") hull() {
    translate([yoke_d - 8, y * (boom_w / 2 + 1) - 1, -boom_h / 2]) cube([16, 2, 1]);
    translate([yoke_d, y * (boom_w / 2 + 1), yoke_h]) rotate([90, 0, 0]) cylinder(d = 6, h = 2, center = true);
  }
  color("silver") translate([yoke_d, 0, yoke_h]) axle(boom_w + 4);
  // constant-force spring drum on the front, its tape pulls the pin forward
  color("dimgray") translate([spring_x, 0, line_z]) axle(10);
  color("dimgray") translate([spring_x, 0, line_z]) rotate([90, 0, 0]) cylinder(d = 10, h = 6, center = true);
  color("silver") translate([pin_x, -2, line_z + 0.5]) cube([spring_x - 5 - pin_x, 4, 0.4]);
  // retract line: fitting over the pivot, filament forward to the pin
  color("dimgray") translate([ret_fit_x - fit_len(), -3, boom_h / 2]) cube([fit_len(), 6, line_z - boom_h / 2 - 2]);
  // tip sheave
  color("silver") translate([tip_len, 0, 0]) rotate([90, 0, 0]) cylinder(d = 14, h = 4, center = true);
  // counterweight: lighter than the boom, so the boom always hangs on its luffing line
  color("darkslategray") translate([-boom_tail, -boom_w / 2 - 2, -boom_h / 2 - 8]) cube([20, boom_w + 4, 14]);
}

module hook() {
  color("black") translate([0, 0, -hook_drop]) cylinder(d = 0.8, h = hook_drop);
  color("red") translate([0, 0, -hook_drop]) {
    translate([0, 0, -5]) cube([8, 4, 10], center = true);
    translate([0, 0, -14]) rotate([90, 0, 0])
      rotate_extrude(angle = 270) translate([5, 0]) circle(d = 2.5);
  }
}

// --------------------------------------------------------------- scene ----

vehicle();
electronics_box();
if (outriggers) bowden_outriggers(feet, deck_y, act_top() - act_floor());   // on top of the luffing actuator
deck_actuator(deck_y, e_luff);
deck_actuator(-deck_y, e_tele);

rotate([0, 0, slew_angle]) {
  color("dimgray") cylinder(d = turntable_d, h = turntable_h);
  translate([0, 0, turntable_h]) {
    mast();
    translate([0, 0, pivot_h]) rotate([0, -theta, 0]) boom();
    // hook hangs straight down from the tip
    translate([tip_len * cos(theta), 0, pivot_h + tip_len * sin(theta)]) hook();
  }
}

// lines and tubes, in vehicle coordinates
tube_fitting(head_m, head_d);
filament(head_m, slew([Y[0], 0, pivot_h + Y[1]]));
tube_fitting(ret_m, ret_d);
filament(ret_m, slew(boom_pt([pin_x, 0, line_z])));
bowden_tube(luff_path);
bowden_tube(tele_path);
