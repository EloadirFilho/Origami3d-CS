# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Controlador do Diálogo Interativo Web (UI::HtmlDialog)
# ==============================================================================

require 'json'

module CS_Origami3D
  class StudioDialog
    @dialog = nil

    def self.show(tab = 'creator')
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end

      html_path = File.join(CS_Origami3D::PLUGIN_DIR, 'ui', 'dialog.html')
      unless File.exist?(html_path)
        UI.messagebox("Arquivo de interface não encontrado: #{html_path}")
        return
      end

      options = {
        dialog_title:    'CS Origami 3D · Estúdio de Volumetria & Facetação em ACM',
        preferences_key: 'CS_Origami3D_StudioDialog',
        scrollable:      true,
        resizable:       true,
        width:           1180,
        height:          780,
        min_width:       900,
        min_height:      600,
        style:           UI::HtmlDialog::STYLE_DIALOG
      }

      @dialog = UI::HtmlDialog.new(options)
      @dialog.set_file(html_path)
      register_callbacks(@dialog)
      @dialog.show
    end

    def self.register_callbacks(dialog)
      # 1. Ready: Envia lista de presets ao carregar
      dialog.add_action_callback('ready') do |action_context|
        presets = LibraryManager.list_presets
        js = "window.CS_ORIGAMI_APP && window.CS_ORIGAMI_APP.onPresetsLoaded(#{JSON.generate(presets)});"
        dialog.execute_script(js)
      end

      # 2. Criar Bloco 3D na Viewport do SketchUp
      dialog.add_action_callback('build_3d_block') do |action_context, json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        group = GeometryEngine.build_in_sketchup(mesh_data)
        UI.messagebox("Bloco Origami 3D criado com sucesso!\nDimensões: #{mesh_data[:width].to_i} x #{mesh_data[:height].to_i} mm\nProfundidade Z: #{mesh_data[:depth].to_i} mm")
      end

      # 3. Planificar 2D e Desenhar Chapa no SketchUp
      dialog.add_action_callback('place_unfolded_2d') do |action_context, json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        unfold_data = UnfoldEngine.unfold_mesh(mesh_data, params)
        # Posicionar ao lado do modelo
        origin = Geom::Point3d.new((mesh_data[:width] * 1.5) / 25.4, 0, 0)
        group = UnfoldEngine.place_unfolded_in_sketchup(unfold_data, origin)
        UI.messagebox("Chapa Planificada 2D inserida na cena!\nTamanho da Chapa Bruta: #{unfold_data[:sheet_width]} x #{unfold_data[:sheet_height]} mm")
      end

      # 4. Multiplicar Painel em Matriz de Fachada
      dialog.add_action_callback('multiply_panel') do |action_context, json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        panel_group = TessellationEngine.generate_panel(mesh_data, params)
        UI.messagebox("Painel de Fachada Tesselado gerado com sucesso!")
      end

      # 5. Exportar DXF CNC AC1009
      dialog.add_action_callback('export_dxf') do |action_context, json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        unfold_data = UnfoldEngine.unfold_mesh(mesh_data, params)

        default_name = "Origami_#{mesh_data[:typology]}_#{mesh_data[:width].to_i}x#{mesh_data[:height].to_i}.dxf"
        filepath = UI.savepanel('Salvar Arquivo DXF para CNC Router', '', default_name)
        if filepath && !filepath.empty?
          filepath += '.dxf' unless filepath.downcase.end_with?('.dxf')
          DxfExporter.export_to_file(filepath, unfold_data, { name: params[:name] || mesh_data[:typology] })
          UI.messagebox("Arquivo DXF CNC gerado com sucesso em:\n#{filepath}\n\nCamadas geradas:\n- CAMADA_CORTE (Corte Passante)\n- CAMADA_VINCO_V90 (Vincos em V)\n- CAMADA_FUROS (Rebites e Perfurações)")
        end
      end

      # 6. Salvar Modelo / Preset
      dialog.add_action_callback('save_preset') do |action_context, json_params|
        data = parse_json(json_params)
        name = data[:name] || 'Novo Bloco'
        typology = data[:typology] || 'diamond_classic'
        params = data[:params] || {}
        desc = data[:description] || ''
        thumb = data[:thumbnail]

        saved_path = LibraryManager.save_preset(name, typology, params, desc, thumb)
        presets = LibraryManager.list_presets
        js = "window.CS_ORIGAMI_APP && window.CS_ORIGAMI_APP.onPresetsLoaded(#{JSON.generate(presets)});"
        dialog.execute_script(js)
        UI.messagebox("Modelo '#{name}' salvo na biblioteca com sucesso!")
      end

      # 7. Obter dados de cálculo em tempo real para a UI
      dialog.add_action_callback('calculate_preview_data') do |action_context, json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        unfold_data = UnfoldEngine.unfold_mesh(mesh_data, params)

        payload = {
          mesh: mesh_data,
          unfold: {
            sheet_width: unfold_data[:sheet_width],
            sheet_height: unfold_data[:sheet_height],
            flange_count: unfold_data[:flanges].size,
            fold_lines_count: unfold_data[:fold_lines].size,
            rivet_holes_count: unfold_data[:rivet_holes].size,
            perforation_holes_count: unfold_data[:perforation_holes].size
          }
        }
        js = "window.CS_ORIGAMI_APP && window.CS_ORIGAMI_APP.onCalculateData(#{JSON.generate(payload)});"
        dialog.execute_script(js)
      end
    end

    private

    def self.parse_json(str)
      return {} if str.nil? || str.empty?
      begin
        JSON.parse(str, symbolize_names: true)
      rescue => e
        puts "[CS_Origami3D] JSON parse error: #{e.message}"
        {}
      end
    end
  end
end
