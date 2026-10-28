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
  # Primeiro grupo ou instância de painel Origami na seleção atual
  def self.selected_block
    Sketchup.active_model.selection.find do |e|
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && GeometryEngine.block_params(e)
    end
  end

  def self.unfold_block(entity)
    params = GeometryEngine.block_params(entity)
    mesh = GeometryEngine.generate_block_mesh(params)
    unfold = UnfoldEngine.unfold_mesh(mesh, params)
    origin = Geom::Point3d.new(entity.bounds.max.x + (100.0 / 25.4), entity.bounds.min.y, 0)
    UnfoldEngine.place_unfolded_in_sketchup(unfold, origin)
    msg = "Chapa planificada inserida ao lado do bloco selecionado!"
    msg += "\n\n#{StudioDialog.overlap_warning(unfold)}" unless unfold[:overlaps].empty?
    UI.messagebox(msg)
  rescue => e
    StudioDialog.report_error('Planificar bloco', e)
  end

  def self.export_block_dxf(entity)
    params = GeometryEngine.block_params(entity)
    mesh = GeometryEngine.generate_block_mesh(params)
    unfold = UnfoldEngine.unfold_mesh(mesh, params)
    typ = mesh[:typology]
    filepath = UI.savepanel('Exportar DXF CNC', '', "Origami_#{typ}_#{mesh[:width].to_i}x#{mesh[:height].to_i}.dxf")
    return unless filepath && !filepath.empty?

    filepath += '.dxf' unless filepath.downcase.end_with?('.dxf')
    DxfExporter.export_to_file(filepath, unfold, { name: "Bloco_#{typ}" })
    UI.messagebox("DXF exportado com sucesso em:\n#{filepath}")
  rescue => e
    StudioDialog.report_error('Exportar DXF', e)
  end

  def self.icon(name)
    File.join(PLUGIN_DIR, 'icons', "#{name}.svg")
  end

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
      sel = selected_block
      sel ? unfold_block(sel) : UI.messagebox("Selecione um bloco Origami 3D para planificar.")
    end

    main_menu.add_item('Exportar DXF CNC do Bloco Selecionado…') do
      sel = selected_block
      sel ? export_block_dxf(sel) : UI.messagebox("Selecione um bloco Origami 3D para exportar DXF.")
    end

    # --------------------------------------------------------------------------
    # 2. BARRA DE FERRAMENTAS (TOOLBAR)
    # --------------------------------------------------------------------------
    toolbar = UI::Toolbar.new('CS Origami 3D')

    add_command = lambda do |label, icon_name, tooltip, status, &block|
      cmd = UI::Command.new(label, &block)
      cmd.small_icon = cmd.large_icon = icon(icon_name)
      cmd.tooltip = tooltip
      cmd.status_bar_text = status
      toolbar.add_item(cmd)
    end

    add_command.call('Estúdio Origami 3D', 'studio', 'Estúdio de Criação de Blocos Origami 3D em ACM',
                     'Abre a interface interativa com visualizador WebGL ao vivo.') do
      StudioDialog.show('creator')
    end
    add_command.call('Multiplicar Painel', 'panel', 'Multiplicar Blocos em Matriz de Fachada',
                     'Abre o estúdio na aba de multiplicação de painel.') do
      StudioDialog.show('tessellation')
    end
    add_command.call('Planificar 2D', 'unfold', 'Planificar Chapa 2D com Abas Perimetrais',
                     'Abre o estúdio na aba de planificação 2D.') do
      StudioDialog.show('unfold')
    end
    add_command.call('Exportar DXF CNC', 'dxf', 'Exportar Arquivo DXF com Camadas para Router CNC',
                     'Exporta o DXF do bloco selecionado, ou abre o estúdio se nada estiver selecionado.') do
      sel = selected_block
      sel ? export_block_dxf(sel) : StudioDialog.show('unfold')
    end

    toolbar.restore if toolbar.get_last_state == TB_VISIBLE

    # --------------------------------------------------------------------------
    # 3. MENU DE CONTEXTO (CLIQUE COM BOTÃO DIREITO)
    # --------------------------------------------------------------------------
    UI.add_context_menu_handler do |context_menu|
      sel = selected_block
      if sel
        sub = context_menu.add_submenu('CS Origami 3D')
        sub.add_item('Editar Bloco no Estúdio…') do
          StudioDialog.show('creator', GeometryEngine.block_params(sel))
        end
        sub.add_item('Planificar Chapa 2D deste Bloco') do
          unfold_block(sel)
        end
        sub.add_item('Exportar DXF CNC deste Bloco…') do
          export_block_dxf(sel)
        end
      end
    end

    file_loaded(__FILE__)
  end
end
