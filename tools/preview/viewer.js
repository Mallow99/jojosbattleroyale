// Browser preview of exported Roblox part geometry and cutscene frame states.
// Approximates Roblox shading; it is a visual check of geometry/timing, not the Roblox engine.
import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

const SRGB = THREE.SRGBColorSpace;

// Lune encodes empty tables as {}; treat anything that is not an array as empty.
const arr = (x) => (Array.isArray(x) ? x : []);

function rgb(c) {
  return new THREE.Color().setRGB(c[0], c[1], c[2], SRGB);
}

function matrixFrom(cf) {
  const m = new THREE.Matrix4();
  m.set(cf[3], cf[4], cf[5], cf[0], cf[6], cf[7], cf[8], cf[1], cf[9], cf[10], cf[11], cf[2], 0, 0, 0, 1);
  return m;
}

function wedgeGeometry(sx, sy, sz) {
  const x = sx / 2, y = sy / 2, z = sz / 2;
  // Roblox WedgePart: full bottom and back faces; slope from top-back to bottom-front.
  const v = {
    lbf: [-x, -y, -z], rbf: [x, -y, -z], lbb: [-x, -y, z], rbb: [x, -y, z], ltb: [-x, y, z], rtb: [x, y, z],
  };
  const tris = [
    [v.lbf, v.rbf, v.rbb], [v.lbf, v.rbb, v.lbb], // bottom
    [v.lbb, v.rbb, v.rtb], [v.lbb, v.rtb, v.ltb], // back
    [v.lbf, v.ltb, v.rtb], [v.lbf, v.rtb, v.rbf], // slope
    [v.lbf, v.lbb, v.ltb], // left
    [v.rbf, v.rtb, v.rbb], // right
  ];
  const positions = [];
  for (const t of tris) for (const p of t) positions.push(...p);
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3));
  g.computeVertexNormals();
  return g;
}

// Classic Roblox R6 head: a cylinder with rounded top and bottom, ~1.25 studs across.
function headGeometry() {
  const points = [];
  const r = 0.6, h = 0.6, bevel = 0.22;
  points.push(new THREE.Vector2(0, -h));
  for (let i = 0; i <= 8; i++) {
    const a = (Math.PI / 2) * (i / 8);
    points.push(new THREE.Vector2(r - bevel + Math.sin(a) * bevel, -h + bevel - Math.cos(a) * bevel));
  }
  for (let i = 0; i <= 8; i++) {
    const a = (Math.PI / 2) * (i / 8);
    points.push(new THREE.Vector2(r - bevel + Math.cos(a) * bevel, h - bevel + Math.sin(a) * bevel));
  }
  points.push(new THREE.Vector2(0, h));
  return new THREE.LatheGeometry(points, 40);
}

function faceDecalTexture() {
  // Stand-in for Roblox's default face (rbxasset://textures/face.png).
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = 256;
  const c = canvas.getContext("2d");
  c.fillStyle = "#111";
  c.beginPath(); c.ellipse(92, 100, 12, 22, 0, 0, Math.PI * 2); c.fill();
  c.beginPath(); c.ellipse(164, 100, 12, 22, 0, 0, Math.PI * 2); c.fill();
  c.lineWidth = 10; c.lineCap = "round"; c.strokeStyle = "#111";
  c.beginPath(); c.arc(128, 128, 56, 0.2 * Math.PI, 0.8 * Math.PI); c.stroke();
  const t = new THREE.CanvasTexture(canvas);
  t.colorSpace = SRGB;
  return t;
}

function geometryFor(part) {
  const [sx, sy, sz] = part.size;
  if (part.shape === "Head") return headGeometry();
  if (part.shape === "Wedge") return wedgeGeometry(sx, sy, sz);
  if (part.shape === "Cylinder") {
    const g = new THREE.CylinderGeometry(Math.min(sy, sz) / 2, Math.min(sy, sz) / 2, sx, 40);
    g.rotateZ(-Math.PI / 2);
    return g;
  }
  if (part.shape === "Ball") return new THREE.SphereGeometry(Math.min(sx, sy, sz) / 2, 32, 16);
  return new THREE.BoxGeometry(sx, sy, sz);
}

