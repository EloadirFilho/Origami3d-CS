# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Plugin de Volumetria Arquitetônica & Origami em ACM
# ==============================================================================

require 'sketchup.rb'
require 'extensions.rb'

module CS_Origami3D
  PLUGIN_ID          = 'CS_Origami3D'.freeze
  PLUGIN_NAME        = 'CS Origami 3D · Volumetria & Facetação em ACM'.freeze
  PLUGIN_VERSION     = '1.0.1'.freeze
  PLUGIN_DESCRIPTION = 'Criação paramétrica de blocos volumétricos facetados (Origami Arquitetônico em ACM), estúdio 3D em tempo real, multiplicação de painéis, desdobramento/planificação 2D e exportação para CNC Router DXF.'.freeze
  PLUGIN_AUTHOR      = 'CS Comunicação / Totem ERP'.freeze
  PLUGIN_COPYRIGHT   = '© 2026 CS Comunicação'.freeze
  PLUGIN_ROOT        = File.dirname(__FILE__).freeze
  PLUGIN_DIR         = File.join(PLUGIN_ROOT, 'CS_Origami3D').freeze

  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_DIR, 'main'))
    ext.version     = PLUGIN_VERSION
    ext.description = PLUGIN_DESCRIPTION
    ext.creator     = PLUGIN_AUTHOR
    ext.copyright   = PLUGIN_COPYRIGHT
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
