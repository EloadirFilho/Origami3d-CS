# encoding: UTF-8
# ==============================================================================
# CS_Origami3D - Exportador DXF CNC AC1009 para Fresadoras Router
# ==============================================================================

module CS_Origami3D
  class DxfExporter
    def self.export_to_file(filepath, unfold_data, metadata = {})
      content = generate_dxf_string(unfold_data, metadata)
      File.open(filepath, 'w:UTF-8') do |f|
        f.write(content)
      end
      filepath
    end

    def self.generate_dxf_string(unfold_data, metadata = {})
      lines = []

      # 1. HEADER
      lines << "0\nSECTION"
      lines << "2\nHEADER"
      lines << "9\n$ACADVER"
      lines << "1\nAC1009"
      lines << "9\n$INSUNITS"
      lines << "70\n4" # 4 = Milímetros
      lines << "0\nENDSEC"

      # 2. TABLES (Definição de Camadas / Cores)
      lines << "0\nSECTION"
      lines << "2\nTABLES"
      lines << "0\nTABLE"
      lines << "2\nLAYER"
      lines << "70\n5"

      # Layer CAMADA_CORTE (Branco / Cor 7)
      add_layer_def(lines, 'CAMADA_CORTE', 7)
      # Layer CAMADA_VINCO_V90 (Vermelho / Cor 1)
      add_layer_def(lines, 'CAMADA_VINCO_V90', 1)
      # Layer CAMADA_VINCO_ANGULAR (Verde / Cor 3)
      add_layer_def(lines, 'CAMADA_VINCO_ANGULAR', 3)
      # Layer CAMADA_FUROS (Amarelo / Cor 2)
      add_layer_def(lines, 'CAMADA_FUROS', 2)
      # Layer CAMADA_TEXTOS (Ciano / Cor 4)
      add_layer_def(lines, 'CAMADA_TEXTOS', 4)

      lines << "0\nENDTAB"
      lines << "0\nENDSEC"

      # 3. ENTITIES
      lines << "0\nSECTION"
      lines << "2\nENTITIES"

      # (A) Contorno de Corte Passante (Abas perimetrais com chanfros)
      unfold_data[:flanges].each do |fl|
        poly = fl[:polygon]
        poly_size = poly.size
        poly_size.times do |i|
          p_start = poly[i]
          p_end = poly[(i + 1) % poly_size]
          # Não desenhar a base da aba como corte, pois a base é vinco de 90°!
          is_base = (p_start == fl[:base_start] && p_end == fl[:base_end]) || (p_start == fl[:base_end] && p_end == fl[:base_start])
          if is_base
            add_line_entity(lines, 'CAMADA_VINCO_V90', p_start[0], p_start[1], p_end[0], p_end[1])
          else
            add_line_entity(lines, 'CAMADA_CORTE', p_start[0], p_start[1], p_end[0], p_end[1])
          end
        end
      end

      # (B) Linhas de Vinco em V Internas das Facetas
      unfold_data[:fold_lines].each do |fl|
        ang = fl[:angle] || 90.0
        layer = (ang - 90.0).abs < 5.0 ? 'CAMADA_VINCO_V90' : 'CAMADA_VINCO_ANGULAR'
        add_line_entity(lines, layer, fl[:start][0], fl[:start][1], fl[:end][0], fl[:end][1])
      end

      # (C) Furações para Rebites
      unfold_data[:rivet_holes].each do |h|
        cx, cy = h[:center][0], h[:center][1]
        r = h[:diameter] / 2.0
        add_circle_entity(lines, 'CAMADA_FUROS', cx, cy, r)
      end

      # (D) Furações das Facetas Perfuradas (Foto 2)
      unfold_data[:perforation_holes].each do |h|
        cx, cy = h[:center][0], h[:center][1]
        r = h[:diameter] / 2.0
        add_circle_entity(lines, 'CAMADA_FUROS', cx, cy, r)
      end

      # (E) Texto de Identificação da Chapa
      bb = unfold_data[:bounding_box]
      tx = bb[:min_x]
      ty = bb[:min_y] - 40.0
      info_text = "CS_ORIGAMI3D | #{metadata[:name] || 'BLOCO_ORIGAMI'} | CHAPA: #{unfold_data[:sheet_width]}x#{unfold_data[:sheet_height]}mm"
      add_text_entity(lines, 'CAMADA_TEXTOS', tx, ty, 15.0, info_text)

      lines << "0\nENDSEC"
      lines << "0\nEOF\n"

      lines.join("\n")
    end

    private

    def self.add_layer_def(lines, name, color)
      lines << "0\nLAYER"
      lines << "2\n#{name}"
      lines << "70\n0"
      lines << "62\n#{color}"
      lines << "6\nCONTINUOUS"
    end

    def self.add_line_entity(lines, layer, x1, y1, x2, y2)
      lines << "0\nLINE"
      lines << "8\n#{layer}"
      lines << "10\n#{format('%.3f', x1)}"
      lines << "20\n#{format('%.3f', y1)}"
      lines << "30\n0.000"
      lines << "11\n#{format('%.3f', x2)}"
      lines << "21\n#{format('%.3f', y2)}"
      lines << "31\n0.000"
    end

    def self.add_circle_entity(lines, layer, cx, cy, radius)
      lines << "0\nCIRCLE"
      lines << "8\n#{layer}"
      lines << "10\n#{format('%.3f', cx)}"
      lines << "20\n#{format('%.3f', cy)}"
      lines << "30\n0.000"
      lines << "40\n#{format('%.3f', radius)}"
    end

    def self.add_text_entity(lines, layer, x, y, height, text)
      lines << "0\nTEXT"
      lines << "8\n#{layer}"
      lines << "10\n#{format('%.3f', x)}"
      lines << "20\n#{format('%.3f', y)}"
      lines << "30\n0.000"
      lines << "40\n#{format('%.3f', height)}"
      lines << "1\n#{text}"
    end
  end
end
