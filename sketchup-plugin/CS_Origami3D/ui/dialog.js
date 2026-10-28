/**
 * CS_Origami3D - Controlador Principal da Interface (dialog.js)
 */

// Ligação entre campos da tela e parâmetros: [id do elemento, chave em params, tipo]
// Usada tanto para ouvir os campos quanto para preenchê-los ao carregar um modelo.
const INPUT_BINDINGS = [
  ['param-width', 'width', 'float'],
  ['param-height', 'height', 'float'],
  ['param-depth', 'depth', 'float'],
  ['slider-cx', 'center_x_ratio', 'float'],
  ['slider-cy', 'center_y_ratio', 'float'],
  ['param-edge-z', 'edge_z', 'float'],
  ['param-chevron-rows', 'chevron_rows', 'int'],
  ['param-chevron-cols', 'chevron_cols', 'int'],
  ['param-top-w', 'top_width', 'float'],
  ['param-top-h', 'top_height', 'float'],
  ['param-flange-w', 'flange_width', 'float'],
  ['param-relief-ang', 'relief_angle', 'float'],
  ['param-rivet-dist', 'rivet_spacing', 'float'],
  ['param-cols', 'cols', 'int'],
  ['param-rows', 'rows', 'int'],
  ['param-gap', 'joint_gap_mm', 'float'],
  ['param-total-w', 'total_width_mm', 'float'],
  ['param-total-h', 'total_height_mm', 'float'],
  ['select-sizing-mode', 'sizing_mode', 'string'],
  ['check-rivets', 'rivet_holes', 'bool'],
  ['check-perforated', 'perforated', 'bool'],
  ['check-flip-x', 'flip_x_alternate', 'bool'],
  ['check-flip-y', 'flip_y_alternate', 'bool'],
  ['check-rotate', 'rotate_alternate', 'bool']
];

// Abaixo deste ângulo (graus) duas facetas são coplanares: sem vinco (igual ao Ruby)
const FLAT_ANGLE_TOL = 0.5;

