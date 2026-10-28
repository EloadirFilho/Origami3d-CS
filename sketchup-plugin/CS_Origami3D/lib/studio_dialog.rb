# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Controlador do Diálogo Interativo Web (UI::HtmlDialog)
# ==============================================================================

require 'json'

module CS_Origami3D
  class StudioDialog
    @dialog = nil
    @pending_tab = 'creator'
    @pending_params = nil

    # tab: aba inicial; params: parâmetros de um bloco existente para editar
    def self.show(tab = 'creator', params = nil)
      if @dialog && @dialog.visible?
        apply_state(tab, params)
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

      # Aplicados quando a página avisar que está pronta (callback 'ready')
      @pending_tab = tab
      @pending_params = params

      @dialog = UI::HtmlDialog.new(options)
      @dialog.set_file(html_path)
      register_callbacks(@dialog)
      @dialog.show
    end

    def self.apply_state(tab, params)
      call_js('loadParams', params) if params
      call_js('switchTab', tab) if tab
    end

    def self.call_js(method, *args)
      return unless @dialog
      js_args = args.map { |a| JSON.generate(a) }.join(', ')
      @dialog.execute_script("window.CS_ORIGAMI_APP && window.CS_ORIGAMI_APP.#{method}(#{js_args});")
    end

    def self.report_error(action, error)
      puts "[CS_Origami3D] #{action}: #{error.class}: #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}"
      UI.messagebox("Erro em \"#{action}\":\n#{error.message}")
    end

    def self.overlap_warning(unfold_data)
      "ATENÇÃO: #{unfold_data[:overlaps].size} sobreposição(ões) de facetas/abas na planificação. " \
        "Revise a chapa antes de enviar para a CNC."
    end

    # Executa o callback e mostra o erro ao usuário em vez de falhar em silêncio
    def self.add_callback(dialog, name, &handler)
      dialog.add_action_callback(name) do |_action_context, *args|
        begin
          handler.call(*args)
        rescue => e
          report_error(name, e)
        end
      end
    end

    def self.register_callbacks(dialog)
      # 1. Ready: Envia lista de presets e o estado inicial ao carregar
      add_callback(dialog, 'ready') do
        call_js('onPresetsLoaded', LibraryManager.list_presets)
        apply_state(@pending_tab, @pending_params)
        @pending_params = nil
      end

      # 2. Criar Bloco 3D na Viewport do SketchUp
      add_callback(dialog, 'build_3d_block') do |json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        GeometryEngine.build_in_sketchup(mesh_data)
        UI.messagebox("Bloco Origami 3D criado com sucesso!\nDimensões: #{mesh_data[:width].to_i} x #{mesh_data[:height].to_i} mm\nProfundidade Z: #{mesh_data[:depth].to_i} mm")
      end

      # 3. Planificar 2D e Desenhar Chapa no SketchUp
      add_callback(dialog, 'place_unfolded_2d') do |json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        unfold_data = UnfoldEngine.unfold_mesh(mesh_data, params)
        # Posicionar ao lado do modelo
        origin = Geom::Point3d.new((mesh_data[:width] * 1.5) / 25.4, 0, 0)
        UnfoldEngine.place_unfolded_in_sketchup(unfold_data, origin)
        msg = "Chapa Planificada 2D inserida na cena!\nTamanho da Chapa Bruta: #{unfold_data[:sheet_width]} x #{unfold_data[:sheet_height]} mm"
        msg += "\n\n#{overlap_warning(unfold_data)}" unless unfold_data[:overlaps].empty?
        UI.messagebox(msg)
      end

      # 4. Multiplicar Painel em Matriz de Fachada
      add_callback(dialog, 'multiply_panel') do |json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        TessellationEngine.generate_panel(mesh_data, params)
        UI.messagebox("Painel de Fachada Tesselado gerado com sucesso!")
      end

      # 5. Exportar DXF CNC AC1009
      add_callback(dialog, 'export_dxf') do |json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        unfold_data = UnfoldEngine.unfold_mesh(mesh_data, params)

        unless unfold_data[:overlaps].empty?
          answer = UI.messagebox("#{overlap_warning(unfold_data)}\n\nExportar mesmo assim?", MB_YESNO)
          next unless answer == IDYES
        end

        default_name = "Origami_#{mesh_data[:typology]}_#{mesh_data[:width].to_i}x#{mesh_data[:height].to_i}.dxf"
        filepath = UI.savepanel('Salvar Arquivo DXF para CNC Router', '', default_name)
        if filepath && !filepath.empty?
          filepath += '.dxf' unless filepath.downcase.end_with?('.dxf')
          DxfExporter.export_to_file(filepath, unfold_data, { name: params[:name] || mesh_data[:typology] })
          UI.messagebox("Arquivo DXF CNC gerado com sucesso em:\n#{filepath}\n\nCamadas geradas:\n- CAMADA_CORTE (Corte Passante)\n- CAMADA_VINCO_V90 / CAMADA_VINCO_ANGULAR (Vincos em V pelo verso)\n- CAMADA_VINCO_VALE (Vincos em V pela frente)\n- CAMADA_FUROS (Rebites e Perfurações)")
        end
      end

      # 6. Salvar Modelo / Preset
      add_callback(dialog, 'save_preset') do |json_params|
        data = parse_json(json_params)
        name = data[:name].to_s.strip
        name = 'Novo Bloco' if name.empty?
        typology = data[:typology] || 'diamond_classic'
        params = data[:params] || {}
        desc = data[:description] || ''
        thumb = data[:thumbnail]

        LibraryManager.save_preset(name, typology, params, desc, thumb)
        call_js('onPresetsLoaded', LibraryManager.list_presets)
        UI.messagebox("Modelo '#{name}' salvo na biblioteca com sucesso!")
      end

      # 7. Obter dados de cálculo da planificação real para a pré-visualização 2D
      add_callback(dialog, 'calculate_preview_data') do |json_params|
        params = parse_json(json_params)
        mesh_data = GeometryEngine.generate_block_mesh(params)
        unfold_data = UnfoldEngine.unfold_mesh(mesh_data, params)
        call_js('onCalculateData', { mesh: mesh_data, unfold: unfold_data })
      end
    end

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
