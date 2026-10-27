# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Gerenciador de Biblioteca de Modelos e Presets JSON
# ==============================================================================

require 'json'
require 'fileutils'

module CS_Origami3D
  class LibraryManager
    PRESETS_DIR = File.join(CS_Origami3D::PLUGIN_DIR, 'presets').freeze

    def self.ensure_presets_dir
      FileUtils.mkdir_p(PRESETS_DIR) unless Dir.exist?(PRESETS_DIR)
      seed_default_presets if Dir.glob(File.join(PRESETS_DIR, '*.json')).empty?
    end

    def self.list_presets
      ensure_presets_dir
      files = Dir.glob(File.join(PRESETS_DIR, '*.json'))
      presets = []
      files.each do |f|
        begin
          data = JSON.parse(File.read(f, encoding: 'UTF-8'))
          presets << {
            id: File.basename(f, '.json'),
            name: data['name'] || File.basename(f, '.json'),
            typology: data['typology'] || 'diamond_classic',
            description: data['description'] || '',
            params: data['params'] || {},
            thumbnail: data['thumbnail'] || nil
          }
        rescue => e
          puts "[CS_Origami3D] Erro ao ler preset #{f}: #{e.message}"
        end
      end
      presets
    end

    def self.save_preset(name, typology, params, description = '', thumbnail_base64 = nil)
      ensure_presets_dir
      filename = name.downcase.gsub(/[^a-z0-9_-]/, '_') + '.json'
      filepath = File.join(PRESETS_DIR, filename)

      data = {
        name: name,
        typology: typology,
        description: description,
        params: params,
        thumbnail: thumbnail_base64,
        updated_at: Time.now.strftime('%Y-%m-%d %H:%M:%S')
      }

      File.open(filepath, 'w:UTF-8') do |f|
        f.write(JSON.pretty_generate(data))
      end
      filepath
    end

    def self.load_preset(preset_id)
      ensure_presets_dir
      filepath = File.join(PRESETS_DIR, "#{preset_id}.json")
      return nil unless File.exist?(filepath)
      JSON.parse(File.read(filepath, encoding: 'UTF-8'))
    end

    def self.seed_default_presets
      defaults = [
        {
          id: 'diamond_classic',
          name: 'Diamante Facetado Clássico',
          typology: 'diamond_classic',
          description: 'Padrão com 8 facetas triangulares e ápice central saliente.',
          params: {
            width: 600.0,
            height: 1000.0,
            depth: 140.0,
            center_x_ratio: 0.5,
            center_y_ratio: 0.5,
            edge_z: 0.0,
            flange_width: 35.0,
            rivet_holes: true,
            rivet_spacing: 150.0
          }
        },
        {
          id: 'yoshimura_chevron',
          name: 'Yoshimura Chevron (Espinha de Peixe)',
          typology: 'yoshimura_chevron',
          description: 'Tesselação contínua estilo origami sanfonado com cristas e vales.',
          params: {
            width: 800.0,
            height: 1200.0,
            depth: 120.0,
            chevron_rows: 4,
            chevron_cols: 2,
            flange_width: 30.0,
            rivet_holes: true
          }
        },
        {
          id: 'split_diagonal_crystal',
          name: 'Cristal Split Diagonal',
          typology: 'split_diagonal',
          description: 'Relevo assimétrico facetado com crista diagonal e reflexos de luz.',
          params: {
            width: 700.0,
            height: 1100.0,
            depth: 160.0,
            split_p1_x: 0.35,
            split_p1_y: 0.25,
            split_p2_x: 0.65,
            split_p2_y: 0.75,
            flange_width: 40.0,
            rivet_holes: true
          }
        },
        {
          id: 'perforated_acoustic_facet',
          name: 'Facetas Perfuradas Acústicas',
          typology: 'diamond_classic',
          description: 'Bloco facetado com perfurações decorativas/acústicas em facetas selecionadas.',
          params: {
            width: 600.0,
            height: 1000.0,
            depth: 150.0,
            center_x_ratio: 0.5,
            center_y_ratio: 0.5,
            flange_width: 35.0,
            rivet_holes: true,
            perforated_faces: [0, 4], # Faces Sul-Oeste e Norte-Leste com perfuração
            perf_hole_dia: 8.0,
            perf_pitch: 18.0
          }
        }
      ]

      defaults.each do |p|
        save_preset(p[:name], p[:typology], p[:params], p[:description])
      end
    end
  end
end
