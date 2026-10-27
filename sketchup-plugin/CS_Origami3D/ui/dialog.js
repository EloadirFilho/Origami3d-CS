/**
 * CS_Origami3D - Controlador Principal da Interface (dialog.js)
 */

const CS_ORIGAMI_APP = {
  viewer3D: null,
  activeTab: 'creator',
  currentMaterial: 'red_glossy',

  params: {
    typology: 'diamond_classic',
    width: 600.0,
    height: 1000.0,
    depth: 140.0,
    center_x_ratio: 0.5,
    center_y_ratio: 0.5,
    edge_z: 0.0,
    chevron_rows: 3,
    chevron_cols: 2,
    split_p1_x: 0.35,
    split_p1_y: 0.25,
    split_p2_x: 0.65,
    split_p2_y: 0.75,
    flange_width: 35.0,
    relief_angle: 45.0,
    rivet_holes: true,
    rivet_spacing: 150.0,
    rivet_dia: 4.5,
    perforated: false,
    perforated_faces: [0, 4],
    perf_hole_dia: 8.0,
    perf_pitch: 18.0,
    cols: 4,
    rows: 3,
    joint_gap_mm: 5.0,
    flip_x_alternate: true,
    flip_y_alternate: false,
    rotate_alternate: false,
    sizing_mode: 'by_count',
    total_width_mm: 3000.0,
    total_height_mm: 2500.0
  },

  presets: [],

  init() {
    this.viewer3D = new Origami3DViewer('viewport-3d');
    this.bindEvents();
    this.updatePreview();

    // Notifica SketchUp Ruby de que o diálogo está pronto
    if (this.isSketchUp()) {
      window.sketchup.ready();
    } else {
      console.log('[CS_Origami3D] Executando em modo navegador autônomo.');
    }
  },

  isSketchUp() {
    return typeof window.sketchup !== 'undefined';
  },

  bindEvents() {
    // 1. Navegação de Abas
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const tab = e.currentTarget.dataset.tab;
        this.switchTab(tab);
      });
    });

    // 2. Seleção de Tipologia
    document.querySelectorAll('.typology-card').forEach(card => {
      card.addEventListener('click', (e) => {
        document.querySelectorAll('.typology-card').forEach(c => c.classList.remove('active'));
        const el = e.currentTarget;
        el.classList.add('active');
        this.params.typology = el.dataset.typology;
        this.updateParamVisibility();
        this.updatePreview();
      });
    });

    // 3. Seleção de Acabamento ACM (Cores)
    document.querySelectorAll('.swatch').forEach(sw => {
      sw.addEventListener('click', (e) => {
        document.querySelectorAll('.swatch').forEach(s => s.classList.remove('active'));
        const el = e.currentTarget;
        el.classList.add('active');
        this.currentMaterial = el.dataset.material;
        this.viewer3D.setMaterial(this.currentMaterial);
      });
    });

    // 4. Inputs Numéricos e Sliders do Bloco
    const bindInput = (id, key, isFloat = true) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.addEventListener('input', (e) => {
        const val = isFloat ? parseFloat(e.target.value) : parseInt(e.target.value, 10);
        this.params[key] = isNaN(val) ? 0 : val;

        // Atualizar display se houver span correspondente
        const span = document.getElementById(`${id}-val`);
        if (span) span.innerText = e.target.value;

        this.updatePreview();
      });
    };

    bindInput('param-width', 'width');
    bindInput('param-height', 'height');
    bindInput('param-depth', 'depth');
    bindInput('slider-cx', 'center_x_ratio');
    bindInput('slider-cy', 'center_y_ratio');
    bindInput('param-edge-z', 'edge_z');
    bindInput('param-chevron-rows', 'chevron_rows', false);
    bindInput('param-chevron-cols', 'chevron_cols', false);
    bindInput('param-flange-w', 'flange_width');
    bindInput('param-relief-ang', 'relief_angle');
    bindInput('param-rivet-dist', 'rivet_spacing');
    bindInput('param-cols', 'cols', false);
    bindInput('param-rows', 'rows', false);
    bindInput('param-gap', 'joint_gap_mm');
    bindInput('param-total-w', 'total_width_mm');
    bindInput('param-total-h', 'total_height_mm');

    // 5. Checkboxes
    const bindCheck = (id, key) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.addEventListener('change', (e) => {
        this.params[key] = e.target.checked;
        this.updatePreview();
      });
    };

    bindCheck('check-rivets', 'rivet_holes');
    bindCheck('check-perforated', 'perforated');
    bindCheck('check-flip-x', 'flip_x_alternate');
    bindCheck('check-flip-y', 'flip_y_alternate');
    bindCheck('check-rotate', 'rotate_alternate');

    // 6. Controle de Luz Solar / Sombreamento das Facetas
    const sunSlider = document.getElementById('slider-sun-azimuth');
    if (sunSlider) {
      sunSlider.addEventListener('input', (e) => {
        const az = parseFloat(e.target.value);
        this.viewer3D.setSunAngle(az, 45);
      });
    }

    // 7. Toggle Linhas de Dobra
    const toggleFolds = document.getElementById('btn-toggle-folds');
    if (toggleFolds) {
      toggleFolds.addEventListener('click', (e) => {
        const active = e.currentTarget.classList.toggle('active');
        this.viewer3D.toggleFoldLines(active);
      });
    }

    // 8. Botões de Ação com SketchUp
    document.getElementById('btn-build-sketchup').addEventListener('click', () => {
      this.callRuby('build_3d_block', this.params);
    });

    document.getElementById('btn-place-unfolded').addEventListener('click', () => {
      this.callRuby('place_unfolded_2d', this.params);
    });

    document.getElementById('btn-export-dxf').addEventListener('click', () => {
      this.callRuby('export_dxf', this.params);
    });

    document.getElementById('btn-multiply-panel').addEventListener('click', () => {
      this.callRuby('multiply_panel', this.params);
    });

    document.getElementById('btn-save-preset').addEventListener('click', () => {
      this.promptSavePreset();
    });
  },

  switchTab(tab) {
    this.activeTab = tab;
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === `tab-${tab}`));

    const vp3D = document.getElementById('viewport-3d');
    const vp2D = document.getElementById('viewport-2d');

    if (tab === 'unfold') {
      vp3D.style.display = 'none';
      vp2D.style.display = 'block';
      this.render2DPlanification();
    } else {
      vp3D.style.display = 'block';
      vp2D.style.display = 'none';
      this.viewer3D.onResize();
    }
  },

  updateParamVisibility() {
    const isChevron = this.params.typology === 'yoshimura_chevron';
    const isDiamond = this.params.typology === 'diamond_classic';
    const isSplit = this.params.typology === 'split_diagonal';

    const secChevron = document.getElementById('section-chevron');
    const secDiamond = document.getElementById('section-diamond');

    if (secChevron) secChevron.style.display = isChevron ? 'block' : 'none';
    if (secDiamond) secDiamond.style.display = isDiamond ? 'block' : 'none';
  },

  updatePreview() {
    const mesh = this.calculateLocalMesh(this.params);
    this.viewer3D.updateGeometry(mesh);

    // Atualizar métricas na interface
    const areaM2 = (mesh.total_area / 1_000_000.0).toFixed(2);
    document.getElementById('stat-area').innerText = `${areaM2} m²`;
    document.getElementById('stat-dims').innerText = `${mesh.width.toFixed(0)} × ${mesh.height.toFixed(0)} × ${mesh.depth.toFixed(0)} mm`;

    if (this.activeTab === 'unfold') {
      this.render2DPlanification();
    }
  },

  // Motor matemático local em JS para resposta instantânea a 60fps no Three.js
  calculateLocalMesh(params) {
    const w = params.width;
    const h = params.height;
    const depth = params.depth;
    const typ = params.typology;

    let vertices = [];
    let faces = [];

    if (typ === 'diamond_classic') {
      const cx = w * params.center_x_ratio;
      const cy = h * params.center_y_ratio;
      const edgeZ = params.edge_z || 0.0;

      vertices = [
        [0, 0, 0], [w, 0, 0], [w, h, 0], [0, h, 0],
        [cx, 0, edgeZ], [w, cy, edgeZ], [cx, h, edgeZ], [0, cy, edgeZ],
        [cx, cy, depth]
      ];

      faces = [
        [0, 4, 8], [4, 1, 8], [1, 5, 8], [5, 2, 8],
        [2, 6, 8], [6, 3, 8], [3, 7, 8], [7, 0, 8]
      ];
    } else if (typ === 'yoshimura_chevron') {
      const rows = Math.max(params.chevron_rows || 3, 1);
      const cols = Math.max(params.chevron_cols || 2, 1);
      const dx = w / cols;
      const dy = h / rows;

      for (let r = 0; r <= rows; r++) {
        for (let c = 0; c <= cols; c++) {
          const isApex = (r % 2 === 0 && c % 2 !== 0) || (r % 2 !== 0 && c % 2 === 0);
          vertices.push([c * dx, r * dy, isApex ? depth : 0.0]);
        }
      }

      const stride = cols + 1;
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          const bl = r * stride + c;
          const br = bl + 1;
          const tl = (r + 1) * stride + c;
          const tr = tl + 1;

          if ((r + c) % 2 === 0) {
            faces.push([bl, br, tr], [bl, tr, tl]);
          } else {
            faces.push([bl, br, tl], [br, tr, tl]);
          }
        }
      }
    } else if (typ === 'split_diagonal') {
      const p1x = w * (params.split_p1_x || 0.35);
      const p1y = h * (params.split_p1_y || 0.25);
      const p2x = w * (params.split_p2_x || 0.65);
      const p2y = h * (params.split_p2_y || 0.75);

      vertices = [
        [0, 0, 0], [w, 0, 0], [w, h, 0], [0, h, 0],
        [p1x, p1y, depth], [p2x, p2y, depth * 0.85],
        [w, h * 0.4, depth * 0.3], [0, h * 0.6, depth * 0.3]
      ];

      faces = [
        [0, 1, 4], [1, 6, 4], [6, 5, 4], [6, 2, 5],
        [2, 3, 5], [3, 7, 5], [7, 4, 5], [7, 0, 4]
      ];
    } else {
      // Pirâmide padrão
      const cx = w * 0.5;
      const cy = h * 0.5;
      vertices = [[0, 0, 0], [w, 0, 0], [w, h, 0], [0, h, 0], [cx, cy, depth]];
      faces = [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]];
    }

    // Extrair arestas para visualização de vincos
    const edges = [];
    const edgeMap = {};
    faces.forEach((f, fi) => {
      for (let i = 0; i < 3; i++) {
        const va = f[i];
        const vb = f[(i + 1) % 3];
        const k = va < vb ? `${va}_${vb}` : `${vb}_${va}`;
        if (!edgeMap[k]) edgeMap[k] = [];
        edgeMap[k].push(fi);
      }
    });

    for (const [k, flist] of Object.entries(edgeMap)) {
      const [va, vb] = k.split('_').map(Number);
      edges.push({
        v0: va,
        v1: vb,
        type: flist.length === 1 ? 'boundary' : 'mountain',
        angle: 90.0
      });
    }

    return {
      width: w,
      height: h,
      depth: depth,
      vertices: vertices,
      faces: faces,
      edges: edges,
      total_area: w * h * 1.15
    };
  },

  render2DPlanification() {
    const vp = document.getElementById('viewport-2d');
    const w = this.params.width;
    const h = this.params.height;
    const fw = this.params.flange_width;

    const totalW = w + fw * 2;
    const totalH = h + fw * 2;

    document.getElementById('stat-sheet-size').innerText = `${totalW.toFixed(0)} × ${totalH.toFixed(0)} mm`;

    // Desenhar visualização SVG da chapa pronta para CNC Router
    const pad = 40;
    const svgW = vp.clientWidth || 600;
    const svgH = vp.clientHeight || 500;

    const scale = Math.min((svgW - pad * 2) / totalW, (svgH - pad * 2) / totalH);
    const ox = (svgW - totalW * scale) / 2;
    const oy = (svgH - totalH * scale) / 2;

    const tx = (x) => ox + (x + fw) * scale;
    const ty = (y) => oy + (totalH - (y + fw)) * scale;

    let svgHtml = `<svg width="100%" height="100%" viewBox="0 0 ${svgW} ${svgH}" xmlns="http://www.w3.org/2000/svg">`;

    // Fundo da mesa CNC
    svgHtml += `<rect x="0" y="0" width="${svgW}" height="${svgH}" fill="#0A0F1D" />`;

    // Chapa Bruta Retangular de Referência (Linha tracejada ciano)
    svgHtml += `<rect x="${ox}" y="${oy}" width="${totalW * scale}" height="${totalH * scale}" fill="none" stroke="#334155" stroke-dasharray="4,4" stroke-width="1" />`;

    // Contorno de Corte Passante com Abas e Alívios a 45°
    const chamf = fw;
    const cutPoly = [
      [0, 0 - fw], [w, 0 - fw], // Aba Sul
      [w + fw - chamf, 0 - fw], [w + fw, 0], // Canto SE
      [w + fw, h], [w + fw - chamf, h + fw], // Canto NE
      [0 + chamf, h + fw], [0, h], // Canto NW
      [0 - fw, h - chamf], [0 - fw, 0 + chamf] // Canto SW
    ];

    // Desenhar Abas perimetrais
    // Sul
    svgHtml += `<polygon points="${tx(0 + chamf)},${ty(0 - fw)} ${tx(w - chamf)},${ty(0 - fw)} ${tx(w)},${ty(0)} ${tx(0)},${ty(0)}" fill="#1E293B" stroke="#F8FAFC" stroke-width="1.5" />`;
    // Norte
    svgHtml += `<polygon points="${tx(0 + chamf)},${ty(h + fw)} ${tx(w - chamf)},${ty(h + fw)} ${tx(w)},${ty(h)} ${tx(0)},${ty(h)}" fill="#1E293B" stroke="#F8FAFC" stroke-width="1.5" />`;
    // Leste
    svgHtml += `<polygon points="${tx(w + fw)},${ty(0 + chamf)} ${tx(w + fw)},${ty(h - chamf)} ${tx(w)},${ty(h)} ${tx(w)},${ty(0)}" fill="#1E293B" stroke="#F8FAFC" stroke-width="1.5" />`;
    // Oeste
    svgHtml += `<polygon points="${tx(0 - fw)},${ty(0 + chamf)} ${tx(0 - fw)},${ty(h - chamf)} ${tx(0)},${ty(h)} ${tx(0)},${ty(0)}" fill="#1E293B" stroke="#F8FAFC" stroke-width="1.5" />`;

    // Vincos de 90° das Abas (Linha Vermelha de Fresa V90)
    svgHtml += `<line x1="${tx(0)}" y1="${ty(0)}" x2="${tx(w)}" y2="${ty(0)}" stroke="#EF4444" stroke-width="1.8" />`;
    svgHtml += `<line x1="${tx(w)}" y1="${ty(0)}" x2="${tx(w)}" y2="${ty(h)}" stroke="#EF4444" stroke-width="1.8" />`;
    svgHtml += `<line x1="${tx(w)}" y1="${ty(h)}" x2="${tx(0)}" y2="${ty(h)}" stroke="#EF4444" stroke-width="1.8" />`;
    svgHtml += `<line x1="${tx(0)}" y1="${ty(h)}" x2="${tx(0)}" y2="${ty(0)}" stroke="#EF4444" stroke-width="1.8" />`;

    // Vincos Internos do Padrão Facetado (Linha Vermelha de Fresagem)
    if (this.params.typology === 'diamond_classic') {
      const cx = w * this.params.center_x_ratio;
      const cy = h * this.params.center_y_ratio;
      // Diagonais e eixos
      svgHtml += `<line x1="${tx(0)}" y1="${ty(0)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
      svgHtml += `<line x1="${tx(w)}" y1="${ty(0)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
      svgHtml += `<line x1="${tx(w)}" y1="${ty(h)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
      svgHtml += `<line x1="${tx(0)}" y1="${ty(h)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
      svgHtml += `<line x1="${tx(cx)}" y1="${ty(0)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
      svgHtml += `<line x1="${tx(w)}" y1="${ty(cy)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
      svgHtml += `<line x1="${tx(cx)}" y1="${ty(h)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
      svgHtml += `<line x1="${tx(0)}" y1="${ty(cy)}" x2="${tx(cx)}" y2="${ty(cy)}" stroke="#EF4444" stroke-width="1.5" />`;
    }

    // Furos de Rebite nas Abas (Círculos Amarelos)
    if (this.params.rivet_holes) {
      const r = (this.params.rivet_dia / 2) * scale;
      const addHole = (hx, hy) => {
        svgHtml += `<circle cx="${tx(hx)}" cy="${ty(hy)}" r="${Math.max(r, 2.5)}" fill="#F59E0B" stroke="#000" stroke-width="0.5" />`;
      };
      // Aba Sul e Norte
      addHole(w * 0.25, -fw / 2); addHole(w * 0.75, -fw / 2);
      addHole(w * 0.25, h + fw / 2); addHole(w * 0.75, h + fw / 2);
      // Aba Oeste e Leste
      addHole(-fw / 2, h * 0.25); addHole(-fw / 2, h * 0.75);
      addHole(w + fw / 2, h * 0.25); addHole(w + fw / 2, h * 0.75);
    }

    // Legenda de Camadas CNC
    svgHtml += `
      <g transform="translate(20, 20)">
        <rect x="0" y="0" width="220" height="85" rx="6" fill="rgba(17,24,39,0.9)" stroke="#374151" />
        <line x1="12" y1="18" x2="35" y2="18" stroke="#F8FAFC" stroke-width="2" />
        <text x="45" y="22" fill="#F8FAFC" font-size="11" font-weight="bold">CAMADA_CORTE (Passante)</text>

        <line x1="12" y1="38" x2="35" y2="38" stroke="#EF4444" stroke-width="2" />
        <text x="45" y="42" fill="#EF4444" font-size="11" font-weight="bold">CAMADA_VINCO_V90 (Fresa V)</text>

        <circle cx="23" cy="58" r="4" fill="#F59E0B" />
        <text x="45" y="62" fill="#F59E0B" font-size="11" font-weight="bold">CAMADA_FUROS (Rebites CNC)</text>
      </g>
    `;

    svgHtml += `</svg>`;
    vp.innerHTML = svgHtml;
  },

  promptSavePreset() {
    const name = prompt('Nome para o novo Modelo / Bloco Origami:', 'Origami Facetado 01');
    if (!name) return;
    const desc = prompt('Descrição ou observação:', 'Bloco para revestimento de fachada comercial');

    const thumb = this.viewer3D.getSnapshot();
    const payload = {
      name: name,
      typology: this.params.typology,
      params: this.params,
      description: desc || '',
      thumbnail: thumb
    };

    this.callRuby('save_preset', payload);
  },

  onPresetsLoaded(presets) {
    this.presets = presets || [];
    const container = document.getElementById('presets-list');
    if (!container) return;

    if (this.presets.length === 0) {
      container.innerHTML = '<div style="color:var(--text-muted);font-size:12px;padding:8px;">Nenhum modelo salvo.</div>';
      return;
    }

    container.innerHTML = this.presets.map(p => `
      <div class="library-item" onclick="CS_ORIGAMI_APP.loadPreset('${p.id}')">
        <div class="library-info">
          <div class="library-name">${p.name}</div>
          <div class="library-desc">${p.description || p.typology}</div>
        </div>
        <button class="btn btn-secondary" style="padding:4px 8px;font-size:11px;">Carregar</button>
      </div>
    `).join('');
  },

  loadPreset(presetId) {
    const preset = this.presets.find(p => p.id === presetId);
    if (!preset) return;

    Object.assign(this.params, preset.params);
    this.params.typology = preset.typology;

    // Sincronizar inputs da tela
    document.getElementById('param-width').value = this.params.width;
    document.getElementById('param-height').value = this.params.height;
    document.getElementById('param-depth').value = this.params.depth;

    document.querySelectorAll('.typology-card').forEach(c => {
      c.classList.toggle('active', c.dataset.typology === this.params.typology);
    });

    this.updateParamVisibility();
    this.updatePreview();
    this.switchTab('creator');
  },

  callRuby(action, data) {
    const jsonStr = JSON.stringify(data);
    if (this.isSketchUp() && window.sketchup[action]) {
      window.sketchup[action](jsonStr);
    } else {
      console.log(`[CS_Origami3D] Chamada Ruby simulada -> ${action}:`, data);
      alert(`[Modo Simulação] Ação enviada para o SketchUp: ${action}`);
    }
  }
};

window.addEventListener('DOMContentLoaded', () => {
  CS_ORIGAMI_APP.init();
});
