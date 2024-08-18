var canvas = document.getElementById("canvas");
var ctx = canvas.getContext("2d");

const sliderU = document.getElementById("sliderU");
const sliderV = document.getElementById("sliderV");

const points = [
  { x: 200, y: 100 },
  { x: 500, y: 150 },
  { x: 100, y: 500 },
  { x: 600, y: 450 },
];

const track_data = [
  {
    pos: { x: -44.40104675292969, y: -1.3928852081298828, z: 1.721134901046753 },
    left_handle: { x: 0.09521102905273438, y: -12.897957801818848, z: 0.0 },
    right_handle: { x: -0.08200836181640625, y: 11.109437942504883, z: 0.0 },
    tilt: 0.4923742711544037,
  },
  {
    pos: { x: -22.16115951538086, y: 25.05327796936035, z: 0.0 },
    left_handle: { x: -10.459827423095703, y: -0.12156295776367188, z: 0.0 },
    right_handle: { x: 11.108991622924805, y: 0.1291065216064453, z: 0.0 },
    tilt: 0.0,
  },
  {
    pos: { x: -0.13704636693000793, y: 18.279998779296875, z: 0.0 },
    left_handle: { x: -9.759026527404785, y: 0.015380859375, z: 0.0 },
    right_handle: { x: 10.364692687988281, y: -0.01633453369140625, z: 0.0 },
    tilt: 0.0,
  },
  {
    pos: { x: 25.252986907958984, y: 25.312191009521484, z: 0.0 },
    left_handle: { x: -10.450516700744629, y: -0.17721176147460938, z: 0.0 },
    right_handle: { x: 10.576545715332031, y: 0.17934799194335938, z: 0.0 },
    tilt: 0.0,
  },
  {
    pos: { x: 39.60963821411133, y: -1.0046038627624512, z: 1.8524237871170044 },
    left_handle: { x: 0.18136978149414062, y: 8.81155776977539, z: 0.0 },
    right_handle: { x: -0.21197891235351562, y: -10.298568725585938, z: 0.0 },
    tilt: 0.7031676769256592,
  },
  {
    pos: { x: 21.150728225708008, y: -22.470476150512695, z: 0.0 },
    left_handle: { x: 9.56886100769043, y: 0.0577392578125, z: 0.0 },
    right_handle: { x: -10.55300235748291, y: -0.06367683410644531, z: 0.0 },
    tilt: 0.0,
  },
  {
    pos: { x: -0.24440056085586548, y: -22.27613067626953, z: 4.444904804229736 },
    left_handle: { x: 7.496023178100586, y: -0.1460742950439453, z: 0.0 },
    right_handle: { x: -8.729326248168945, y: 0.1701068878173828, z: 0.0 },
    tilt: 0.0,
  },
  {
    pos: { x: -24.074430465698242, y: -21.877046585083008, z: 0.0 },
    left_handle: { x: 11.414963722229004, y: -0.07281494140625, z: 0.0 },
    right_handle: { x: -14.097784042358398, y: 0.08992767333984375, z: 0.0 },
    tilt: 0.0,
  },
];

let track = undefined;
function initTrack() {
  // transform track data coordinates
  for (let n = 0; n < track_data.length; n++) {
    const node = track_data[n];
    track_data[n].pos = add(scale(node.pos, 12), { x: 900, y: 400, z: 0 });
    track_data[n].left_handle = scale(node.left_handle, 12);
    track_data[n].right_handle = scale(node.right_handle, 12);
  }

  track = { segments: [] };
  for (let n = 0; n < track_data.length; n++) {
    const segment = { quads: [] };
    const points = evaluateTrackSegment(track_data[n], track_data[(n + 1) % track_data.length], 60);
    for (let i = 0; i < points.length - 3; i += 2) {
      const p1 = points[i];
      const p2 = points[i + 1];
      const p3 = points[i + 3];
      const p4 = points[i + 2];
      segment.quads.push([p1, p2, p3, p4]);
    }
    track.segments.push(segment);
  }

  // const pq = track.segments[player.segment].quads[player.quad];
  // player.pos = scale(add(add(pq[0], pq[1]), add(pq[2], pq[3])), 0.25);
}

canvas.addEventListener("mousedown", function (e) {
  const x = e.offsetX;
  const y = e.offsetY;

  return;
  playerSlideMove(player.dir);

  player.dir.x = x - player.pos.x;
  player.dir.y = y - player.pos.y;
});

