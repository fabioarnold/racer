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
    pos: { x: -44.40104675292969, y: 1.721134901046753, z: -1.3928852081298828 },
    left_handle: { x: 0.09521102905273438, y: 0.0, z: -12.897957801818848 },
    right_handle: { x: -0.08200836181640625, y: 0.0, z: 11.109437942504883 },
    tilt: 0.4923742711544037,
  },
  {
    pos: { x: -22.16115951538086, y: 0.0, z: 25.05327796936035 },
    left_handle: { x: -10.459827423095703, y: 0.0, z: -0.12156295776367188 },
    right_handle: { x: 11.108991622924805, y: 0.0, z: 0.1291065216064453 },
    tilt: 0.0,
  },
  {
    pos: { x: -0.13704636693000793, y: 0.0, z: 18.279998779296875 },
    left_handle: { x: -9.759026527404785, y: 0.0, z: 0.015380859375 },
    right_handle: { x: 10.364692687988281, y: 0.0, z: -0.01633453369140625 },
    tilt: 0.0,
  },
  {
    pos: { x: 25.252986907958984, y: 0.0, z: 25.312191009521484 },
    left_handle: { x: -10.450516700744629, y: 0.0, z: -0.17721176147460938 },
    right_handle: { x: 10.576545715332031, y: 0.0, z: 0.17934799194335938 },
    tilt: 0.0,
  },
  {
    pos: { x: 39.60963821411133, y: 1.8524237871170044, z: -1.0046038627624512 },
    left_handle: { x: 0.18136978149414062, y: 0.0, z: 8.81155776977539 },
    right_handle: { x: -0.21197891235351562, y: 0.0, z: -10.298568725585938 },
    tilt: 0.7031676769256592,
  },
  {
    pos: { x: 21.150728225708008, y: 0.0, z: -22.470476150512695 },
    left_handle: { x: 9.56886100769043, y: 0.0, z: 0.0577392578125 },
    right_handle: { x: -10.55300235748291, y: 0.0, z: -0.06367683410644531 },
    tilt: 0.0,
  },
  {
    pos: { x: -0.24440056085586548, y: 4.444904804229736, z: -22.27613067626953 },
    left_handle: { x: 7.496023178100586, y: 0.0, z: -0.1460742950439453 },
    right_handle: { x: -8.729326248168945, y: 0.0, z: 0.1701068878173828 },
    tilt: 0.0,
  },
  {
    pos: { x: -24.074430465698242, y: 0.0, z: -21.877046585083008 },
    left_handle: { x: 11.414963722229004, y: 0.0, z: -0.07281494140625 },
    right_handle: { x: -14.097784042358398, y: 0.0, z: 0.08992767333984375 },
    tilt: 0.0,
  },
];

canvas.addEventListener("click", function (e) {
  const x = e.offsetX;
  const y = e.offsetY;

  const [u, v] = reverseBilinearInterpolate(x, y, points[0], points[1], points[3], points[2]);

  sliderU.value = u;
  sliderU.dispatchEvent(new Event("input"));
  sliderV.value = v;
  sliderV.dispatchEvent(new Event("input"));
});

function drawTrack() {
  ctx.translate(900, 400);
  ctx.scale(12, 12);

  ctx.beginPath();
  ctx.moveTo(track_data[0].pos.x, track_data[0].pos.z);
  for (let i = 0; i < track_data.length; i++) {
    const i2 = (i + 1) % track_data.length;
    const cp1 = add(track_data[i].pos, track_data[i].right_handle);
    const cp2 = add(track_data[i2].pos, track_data[i2].left_handle);
    const p = track_data[i2].pos;

    ctx.bezierCurveTo(cp1.x, cp1.z, cp2.x, cp2.z, p.x, p.z);
  }
  ctx.resetTransform();
  ctx.stroke();
}

function add(p1, p2) {
  return { x: p1.x + p2.x, y: p1.y + p2.y, z: p1.z + p2.z };
}

function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

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

function calculateTriangleArea(p0, p1, p2) {
  return Math.abs((p0.x * (p1.y - p2.y) + p1.x * (p2.y - p0.y) + p2.x * (p0.y - p1.y)) / 2);
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

setInterval(draw, 1000 / 60);
