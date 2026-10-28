# Manual de Uso & Guia Técnico — CS Origami 3D (v1.0.1)

Extensão autônoma para **Trimble SketchUp** especializada em modelagem volumétrica facetada, origami arquitetônico em ACM (Material Composto de Alumínio), planificação 2D com abas e usinagem CNC Router (DXF AC1009).

---

## 1. Como Instalar no SketchUp

1. Abra o **Trimble SketchUp** (compatível com SketchUp 2017 até 2024+).
2. Vá no menu: `Janela` > `Gerenciador de Extensões` (ou `Extensões` > `Gerenciador de Extensões`).
3. Clique no botão vermelho **"Instalar Extensão"** no canto inferior esquerdo.
4. Selecione o arquivo compilado:
   `CS_Origami3D_v1.0.1.rbz`
5. A barra de ferramentas **CS Origami 3D** e o menu `Extensões > CS Origami 3D · Volumetria ACM` aparecerão imediatamente.

---

## 2. Visão Geral das Funcionalidades

### 2.1. Calculadora e Estúdio 3D ao Vivo (WebGL Three.js)
- **Visualização Renderizada**: Simula o acabamento físico real das chapas de ACM (Vermelho Brilhante, Prata Metálico, Chumbo/Grafite, Dourado Champagne, Preto Fosco, Branco Puro).
- **Estudo de Luz e Sombreamento**: Slider para orbitar o sol em tempo real, permitindo analisar como as facetas triangulares reagem à iluminação natural da fachada.
- **Tipologias de Origami Suportadas**:
  - **Diamante Facetado Clássico**: 8 facetas com ápice central saliente.
  - **Yoshimura Chevron (Espinha de Peixe)**: Dobras sanfonadas contínuas com cristas e vales (idêntico à foto 5).
  - **Split Diagonal (Cristal Assimétrico)**: Crista diagonal com facetas inclinadas (fotos 1 e 3).
  - **Pirâmide Truncada ou Aguda**: 4 ou 5 facetas com topo plano ou pontiagudo.
- **Diferenciação de Dobras**: Linhas de vinco em Vermelho (Montanha) e Azul (Vale).

### 2.2. Planificação 2D & Usinagem CNC
- **Desdobramento Matemático Exato**: Preserva as dimensões verdadeiras (*True Lengths*) de cada faceta triangular através de trilateração 2D sem distorções.
- **Abas Perimetrais de Fixação (Flanges)**:
  - Largura configurável de $20$ a $60\text{ mm}$ (padrão $35\text{ mm}$).
  - Alívios e chanfros de canto a $45^\circ$ para permitir a dobra sem sobreposição.
  - Furações automáticas para rebites com espaçamento de $150\text{ mm}$ e broca de $4.5\text{ mm}$.
- **Facetas Perfuradas (Foto 2)**: Malha de furos cilíndricos paramétricos para placas decorativas, acústicas ou fachadas ventiladas.

### 2.3. Multiplicação de Painéis de Fachada (Tesselação)
- Matriz completa de repetição em Linhas ($R$) $\times$ Colunas ($C$).
- **Modos de Dimensionamento**:
  - *Por Quantidade de Módulos*: Define a quantidade e dimensões fixas do bloco.
  - *Por Vão Total*: Informa a largura e altura total da parede e o plugin calcula a quantidade de módulos e ajusta milimetricamente o tamanho para preenchimento perfeito.
- **Opções de Paridade / Caleidoscópio**:
  - Espelhamento em X alternado (Flip X nas colunas ímpares).
  - Espelhamento em Y alternado (Flip Y nas linhas ímpares).
  - Rotação de $180^\circ$ estilo xadrez.
- **Junta de Dilatação**: Espaçamento configurável de $3$ a $15\text{ mm}$ entre os blocos.

### 2.4. Exportador DXF CNC AC1009
Gera arquivos prontos para carregar diretamente nos softwares CAM de fresadoras router (Aspire, ArtCAM, EnRoute, Type3):
| Camada (Layer) | Cor AutoCAD | Ferramenta / Processo |
| :--- | :--- | :--- |
| `CAMADA_CORTE` | Branco (7) | Fresa cilíndrica de topo 4mm (Corte passante total) |
| `CAMADA_VINCO_V90` | Vermelho (1) | Fresa em V 90° (Usinagem no verso, preserva lâmina de alumínio) |
| `CAMADA_VINCO_ANGULAR` | Verde (3) | Fresa em V para ângulos agudos/obtusos calculados |
| `CAMADA_VINCO_VALE` | Magenta (6) | Fresa em V pela **frente** da chapa (dobras em vale) |
| `CAMADA_FUROS` | Amarelo (2) | Broca CNC de furação para rebites e alívios |
| `CAMADA_TEXTOS` | Ciano (4) | Etiquetas, dimensões da chapa bruta e identificação |

---

## 3. Biblioteca de Modelos (Presets)

O plugin já inclui 5 modelos profissionais prontos para uso:
1. `Diamante Facetado Clássico` (600 × 1000 × 140 mm)
2. `Yoshimura Chevron` (800 × 1200 × 130 mm)
3. `Cristal Split Diagonal` (700 × 1100 × 160 mm)
4. `Pirâmide Facetada Truncada` (600 × 600 × 100 mm)
5. `Facetas Perfuradas Acústicas` (600 × 1000 × 150 mm com padrão de furos CNC)

O usuário pode personalizar qualquer geometria, clicar em **"+ Salvar Atual"** e guardar novos modelos com nome, descrição e captura de tela automática.