canvas.addEventListener("mousemove", function (e) {
  const x = e.offsetX;
  const y = e.offsetY;

  return;
  player.dir.x = x - player.pos.x;
  player.dir.y = y - player.pos.y;

  return;
  const [u, v] = reverseBilinearInterpolate(x, y, points[0], points[1], points[3], points[2]);

  sliderU.value = u;
  sliderU.dispatchEvent(new Event("input"));
  sliderV.value = v;
  sliderV.dispatchEvent(new Event("input"));
});

let keys = [];
window.addEventListener("keydown", function (e) {
  keys[e.key] = true;
});
window.addEventListener("keyup", function (e) {
  keys[e.key] = false;
});

let player = {
  pos: { x: 0, y: 0 },
  dir: { x: 0, y: 0 },
  angle: 0,
  speed: 0,
  segment: 0,
  quad: 0,
};

function pointInQuad(p, p1, p2, p3, p4) {
  const A = calculateTriangleArea(p1, p2, p3) + calculateTriangleArea(p1, p3, p4);
  const A1 = calculateTriangleArea(p, p1, p2);
  const A2 = calculateTriangleArea(p, p2, p3);
  const A3 = calculateTriangleArea(p, p3, p4);
  const A4 = calculateTriangleArea(p, p4, p1);
  return Math.abs(A - (A1 + A2 + A3 + A4)) < 1e-6;
}

function drawTrack() {
  // draw bezier curves
  ctx.beginPath();
  ctx.moveTo(track_data[0].pos.x, track_data[0].pos.y);
  for (let i = 0; i < track_data.length; i++) {
    const i2 = (i + 1) % track_data.length;
    const cp1 = add(track_data[i].pos, track_data[i].right_handle);
    const cp2 = add(track_data[i2].pos, track_data[i2].left_handle);
    const p = track_data[i2].pos;

    ctx.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, p.x, p.y);
  }

  for (let n = 0; n < track.segments.length; n++) {
    const segment = track.segments[n];
    for (let i = 0; i < segment.quads.length; i++) {
      const quad = segment.quads[i];
      ctx.moveTo(quad[0].x, quad[0].y);
      ctx.lineTo(quad[1].x, quad[1].y);
      ctx.lineTo(quad[2].x, quad[2].y);
      ctx.moveTo(quad[0].x, quad[0].y);
      ctx.lineTo(quad[3].x, quad[3].y);
    }
  }
  ctx.strokeStyle = "black";
  ctx.stroke();

  ctx.beginPath();
  ctx.arc(player.pos.x, player.pos.y, 5, 0, Math.PI * 2);
  ctx.fillStyle = "red";

  const player_quad = track.segments[player.segment].quads[player.quad];
  if (pointInQuad(player.pos, ...player_quad)) {
    ctx.moveTo(player_quad[0].x, player_quad[0].y);
    ctx.lineTo(player_quad[1].x, player_quad[1].y);
    ctx.lineTo(player_quad[2].x, player_quad[2].y);
    ctx.lineTo(player_quad[3].x, player_quad[3].y);
    ctx.closePath();
    ctx.fillStyle = "rgba(0,0,255,0.5)";
  }
  ctx.fill();

  // visualize direction
  let hit = add(player.pos, player.dir);
  ctx.beginPath();
  ctx.moveTo(player.pos.x, player.pos.y);
  ctx.lineTo(hit.x, hit.y);
  ctx.strokeStyle = "red";
  ctx.stroke();
}

function playerSnapToQuad(quad) {
  for (let i = 0; i < 4; i++) {
    let normal = subtract(quad[(i + 1) % 4], quad[i]);
    normal = normalize({ x: normal.y, y: -normal.x });
    const d = subtract(player.pos, quad[i]);
    const dot = d.x * normal.x + d.y * normal.y;
    if (dot < 0.01) {
      player.pos = add(player.pos, scale(normal, -dot + 0.01));
    }
  }
}

