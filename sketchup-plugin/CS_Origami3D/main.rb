# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Arquivo Principal da Extensão (main.rb)
# Registra Módulos, Menus, Barra de Ferramentas e Menu de Contexto
# ==============================================================================

require 'sketchup.rb'

require File.join(CS_Origami3D::PLUGIN_DIR, 'lib', 'geometry_engine')
require File.join(CS_Origami3D::PLUGIN_DIR, 'lib', 'unfold_engine')
require File.join(CS_Origami3D::PLUGIN_DIR, 'lib', 'tessellation_engine')
require File.join(CS_Origami3D::PLUGIN_DIR, 'lib', 'dxf_exporter')
require File.join(CS_Origami3D::PLUGIN_DIR, 'lib', 'library_manager')
require File.join(CS_Origami3D::PLUGIN_DIR, 'lib', 'studio_dialog')

module CS_Origami3D
  unless file_loaded?(__FILE__)
    # --------------------------------------------------------------------------
    # 1. MENU SUPERIOR EM EXTENSÕES
    # --------------------------------------------------------------------------
    main_menu = UI.menu('Plugins').add_submenu('CS Origami 3D · Volumetria ACM')

    main_menu.add_item('Abrir Estúdio Origami 3D & Facetação…') do
      StudioDialog.show('creator')
    end

    main_menu.add_separator

    main_menu.add_item('Multiplicar Painel em Fachada…') do
      StudioDialog.show('tessellation')
    end

    main_menu.add_item('Biblioteca de Modelos & Presets…') do
      StudioDialog.show('library')
    end

    main_menu.add_separator

    main_menu.add_item('Planificar Bloco Selecionado na Cena') do
      model = Sketchup.active_model
      sel = model.selection.grep(Sketchup::Group).find { |g| g.get_attribute(GeometryEngine::ATTR_DICT, 'typology') }
      if sel
        w = sel.get_attribute(GeometryEngine::ATTR_DICT, 'width_mm') || 600.0
        h = sel.get_attribute(GeometryEngine::ATTR_DICT, 'height_mm') || 1000.0
        d = sel.get_attribute(GeometryEngine::ATTR_DICT, 'depth_mm') || 150.0
        typ = sel.get_attribute(GeometryEngine::ATTR_DICT, 'typology') || 'diamond_classic'

        mesh = GeometryEngine.generate_block_mesh({ width: w, height: h, depth: d, typology: typ })
        unfold = UnfoldEngine.unfold_mesh(mesh)
        origin = Geom::Point3d.new(sel.bounds.max.x + (100.0 / 25.4), sel.bounds.min.y, 0)
        UnfoldEngine.place_unfolded_in_sketchup(unfold, origin)
        UI.messagebox("Chapa planificada inserida ao lado do bloco selecionado!")
      else
        UI.messagebox("Selecione um bloco Origami 3D para planificar.")
      end
    end

    main_menu.add_item('Exportar DXF CNC do Bloco Selecionado…') do
      model = Sketchup.active_model
      sel = model.selection.grep(Sketchup::Group).find { |g| g.get_attribute(GeometryEngine::ATTR_DICT, 'typology') }
      if sel
        w = sel.get_attribute(GeometryEngine::ATTR_DICT, 'width_mm') || 600.0
        h = sel.get_attribute(GeometryEngine::ATTR_DICT, 'height_mm') || 1000.0
        d = sel.get_attribute(GeometryEngine::ATTR_DICT, 'depth_mm') || 150.0
        typ = sel.get_attribute(GeometryEngine::ATTR_DICT, 'typology') || 'diamond_classic'

        mesh = GeometryEngine.generate_block_mesh({ width: w, height: h, depth: d, typology: typ })
        unfold = UnfoldEngine.unfold_mesh(mesh)
        filepath = UI.savepanel('Exportar DXF CNC', '', "Origami_#{typ}_#{w.to_i}x#{h.to_i}.dxf")
        if filepath && !filepath.empty?
          filepath += '.dxf' unless filepath.downcase.end_with?('.dxf')
          DxfExporter.export_to_file(filepath, unfold, { name: "Bloco_#{typ}" })
          UI.messagebox("DXF exportado com sucesso em:\n#{filepath}")
        end
      else
        UI.messagebox("Selecione um bloco Origami 3D para exportar DXF.")
      end
    end

    # --------------------------------------------------------------------------
    # 2. BARRA DE FERRAMENTAS (TOOLBAR)
    # --------------------------------------------------------------------------
    toolbar = UI::Toolbar.new('CS Origami 3D')

    cmd_studio = UI::Command.new('Estúdio Origami 3D') do
      StudioDialog.show('creator')
    end
    cmd_studio.tooltip = 'Estúdio de Criação de Blocos Origami 3D em ACM'
    cmd_studio.status_bar_text = 'Abre a interface interativa com visualizador WebGL ao vivo.'
    toolbar.add_item(cmd_studio)

    cmd_panel = UI::Command.new('Multiplicar Painel') do
      StudioDialog.show('tessellation')
    end
    cmd_panel.tooltip = 'Multiplicar Blocos em Matriz de Fachada'
    toolbar.add_item(cmd_panel)

    cmd_unfold = UI::Command.new('Planificar 2D') do
      StudioDialog.show('unfold')
    end
    cmd_unfold.tooltip = 'Planificar Chapa 2D com Abas Perimetrais'
    toolbar.add_item(cmd_unfold)

    cmd_dxf = UI::Command.new('Exportar DXF CNC') do
      StudioDialog.show('dxf')
    end
    cmd_dxf.tooltip = 'Exportar Arquivo DXF com Camadas para Router CNC'
    toolbar.add_item(cmd_dxf)

    toolbar.restore if toolbar.get_last_state == TB_VISIBLE

    # --------------------------------------------------------------------------
    # 3. MENU DE CONTEXTO (CLIQUE COM BOTÃO DIREITO)
    # --------------------------------------------------------------------------
    UI.add_context_menu_handler do |context_menu|
      model = Sketchup.active_model
      sel = model.selection.grep(Sketchup::Group).find { |g| g.get_attribute(GeometryEngine::ATTR_DICT, 'typology') }
      if sel
        sub = context_menu.add_submenu('CS Origami 3D')
        sub.add_item('Editar Bloco no Estúdio…') do
          StudioDialog.show('creator')
        end
        sub.add_item('Planificar Chapa 2D deste Bloco') do
          w = sel.get_attribute(GeometryEngine::ATTR_DICT, 'width_mm') || 600.0
          h = sel.get_attribute(GeometryEngine::ATTR_DICT, 'height_mm') || 1000.0
          d = sel.get_attribute(GeometryEngine::ATTR_DICT, 'depth_mm') || 150.0
          typ = sel.get_attribute(GeometryEngine::ATTR_DICT, 'typology') || 'diamond_classic'

          mesh = GeometryEngine.generate_block_mesh({ width: w, height: h, depth: d, typology: typ })
          unfold = UnfoldEngine.unfold_mesh(mesh)
          origin = Geom::Point3d.new(sel.bounds.max.x + (100.0 / 25.4), sel.bounds.min.y, 0)
          UnfoldEngine.place_unfolded_in_sketchup(unfold, origin)
        end
        sub.add_item('Exportar DXF CNC deste Bloco…') do
          w = sel.get_attribute(GeometryEngine::ATTR_DICT, 'width_mm') || 600.0
          h = sel.get_attribute(GeometryEngine::ATTR_DICT, 'height_mm') || 1000.0
          d = sel.get_attribute(GeometryEngine::ATTR_DICT, 'depth_mm') || 150.0
          typ = sel.get_attribute(GeometryEngine::ATTR_DICT, 'typology') || 'diamond_classic'

          mesh = GeometryEngine.generate_block_mesh({ width: w, height: h, depth: d, typology: typ })
          unfold = UnfoldEngine.unfold_mesh(mesh)
          filepath = UI.savepanel('Exportar DXF CNC', '', "Origami_#{typ}_#{w.to_i}x#{h.to_i}.dxf")
          if filepath && !filepath.empty?
            filepath += '.dxf' unless filepath.downcase.end_with?('.dxf')
            DxfExporter.export_to_file(filepath, unfold, { name: "Bloco_#{typ}" })
          end
        end
      end
    end

    file_loaded(__FILE__)
  end
end