function sampleSequence(keys, t) {
  if (!keys || keys.length === 0) return null;
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    if (t <= keys[i][0]) {
      const a = keys[i - 1], b = keys[i];
      const f = (t - a[0]) / Math.max(1e-6, b[0] - a[0]);
      if (Array.isArray(a[1])) return a[1].map((v, k) => v + (b[1][k] - v) * f);
      return a[1] + (b[1] - a[1]) * f;
    }
  }
  return keys[keys.length - 1][1];
}

function css(c, alpha = 1) {
  return `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${alpha})`;
}

const FONT_MAP = { Bangers: "Bangers", GothamBlack: "Inter", Antique: "serif" };

function drawGui(guiSpec, width, height) {
  const scale = 512 / Math.max(width, height);
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(8, Math.round(width * scale));
  canvas.height = Math.max(8, Math.round(height * scale));
  const ctx = canvas.getContext("2d");
  const W = canvas.width, H = canvas.height;
  const elements = [...arr(guiSpec.elements)].sort((a, b) => a.z - b.z);
  for (const e of elements) {
    const w = e.w * W, h = e.h * H;
    const cx = e.x * W + (0.5 - e.ax) * w, cy = e.y * H + (0.5 - e.ay) * h;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate((e.rotation * Math.PI) / 180);
    if (e.kind === "TextLabel") {
      const fontName = FONT_MAP[e.font] || "Inter";
      let size = h;
      ctx.font = `900 ${size}px ${fontName}`;
      const measured = ctx.measureText(e.text).width;
      if (measured > w) size *= w / measured;
      ctx.font = `900 ${size}px ${fontName}`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      if (e.textStroke > 0) {
        ctx.lineWidth = Math.max(1, size * 0.08);
        ctx.strokeStyle = `rgba(0,0,0,${e.textStroke})`;
        ctx.strokeText(e.text, 0, 0);
      }
      ctx.fillStyle = css(e.textColor);
      ctx.fillText(e.text, 0, 0);
    } else if (e.transparency < 1) {
      let fill = css(e.color, 1 - e.transparency);
      if (e.gradient) {
        const angle = (e.gradient.rotation * Math.PI) / 180;
        const dx = (Math.cos(angle) * w) / 2, dy = (Math.sin(angle) * h) / 2;
        const grad = ctx.createLinearGradient(-dx, -dy, dx, dy);
        for (let s = 0; s <= 16; s++) {
          const f = s / 16;
          const c = sampleSequence(e.gradient.color, f);
          const tr = sampleSequence(e.gradient.transparency, f) ?? 0;
          grad.addColorStop(f, css(c.map((v, k) => v * e.color[k]), (1 - e.transparency) * (1 - tr)));
        }
        fill = grad;
      }
      ctx.fillStyle = fill;
      ctx.beginPath();
      const r = e.round ? Math.min(w, h) * e.round : 0;
      ctx.roundRect(-w / 2, -h / 2, w, h, r);
      ctx.fill();
    }
    ctx.restore();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = SRGB;
  texture.anisotropy = 4;
  return texture;
}

function guiPlane(part, guiSpec) {
  const [sx, sy, sz] = part.size;
  const faces = {
    Front: { w: sx, h: sy, rot: [0, Math.PI, 0], pos: [0, 0, -sz / 2 - 0.003] },
    Back: { w: sx, h: sy, rot: [0, 0, 0], pos: [0, 0, sz / 2 + 0.003] },
    Right: { w: sz, h: sy, rot: [0, Math.PI / 2, 0], pos: [sx / 2 + 0.003, 0, 0] },
    Left: { w: sz, h: sy, rot: [0, -Math.PI / 2, 0], pos: [-sx / 2 - 0.003, 0, 0] },
    Top: { w: sx, h: sz, rot: [-Math.PI / 2, 0, 0], pos: [0, sy / 2 + 0.003, 0] },
    Bottom: { w: sx, h: sz, rot: [Math.PI / 2, 0, 0], pos: [0, -sy / 2 - 0.003, 0] },
  };
  const f = faces[guiSpec.face];
  const material = new THREE.MeshStandardMaterial({
    map: drawGui(guiSpec, f.w, f.h), transparent: true, roughness: 0.7, depthWrite: false,
    polygonOffset: true, polygonOffsetFactor: -2,
  });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(f.w, f.h), material);
  mesh.rotation.set(...f.rot);
  mesh.position.set(...f.pos);
  return mesh;
}