function playerSlideMove(move) {
  const segment = track.segments[player.segment];
  const quad = segment.quads[player.quad];

  playerSnapToQuad(quad);

  let move_forward = false; // are we moving to the next or previous quad
  let t = 1e6;
  const t_forward = intersectRayLine(player.pos, move, quad[2], quad[3]);
  if (t_forward) {
    move_forward = true;
    t = t_forward;
  } else {
    t_back = intersectRayLine(player.pos, move, quad[0], quad[1]);
    if (t_back) {
      move_forward = false;
      t = t_back;
    }
  }

  t_left = intersectRayLine(player.pos, move, quad[3], quad[0]);
  if (t_left && t_left < t) {
    t = t_left;
    const step = scale(move, Math.min(1, t));
    player.pos = add(player.pos, step);
    if (t < 1) {
      move = subtract(move, step);

      // clip move by normal
      let normal = subtract(quad[0], quad[3]);
      normal = normalize({ x: normal.y, y: -normal.x });
      const dot = normal.x * move.x + normal.y * move.y;
      move = subtract(move, scale(normal, dot));
      playerSlideMove(move);
    }
    return;
  }

  t_right = intersectRayLine(player.pos, move, quad[1], quad[2]);
  if (t_right && t_right < t) {
    t = t_right;
    const step = scale(move, Math.min(1, t));
    player.pos = add(player.pos, step);
    if (t < 1) {
      move = subtract(move, step);

      // clip move by normal
      let normal = subtract(quad[2], quad[1]);
      normal = normalize({ x: normal.y, y: -normal.x });
      const dot = normal.x * move.x + normal.y * move.y;
      move = subtract(move, scale(normal, dot));
      playerSlideMove(move);
    }
    return;
  }

  const step = scale(move, Math.min(1, t));
  player.pos = add(player.pos, step);

  if (t < 1) {
    // go to next/previous quad
    if (move_forward) {
      player.quad++;
      if (player.quad == segment.quads.length) {
        player.quad = 0;
        player.segment++;
        if (player.segment == track.segments.length) {
          player.segment = 0;
        }
      }
    } else {
      player.quad--;
      if (player.quad == -1) {
        player.quad = segment.quads.length - 1;
        player.segment--;
        if (player.segment == -1) {
          player.segment = track.segments.length - 1;
        }
      }
    }

    move = subtract(move, step);
    playerSlideMove(move);
  }
}

function intersectRayLine(ro, rd, l1, l2) {
  const v1 = subtract(l1, ro);
  const v2 = subtract(l2, l1);

  const denom = rd.x * v2.y - rd.y * v2.x;

  if (Math.abs(denom) < 0.0001) {
    return null; // parallel
  }

  const t = (v1.x * v2.y - v1.y * v2.x) / denom;
  if (t < 0.0001) {
    return null; // behind
  }

  return t;
}

function interpolateCubic(p1, c1, c2, p2, t) {
  const a = Math.pow(1.0 - t, 3);
  const b = 3.0 * Math.pow(1.0 - t, 2) * t;
  const c = 3.0 * (1.0 - t) * Math.pow(t, 2);
  const d = Math.pow(t, 3);
  return add(scale(p1, a), add(scale(c1, b), add(scale(c2, c), scale(p2, d))));
}

function evaluateTrackSegment(node1, node2, thick) {
  const SPLINE_SEGMENT_DIVISIONS = 4;
  const points = [];

  const p1 = node1.pos;
  const c2 = add(node1.pos, node1.right_handle);
  const c3 = add(node2.pos, node2.left_handle);
  const p4 = node2.pos;

  for (let i = 0; i <= SPLINE_SEGMENT_DIVISIONS; i++) {
    const t = i / SPLINE_SEGMENT_DIVISIONS;
    const pos = interpolateCubic(p1, c2, c3, p4, t);
    let dir = undefined;
    if (i === 0) {
      dir = normalize(node1.right_handle);
    } else if (i === SPLINE_SEGMENT_DIVISIONS) {
      dir = normalize(node2.right_handle);
    } else {
      const next_pos = interpolateCubic(p1, c2, c3, p4, t + 0.01);
      dir = normalize(subtract(next_pos, pos));
    }

    const side = { x: dir.y, y: -dir.x, z: 0 };

    points.push(add(pos, scale(side, thick)));
    points.push(add(pos, scale(side, -thick)));

    prev_pos = pos;
  }

  return points;
}

