/**
 * CS_Origami3D - Three.js WebGL Live 3D Viewport
 * Renderização PBR em tempo real para volumetria e facetação de ACM
 */

class Origami3DViewer {
  constructor(containerId) {
    this.container = document.getElementById(containerId);
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.controls = null;
    this.mesh = null;
    this.wireframe = null;
    this.foldLinesGroup = null;
    this.sunLight = null;

    this.currentMaterialKey = 'red_glossy';
    this.showFoldLines = true;

    this.init();
  }

  init() {
    const width = this.container.clientWidth || 500;
    const height = this.container.clientHeight || 500;

    // 1. Cena
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x0f172a); // Dark slate

    // 2. Câmera
    this.camera = new THREE.PerspectiveCamera(45, width / height, 10, 10000);
    this.camera.position.set(600, 800, 1200);

    // 3. Renderizador WebGL
    this.renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    this.renderer.setSize(width, height);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.1;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    this.container.appendChild(this.renderer.domElement);

    // 4. OrbitControls
    if (typeof THREE.OrbitControls !== 'undefined') {
      this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
      this.controls.enableDamping = true;
      this.controls.dampingFactor = 0.08;
      this.controls.maxDistance = 6000;
      this.controls.minDistance = 100;
    }

    // 5. Iluminação PBR de Estúdio para Facetas
    this.setupLighting();

    // 6. Grid auxiliar de piso
    const grid = new THREE.GridHelper(2000, 20, 0x334155, 0x1e293b);
    grid.rotation.x = Math.PI / 2; // Plano XY
    grid.position.z = -5;
    this.scene.add(grid);

    // 7. Grupo de linhas de vinco
    this.foldLinesGroup = new THREE.Group();
    this.scene.add(this.foldLinesGroup);

    // 8. Evento de redimensionamento
    window.addEventListener('resize', () => this.onResize());

