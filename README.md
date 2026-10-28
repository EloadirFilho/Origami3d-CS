# Origami3d-CS · Volumetria Geométrica & Origami Arquitetônico em ACM

> **Plugin Autônomo para Trimble SketchUp & Estúdio WebGL** desenvolvido para projeto, modelagem e fabricação industrial de fachadas e interiores facetados em **ACM (Material Composto de Alumínio)**.

![Versão](https://img.shields.io/badge/vers%C3%A3o-1.0.1-rose)
![SketchUp](https://img.shields.io/badge/SketchUp-2017%20a%202024%2B-blue)
![CNC Router](https://img.shields.io/badge/CNC-AutoCAD%20DXF%20AC1009-amber)
![Three.js](https://img.shields.io/badge/WebGL-Three.js%20PBR-emerald)

---

## 📐 Visão Geral

A técnica inspirada em dobraduras e aplicada em superfícies tridimensionais é conhecida mundialmente como **Origami Arquitetônico** ou **Origami 3D**. No universo da comunicação visual e fachadas modernas em chapas rígidas, é denominada **Volumetria Geométrica em ACM**.

O **Origami3d-CS** automatiza todo o ciclo de vida desse produto:
1. **Concepção e Design Paramétrico** via calculadora matemática.
2. **Visualização 3D Fotorrealista** em tempo real com materiais de ACM e simulação de iluminação solar.
3. **Multiplicação em Matriz de Fachada** com alternância de reflexos e espelhamentos (caleidoscópio).
4. **Planificação Matemática 2D** (*True Lengths*) gerando abas de fixação perimetrais com chanfros de alívio a 45°.
5. **Geração de Arquivo DXF CNC (AC1009)** pronto para carregar no Aspire / ArtCAM / EnRoute.

---

## 🌟 Principais Recursos

### 1. Estúdio 3D ao Vivo (WebGL Three.js Offline)
- Renderização PBR em tempo real simulando acabamentos comerciais de ACM:
  - **Vermelho Brilhante** (High Gloss Red)
  - **Prata Metálico** (Silver Metallic)
  - **Grafite / Titânio** (Dark Titanium)
  - **Dourado Champagne** (Champagne Gold)
  - **Preto Fosco** (Matte Black)
  - **Branco Puro** (Pure White)
- **Luz Solar Orbitável**: Simula a trajetória do sol e o efeito de sombra dinâmico das facetas na fachada.
- **Diferenciação de Dobras**: Visualização de arestas de Montanha (vermelho), Vale (azul) e Perímetro (cinza).
- **100% Offline**: Bibliotecas Three.js e OrbitControls embutidas no pacote sem depender de internet.

### 2. Calculadora Geométrica Paramétrica
- **Diamante Facetado Clássico**: 8 facetas triangulares com ápice central saliente e controle de offset $X, Y, Z$.
- **Yoshimura Chevron (Espinha de Peixe)**: Tesselação contínua com cristas e vales (estilo acordeão).
- **Split Diagonal (Cristal Assimétrico)**: Crista diagonal com facetas inclinadas para reflexos assimétricos.
- **Pirâmide Truncada ou Aguda**: 4 a 5 facetas com topo plano ou pontiagudo.
- **Facetas Perfuradas (Design Acústico / Iluminação)**: Malha paramétrica de furos circulares em facetas selecionadas.

### 3. Planificação 2D & Usinagem CNC
- **Desdobramento Matemático Exato**: Trilateração 2D que preserva o comprimento real de todas as facetas sem distorções de escala.
- **Abas de Fixação Perimetrais**: Flanges de $25$ a $60\text{ mm}$ com chanfros de alívio a $45^\circ$ nos cantos.
- **Furações de Rebite**: Furos paramétricos para rebites de fixação estrutural (diâmetro padrão $4.5\text{ mm}$, passo $150\text{ mm}$).
- **Emendas e Sobreposições**: Quando a superfície não planifica numa peça só, as arestas abertas viram corte (emenda) e sobreposições de facetas/abas são destacadas antes da exportação.
- **Desenho 2D na Cena**: Insere a chapa desenhada diretamente na viewport do SketchUp.
- **Exportação DXF AC1009**: Arquivo padronizado com camadas CAM para router CNC:
  - `CAMADA_CORTE` (Corte passante total das abas e chapa)
  - `CAMADA_VINCO_V90` (Vincos em V de 90° no verso do ACM)
  - `CAMADA_VINCO_ANGULAR` (Vincos para ângulos específicos)
  - `CAMADA_VINCO_VALE` (Vincos de dobras em vale, fresados pela frente da chapa)
  - `CAMADA_FUROS` (Furações de alívio e rebites)
  - `CAMADA_TEXTOS` (Identificação da peça e medidas brutas)

### 4. Multiplicação de Painel (Tesselação de Fachada)
- Matriz de repetição em Linhas $\times$ Colunas.
- Dimensionamento tanto por quantidade fixa de módulos quanto por vão total da fachada ($L_{\text{total}} \times H_{\text{total}}$).
- Alternância de paridade:
  - Espelhamento em X nas colunas ímpares (Flip X).
  - Espelhamento em Y nas linhas ímpares (Flip Y).
  - Rotação de $180^\circ$ alternada.
- Controle de junta de dilatação ($3$ a $15\text{ mm}$).

### 5. Biblioteca de Modelos (Presets JSON)
- Salva e carrega configurações completas com miniatura gerada automaticamente pelo WebGL.
- Já inclui 5 presets de fábrica prontos para uso.

---

## 📥 Como Instalar no Trimble SketchUp

1. Baixe o instalador compilado [`dist/CS_Origami3D_v1.0.1.rbz`](dist/CS_Origami3D_v1.0.1.rbz).
2. No SketchUp, acesse:
   `Janela` > `Gerenciador de Extensões` (ou `Extensões` > `Gerenciador de Extensões`).
3. Clique em **"Instalar Extensão"**.
4. Selecione o arquivo `CS_Origami3D_v1.0.1.rbz`.
5. A barra de ferramentas **CS Origami 3D** e o menu `Extensões > CS Origami 3D · Volumetria ACM` estarão prontos para uso!

---

## 📂 Estrutura do Repositório

```text
Origami3d-CS/
├── dist/
│   └── CS_Origami3D_v1.0.1.rbz        # Instalador oficial para SketchUp
├── docs/
│   ├── CS_ORIGAMI3D_MANUAL.md         # Manual do Usuário e Operação
│   ├── ESPECIFICACAO_CS_ORIGAMI3D.md  # Especificação técnica e matemática
│   ├── PLANO_MELHORIAS.md             # Correções da v1.0.1 e roteiro de melhorias
│   └── images/                        # Fotos e referências visuais
└── sketchup-plugin/
    ├── CS_Origami3D.rb                # Registro da extensão no SketchUp
    └── CS_Origami3D/
        ├── main.rb                    # Menus, Toolbar e Context Menu
        ├── lib/
        │   ├── geometry_engine.rb     # Motor de cálculo 3D de facetas e dobras
        │   ├── unfold_engine.rb       # Desdobramento 2D, abas e furações
        │   ├── tessellation_engine.rb # Multiplicação e espelhamento em matriz
        │   ├── dxf_exporter.rb        # Gerador nativo DXF AC1009
        │   ├── library_manager.rb     # Catálogo de presets JSON
        │   └── studio_dialog.rb       # Ponte UI::HtmlDialog Ruby-JS
        ├── icons/                     # Ícones SVG da barra de ferramentas
        ├── presets/                   # Modelos pré-configurados
        └── ui/
            ├── dialog.html            # Interface do Estúdio 3D
            ├── dialog.css             # Estilos do estúdio
            ├── dialog.js              # Controlador e ponte com o SketchUp
            ├── three_viewer.js        # Viewport WebGL Three.js PBR
            └── vendor/                # Three.js e OrbitControls offline
```

---

## 📄 Licença

Desenvolvido por **CS Comunicação / Totem ERP**. Todos os direitos reservados.