function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  if (keys["ArrowUp"]) player.speed += 1;
  if (keys["ArrowDown"]) player.speed -= 1;
  if (keys["ArrowLeft"]) player.angle -= 0.04;
  if (keys["ArrowRight"]) player.angle += 0.04;

  player.dir.x = Math.cos(player.angle) * player.speed;
  player.dir.y = Math.sin(player.angle) * player.speed;
  playerSlideMove(scale(player.dir, 1.0 / 60.0));

  drawTrack();

  const drawBilinearTest = false;
  if (drawBilinearTest) {
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    ctx.lineTo(points[1].x, points[1].y);
    ctx.lineTo(points[3].x, points[3].y);
    ctx.lineTo(points[2].x, points[2].y);
    ctx.closePath();
    ctx.stroke();

    const u = Number(sliderU.value);
    const v = Number(sliderV.value);

    const u01 = lerp(points[0], points[1], u);
    const u23 = lerp(points[2], points[3], u);
    const v02 = lerp(points[0], points[2], v);
    const v13 = lerp(points[1], points[3], v);
    const p = lerp(u01, u23, v);

    ctx.beginPath();
    ctx.moveTo(u01.x, u01.y);
    ctx.lineTo(u23.x, u23.y);
    ctx.moveTo(v02.x, v02.y);
    ctx.lineTo(v13.x, v13.y);
    ctx.setLineDash([5, 5]);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.beginPath();
    ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
    ctx.fill();
  }
}

function lerp(p0, p1, t) {
  return {
    x: p0.x + (p1.x - p0.x) * t,
    y: p0.y + (p1.y - p0.y) * t,
  };
}

function add(p1, p2) {
  return { x: p1.x + p2.x, y: p1.y + p2.y };
}

function subtract(p1, p2) {
  return { x: p1.x - p2.x, y: p1.y - p2.y };
}

function scale(p, s) {
  return { x: p.x * s, y: p.y * s };
}

function normalize(p) {
  const len = Math.sqrt(p.x * p.x + p.y * p.y);
  return { x: p.x / len, y: p.y / len };
}

function calculateTriangleArea(p0, p1, p2) {
  return Math.max(0, (p0.x * (p1.y - p2.y) + p1.x * (p2.y - p0.y) + p2.x * (p0.y - p1.y)) / 2);
}

function reverseBilinearInterpolate(x, y, p1, p2, p3, p4, tol = 1e-6, maxIter = 100) {
  // Vertices of the quadrilateral
  const [x1, y1] = [p1.x, p1.y];
  const [x2, y2] = [p2.x, p2.y];
  const [x3, y3] = [p3.x, p3.y];
  const [x4, y4] = [p4.x, p4.y];

  // Initial guess for (u, v)
  let u = 0.5;
  let v = 0.5;

  // Iterative method
  for (let iter = 0; iter < maxIter; iter++) {
    // Calculate x(u, v) and y(u, v)
    const xu = (1 - u) * (1 - v) * x1 + u * (1 - v) * x2 + u * v * x3 + (1 - u) * v * x4;
    const yv = (1 - u) * (1 - v) * y1 + u * (1 - v) * y2 + u * v * y3 + (1 - u) * v * y4;

    // Calculate the difference
    const dx = xu - x;
    const dy = yv - y;

    // Check if the difference is within the tolerance
    if (Math.abs(dx) < tol && Math.abs(dy) < tol) {
      return [u, v];
    }

    // Calculate partial derivatives
    const dxdu = (1 - v) * (x2 - x1) + v * (x3 - x4);
    const dxdv = (1 - u) * (x4 - x1) + u * (x3 - x2);
    const dydu = (1 - v) * (y2 - y1) + v * (y3 - y4);
    const dydv = (1 - u) * (y4 - y1) + u * (y3 - y2);

    // Jacobian matrix determinant
    const detJ = dxdu * dydv - dxdv * dydu;

    if (Math.abs(detJ) < tol) {
      throw new Error("Jacobian determinant is too small, the method may not converge.");
    }

    // Newton-Raphson step
    const du = (dydv * dx - dxdv * dy) / detJ;
    const dv = (dxdu * dy - dydu * dx) / detJ;

    u -= du;
    v -= dv;

    // Clamp u and v to [0, 1] to stay within bounds
    u = Math.min(Math.max(u, 0), 1);
    v = Math.min(Math.max(v, 0), 1);
  }

  throw new Error("Maximum iterations exceeded, the method did not converge.");
}

initTrack();
setInterval(draw, 1000 / 60);
