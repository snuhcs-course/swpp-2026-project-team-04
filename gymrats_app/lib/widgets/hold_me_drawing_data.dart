/// The hold stage's new drawings and effect art (version
/// hold-me-drawing-1, A8 spec 2) as a Dart string, so it is read without an
/// asset: 곰탱이's high plank and 펭뚱이's and 물렁범's lying pose (the
/// mockup's `kp.pk.bear`, `kp.pk.Apenguin` and `kp.pk.Aseal` groups), and
/// the shadow, sweat, shake, spark, dust and flying star around them.
///
/// Converted from the design bundle's `HoldMe.dc.html` (its
/// `design/drawings/*.svg.txt` copies) by a script outside the repo: the
/// shapes in drawing order, nested moves flattened into a chain, H and V
/// written as L and relative steps as absolute, colors as they are and the
/// team's lime as `team`. Change the drawing there and convert it again.
library;

const holdMeDrawingJson = r'''
{
 "version": "hold-me-drawing-1",
 "source": "HoldMe.dc.html (canvas version 1795674999-e13f): the groups <g display=\"{{kp.pk.bear}}\">, <g display=\"{{kp.pk.Apenguin}}\">, <g display=\"{{kp.pk.Aseal}}\"> and the effect art around the character",
 "note": "Box 140 x 160, feet on (70, 150). Each shape: chain = the moves from the outside in (a part name, moved by the scene, or a fixed matrix [a, b, c, d, e, f]); face = the expression tags it needs, all of them (absent: always drawn); one of path (absolute M, L, Q, C, A, Z), circle [cx, cy, r], ellipse [cx, cy, rx, ry], rect [x, y, w, h, rx]; fill and stroke #RRGGBB, team (the team lime) or null; width, cap (round unless given), strokeOpacity, opacity.",
 "drawings": {
  "bearPlank": [
   {"chain":["tilt","farArm"],"path":[["M",86,104],["L",88,134]],"fill":null,"stroke":"#141A26","width":22},
   {"chain":["tilt","farArm"],"path":[["M",86,104],["L",88,134]],"fill":null,"stroke":"#6E472F","width":15},
   {"chain":["tilt","farArm"],"circle":[89,138,12],"fill":"team","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",40,112],["L",24,128],["L",10,138]],"fill":null,"stroke":"#141A26","width":22},
   {"chain":["tilt"],"path":[["M",40,112],["L",24,128],["L",10,138]],"fill":null,"stroke":"#6E472F","width":15},
   {"chain":["tilt",[0.635903,1.017658,-0.848048,0.529919,9.0,143.0]],"ellipse":[0,0,13,7.5],"fill":"team","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",50,116],["L",34,132],["L",20,142]],"fill":null,"stroke":"#141A26","width":22},
   {"chain":["tilt"],"path":[["M",50,116],["L",34,132],["L",20,142]],"fill":null,"stroke":"#8A5A3C","width":15},
   {"chain":["tilt",[0.635903,1.017658,-0.848048,0.529919,19.0,146.0]],"ellipse":[0,0,13,7.5],"fill":"team","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",40,86],["C",52,74,78,70,100,72],["C",116,74,124,86,122,100],["C",120,114,108,120,92,122],["C",74,124,54,124,40,120],["C",28,116,26,98,40,86],["Z"]],"fill":"#8A5A3C","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",58,76],["C",48,79,40,83,36,89],["C",27,99,28,114,40,120],["C",46,122,54,123,60,123],["L",56,106],["L",64,120],["L",66,122],["Z"]],"fill":"team","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",44,103],["L",33,101]],"fill":null,"stroke":"#FFFFFF","width":4.5,"cap":"butt"},
   {"chain":["tilt"],"path":[["M",60,75],["Q",55,98,66,123]],"fill":null,"stroke":"#141A26","width":12,"cap":"butt"},
   {"chain":["tilt"],"path":[["M",60,75],["Q",55,98,66,123]],"fill":null,"stroke":"#FFFFFF","width":5.5,"cap":"butt"},
   {"chain":["tilt","head"],"circle":[104,58,9.5],"fill":"#8A5A3C","stroke":"#141A26","width":4},
   {"chain":["tilt","head"],"circle":[104,58,4.2],"fill":"#E3C29E","stroke":null},
   {"chain":["tilt","head"],"circle":[129,54,9.5],"fill":"#8A5A3C","stroke":"#141A26","width":4},
   {"chain":["tilt","head"],"circle":[129,54,4.2],"fill":"#E3C29E","stroke":null},
   {"chain":["tilt","head"],"path":[["M",118,56],["C",102,56,94,66,94,79],["C",94,92,104,100,118,100],["C",132,100,142,92,142,79],["C",142,66,134,56,118,56],["Z"]],"fill":"#8A5A3C","stroke":"#141A26","width":4},
   {"chain":["tilt","head"],"ellipse":[139,86,12,9],"fill":"#E3C29E","stroke":"#141A26","width":3.5},
   {"chain":["tilt","head"],"ellipse":[146,81.5,4.8,3.5],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["idle"],"circle":[123,74,3],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["idle"],"circle":[134,73,2.8],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["idle"],"path":[["M",136,92],["Q",140,94.5,144,91.5]],"fill":null,"stroke":"#141A26","width":2.2},
   {"chain":["tilt","head"],"face":["atk"],"circle":[123,75,3],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["atk"],"circle":[134,74,2.8],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["atk"],"path":[["M",117,67],["L",127,71],["M",131,70],["L",139,66.5]],"fill":null,"stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"face":["atk"],"rect":[134,89,11.5,6.6,2.2],"fill":"#FFFFFF","stroke":"#141A26","width":2.2},
   {"chain":["tilt","head"],"face":["atk"],"path":[["M",134.5,92.3],["L",145.5,92.3],["M",138,89.6],["L",138,95],["M",141.6,89.6],["L",141.6,95]],"fill":null,"stroke":"#141A26","width":1.4},
   {"chain":["tilt","head"],"face":["win"],"path":[["M",119,76],["Q",123,69.5,127,76],["M",130,75],["Q",134,68.5,138,75]],"fill":null,"stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"face":["win"],"path":[["M",135,90],["Q",140,97,145,90],["Z"]],"fill":"#141A26","stroke":"#141A26","width":2},
   {"chain":["tilt","head"],"face":["hit"],"path":[["M",119,70],["L",126,74.5],["L",119,79],["M",138,69],["L",131,73.5],["L",138,78]],"fill":null,"stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"face":["hit"],"ellipse":[140,92.5,2.6,2.2],"fill":"#141A26","stroke":null},
   {"chain":["tilt","nearArm"],"path":[["M",102,104],["L",104,134]],"fill":null,"stroke":"#141A26","width":22},
   {"chain":["tilt","nearArm"],"path":[["M",102,104],["L",104,134]],"fill":null,"stroke":"#8A5A3C","width":15},
   {"chain":["tilt","nearArm"],"circle":[105,137,13],"fill":"team","stroke":"#141A26","width":4},
   {"chain":["tilt","nearArm"],"path":[["M",100,132],["Q",105,128,110,132]],"fill":null,"stroke":"#141A26","width":2.2,"strokeOpacity":0.45}
  ],
  "penguinLie": [
   {"chain":["tilt",[0.546369,-0.651138,0.612836,0.51423,13.0,126.0]],"ellipse":[0,0,13,7.5],"fill":"team","stroke":"#141A26","width":4},
   {"chain":["tilt",[0.750505,-0.399051,0.375577,0.706358,21.0,133.0]],"ellipse":[0,0,13,7.5],"fill":"team","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",108,78],["C",128,78,143,92,143,111],["C",143,130,130,146,113,150],["L",26,150],["C",16,150,10,142,12,132],["C",14,120,26,112,44,106],["C",60,100,73,92,83,86],["C",91,81,99,78,108,78],["Z"]],"fill":"#2E3A55","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",22,148],["C",42,141,76,138,112,140],["C",118,141,122,144,124,148],["C",118,150,114,150,113,150],["L",26,150],["C",24,150,23,149,22,148],["Z"]],"fill":"#FFFFFF","stroke":null},
   {"chain":["tilt"],"path":[["M",108,78],["C",128,78,143,92,143,111],["C",143,130,130,146,113,150],["L",26,150],["C",16,150,10,142,12,132],["C",14,120,26,112,44,106],["C",60,100,73,92,83,86],["C",91,81,99,78,108,78],["Z"]],"fill":null,"stroke":"#141A26","width":4},
   {"chain":["tilt","nearArm"],"path":[["M",62,116],["Q",76,136,100,146]],"fill":null,"stroke":"#141A26","width":19},
   {"chain":["tilt","nearArm"],"path":[["M",62,116],["Q",76,136,100,146]],"fill":null,"stroke":"#2E3A55","width":12},
   {"chain":["tilt","head"],"path":[["M",89,91],["L",72,83],["L",76,101],["Z"]],"fill":"team","stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"path":[["M",86,94],["Q",112,72,140,88]],"fill":null,"stroke":"#141A26","width":13,"cap":"butt"},
   {"chain":["tilt","head"],"path":[["M",86,94],["Q",112,72,140,88]],"fill":null,"stroke":"team","width":8,"cap":"butt"},
   {"chain":["tilt","head"],"circle":[119,110,16],"fill":"#FFFFFF","stroke":null},
   {"chain":["tilt","head"],"path":[["M",131,108],["L",152,114],["L",132,120],["Z"]],"fill":"#FFB547","stroke":"#141A26","width":3.5},
   {"chain":["tilt","head"],"face":["idle"],"path":[["M",110,107],["L",118,107],["A",4.2,5.2,0,0,1,110,107],["Z"]],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["idle"],"path":[["M",122,106],["L",129,106],["A",3.8,5.2,0,0,1,122,106],["Z"]],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["idle"],"path":[["M",108,107],["L",119,107],["M",121,106],["L",130,106]],"fill":null,"stroke":"#141A26","width":2.5},
   {"chain":["tilt","head"],"face":["atk"],"path":[["M",110,108],["L",118,108],["A",4.2,5.2,0,0,1,110,108],["Z"]],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["atk"],"path":[["M",122,107],["L",129,107],["A",3.8,5.2,0,0,1,122,107],["Z"]],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["atk"],"path":[["M",107,102],["L",119,107],["M",121,107],["L",131,102]],"fill":null,"stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"face":["atk","teeth"],"rect":[131,120,10,6,2],"fill":"#FFFFFF","stroke":"#141A26","width":2},
   {"chain":["tilt","head"],"face":["atk","teeth"],"path":[["M",131.5,123],["L",140.5,123],["M",134.5,120.5],["L",134.5,125.5],["M",137.7,120.5],["L",137.7,125.5]],"fill":null,"stroke":"#141A26","width":1.3},
   {"chain":["tilt","head"],"face":["win"],"path":[["M",109,110],["Q",114,102.5,119,110],["M",122,109],["Q",126.5,101.5,131,109]],"fill":null,"stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"face":["hit"],"path":[["M",109,103],["L",117,111],["M",117,103],["L",109,111],["M",122,102],["L",130,110],["M",130,102],["L",122,110]],"fill":null,"stroke":"#141A26","width":3}
  ],
  "sealLie": [
   {"chain":["tilt",[-0.788011,0.615661,0.615661,0.788011,18.0,130.0]],"path":[["M",-13,-3],["Q",-3,-8,10,-4],["Q",17,-1,15,4],["Q",2,8,-12,5],["Q",-17,1,-13,-3],["Z"]],"fill":"#5B7E9B","stroke":"#141A26","width":4},
   {"chain":["tilt",[-0.990268,0.139173,0.139173,0.990268,20.0,140.0]],"path":[["M",-13,-3],["Q",-3,-8,10,-4],["Q",17,-1,15,4],["Q",2,8,-12,5],["Q",-17,1,-13,-3],["Z"]],"fill":"#5B7E9B","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",110,62],["C",132,62,148,78,148,98],["C",148,112,142,122,134,128],["C",127,134,125,143,127,150],["L",34,150],["C",22,150,14,142,16,132],["C",18,120,30,112,46,106],["C",60,100,70,92,79,80],["C",87,69,97,62,110,62],["Z"]],"fill":"#8DB0CB","stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",36,150],["C",56,142,92,138,126,140],["C",125,144,126,147,127,150],["Z"]],"fill":"#F4F7FA","stroke":null},
   {"chain":["tilt"],"ellipse":[36,124,3.5,2.6],"fill":"#5B7E9B","stroke":null},
   {"chain":["tilt"],"ellipse":[52,114,4,3],"fill":"#5B7E9B","stroke":null},
   {"chain":["tilt"],"ellipse":[64,108,3,2.4],"fill":"#5B7E9B","stroke":null},
   {"chain":["tilt"],"ellipse":[48,132,3,2.3],"fill":"#5B7E9B","stroke":null},
   {"chain":["tilt"],"ellipse":[76,100,3.2,3.8],"fill":"#5B7E9B","stroke":null},
   {"chain":["tilt"],"path":[["M",110,62],["C",132,62,148,78,148,98],["C",148,112,142,122,134,128],["C",127,134,125,143,127,150],["L",34,150],["C",22,150,14,142,16,132],["C",18,120,30,112,46,106],["C",60,100,70,92,79,80],["C",87,69,97,62,110,62],["Z"]],"fill":null,"stroke":"#141A26","width":4},
   {"chain":["tilt"],"path":[["M",127,134],["Q",104,142,88,120]],"fill":null,"stroke":"#141A26","width":3.5},
   {"chain":["tilt","nearArm",[0.827411,0.646445,-0.664914,0.851052,98.0,126.0]],"path":[["M",-7,-3],["C",-8.5,7,-10.5,17,-7,24],["C",-3.5,30.5,5.5,30.5,8.5,24],["C",11,17,9,7,7,-3],["Z"]],"fill":"#5B7E9B","stroke":null},
   {"chain":["tilt","nearArm",[0.827411,0.646445,-0.664914,0.851052,98.0,126.0]],"path":[["M",-8.57,8],["L",9,8],["L",9.55,13],["L",-8.93,13],["Z"]],"fill":"team","stroke":null},
   {"chain":["tilt","nearArm",[0.827411,0.646445,-0.664914,0.851052,98.0,126.0]],"path":[["M",-8.57,8],["L",9,8],["M",-8.93,13],["L",9.55,13]],"fill":null,"stroke":"#141A26","width":2.5},
   {"chain":["tilt","nearArm",[0.827411,0.646445,-0.664914,0.851052,98.0,126.0]],"path":[["M",-7,-3],["C",-8.5,7,-10.5,17,-7,24],["C",-3.5,30.5,5.5,30.5,8.5,24],["C",11,17,9,7,7,-3],["Z"]],"fill":null,"stroke":"#141A26","width":4},
   {"chain":["tilt","head"],"path":[["M",86,79],["L",70,72],["L",74,90],["Z"]],"fill":"team","stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"path":[["M",84,82],["Q",108,58,142,72]],"fill":null,"stroke":"#141A26","width":13,"cap":"butt"},
   {"chain":["tilt","head"],"path":[["M",84,82],["Q",108,58,142,72]],"fill":null,"stroke":"team","width":8,"cap":"butt"},
   {"chain":["tilt","head"],"path":[["M",107,101],["L",95,99],["M",107,104],["L",94,106],["M",108,107],["L",97,111],["M",132,100],["L",143,96],["M",132.5,103],["L",145,103],["M",132,106],["L",143,110]],"fill":null,"stroke":"#141A26","width":2},
   {"chain":["tilt","head"],"ellipse":[114,103,6.5,5],"fill":"#F4F7FA","stroke":"#141A26","width":2.5},
   {"chain":["tilt","head"],"ellipse":[125,102.5,6.5,5],"fill":"#F4F7FA","stroke":"#141A26","width":2.5},
   {"chain":["tilt","head"],"path":[["M",116,97],["L",123.5,97],["L",119.7,101.5],["Z"]],"fill":"#141A26","stroke":"#141A26","width":2},
   {"chain":["tilt","head"],"face":["idle"],"circle":[109,87,8],"fill":"#FFFFFF","stroke":"#141A26","width":2.5},
   {"chain":["tilt","head"],"face":["idle"],"circle":[128,86,7.3],"fill":"#FFFFFF","stroke":"#141A26","width":2.5},
   {"chain":["tilt","head"],"face":["idle"],"circle":[110.5,87.5,2.8],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["idle"],"circle":[129.2,86.5,2.6],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["atk"],"circle":[109,87,8],"fill":"#FFFFFF","stroke":"#141A26","width":2.5},
   {"chain":["tilt","head"],"face":["atk"],"circle":[128,86,7.3],"fill":"#FFFFFF","stroke":"#141A26","width":2.5},
   {"chain":["tilt","head"],"face":["atk"],"circle":[111.5,88,2.8],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["atk"],"circle":[130,87,2.6],"fill":"#141A26","stroke":null},
   {"chain":["tilt","head"],"face":["atk"],"path":[["M",101,78],["L",115,82],["M",123,81],["L",135,77]],"fill":null,"stroke":"#141A26","width":3},
   {"chain":["tilt","head"],"face":["atk","teeth"],"rect":[114,108,11.5,6.6,2.2],"fill":"#FFFFFF","stroke":"#141A26","width":2.2},
   {"chain":["tilt","head"],"face":["atk","teeth"],"path":[["M",114.5,111.3],["L",125,111.3],["M",118,108.6],["L",118,114],["M",121.6,108.6],["L",121.6,114]],"fill":null,"stroke":"#141A26","width":1.4},
   {"chain":["tilt","head"],"face":["win"],"path":[["M",102,90],["Q",109,80,116,90],["M",121.5,89],["Q",128,79.5,134.5,89]],"fill":null,"stroke":"#141A26","width":3.5},
   {"chain":["tilt","head"],"face":["win"],"path":[["M",114,108],["Q",119,116,124,108],["Z"]],"fill":"#141A26","stroke":"#141A26","width":2},
   {"chain":["tilt","head"],"face":["hit"],"path":[["M",102,81],["L",112,87],["L",102,93],["M",136,80],["L",126,86],["L",136,92]],"fill":null,"stroke":"#141A26","width":3.5},
   {"chain":["tilt","head"],"face":["hit"],"ellipse":[119,111,3,3.4],"fill":"#141A26","stroke":null}
  ]
 },
 "fx": {
  "shadow": {"cy":152,"ry":5,"fill":"#141A26","opacity":0.14},
  "sweat": [{"path":[["M",0,-7],["C",3.5,-1.5,4.6,1.6,4.6,3.4],["A",4.6,4.6,0,0,1,-4.6,3.4],["C",-4.6,1.6,-3.5,-1.5,0,-7],["Z"]],"fill":"#9FDCFF","stroke":"#141A26","width":2.2}],
  "shake": {"stroke":"#141A26","width":2.4},
  "spark": [{"path":[["M",0,-58],["L",0,-44],["M",0,44],["L",0,58],["M",-58,0],["L",-44,0],["M",44,0],["L",58,0],["M",-41,-41],["L",-31,-31],["M",41,41],["L",31,31],["M",41,-41],["L",31,-31],["M",-41,41],["L",-31,31]],"fill":null,"stroke":"#141A26","width":3.2}],
  "dust": [{"circle":[-44,146,7],"fill":"#FFFFFF","stroke":"#141A26","width":2.2},{"circle":[-34,142,5],"fill":"#FFFFFF","stroke":"#141A26","width":2.2},{"circle":[44,146,7],"fill":"#FFFFFF","stroke":"#141A26","width":2.2},{"circle":[34,142,5],"fill":"#FFFFFF","stroke":"#141A26","width":2.2}],
  "star": [{"chain":[[1,0,0,1,-12.0,-12.0]],"path":[["M",12,2.5],["L",14.9,8.6],["L",21.5,9.4],["L",16.6,14],["L",17.9,20.6],["L",12,17.3],["L",6.1,20.6],["L",7.4,14],["L",2.5,9.4],["L",9.1,8.6],["Z"]],"fill":"#FFB547","stroke":"#141A26","width":2}],
  "trail": {"stroke":"#FFB547","width":5,"opacity":0.7}
 }
}
''';