    // 9. Loop de animação
    this.animate();
  }

  setupLighting() {
    // Luz ambiente suave
    const ambient = new THREE.AmbientLight(0xffffff, 0.45);
    this.scene.add(ambient);

    // Luz solar direta orbitável (simula a incidência de luz na fachada)
    this.sunLight = new THREE.DirectionalLight(0xffffff, 1.2);
    this.sunLight.position.set(500, 800, 1000);
    this.sunLight.castShadow = true;
    // A câmera de sombra padrão cobre só ±5 unidades; a cena está em mm (blocos de até ~2 m)
    const shadowCam = this.sunLight.shadow.camera;
    shadowCam.left = shadowCam.bottom = -1500;
    shadowCam.right = shadowCam.top = 1500;
    shadowCam.near = 10;
    shadowCam.far = 5000;
    this.sunLight.shadow.mapSize.set(2048, 2048);
    this.sunLight.shadow.bias = -0.0005;
    this.scene.add(this.sunLight);

    // Luz de preenchimento (Fill light)
    const fillLight = new THREE.DirectionalLight(0x93c5fd, 0.4);
    fillLight.position.set(-600, -400, 400);
    this.scene.add(fillLight);
  }

  // Criados uma única vez: recriar a cada atualização vazava materiais na GPU
  getMaterials() {
    if (this.materials) return this.materials;
    this.materials = {
      red_glossy: new THREE.MeshStandardMaterial({
        color: 0xDC2626,
        roughness: 0.18,
        metalness: 0.45,
        side: THREE.DoubleSide
      }),
      silver_metallic: new THREE.MeshStandardMaterial({
        color: 0xE2E8F0,
        roughness: 0.25,
        metalness: 0.85,
        side: THREE.DoubleSide
      }),
      charcoal_titanium: new THREE.MeshStandardMaterial({
        color: 0x334155,
        roughness: 0.35,
        metalness: 0.70,
        side: THREE.DoubleSide
      }),
      gold_champagne: new THREE.MeshStandardMaterial({
        color: 0xD97706,
        roughness: 0.28,
        metalness: 0.75,
        side: THREE.DoubleSide
      }),
      black_matte: new THREE.MeshStandardMaterial({
        color: 0x1E293B,
        roughness: 0.85,
        metalness: 0.15,
        side: THREE.DoubleSide
      }),
      pure_white: new THREE.MeshStandardMaterial({
        color: 0xF8FAFC,
        roughness: 0.30,
        metalness: 0.10,
        side: THREE.DoubleSide
      })
    };
    return this.materials;
  }

  setMaterial(materialKey) {
    this.currentMaterialKey = materialKey;
    const materials = this.getMaterials();
    if (this.mesh && materials[materialKey]) {
      this.mesh.material = materials[materialKey];
    }
  }

  setSunAngle(azimuthDeg, altitudeDeg) {
    const r = 1200;
    const azRad = (azimuthDeg * Math.PI) / 180;
    const altRad = (altitudeDeg * Math.PI) / 180;

    const x = r * Math.cos(altRad) * Math.sin(azRad);
    const y = r * Math.sin(altRad);
    const z = r * Math.cos(altRad) * Math.cos(azRad);

    this.sunLight.position.set(x, y, z);
  }

  toggleFoldLines(visible) {
    this.showFoldLines = visible;
    this.foldLinesGroup.visible = visible;
  }

  updateGeometry(meshData) {
    if (!meshData || !meshData.vertices || !meshData.faces) return;

    // Remover malha anterior
    if (this.mesh) {
      this.scene.remove(this.mesh);
      if (this.mesh.geometry) this.mesh.geometry.dispose();
      this.mesh = null;
    }

    // Limpar linhas de dobra anteriores
    while (this.foldLinesGroup.children.length > 0) {
      const obj = this.foldLinesGroup.children.pop();
      if (obj.geometry) obj.geometry.dispose();
      if (obj.material) obj.material.dispose();
    }

    const { width, height, depth, vertices, faces, edges } = meshData;

    // Centralizar a geometria na origem para rotação suave
    const cx = width / 2;
    const cy = height / 2;

    const positions = [];
    faces.forEach(f => {
      f.forEach(vi => {
        const v = vertices[vi];
        positions.push(v[0] - cx, v[1] - cy, v[2]);
      });
    });

    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geometry.computeVertexNormals();

    const materials = this.getMaterials();
    const mat = materials[this.currentMaterialKey] || materials.red_glossy;

    this.mesh = new THREE.Mesh(geometry, mat);
    this.mesh.castShadow = true;
    this.mesh.receiveShadow = true;
    this.scene.add(this.mesh);

    // Criar linhas de dobra com diferenciação por tipo
    if (edges) {
      edges.forEach(e => {
        const p0 = vertices[e.v0];
        const p1 = vertices[e.v1];
        if (!p0 || !p1) return;

        const lineGeo = new THREE.BufferGeometry().setFromPoints([
          new THREE.Vector3(p0[0] - cx, p0[1] - cy, p0[2] + 0.5),
          new THREE.Vector3(p1[0] - cx, p1[1] - cy, p1[2] + 0.5)
        ]);

        let color = 0x94A3B8; // Boundary
        if (e.type === 'mountain') color = 0xEF4444; // Montanha (Vermelho)
        if (e.type === 'valley') color = 0x3B82F6;   // Vale (Azul)

        const lineMat = new THREE.LineBasicMaterial({ color: color, linewidth: 2 });
        const line = new THREE.Line(lineGeo, lineMat);
        this.foldLinesGroup.add(line);
      });
    }

    // Ajustar foco da câmera
    if (this.controls) {
      this.controls.target.set(0, 0, depth / 2);
    }
  }

  getSnapshot() {
    this.renderer.render(this.scene, this.camera);
    return this.renderer.domElement.toDataURL('image/jpeg', 0.85);
  }

  onResize() {
    const width = this.container.clientWidth;
    const height = this.container.clientHeight;
    if (width === 0 || height === 0) return;

    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height);
  }

  animate() {
    requestAnimationFrame(() => this.animate());
    if (this.controls) this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }
}
