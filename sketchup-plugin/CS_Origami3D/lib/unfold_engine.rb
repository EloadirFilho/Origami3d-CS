# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Motor de Planificação / Desdobramento 2D de Chapas em ACM
# ==============================================================================

module CS_Origami3D
  class UnfoldEngine
    # Planifica a malha 3D preservando as dimensões reais de cada faceta (True Lengths)
    # Adiciona abas de fixação perimetrais com alívios a 45° e furações CNC
    def self.unfold_mesh(mesh_data, options = {})
      flange_width   = (options[:flange_width] || 35.0).to_f # mm
      relief_angle   = (options[:relief_angle] || 45.0).to_f # graus
      has_rivet_holes= options.fetch(:rivet_holes, true)
      rivet_spacing  = (options[:rivet_spacing] || 150.0).to_f # mm
      rivet_dia      = (options[:rivet_dia] || 4.5).to_f # mm
      perforated_faces = options[:perforated_faces] || [] # Índices de faces com perfuração
      perf_hole_dia  = (options[:perf_hole_dia] || 8.0).to_f # mm
      perf_pitch     = (options[:perf_pitch] || 18.0).to_f # mm

      vertices_3d = mesh_data[:vertices]
      faces_3d    = mesh_data[:faces]
      edges_3d    = mesh_data[:edges]

      # 1. Planificação das Facetas via Árvore de Desdobramento (True-Length Trilateration)
      flat_faces, flat_vertices, fold_lines, boundary_loops = unfold_triangles(vertices_3d, faces_3d, edges_3d)

      # 2. Gerar Abas de Fixação Perimetrais (Flanges) com Chanfros de Alívio a 45°
      flanges = generate_perimeter_flanges(boundary_loops, flat_vertices, flange_width, relief_angle)

      # 3. Gerar Furações para Rebites nas Abas
      rivet_holes = []
      if has_rivet_holes
        rivet_holes = generate_rivet_holes(flanges, rivet_spacing, rivet_dia)
      end

      # 4. Gerar Padrão de Perfuração Decorativa/Acústica nas Facetas Selecionadas
      perforation_holes = []
      perforated_faces.each do |face_idx|
        if flat_faces[face_idx]
          pts = flat_faces[face_idx][:vertices].map { |vi| flat_vertices[vi] }
          holes = generate_face_perforations(pts, perf_hole_dia, perf_pitch)
          perforation_holes.concat(holes)
        end
      end

      # 5. Calcular Bounding Box da Chapa Planificada
      all_pts = flat_vertices.values + flanges.flat_map { |fl| fl[:polygon] }
      xs = all_pts.map { |p| p[0] }
      ys = all_pts.map { |p| p[1] }
      min_x = xs.min || 0.0
      max_x = xs.max || 0.0
      min_y = ys.min || 0.0
      max_y = ys.max || 0.0

      sheet_w = (max_x - min_x).round(1)
      sheet_h = (max_y - min_y).round(1)

      {
        flat_vertices: flat_vertices,
        flat_faces: flat_faces,
        fold_lines: fold_lines,
        boundary_loops: boundary_loops,
        flanges: flanges,
        rivet_holes: rivet_holes,
        perforation_holes: perforation_holes,
        sheet_width: sheet_w,
        sheet_height: sheet_h,
        bounding_box: { min_x: min_x, max_x: max_x, min_y: min_y, max_y: max_y },
        flange_width: flange_width
      }
    end

    # --------------------------------------------------------------------------
    # DESDOBRAMENTO MATEMÁTICO SEM DISTORÇÃO (Trilateração 2D)
    # --------------------------------------------------------------------------
    def self.unfold_triangles(vertices_3d, faces_3d, edges_3d)
      flat_vertices = {} # 2D coords { vert_id => [x, y] }
      flat_faces = []
      fold_lines = []

      return [flat_faces, flat_vertices, fold_lines, []] if faces_3d.empty?

      # Mapear vizinhança entre faces
      edge_to_faces = {}
      faces_3d.each_with_index do |f, fi|
        3.times do |i|
          va = f[i]
          vb = f[(i + 1) % 3]
          key = va < vb ? [va, vb] : [vb, va]
          edge_to_faces[key] ||= []
          edge_to_faces[key] << fi
        end
      end

      # Começar pela primeira face (Face Raiz)
      f0 = faces_3d[0]
      v0, v1, v2 = f0[0], f0[1], f0[2]

      p0 = vertices_3d[v0]
      p1 = vertices_3d[v1]
      p2 = vertices_3d[v2]

      l01 = dist3d(p0, p1)
      l02 = dist3d(p0, p2)
      l12 = dist3d(p1, p2)

      # Posicionar Face 0 no plano 2D
      flat_vertices[v0] = [0.0, 0.0]
      flat_vertices[v1] = [l01, 0.0]

      # Ângulo do vértice 0 usando Lei dos Cossenos
      cos_a = (l01 * l01 + l02 * l02 - l12 * l12) / (2.0 * l01 * l02 + 1e-9)
      cos_a = [[cos_a, -1.0].max, 1.0].min
      sin_a = Math.sqrt([1.0 - cos_a * cos_a, 0.0].max)
      flat_vertices[v2] = [l02 * cos_a, l02 * sin_a]

      visited_faces = { 0 => true }
      queue = [0]

      while !queue.empty?
        curr_fi = queue.shift
        curr_f = faces_3d[curr_fi]

        3.times do |i|
          va = curr_f[i]
          vb = curr_f[(i + 1) % 3]
          key = va < vb ? [va, vb] : [vb, va]

          neighbors = edge_to_faces[key] || []
          neighbors.each do |n_fi|
            next if visited_faces[n_fi]

            visited_faces[n_fi] = true
            queue << n_fi

            # Terceiro vértice da face vizinha
            n_f = faces_3d[n_fi]
            vc = (n_f - [va, vb]).first

            # Trilateração 2D para achar vc a partir de va e vb conhecidos
            pa_2d = flat_vertices[va]
            pb_2d = flat_vertices[vb]
            opp_2d = flat_vertices[(curr_f - [va, vb]).first]

            pc_3d = vertices_3d[vc]
            r_a = dist3d(vertices_3d[va], pc_3d)
            r_b = dist3d(vertices_3d[vb], pc_3d)

            flat_vc = trilaterate_2d(pa_2d, pb_2d, r_a, r_b, opp_2d)
            flat_vertices[vc] = flat_vc

            # Registra linha de vinco interna
            e_info = edges_3d.find { |e| (e[:v0] == va && e[:v1] == vb) || (e[:v0] == vb && e[:v1] == va) }
            angle = e_info ? e_info[:angle] : 90.0
            ftype = e_info ? e_info[:type] : 'mountain'

            fold_lines << {
              start: pa_2d,
              end: pb_2d,
              v0: va,
              v1: vb,
              angle: angle,
              type: ftype
            }
          end
        end
      end

      # Armazenar faces planificadas
      faces_3d.each_with_index do |f, fi|
        flat_faces << {
          index: fi,
          vertices: f,
          coords_2d: f.map { |vi| flat_vertices[vi] }
        }
      end

      # Arestas de contorno perimetral (que possuem apenas 1 face incidente)
      boundary_edges = []
      edge_to_faces.each do |(va, vb), face_indices|
        if face_indices.size == 1
          boundary_edges << [va, vb]
        end
      end

      [flat_faces, flat_vertices, fold_lines, boundary_edges]
    end

    # --------------------------------------------------------------------------
    # TRILATERAÇÃO 2D (Calcula posição do terceiro ponto preservando distâncias)
    # --------------------------------------------------------------------------
    def self.trilaterate_2d(p1, p2, r1, r2, opp_ref)
      dx = p2[0] - p1[0]
      dy = p2[1] - p1[1]
      d = Math.sqrt(dx * dx + dy * dy)
      d = 1e-6 if d < 1e-6

      a = (r1 * r1 - r2 * r2 + d * d) / (2.0 * d)
      h2 = r1 * r1 - a * a
      h = Math.sqrt([h2, 0.0].max)

      # Vetor base unitário de p1 para p2
      ux = dx / d
      uy = dy / d

      # Vetor normal perpendicular
      nx = -uy
      ny = ux

      # Ponto base
      bx = p1[0] + a * ux
      by = p1[1] + a * uy

      # Duas possíveis soluções (esquerda e direita da aresta)
      sol1 = [bx + h * nx, by + h * ny]
      sol2 = [bx - h * nx, by - h * ny]

      # A solução correta deve ficar do lado OPOSTO ao ponto de referência opp_ref
      d1 = dist2d(sol1, opp_ref)
      d2 = dist2d(sol2, opp_ref)

      d1 > d2 ? sol1 : sol2
    end

    # --------------------------------------------------------------------------
    # GERAÇÃO DE ABAS PERIMETRAIS COM CHANFRO DE ALÍVIO A 45°
    # --------------------------------------------------------------------------
    def self.generate_perimeter_flanges(boundary_edges, flat_vertices, flange_w, relief_ang)
      flanges = []
      relief_rad = (relief_ang * Math::PI / 180.0)
      chamfer_offset = flange_w / Math.tan(relief_rad)

      boundary_edges.each do |(va, vb)|
        p_a = flat_vertices[va]
        p_b = flat_vertices[vb]
        next unless p_a && p_b

        dx = p_b[0] - p_a[0]
        dy = p_b[1] - p_a[1]
        len = Math.sqrt(dx * dx + dy * dy)
        next if len < 1e-4

        ux = dx / len
        uy = dy / len

        # Vetor normal apontando para fora da chapa
        # Convencionado normal à direita da direção A -> B
        nx = uy
        ny = -ux

        # Vértices da aba trapezoidal com chanfro
        # A' = A + chanfro * U + flange_w * N
        # B' = B - chanfro * U + flange_w * N
        actual_chamfer = [chamfer_offset, len * 0.35].min

        p_a_prime = [
          p_a[0] + actual_chamfer * ux + flange_w * nx,
          p_a[1] + actual_chamfer * uy + flange_w * ny
        ]
        p_b_prime = [
          p_b[0] - actual_chamfer * ux + flange_w * nx,
          p_b[1] - actual_chamfer * uy + flange_w * ny
        ]

        flanges << {
          edge_va: va,
          edge_vb: vb,
          base_start: p_a,
          base_end: p_b,
          tab_start: p_a_prime,
          tab_end: p_b_prime,
          polygon: [p_a, p_a_prime, p_b_prime, p_b],
          flange_width: flange_w,
          normal: [nx, ny],
          length: len
        }
      end

      flanges
    end

    # --------------------------------------------------------------------------
    # FURAÇÕES PARAMÉTRICAS PARA REBITES NAS ABAS
    # --------------------------------------------------------------------------
    def self.generate_rivet_holes(flanges, spacing, dia)
      holes = []
      flanges.each do |fl|
        len = fl[:length]
        # Pelo menos 1 furo central se a aba for menor que o espaçamento
        num_holes = [(len / spacing).floor, 1].max
        step = len / (num_holes + 1)

        p_a = fl[:base_start]
        p_b = fl[:base_end]
        dx = (p_b[0] - p_a[0]) / len
        dy = (p_b[1] - p_a[1]) / len
        nx = fl[:normal][0]
        ny = fl[:normal][1]

        # Centralizado na largura da aba
        mid_tab_dist = fl[:flange_width] / 2.0

        (1..num_holes).each do |i|
          t = i * step
          hx = p_a[0] + t * dx + mid_tab_dist * nx
          hy = p_a[1] + t * dy + mid_tab_dist * ny
          holes << { center: [hx, hy], diameter: dia }
        end
      end
      holes
    end

    # --------------------------------------------------------------------------
    # PADRÃO DE PERFURAÇÃO EM FACETAS SELECIONADAS (Foto 2)
    # --------------------------------------------------------------------------
    def self.generate_face_perforations(triangle_pts, hole_dia, pitch)
      holes = []
      # Bounding box do triângulo
      xs = triangle_pts.map { |p| p[0] }
      ys = triangle_pts.map { |p| p[1] }
      min_x, max_x = xs.min, xs.max
      min_y, max_y = ys.min, ys.max

      margin = hole_dia * 2.0 # Margem de afastamento das arestas/vincos

      y = min_y + margin
      while y <= max_y - margin
        x = min_x + margin
        while x <= max_x - margin
          # Testar se o ponto está dentro do triângulo e afastado das bordas
          if point_in_triangle([x, y], triangle_pts) && dist_to_edges([x, y], triangle_pts) >= margin
            holes << { center: [x, y], diameter: hole_dia }
          end
          x += pitch
        end
        y += pitch
      end

      holes
    end

    # --------------------------------------------------------------------------
    # DESENHAR CHAPA PLANIFICADA 2D NA VIEWPORT DO SKETCHUP
    # --------------------------------------------------------------------------
    def self.place_unfolded_in_sketchup(unfold_data, origin = Geom::Point3d.new(0, 0, 0))
      model = Sketchup.active_model
      model.start_operation('Inserir Chapa Planificada 2D', true)

      entities = model.active_entities
      unfold_group = entities.add_group
      unfold_group.name = "Chapa_Planificada_ACM_#{unfold_data[:sheet_width].to_i}x#{unfold_data[:sheet_height].to_i}mm"

      scale = 1.0 / 25.4

      # 1. Desenhar Contorno das Abas e Chapa (Corte Passante)
      unfold_data[:flanges].each do |fl|
        poly_pts = fl[:polygon].map do |pt|
          Geom::Point3d.new(origin.x + pt[0] * scale, origin.y + pt[1] * scale, origin.z)
        end
        begin
          face = unfold_group.entities.add_face(poly_pts)
          face.material = 'LightGray' if face
        rescue => e
          puts "[CS_Origami3D] Flange poly: #{e.message}"
        end
      end

      # 2. Desenhar Facetas Centrais
      unfold_data[:flat_faces].each do |ff|
        poly_pts = ff[:coords_2d].map do |pt|
          Geom::Point3d.new(origin.x + pt[0] * scale, origin.y + pt[1] * scale, origin.z)
        end
        begin
          face = unfold_group.entities.add_face(poly_pts)
          face.material = 'White' if face
        rescue => e
          puts "[CS_Origami3D] Central face: #{e.message}"
        end
      end

      # 3. Desenhar Linhas de Vinco em V (Cores Vivas para Diferenciar no SketchUp)
      unfold_data[:fold_lines].each do |fl|
        p0 = Geom::Point3d.new(origin.x + fl[:start][0] * scale, origin.y + fl[:start][1] * scale, origin.z)
        p1 = Geom::Point3d.new(origin.x + fl[:end][0] * scale, origin.y + fl[:end][1] * scale, origin.z)
        edge = unfold_group.entities.add_line(p0, p1)
      end

      # 4. Desenhar Furos de Rebites e Perfurações
      all_holes = unfold_data[:rivet_holes] + unfold_data[:perforation_holes]
      all_holes.each do |h|
        center = Geom::Point3d.new(origin.x + h[:center][0] * scale, origin.y + h[:center][1] * scale, origin.z)
        radius = (h[:diameter] / 2.0) * scale
        unfold_group.entities.add_circle(center, Geom::Vector3d.new(0, 0, 1), radius, 16)
      end

      model.commit_operation
      unfold_group
    end

    # Utilitários geométricos
    def self.dist3d(a, b)
      dx = a[0] - b[0]
      dy = a[1] - b[1]
      dz = a[2] - b[2]
      Math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    def self.dist2d(a, b)
      dx = a[0] - b[0]
      dy = a[1] - b[1]
      Math.sqrt(dx * dx + dy * dy)
    end

    def self.point_in_triangle(p, tri)
      p0, p1, p2 = tri[0], tri[1], tri[2]
      d1 = sign(p, p0, p1)
      d2 = sign(p, p1, p2)
      d3 = sign(p, p2, p0)
      has_neg = (d1 < 0) || (d2 < 0) || (d3 < 0)
      has_pos = (d1 > 0) || (d2 > 0) || (d3 > 0)
      !(has_neg && has_pos)
    end

    def self.sign(p1, p2, p3)
      (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    end

    def self.dist_to_edges(p, tri)
      dists = [
        dist_pt_seg(p, tri[0], tri[1]),
        dist_pt_seg(p, tri[1], tri[2]),
        dist_pt_seg(p, tri[2], tri[0])
      ]
      dists.min
    end

    def self.dist_pt_seg(p, a, b)
      dx = b[0] - a[0]
      dy = b[1] - a[1]
      l2 = dx * dx + dy * dy
      return dist2d(p, a) if l2 < 1e-6
      t = [0.0, [1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2].min].max
      proj = [a[0] + t * dx, a[1] + t * dy]
      dist2d(p, proj)
    end
  end
end
