# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Motor de Multiplicação de Blocos e Tesselagem de Painéis
# ==============================================================================

module CS_Origami3D
  class TessellationEngine
    def self.generate_panel(mesh_data, options = {}, origin = Geom::Point3d.new(0, 0, 0))
      model = Sketchup.active_model
      model.start_operation('Multiplicar Painel Origami 3D', true)

      mode = options[:sizing_mode] || 'by_count' # 'by_count' ou 'by_total_size'
      gap_mm = (options[:joint_gap_mm] || 5.0).to_f # Junta de dilatação entre blocos

      flip_x_alternate = options.fetch(:flip_x_alternate, true)  # Espelhar colunas ímpares
      flip_y_alternate = options.fetch(:flip_y_alternate, false) # Espelhar linhas ímpares
      rotate_alternate = options.fetch(:rotate_alternate, false) # Girar 180° alternado

      w = mesh_data[:width].to_f
      h = mesh_data[:height].to_f

      if mode == 'by_total_size'
        total_w = (options[:total_width_mm] || 3000.0).to_f
        total_h = (options[:total_height_mm] || 2500.0).to_f
        cols = [((total_w + gap_mm) / (w + gap_mm)).round, 1].max
        rows = [((total_h + gap_mm) / (h + gap_mm)).round, 1].max
        # Recalcular largura e altura unitária para fechar exatamente no vão
        w = ((total_w - (cols - 1) * gap_mm) / cols).round(1)
        h = ((total_h - (rows - 1) * gap_mm) / rows).round(1)
        
        # Regenerar mesh com novas dimensões ajustadas
        updated_params = mesh_data[:params].dup
        updated_params[:width] = w
        updated_params[:height] = h
        mesh_data = GeometryEngine.generate_block_mesh(updated_params)
      else
        cols = [(options[:cols] || 4).to_i, 1].max
        rows = [(options[:rows] || 3).to_i, 1].max
      end

      # Criar ComponentDefinition base para o bloco unitário (Muito mais rápido e leve)
      comp_def = create_block_definition(model, mesh_data)

      # Grupo principal do painel
      panel_group = model.active_entities.add_group
      panel_group.name = "Painel_Origami_#{cols}x#{rows}_#{w.to_i}x#{h.to_i}mm"

      scale = 1.0 / 25.4
      w_inch = w * scale
      h_inch = h * scale
      gap_inch = gap_mm * scale

      (0...rows).each do |r|
        (0...cols).each do |c|
          pos_x = c * (w_inch + gap_inch)
          pos_y = r * (h_inch + gap_inch)

          trans_pos = Geom::Transformation.translation(Geom::Vector3d.new(pos_x, pos_y, 0))

          # Espelhamento em X nas colunas ímpares
          trans_flip_x = Geom::Transformation.new
          if flip_x_alternate && c.odd?
            # Espelha em torno do centro do bloco em X
            center_x = w_inch / 2.0
            t_to_center = Geom::Transformation.translation(Geom::Vector3d.new(center_x, 0, 0))
            t_scale = Geom::Transformation.scaling(Geom::Point3d.new(0, 0, 0), -1.0, 1.0, 1.0)
            t_from_center = Geom::Transformation.translation(Geom::Vector3d.new(-center_x, 0, 0))
            trans_flip_x = t_to_center * t_scale * t_from_center
          end

          # Espelhamento em Y nas linhas ímpares
          trans_flip_y = Geom::Transformation.new
          if flip_y_alternate && r.odd?
            center_y = h_inch / 2.0
            t_to_center = Geom::Transformation.translation(Geom::Vector3d.new(0, center_y, 0))
            t_scale = Geom::Transformation.scaling(Geom::Point3d.new(0, 0, 0), 1.0, -1.0, 1.0)
            t_from_center = Geom::Transformation.translation(Geom::Vector3d.new(0, -center_y, 0))
            trans_flip_y = t_to_center * t_scale * t_from_center
          end

          # Rotação 180° alternada estilo xadrez
          trans_rot = Geom::Transformation.new
          if rotate_alternate && (r + c).odd?
            center_pt = Geom::Point3d.new(w_inch / 2.0, h_inch / 2.0, 0)
            trans_rot = Geom::Transformation.rotation(center_pt, Geom::Vector3d.new(0, 0, 1), 180.degrees)
          end

          full_trans = trans_pos * trans_flip_x * trans_flip_y * trans_rot
          instance = panel_group.entities.add_instance(comp_def, full_trans)
          instance.name = "Bloco_L#{r + 1}_C#{c + 1}"
        end
      end

      # Mover para a origem solicitada
      panel_group.transform!(Geom::Transformation.translation(origin.to_a))

      model.commit_operation
      panel_group
    end

    private

    def self.create_block_definition(model, mesh_data)
      name = "CS_Origami_Def_#{mesh_data[:typology]}_#{mesh_data[:width].to_i}x#{mesh_data[:height].to_i}"
      existing = model.definitions[name]
      return existing if existing && !existing.deleted?

      comp_def = model.definitions.add(name)
      scale = 1.0 / 25.4
      pts = mesh_data[:vertices].map do |v|
        Geom::Point3d.new(v[0] * scale, v[1] * scale, v[2] * scale)
      end

      mesh_data[:faces].each do |f|
        begin
          face = comp_def.entities.add_face(pts[f[0]], pts[f[1]], pts[f[2]])
          face.reverse! if face && face.normal.z < 0 && mesh_data[:depth] > 0
        rescue => e
          puts "[CS_Origami3D] Erro ao criar face no componente: #{e.message}"
        end
      end

      comp_def
    end
  end
end