export class Preview {
  constructor(container, scene, options = {}) {
    this.data = scene;
    this.width = options.width || 1280;
    this.height = options.height || 720;
    this.renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    this.renderer.setSize(this.width, this.height);
    this.renderer.outputColorSpace = SRGB;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.15;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene();
    this.scene.background = rgb(scene.sky || [0.55, 0.7, 0.92]);
    this.scene.fog = new THREE.Fog(this.scene.background, 120, 400);
    const hemi = new THREE.HemisphereLight(0xdfe8ff, 0x6a5c50, 1.6);
    this.scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xfff1dc, 2.6);
    const sunDir = scene.sunDirection || [-0.45, 0.8, -0.4];
    sun.position.set(sunDir[0] * 60, sunDir[1] * 60, sunDir[2] * 60);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.left = -25; sun.shadow.camera.right = 25;
    sun.shadow.camera.top = 25; sun.shadow.camera.bottom = -25;
    sun.shadow.bias = -0.0005;
    this.scene.add(sun);
    this.scene.add(sun.target);
    this.sun = sun;

    this.camera = new THREE.PerspectiveCamera(70, this.width / this.height, 0.1, 1000);
    this.parts = [];
    for (const part of scene.parts) {
      const transparency = part.transparency;
      if (transparency >= 1 && arr(part.guis).length === 0) continue;
      const neon = part.material === "Neon";
      const material = neon
        ? new THREE.MeshBasicMaterial({ color: rgb(part.color).multiplyScalar(1.6), transparent: true })
        : new THREE.MeshStandardMaterial({
            color: rgb(part.color), roughness: part.material === "Metal" ? 0.38 : part.reflectance > 0 ? 0.35 : 0.62,
            metalness: part.material === "Metal" ? 0.55 : part.reflectance > 0 ? 0.45 : 0.0, transparent: true,
          });
      material.opacity = 1 - transparency;
      let geometry;
      if (part.shape === "Mesh") {
        const node = options.meshes && options.meshes[part.mesh];
        if (!node) continue;
        geometry = node.geometry.clone();
        const c = part.meshCenter || [0, 0, 0];
        geometry.translate(-c[0], -c[1], -c[2]);
        if (part.textured && node.material && node.material.map) {
          material.map = node.material.map;
          material.color.setRGB(1, 1, 1);
        } else if (node.material) {
          material.color = rgb(part.color);
        }
      } else {
        geometry = geometryFor(part);
      }
      const mesh = new THREE.Mesh(geometry, material);
      mesh.castShadow = transparency < 0.5 && !neon;
      mesh.receiveShadow = true;
      mesh.matrixAutoUpdate = false;
      mesh.visible = transparency < 1;
      const guis = arr(part.guis).map((g) => guiPlane(part, g));
      for (const d of arr(part.decals)) {
        const plane = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.9),
          new THREE.MeshStandardMaterial({ map: faceDecalTexture(), transparent: true, depthWrite: false, roughness: 0.8 }));
        plane.rotation.set(0, Math.PI, 0);
        plane.position.set(0, 0, -0.605);
        guis.push(plane);
      }
      const holder = new THREE.Group();
      holder.matrixAutoUpdate = false;
      holder.add(mesh);
      // GUI planes follow the part transform.
      for (const g of guis) {
        g.updateMatrix();
        g.matrixAutoUpdate = false;
        holder.add(g);
      }
      mesh.matrix.identity();
      this.scene.add(holder);
      this.parts.push({ spec: part, holder, mesh, guis, offset: matrixFrom(part.offset), base: 1 - transparency });
    }
    this.fx = new FxLayer(this.scene);
    this.overlay = options.overlay;
  }

  setFrame(frame) {
    const actors = frame.actors || {};
    const bone = new THREE.Matrix4();
    for (const p of this.parts) {
      const actor = actors[p.spec.actor];
      if (p.spec.bone === "World") {
        p.holder.matrix.copy(p.offset);
      } else {
        if (!actor || !actor.bones[p.spec.bone]) { p.holder.visible = false; continue; }
        bone.copy(matrixFrom(actor.bones[p.spec.bone]));
        p.holder.matrix.multiplyMatrices(bone, p.offset);
      }
      const visibility = actor ? actor.visibility ?? 1 : 1;
      p.holder.visible = visibility > 0.001;
      p.mesh.material.opacity = p.base * visibility;
      p.mesh.material.depthWrite = visibility > 0.95;
      const glow = actor ? actor.glow || 0 : 0;
      if (p.mesh.material.emissive) p.mesh.material.emissive.setRGB(0.55 * glow, 0.35 * glow, 1.0 * glow);
      for (const g of p.guis) g.material.opacity = visibility;
      p.holder.matrixWorldNeedsUpdate = true;
    }
    const cam = matrixFrom(frame.camera);
    this.camera.matrixAutoUpdate = false;
    this.camera.matrix.copy(cam);
    this.camera.matrixWorldNeedsUpdate = true;
    this.camera.fov = frame.fov || 70;
    this.camera.updateProjectionMatrix();
    const focus = frame.focus || [0, 3, 0];
    this.sun.target.position.set(focus[0], focus[1], focus[2]);
    const sd = this.data.sunDirection || [-0.45, 0.8, -0.4];
    this.sun.position.set(focus[0] + sd[0] * 60, focus[1] + sd[1] * 60, focus[2] + sd[2] * 60);
    this.fx.update(frame);
    if (this.overlay) this.overlay(frame);
    this.renderer.render(this.scene, this.camera);
  }
}