function escapeHtml(text) {
  return String(text == null ? '' : text).replace(/[&<>"']/g, ch => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[ch]);
}

const CS_ORIGAMI_APP = {
  viewer3D: null,
  activeTab: 'creator',
  currentMaterial: 'red_glossy',
  unfoldData: null,
  unfoldRequestTimer: null,

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
    top_width: 0.0,
    top_height: 0.0,
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
    this.syncInputs();
    this.updateParamVisibility();
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
        this.params.typology = e.currentTarget.dataset.typology;
        this.syncTypologyCards();
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

    // 4. Campos numéricos, sliders, seletores e checkboxes
    INPUT_BINDINGS.forEach(([id, key, kind]) => {
      const el = document.getElementById(id);
      if (!el) return;
      const eventName = kind === 'bool' || kind === 'string' ? 'change' : 'input';
      el.addEventListener(eventName, (e) => {
        if (kind === 'bool') {
          this.params[key] = e.target.checked;
        } else if (kind === 'string') {
          this.params[key] = e.target.value;
        } else {
          const val = kind === 'float' ? parseFloat(e.target.value) : parseInt(e.target.value, 10);
          // Campo vazio ou incompleto durante a digitação: mantém o último valor válido
          if (isNaN(val)) return;
          this.params[key] = val;
        }
        this.updateValueLabel(id);
        this.updatePreview();
      });
    });

    // 5. Controle de Luz Solar / Sombreamento das Facetas
    const sunSlider = document.getElementById('slider-sun-azimuth');
    if (sunSlider) {
      sunSlider.addEventListener('input', (e) => {
        const az = parseFloat(e.target.value);
        this.viewer3D.setSunAngle(az, 45);
      });
    }

    // 6. Toggle Linhas de Dobra
    const toggleFolds = document.getElementById('btn-toggle-folds');
    if (toggleFolds) {
      toggleFolds.addEventListener('click', (e) => {
        const active = e.currentTarget.classList.toggle('active');
        this.viewer3D.toggleFoldLines(active);
      });
    }

    // 7. Botões de Ação com SketchUp
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
      this.savePreset();
    });

    // 8. Biblioteca: carregar modelo (delegação, sem JS inline no HTML gerado)
    document.getElementById('presets-list').addEventListener('click', (e) => {
      const item = e.target.closest('.library-item');
      if (item) this.loadPreset(item.dataset.presetId);
    });

    window.addEventListener('resize', () => {
      if (this.activeTab === 'unfold') this.render2DPlanification();
    });
  },

  switchTab(tab) {
    if (!document.getElementById(`tab-${tab}`)) tab = 'creator';
    this.activeTab = tab;
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === `tab-${tab}`));

    const vp3D = document.getElementById('viewport-3d');
    const vp2D = document.getElementById('viewport-2d');

    if (tab === 'unfold') {
      vp3D.style.display = 'none';
      vp2D.style.display = 'block';
      this.requestUnfold();
      this.render2DPlanification();
    } else {
      vp3D.style.display = 'block';
      vp2D.style.display = 'none';
      this.viewer3D.onResize();
    }
  },

  updateParamVisibility() {
    const typ = this.params.typology;
    const sections = {
      'section-chevron': typ === 'yoshimura_chevron',
      'section-diamond': typ === 'diamond_classic',
      'section-pyramid': typ === 'pyramid'
    };
    for (const id in sections) {
      const el = document.getElementById(id);
      if (el) el.style.display = sections[id] ? 'block' : 'none';
    }

    const byTotal = this.params.sizing_mode === 'by_total_size';
    const secCount = document.getElementById('section-by-count');
    const secTotal = document.getElementById('section-by-total');
    if (secCount) secCount.style.display = byTotal ? 'none' : 'flex';
    if (secTotal) secTotal.style.display = byTotal ? 'flex' : 'none';
  },

  updateValueLabel(id) {
    const span = document.getElementById(`${id}-val`);
    const el = document.getElementById(id);
    if (span && el) span.innerText = `${Math.round(parseFloat(el.value) * 100)}%`;
  },

  // Preenche todos os campos da tela a partir de this.params
  syncInputs() {
    INPUT_BINDINGS.forEach(([id, key, kind]) => {
      const el = document.getElementById(id);
      if (!el || this.params[key] === undefined) return;
      if (kind === 'bool') {
        el.checked = !!this.params[key];
      } else {
        el.value = this.params[key];
      }
      this.updateValueLabel(id);
    });
    this.syncTypologyCards();
  },

  syncTypologyCards() {
    document.querySelectorAll('.typology-card').forEach(c => {
      c.classList.toggle('active', c.dataset.typology === this.params.typology);
    });
  },

  updatePreview() {
    this.updateParamVisibility();
    const mesh = this.calculateLocalMesh(this.params);
    this.viewer3D.updateGeometry(mesh);

    // Atualizar métricas na interface
    const areaM2 = (mesh.total_area / 1e6).toFixed(2);
    document.getElementById('stat-area').innerText = `${areaM2} m²`;
    document.getElementById('stat-dims').innerText = `${mesh.width.toFixed(0)} × ${mesh.height.toFixed(0)} × ${mesh.depth.toFixed(0)} mm`;

    // A planificação exata vem do Ruby: invalida a anterior e pede uma nova
    this.unfoldData = null;
    if (this.activeTab === 'unfold') {
      this.requestUnfold();
      this.render2DPlanification();
    }
  },

  // Motor matemático local em JS para resposta instantânea a 60fps no Three.js
  // (espelha GeometryEngine do Ruby; o Ruby continua sendo a fonte para SketchUp/DXF)
  calculateLocalMesh(params) {
    const w = Math.max(params.width, 10);
    const h = Math.max(params.height, 10);
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
      // Pirâmide: truncada quando há topo plano, senão aguda
      const cx = w * (params.center_x_ratio || 0.5);
      const cy = h * (params.center_y_ratio || 0.5);
      const topW = params.top_width || 0;
      const topH = params.top_height || 0;
      vertices = [[0, 0, 0], [w, 0, 0], [w, h, 0], [0, h, 0]];

      if (topW > 0 && topH > 0) {
        const hw = topW / 2;
        const hh = topH / 2;
        vertices.push(
          [cx - hw, cy - hh, depth], [cx + hw, cy - hh, depth],
          [cx + hw, cy + hh, depth], [cx - hw, cy + hh, depth]
        );
        faces = [
          [0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5],
          [2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7],
          [4, 5, 6], [4, 6, 7]
        ];
      } else {
        vertices.push([cx, cy, depth]);
        faces = [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]];
      }
    }

    return Object.assign({ width: w, height: h, depth: depth, vertices: vertices, faces: faces },
      this.analyzeMesh(vertices, faces));
  },

  // Normais, área real e classificação montanha/vale das arestas (mesma regra do Ruby)
  analyzeMesh(vertices, faces) {
    const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
    const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

    let totalArea = 0;
    const normals = faces.map(f => {
      const v1 = sub(vertices[f[1]], vertices[f[0]]);
      const v2 = sub(vertices[f[2]], vertices[f[0]]);
      const n = [v1[1] * v2[2] - v1[2] * v2[1], v1[2] * v2[0] - v1[0] * v2[2], v1[0] * v2[1] - v1[1] * v2[0]];
      const len = Math.sqrt(dot(n, n));
      totalArea += len / 2;
      return len > 1e-6 ? [n[0] / len, n[1] / len, n[2] / len] : [0, 0, 1];
    });

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

    const edges = [];
    Object.keys(edgeMap).forEach(k => {
      const flist = edgeMap[k];
      const [va, vb] = k.split('_').map(Number);
      if (flist.length !== 2) {
        edges.push({ v0: va, v1: vb, type: 'boundary', angle: 90.0 });
        return;
      }
      const n1 = normals[flist[0]];
      const n2 = normals[flist[1]];
      const angle = Math.acos(Math.max(-1, Math.min(1, dot(n1, n2)))) * 180 / Math.PI;
      if (angle < FLAT_ANGLE_TOL) return; // coplanares: sem vinco

      const pa = vertices[va];
      const pb = vertices[vb];
      const mid = [(pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2, (pa[2] + pb[2]) / 2];
      const opp = faces[flist[0]].find(v => v !== va && v !== vb);
      const type = dot(sub(vertices[opp], mid), n2) < 0 ? 'mountain' : 'valley';
      edges.push({ v0: va, v1: vb, type: type, angle: angle });
    });

    return { edges: edges, total_area: totalArea };
  },

  // Pede ao Ruby a planificação real (com atraso para não recalcular a cada tecla)
  requestUnfold() {
    if (!this.isSketchUp()) return;
    clearTimeout(this.unfoldRequestTimer);
    this.unfoldRequestTimer = setTimeout(() => {
      window.sketchup.calculate_preview_data(JSON.stringify(this.params));
    }, 150);
  },

  onCalculateData(payload) {
    this.unfoldData = payload && payload.unfold;
    if (this.activeTab === 'unfold') this.render2DPlanification();
  },

  render2DPlanification() {
    const vp = document.getElementById('viewport-2d');
    const warn = document.getElementById('unfold-warning');
    const u = this.unfoldData;

    if (!u) {
      document.getElementById('stat-sheet-size').innerText = '—';
      document.getElementById('stat-folds').innerText = '—';
      if (warn) warn.style.display = 'none';
      const msg = this.isSketchUp()
        ? 'Calculando planificação…'
        : 'A planificação exata é calculada pelo SketchUp. Abra o estúdio pelo plugin para ver a chapa.';
      vp.innerHTML = `<div class="viewport-message">${msg}</div>`;
      return;
    }

    document.getElementById('stat-sheet-size').innerText = `${u.sheet_width.toFixed(0)} × ${u.sheet_height.toFixed(0)} mm`;
    const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;
    document.getElementById('stat-folds').innerText =
      `${plural(u.fold_lines.length, 'vinco', 'vincos')} · ${plural(u.seam_lines.length / 2, 'emenda', 'emendas')}`;
    if (warn) {
      const n = u.overlaps.length;
      warn.style.display = n ? 'block' : 'none';
      warn.innerText = `Atenção: ${n} sobreposição(ões) de facetas/abas nesta planificação. A chapa não pode ser cortada assim; ajuste a geometria ou divida o bloco em mais peças.`;
    }

    // Desenhar visualização SVG da chapa pronta para CNC Router
    const pad = 40;
    const svgW = vp.clientWidth || 600;
    const svgH = vp.clientHeight || 500;
    const bb = u.bounding_box;
    const totalW = Math.max(bb.max_x - bb.min_x, 1);
    const totalH = Math.max(bb.max_y - bb.min_y, 1);

    const scale = Math.min((svgW - pad * 2) / totalW, (svgH - pad * 2) / totalH);
    const ox = (svgW - totalW * scale) / 2;
    const oy = (svgH - totalH * scale) / 2;

    // Y do SketchUp cresce para cima; no SVG cresce para baixo
    const pt = (p) => `${(ox + (p[0] - bb.min_x) * scale).toFixed(2)},${(oy + (bb.max_y - p[1]) * scale).toFixed(2)}`;
    const line = (a, b, color, width) => {
      const [x1, y1] = pt(a).split(',');
      const [x2, y2] = pt(b).split(',');
      return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="${width}" />`;
    };
    const circle = (h, color) => {
      const [cx, cy] = pt(h.center).split(',');
      return `<circle cx="${cx}" cy="${cy}" r="${Math.max((h.diameter / 2) * scale, 1.2).toFixed(2)}" fill="${color}" />`;
    };

    let svg = `<svg width="100%" height="100%" viewBox="0 0 ${svgW} ${svgH}" xmlns="http://www.w3.org/2000/svg">`;
    svg += `<rect x="0" y="0" width="${svgW}" height="${svgH}" fill="#0A0F1D" />`;

    // Chapa bruta retangular de referência (linha tracejada)
    svg += `<rect x="${ox}" y="${oy}" width="${totalW * scale}" height="${totalH * scale}" fill="none" stroke="#334155" stroke-dasharray="4,4" stroke-width="1" />`;

    const overlapping = new Set();
    u.overlaps.forEach(o => {
      overlapping.add(`${o.a.kind}${o.a.index}`);
      overlapping.add(`${o.b.kind}${o.b.index}`);
    });
    const fillFor = (kind, index, base) => overlapping.has(`${kind}${index}`) ? 'rgba(239,68,68,0.35)' : base;

    // Abas (corte nas laterais, vinco V90 na base)
    u.flanges.forEach((fl, i) => {
      svg += `<polygon points="${fl.polygon.map(pt).join(' ')}" fill="${fillFor('flange', i, '#1E293B')}" stroke="none" />`;
      const poly = fl.polygon;
      for (let k = 1; k < poly.length; k++) svg += line(poly[k - 1], poly[k], '#F8FAFC', 1.5);
      svg += line(fl.base_start, fl.base_end, '#EF4444', 1.8);
    });

    // Facetas
    u.flat_faces.forEach(ff => {
      svg += `<polygon points="${ff.coords_2d.map(pt).join(' ')}" fill="${fillFor('face', ff.index, '#334155')}" stroke="none" />`;
    });

    // Emendas (corte passante entre facetas que não ficaram unidas)
    u.seam_lines.forEach(sl => { svg += line(sl.start, sl.end, '#F8FAFC', 1.5); });

    // Vincos internos: vermelho = verso (montanha), magenta = frente (vale)
    u.fold_lines.forEach(fl => {
      svg += line(fl.start, fl.end, fl.type === 'valley' ? '#E879F9' : '#EF4444', 1.5);
    });

    u.rivet_holes.forEach(h => { svg += circle(h, '#F59E0B'); });
    u.perforation_holes.forEach(h => { svg += circle(h, '#FCD34D'); });

    // Legenda de Camadas CNC (canto inferior direito: o superior esquerdo tem os badges de medidas)
    svg += `
      <g transform="translate(${svgW - 250}, ${svgH - 108})">
        <rect x="0" y="0" width="230" height="88" rx="6" fill="rgba(17,24,39,0.9)" stroke="#374151" />
        <line x1="12" y1="18" x2="35" y2="18" stroke="#F8FAFC" stroke-width="2" />
        <text x="45" y="22" fill="#F8FAFC" font-size="11" font-weight="bold">CAMADA_CORTE (Passante)</text>
        <line x1="12" y1="38" x2="35" y2="38" stroke="#EF4444" stroke-width="2" />
        <text x="45" y="42" fill="#EF4444" font-size="11" font-weight="bold">VINCO V (verso / montanha)</text>
        <line x1="12" y1="56" x2="35" y2="56" stroke="#E879F9" stroke-width="2" />
        <text x="45" y="60" fill="#E879F9" font-size="11" font-weight="bold">CAMADA_VINCO_VALE (frente)</text>
        <circle cx="23" cy="74" r="4" fill="#F59E0B" />
        <text x="45" y="78" fill="#F59E0B" font-size="11" font-weight="bold">CAMADA_FUROS (Rebites CNC)</text>
      </g>
    `;

    svg += `</svg>`;
    vp.innerHTML = svg;
  },

  // Formulário na própria aba (prompt() não é confiável dentro do UI::HtmlDialog)
  savePreset() {
    const nameEl = document.getElementById('preset-name');
    const descEl = document.getElementById('preset-desc');
    const name = nameEl.value.trim();
    if (!name) {
      nameEl.focus();
      return;
    }

    const payload = {
      name: name,
      typology: this.params.typology,
      params: this.params,
      description: descEl.value.trim(),
      thumbnail: this.viewer3D.getSnapshot()
    };

    this.callRuby('save_preset', payload);
    nameEl.value = '';
    descEl.value = '';
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
      <div class="library-item" data-preset-id="${escapeHtml(p.id)}">
        <div class="library-info">
          <div class="library-name">${escapeHtml(p.name)}</div>
          <div class="library-desc">${escapeHtml(p.description || p.typology)}</div>
        </div>
        <button class="btn btn-secondary" style="padding:4px 8px;font-size:11px;">Carregar</button>
      </div>
    `).join('');
  },

  loadPreset(presetId) {
    const preset = this.presets.find(p => p.id === presetId);
    if (!preset) return;
    this.loadParams(Object.assign({}, preset.params, { typology: preset.typology }));
  },

  // Também chamado pelo Ruby ao editar um bloco já existente na cena
  loadParams(params) {
    if (!params) return;
    Object.assign(this.params, params);
    this.syncInputs();
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

// O Ruby chama window.CS_ORIGAMI_APP via execute_script; const no topo do script não vira propriedade de window
window.CS_ORIGAMI_APP = CS_ORIGAMI_APP;

window.addEventListener('DOMContentLoaded', () => {
  CS_ORIGAMI_APP.init();
});
