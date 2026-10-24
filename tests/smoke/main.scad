use <sub/lib.scad>
include <sub/inc.scad>
echo(libval(), inc_val);
libcube(10);
translate([20,0,0]) incsphere();
translate([40,0,0]) import("sub/box.stl");
translate([0,20,0]) linear_extrude(3) import("sub/shape.dxf");
