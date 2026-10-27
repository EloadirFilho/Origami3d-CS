# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Motor Geométrico Paramétrico de Facetas e Origami
# ==============================================================================

module CS_Origami3D
  class GeometryEngine
    ATTR_DICT = 'CS_Origami3D_Block'.freeze

    # Estrutura de retorno para geometria do bloco
    # vertices: Array de [x, y, z] em milímetros
    # faces: Array de índices de vértices [[i0, i1, i2], ...]
    # edges: Array de { v0: int, v1: int, type: 'boundary'|'mountain'|'valley', angle: float }
    # bounds: { width, height, depth }
    
    def self.generate_block_mesh(params)
      typology = params[:typology] || 'diamond_classic'
      w = (params[:width] || 600.0).to_f
      h = (params[:height] || 1000.0).to_f
      depth = (params[:depth] || 150.0).to_f

      case typology
      when 'diamond_classic'
        generate_diamond(w, h, depth, params)
      when 'yoshimura_chevron'
        generate_yoshimura(w, h, depth, params)
      when 'split_diagonal'
        generate_split_diagonal(w, h, depth, params)
      when 'pyramid'
        generate_pyramid(w, h, depth, params)
      when 'custom_mesh'
        generate_custom_mesh(w, h, depth, params)
      else
        generate_diamond(w, h, depth, params)
      end
    end

    # --------------------------------------------------------------------------
    # 1. DIAMANTE FACETADO CLÁSSICO (8 Facetas Triangulares)
    # --------------------------------------------------------------------------
    def self.generate_diamond(w, h, depth, params)
      cx = w * (params[:center_x_ratio] || 0.5).to_f
      cy = h * (params[:center_y_ratio] || 0.5).to_f
      cz = depth
      edge_z = (params[:edge_z] || 0.0).to_f

      # Vértices (mm)
      # 0: Inferior Esquerdo (0, 0, 0)
      # 1: Inferior Direito  (W, 0, 0)
      # 2: Superior Direito  (W, H, 0)
      # 3: Superior Esquerdo (0, H, 0)
      # 4: Meio Inferior     (cx, 0, edge_z)
      # 5: Meio Direito      (W, cy, edge_z)
      # 6: Meio Superior     (cx, H, edge_z)
      # 7: Meio Esquerdo     (0, cy, edge_z)
      # 8: Ápice Central     (cx, cy, cz)
      vertices = [
        [0.0, 0.0, 0.0],         # 0
        [w, 0.0, 0.0],           # 1
        [w, h, 0.0],             # 2
        [0.0, h, 0.0],           # 3
        [cx, 0.0, edge_z],       # 4
        [w, cy, edge_z],         # 5
        [cx, h, edge_z],         # 6
        [0.0, cy, edge_z],       # 7
        [cx, cy, cz]             # 8
      ]

      # 8 Faces Triangulares orientadas no sentido anti-horário (Normais apontando para fora)
      faces = [
        [0, 4, 8], # Face Sul-Oeste
        [4, 1, 8], # Face Sul-Leste
        [1, 5, 8], # Face Leste-Sul
        [5, 2, 8], # Face Leste-Norte
        [2, 6, 8], # Face Norte-Leste
        [6, 3, 8], # Face Norte-Oeste
        [3, 7, 8], # Face Oeste-Norte
        [7, 0, 8]  # Face Oeste-Sul
      ]

      analyze_mesh(vertices, faces, w, h, depth, 'diamond_classic', params)
    end

    # --------------------------------------------------------------------------
    # 2. YOSHIMURA / CHEVRON (Espinha de peixe / Dobras tipo Acordeão)
    # Conforme foto 5: Tesselação contínua com cristas e vales
    # --------------------------------------------------------------------------
    def self.generate_yoshimura(w, h, depth, params)
      rows = [(params[:chevron_rows] || 3).to_i, 1].max
      cols = [(params[:chevron_cols] || 2).to_i, 1].max

      vertices = []
      faces = []

      dx = w / cols
      dy = h / rows

      # Grid de vértices com deslocamento z alternado
      # Cada célula retangular é cortada em triângulos com dobras de montanha e vale
      (0..rows).each do |r|
        y = r * dy
        (0..cols).each do |c|
          x = c * dx
          # Vértices internos ou alternados ganham altura Z
          is_internal = (r > 0 && r < rows && c > 0 && c < cols)
          is_apex = (r.even? && c.odd?) || (r.odd? && c.even?)
          z = is_apex ? depth : 0.0
          vertices << [x, y, z]
        end
      end

      stride = cols + 1
      (0...rows).each do |r|
        (0...cols).each do |c|
          v_bl = r * stride + c
          v_br = v_bl + 1
          v_tl = (r + 1) * stride + c
          v_tr = v_tl + 1

          # Alterna a diagonal de corte para criar padrão espinha de peixe (chevron)
          if (r + c).even?
            faces << [v_bl, v_br, v_tr]
            faces << [v_bl, v_tr, v_tl]
          else
            faces << [v_bl, v_br, v_tl]
            faces << [v_br, v_tr, v_tl]
          end
        end
      end

      analyze_mesh(vertices, faces, w, h, depth, 'yoshimura_chevron', params)
    end

    # --------------------------------------------------------------------------
    # 3. SPLIT DIAGONAL / CRISTAL ASSIMÉTRICO (Fotos 1, 3 e 4)
    # --------------------------------------------------------------------------
    def self.generate_split_diagonal(w, h, depth, params)
      # Crista diagonal que divide a chapa retangular
      p1_x = w * (params[:split_p1_x] || 0.35).to_f
      p1_y = h * (params[:split_p1_y] || 0.25).to_f
      p1_z = depth

      p2_x = w * (params[:split_p2_x] || 0.65).to_f
      p2_y = h * (params[:split_p2_y] || 0.75).to_f
      p2_z = depth * (params[:split_p2_ratio] || 0.85).to_f

      vertices = [
        [0.0, 0.0, 0.0], # 0: BL
        [w,   0.0, 0.0], # 1: BR
        [w,   h,   0.0], # 2: TR
        [0.0, h,   0.0], # 3: TL
        [p1_x, p1_y, p1_z], # 4: Ponto Crista 1
        [p2_x, p2_y, p2_z], # 5: Ponto Crista 2
        [w,   h * 0.4, depth * 0.3], # 6: Ponto Lateral Direito
        [0.0, h * 0.6, depth * 0.3]  # 7: Ponto Lateral Esquerdo
      ]

      faces = [
        [0, 1, 4],
        [1, 6, 4],
        [6, 5, 4],
        [6, 2, 5],
        [2, 3, 5],
        [3, 7, 5],
        [7, 4, 5],
        [7, 0, 4]
      ]

      analyze_mesh(vertices, faces, w, h, depth, 'split_diagonal', params)
    end

    # --------------------------------------------------------------------------
    # 4. PIRÂMIDE TRUNCADA OU AGUDA (4 ou 5 Facetas)
    # --------------------------------------------------------------------------
    def self.generate_pyramid(w, h, depth, params)
      cx = w * (params[:center_x_ratio] || 0.5).to_f
      cy = h * (params[:center_y_ratio] || 0.5).to_f
      top_w = (params[:top_width] || 0.0).to_f
      top_h = (params[:top_height] || 0.0).to_f

      vertices = [
        [0.0, 0.0, 0.0], # 0
        [w,   0.0, 0.0], # 1
        [w,   h,   0.0], # 2
        [0.0, h,   0.0]  # 3
      ]

      if top_w > 0.0 && top_h > 0.0
        # Pirâmide Truncada (5 faces: 4 trapézios + 1 topo plano)
        hw = top_w / 2.0
        hh = top_h / 2.0
        vertices << [cx - hw, cy - hh, depth] # 4: Top BL
        vertices << [cx + hw, cy - hh, depth] # 5: Top BR
        vertices << [cx + hw, cy + hh, depth] # 6: Top TR
        vertices << [cx - hw, cy + hh, depth] # 7: Top TL

        faces = [
          [0, 1, 5], [0, 5, 4], # Face Sul
          [1, 2, 6], [1, 6, 5], # Face Leste
          [2, 3, 7], [2, 7, 6], # Face Norte
          [3, 0, 4], [3, 4, 7], # Face Oeste
          [4, 5, 6], [4, 6, 7]  # Topo
        ]
      else
        # Pirâmide Aguda Simples (4 triângulos com ápice pontiagudo)
        vertices << [cx, cy, depth] # 4: Ápice
        faces = [
          [0, 1, 4],
          [1, 2, 4],
          [2, 3, 4],
          [3, 0, 4]
        ]
      end

      analyze_mesh(vertices, faces, w, h, depth, 'pyramid', params)
    end

    # --------------------------------------------------------------------------
    # 5. MALHA LIVRE PARAMÉTRICA (Custom Mesh)
    # --------------------------------------------------------------------------
    def self.generate_custom_mesh(w, h, depth, params)
      nx = [(params[:grid_x] || 3).to_i, 2].max
      ny = [(params[:grid_y] || 3).to_i, 2].max
      z_matrix = params[:z_matrix] # Array de alturas Z por ponto

      dx = w / (nx - 1)
      dy = h / (ny - 1)

      vertices = []
      idx = 0
      (0...ny).each do |iy|
        y = iy * dy
        (0...nx).each do |ix|
          x = ix * dx
          custom_z = if z_matrix && z_matrix[idx]
            z_matrix[idx].to_f
          else
            # Curvatura padrão ou ápice central
            (ix > 0 && ix < nx - 1 && iy > 0 && iy < ny - 1) ? depth : 0.0
          end
          vertices << [x, y, custom_z]
          idx += 1
        end
      end

      faces = []
      (0...ny - 1).each do |iy|
        (0...nx - 1).each do |ix|
          bl = iy * nx + ix
          br = bl + 1
          tl = (iy + 1) * nx + ix
          tr = tl + 1

          faces << [bl, br, tr]
          faces << [bl, tr, tl]
        end
      end

      analyze_mesh(vertices, faces, w, h, depth, 'custom_mesh', params)
    end

    # --------------------------------------------------------------------------
    # ANÁLISE TOPOLÓGICA DA MALHA: Normais, Arestas, Ângulos Diédricos e Dobras
    # --------------------------------------------------------------------------
    def self.analyze_mesh(vertices, faces, w, h, depth, typology, raw_params)
      # 1. Calcular normais e áreas de cada face
      face_normals = []
      face_areas = []

      faces.each do |f|
        p0 = vertices[f[0]]
        p1 = vertices[f[1]]
        p2 = vertices[f[2]]

        # Vetores v1 = p1 - p0, v2 = p2 - p0
        v1 = [p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]]
        v2 = [p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]]

        # Produto vetorial normal = v1 x v2
        nx = v1[1] * v2[2] - v1[2] * v2[1]
        ny = v1[2] * v2[0] - v1[0] * v2[2]
        nz = v1[0] * v2[1] - v1[1] * v2[0]
        len = Math.sqrt(nx * nx + ny * ny + nz * nz)

        if len > 1e-6
          face_normals << [nx / len, ny / len, nz / len]
          face_areas << (len / 2.0)
        else
          face_normals << [0.0, 0.0, 1.0]
          face_areas << 0.0
        end
      end

      # 2. Mapear arestas compartilhadas e calcular ângulos de dobra (vincos)
      edge_face_map = {}
      faces.each_with_index do |f, fi|
        f_size = f.size
        f_size.times do |i|
          va = f[i]
          vb = f[(i + 1) % f_size]
          edge_key = va < vb ? [va, vb] : [vb, va]
          edge_face_map[edge_key] ||= []
          edge_face_map[edge_key] << fi
        end
      end

      edges = []
      edge_face_map.each do |(va, vb), face_indices|
        if face_indices.size == 1
          # Aresta de contorno/perímetro (Boundary)
          edges << {
            v0: va,
            v1: vb,
            type: 'boundary',
            angle: 90.0, # Ângulo padrão de dobra da aba perimetral
            faces: face_indices
          }
        elsif face_indices.size == 2
          f1 = face_indices[0]
          f2 = face_indices[1]
          n1 = face_normals[f1]
          n2 = face_normals[f2]

          dot = n1[0] * n2[0] + n1[1] * n2[1] + n1[2] * n2[2]
          dot = [[dot, -1.0].max, 1.0].min
          angle_rad = Math.acos(dot)
          angle_deg = (angle_rad * 180.0 / Math::PI).round(1)

          # Determinar se é dobra de montanha (saliente para fora) ou vale
          # Ponto médio da aresta
          pa = vertices[va]
          pb = vertices[vb]
          mid = [(pa[0] + pb[0]) / 2.0, (pa[1] + pb[1]) / 2.0, (pa[2] + pb[2]) / 2.0]

          # Vértice oposto em face 1
          f1_opp = (faces[f1] - [va, vb]).first
          opp_p = vertices[f1_opp]
          vec_to_opp = [opp_p[0] - mid[0], opp_p[1] - mid[1], opp_p[2] - mid[2]]
          
          # Se o produto com a normal n2 é negativo -> dobra de montanha
          dp = vec_to_opp[0] * n2[0] + vec_to_opp[1] * n2[1] + vec_to_opp[2] * n2[2]
          fold_type = dp < 0.0 ? 'mountain' : 'valley'

          edges << {
            v0: va,
            v1: vb,
            type: fold_type,
            angle: angle_deg,
            faces: face_indices
          }
        end
      end

      {
        typology: typology,
        params: raw_params,
        width: w,
        height: h,
        depth: depth,
        vertices: vertices,
        faces: faces,
        face_normals: face_normals,
        face_areas: face_areas,
        edges: edges,
        total_area: face_areas.sum
      }
    end

    # --------------------------------------------------------------------------
    # CONSTRUIR BLOCO 3D NATIVO NO SKETCHUP
    # --------------------------------------------------------------------------
    def self.build_in_sketchup(mesh_data, origin = Geom::Point3d.new(0, 0, 0), tag_name = 'CS_ORIGAMI_3D')
      model = Sketchup.active_model
      model.start_operation('Criar Bloco Origami 3D', true)

      entities = model.active_entities
      group = entities.add_group
      group.name = "Origami_#{mesh_data[:typology]}_#{mesh_data[:width].to_i}x#{mesh_data[:height].to_i}"

      # Conversão de mm para polegadas do SketchUp
      scale = 1.0 / 25.4
      pts = mesh_data[:vertices].map do |v|
        Geom::Point3d.new(
          origin.x + v[0] * scale,
          origin.y + v[1] * scale,
          origin.z + v[2] * scale
        )
      end

      # Criar faces triangulares
      mesh_data[:faces].each_with_index do |f, idx|
        p0 = pts[f[0]]
        p1 = pts[f[1]]
        p2 = pts[f[2]]
        begin
          face = group.entities.add_face(p0, p1, p2)
          # Orientar face se a normal estiver para baixo
          if face && face.normal.z < 0 && mesh_data[:depth] > 0
            face.reverse!
          end
        rescue => e
          puts "[CS_Origami3D] Erro ao criar face #{idx}: #{e.message}"
        end
      end

      # Suavizar arestas internas de vinco ou manter vivas para visualização facetada
      group.entities.grep(Sketchup::Edge).each do |edge|
        edge.soft = false
        edge.smooth = false
      end

      # Gravar Atributos
      group.set_attribute(ATTR_DICT, 'typology', mesh_data[:typology])
      group.set_attribute(ATTR_DICT, 'width_mm', mesh_data[:width])
      group.set_attribute(ATTR_DICT, 'height_mm', mesh_data[:height])
      group.set_attribute(ATTR_DICT, 'depth_mm', mesh_data[:depth])
      group.set_attribute(ATTR_DICT, 'total_area_m2', (mesh_data[:total_area] / 1_000_000.0).round(4))

      model.commit_operation
      group
    end
  end
end
