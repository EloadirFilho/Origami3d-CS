# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Motor de Planificação / Desdobramento 2D de Chapas em ACM
# ==============================================================================

module CS_Origami3D
  class UnfoldEngine
    # Abaixo deste ângulo (graus) duas facetas são consideradas coplanares: não há vinco.
    FLAT_ANGLE_TOL = 0.5
    # Penetração mínima (mm) entre polígonos para acusar sobreposição na chapa.
    OVERLAP_TOL = 0.05

    # Planifica a malha 3D preservando as dimensões reais de cada faceta (True Lengths)
    # Adiciona abas de fixação perimetrais com alívios a 45° e furações CNC
    def self.unfold_mesh(mesh_data, options = {})
      flange_width   = (options[:flange_width] || 35.0).to_f # mm
      relief_angle   = (options[:relief_angle] || 45.0).to_f # graus
      has_rivet_holes= options.fetch(:rivet_holes, true)
      rivet_spacing  = (options[:rivet_spacing] || 150.0).to_f # mm
      rivet_dia      = (options[:rivet_dia] || 4.5).to_f # mm
      # Índices de faces com perfuração (só quando a perfuração está ativada)
      perforated_faces = options[:perforated] ? (options[:perforated_faces] || []) : []
      perf_hole_dia  = (options[:perf_hole_dia] || 8.0).to_f # mm
      perf_pitch     = (options[:perf_pitch] || 18.0).to_f # mm

      vertices_3d = mesh_data[:vertices]
      faces_3d    = mesh_data[:faces]
      edges_3d    = mesh_data[:edges]

      # 1. Planificação das Facetas via Árvore de Desdobramento (True-Length Trilateration)
      flat_faces, fold_lines, boundary_edges, seam_lines = unfold_triangles(vertices_3d, faces_3d, edges_3d)

      # 2. Gerar Abas de Fixação Perimetrais (Flanges) com Chanfros de Alívio a 45°
      flanges = generate_perimeter_flanges(merge_collinear(boundary_edges), flange_width, relief_angle)

      # 3. Gerar Furações para Rebites nas Abas
      rivet_holes = []
      if has_rivet_holes
        rivet_holes = generate_rivet_holes(flanges, rivet_spacing, rivet_dia)
      end

      # 4. Gerar Padrão de Perfuração Decorativa/Acústica nas Facetas Selecionadas
      perforation_holes = []
      perforated_faces.each do |face_idx|
        ff = flat_faces[face_idx.to_i]
        next unless ff
        holes = generate_face_perforations(ff[:coords_2d], perf_hole_dia, perf_pitch)
        perforation_holes.concat(holes)
      end

      # 5. Calcular Bounding Box da Chapa Planificada
      all_pts = flat_faces.flat_map { |ff| ff[:coords_2d] } + flanges.flat_map { |fl| fl[:polygon] }
      xs = all_pts.map { |p| p[0] }
      ys = all_pts.map { |p| p[1] }
      min_x = xs.min || 0.0
      max_x = xs.max || 0.0
      min_y = ys.min || 0.0
      max_y = ys.max || 0.0

      sheet_w = (max_x - min_x).round(1)
      sheet_h = (max_y - min_y).round(1)

      {
        flat_faces: flat_faces,
        fold_lines: fold_lines,
        seam_lines: seam_lines,
        flanges: flanges,
        rivet_holes: rivet_holes,
        perforation_holes: perforation_holes,
        sheet_width: sheet_w,
        sheet_height: sheet_h,
        bounding_box: { min_x: min_x, max_x: max_x, min_y: min_y, max_y: max_y },
        flange_width: flange_width,
        overlaps: find_overlaps(flat_faces, flanges)
      }
    end

    # --------------------------------------------------------------------------
    # DESDOBRAMENTO MATEMÁTICO SEM DISTORÇÃO (Trilateração 2D)
    # --------------------------------------------------------------------------
    def self.unfold_triangles(vertices_3d, faces_3d, edges_3d)
      return [[], [], [], []] if faces_3d.empty?

      edge_info = {}
      edges_3d.each { |e| edge_info[[e[:v0], e[:v1]].sort] = e }

      # Mapear vizinhança entre faces
      edge_to_faces = Hash.new { |hsh, k| hsh[k] = [] }
      faces_3d.each_with_index do |f, fi|
        3.times { |i| edge_to_faces[[f[i], f[(i + 1) % 3]].sort] << fi }
      end

      # Cada face guarda as próprias coordenadas 2D: um vértice 3D pode aparecer
      # em posições diferentes da chapa (dos dois lados de uma emenda).
      face_coords = {}

      # Posicionar a face raiz no plano 2D (sentido anti-horário preservado)
      v0, v1, v2 = faces_3d[0]
      l01 = dist3d(vertices_3d[v0], vertices_3d[v1])
      l02 = dist3d(vertices_3d[v0], vertices_3d[v2])
      l12 = dist3d(vertices_3d[v1], vertices_3d[v2])
      cos_a = (l01 * l01 + l02 * l02 - l12 * l12) / (2.0 * l01 * l02 + 1e-9)
      cos_a = [[cos_a, -1.0].max, 1.0].min
      sin_a = Math.sqrt([1.0 - cos_a * cos_a, 0.0].max)
      face_coords[0] = { v0 => [0.0, 0.0], v1 => [l01, 0.0], v2 => [l02 * cos_a, l02 * sin_a] }

      # Árvore de desdobramento (Prim): une sempre pela aresta de menor ângulo de
      # dobra, assim facetas coplanares ficam juntas e as emendas caem nos vincos mais fortes.
      tree_edges = {}
      fold_lines = []
      until face_coords.size == faces_3d.size
        best = nil
        face_coords.each_key do |fi|
          f = faces_3d[fi]
          3.times do |i|
            key = [f[i], f[(i + 1) % 3]].sort
            edge_to_faces[key].each do |n_fi|
              next if face_coords[n_fi]
              angle = edge_info[key] ? edge_info[key][:angle] : 90.0
              best = [angle, fi, n_fi, key] if best.nil? || angle < best[0]
            end
          end
        end
        break unless best # malha desconexa: o restante fica de fora

        angle, curr_fi, n_fi, (va, vb) = best
        curr = face_coords[curr_fi]
        pa_2d = curr[va]
        pb_2d = curr[vb]
        opp_2d = curr[(faces_3d[curr_fi] - [va, vb]).first]

        # Trilateração 2D do terceiro vértice da face vizinha, do lado oposto da aresta
        vc = (faces_3d[n_fi] - [va, vb]).first
        pc_3d = vertices_3d[vc]
        r_a = dist3d(vertices_3d[va], pc_3d)
        r_b = dist3d(vertices_3d[vb], pc_3d)
        face_coords[n_fi] = { va => pa_2d, vb => pb_2d, vc => trilaterate_2d(pa_2d, pb_2d, r_a, r_b, opp_2d) }
        tree_edges[[va, vb]] = true

        # Facetas coplanares continuam unidas, mas sem linha de vinco
        next if angle < FLAT_ANGLE_TOL

        e_info = edge_info[[va, vb]]
        fold_lines << {
          start: pa_2d,
          end: pb_2d,
          v0: va,
          v1: vb,
          angle: angle,
          type: e_info ? e_info[:type] : 'mountain'
        }
      end

      # Armazenar faces planificadas
      flat_faces = []
      faces_3d.each_with_index do |f, fi|
        next unless face_coords[fi]
        flat_faces << {
          index: fi,
          vertices: f,
          coords_2d: f.map { |vi| face_coords[fi][vi] }
        }
      end

      # Arestas de contorno (1 face) e emendas (arestas internas fora da árvore,
      # que viram corte dos dois lados) seguindo o sentido de cada face.
      boundary_edges = []
      seam_lines = []
      flat_faces.each do |ff|
        f = ff[:vertices]
        3.times do |i|
          va = f[i]
          vb = f[(i + 1) % 3]
          key = [va, vb].sort
          next if tree_edges[key]
          seg = {
            face: ff[:index], va: va, vb: vb,
            start: ff[:coords_2d][i], end: ff[:coords_2d][(i + 1) % 3],
            opposite: ff[:coords_2d][(i + 2) % 3]
          }
          if edge_to_faces[key].size == 1
            boundary_edges << seg
          else
            seam_lines << seg
          end
        end
      end

      [flat_faces, fold_lines, boundary_edges, seam_lines]
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
    def self.generate_perimeter_flanges(boundary_edges, flange_w, relief_ang)
      flanges = []
      relief_rad = (relief_ang * Math::PI / 180.0)
      chamfer_offset = flange_w / Math.tan(relief_rad)

      boundary_edges.each do |seg|
        p_a = seg[:start]
        p_b = seg[:end]

        dx = p_b[0] - p_a[0]
        dy = p_b[1] - p_a[1]
        len = Math.sqrt(dx * dx + dy * dy)
        next if len < 1e-4

        ux = dx / len
        uy = dy / len

        # Vetor normal apontando para fora da chapa: lado oposto ao vértice
        # restante da faceta à qual a aresta pertence
        nx = uy
        ny = -ux
        opp = seg[:opposite]
        if (opp[0] - p_a[0]) * nx + (opp[1] - p_a[1]) * ny > 0
          nx = -nx
          ny = -ny
        end

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
          face: seg[:face],
          edge_va: seg[:va],
          edge_vb: seg[:vb],
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

    # Une arestas de contorno consecutivas e colineares numa só aba
    # (ex.: lado reto formado por duas facetas coplanares).
    def self.merge_collinear(segments, tol = 1e-3)
      segs = segments.map(&:dup)
      merged = true
      while merged
        merged = false
        segs.each do |s|
          t = segs.find do |o|
            next false if o.equal?(s) || dist2d(o[:start], s[:end]) > tol
            # colinear: B de s fica sobre a reta A(s)→B(o)
            dist_pt_line(s[:end], s[:start], o[:end]) < tol
          end
          next unless t
          s[:end] = t[:end]
          s[:vb] = t[:vb]
          segs.delete(t)
          merged = true
          break
        end
      end
      segs
    end

    # --------------------------------------------------------------------------
    # DETECÇÃO DE SOBREPOSIÇÃO NA CHAPA (facetas e abas são polígonos convexos)
    # --------------------------------------------------------------------------
    def self.find_overlaps(flat_faces, flanges)
      polys = flat_faces.map { |ff| { kind: 'face', index: ff[:index], pts: ff[:coords_2d] } }
      flanges.each_with_index { |fl, i| polys << { kind: 'flange', index: i, pts: fl[:polygon] } }

      overlaps = []
      polys.each_with_index do |a, i|
        polys[(i + 1)..-1].each do |b|
          next unless convex_overlap?(a[:pts], b[:pts])
          overlaps << { a: { kind: a[:kind], index: a[:index] }, b: { kind: b[:kind], index: b[:index] } }
        end
      end
      overlaps
    end

    # Teorema do eixo separador: só acusa quando a penetração passa de OVERLAP_TOL,
    # então polígonos que apenas se tocam numa aresta ou vértice não contam.
    def self.convex_overlap?(pa, pb)
      [pa, pb].each do |poly|
        poly.size.times do |i|
          p1 = poly[i]
          p2 = poly[(i + 1) % poly.size]
          ax = -(p2[1] - p1[1])
          ay = p2[0] - p1[0]
          len = Math.sqrt(ax * ax + ay * ay)
          next if len < 1e-9
          ax /= len
          ay /= len
          proj_a = pa.map { |p| p[0] * ax + p[1] * ay }
          proj_b = pb.map { |p| p[0] * ax + p[1] * ay }
          depth = [proj_a.max, proj_b.max].min - [proj_a.min, proj_b.min].max
          return false if depth <= OVERLAP_TOL
        end
      end
      true
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
      begin
        unfold_group = draw_unfolded(model.active_entities, unfold_data, origin)
        model.commit_operation
        unfold_group
      rescue
        model.abort_operation
        raise
      end
    end

    def self.draw_unfolded(entities, unfold_data, origin)
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
        unfold_group.entities.add_line(p0, p1)
      end

      # 4. Desenhar Furos de Rebites e Perfurações
      all_holes = unfold_data[:rivet_holes] + unfold_data[:perforation_holes]
      all_holes.each do |h|
        center = Geom::Point3d.new(origin.x + h[:center][0] * scale, origin.y + h[:center][1] * scale, origin.z)
        radius = (h[:diameter] / 2.0) * scale
        unfold_group.entities.add_circle(center, Geom::Vector3d.new(0, 0, 1), radius, 16)
      end

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

    def self.dist_pt_line(p, a, b)
      dx = b[0] - a[0]
      dy = b[1] - a[1]
      len = Math.sqrt(dx * dx + dy * dy)
      return dist2d(p, a) if len < 1e-9
      ((p[0] - a[0]) * dy - (p[1] - a[1]) * dx).abs / len
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