// Effects approximations (Roblox uses ParticleEmitters/Neon parts driven by the same state).
class FxLayer {
  constructor(scene) {
    this.group = new THREE.Group();
    scene.add(this.group);
    this.rings = [];
    const sprite = document.createElement("canvas");
    sprite.width = sprite.height = 64;
    const c = sprite.getContext("2d");
    const g = c.createRadialGradient(32, 32, 0, 32, 32, 32);
    g.addColorStop(0, "rgba(255,255,255,1)");
    g.addColorStop(0.3, "rgba(255,255,255,0.6)");
    g.addColorStop(1, "rgba(255,255,255,0)");
    c.fillStyle = g;
    c.fillRect(0, 0, 64, 64);
    this.spriteTexture = new THREE.CanvasTexture(sprite);
    this.maxParticles = 600;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(new Float32Array(this.maxParticles * 3), 3));
    geo.setAttribute("color", new THREE.Float32BufferAttribute(new Float32Array(this.maxParticles * 3), 3));
    this.points = new THREE.Points(geo, new THREE.PointsMaterial({
      size: 0.35, map: this.spriteTexture, vertexColors: true, transparent: true,
      blending: THREE.AdditiveBlending, depthWrite: false,
    }));
    this.points.frustumCulled = false;
    this.group.add(this.points);
  }

  ring(i) {
    if (!this.rings[i]) {
      const mesh = new THREE.Mesh(
        new THREE.TorusGeometry(1, 0.06, 8, 64),
        new THREE.MeshBasicMaterial({ color: 0xc8a0ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }),
      );
      this.group.add(mesh);
      this.rings[i] = mesh;
    }
    return this.rings[i];
  }

  update(frame) {
    const fx = frame.fx || {};
    arr(fx.rings).forEach((r, i) => {
      const mesh = this.ring(i);
      mesh.visible = r.alpha > 0.01;
      mesh.matrixAutoUpdate = false;
      const m = matrixFrom(r.cframe);
      const s = new THREE.Matrix4().makeScale(r.radius, r.radius, r.radius * 1.5);
      const rot = new THREE.Matrix4().makeRotationX(Math.PI / 2);
      mesh.matrix.multiplyMatrices(m, rot).multiply(s);
      mesh.material.opacity = r.alpha;
      mesh.material.color = rgb(r.color || [0.8, 0.65, 1]);
    });
    for (let i = arr(fx.rings).length; i < this.rings.length; i++) this.rings[i].visible = false;
    const pos = this.points.geometry.attributes.position;
    const col = this.points.geometry.attributes.color;
    let n = 0;
    for (const emitter of arr(fx.particles)) {
      for (const p of arr(emitter.points)) {
        if (n >= this.maxParticles) break;
        pos.setXYZ(n, p[0], p[1], p[2]);
        col.setXYZ(n, p[3], p[4], p[5]);
        n++;
      }
    }
    for (let i = n; i < this.maxParticles; i++) pos.setXYZ(i, 0, -1000, 0);
    pos.needsUpdate = true;
    col.needsUpdate = true;
  }
}
