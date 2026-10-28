# Plano de Melhorias — CS Origami 3D (após v1.0.1)

Este plano parte de duas fontes: o que a [Especificação](ESPECIFICACAO_CS_ORIGAMI3D.md) e o [Manual](CS_ORIGAMI3D_MANUAL.md) prometem e ainda não existe no código, e os problemas encontrados na varredura que gerou a v1.0.1. As fases estão em ordem de prioridade. A Fase 1 trata do que pode estragar uma chapa de ACM na CNC; as outras melhoram o produto.

---

## O que a v1.0.1 já corrigiu

| Área | Problema na v1.0.0 | Correção |
| :--- | :--- | :--- |
| Planificação | Vértices compartilhados eram sobrescritos: facetas saíam até **250 mm** fora da medida real | Cada faceta guarda as próprias coordenadas 2D; erro medido agora é 0,000 mm em todas as tipologias |
| Planificação | Cerca de metade das abas apontava **para dentro** da chapa | Normal da aba calculada para longe da própria faceta |
| Planificação | Arestas internas não usadas na árvore sumiam (sem linha de corte) | Viram **emendas** (corte passante) no DXF e na pré-visualização |
| Planificação | Facetas coplanares geravam vinco de 0° e abas com entalhe no meio de lado reto | Árvore de desdobramento pelo menor ângulo; arestas colineares viram uma aba só |
| Planificação | Sobreposições passavam despercebidas | Detecção de sobreposição, aviso na UI e confirmação antes de exportar DXF |
| Perfuração | Facetas eram perfuradas mesmo com a opção desligada | Respeita `perforated` |
| DXF | Sem tabela LTYPE; acentos em UTF-8 num arquivo R12; vale e montanha na mesma camada | LTYPE `CONTINUOUS`, texto ASCII, nova camada `CAMADA_VINCO_VALE` (fresa pela frente) |
| SketchUp | Planificar/exportar a partir da cena usava só L×A×P (perdia ápice, linhas, abas…) | Parâmetros completos gravados no bloco (`params_json`) e reutilizados |
| SketchUp | Painel reaproveitava componente de outro bloco com mesma L×A | Nome da definição inclui um resumo da geometria |
| SketchUp | Erro no meio de uma operação deixava o desfazer quebrado | `abort_operation` em criar bloco, planificar e multiplicar |
| SketchUp | Botões da barra sem ícone; aba pedida pela barra era ignorada | Ícones SVG; o estúdio abre na aba certa |
| Interface | Ruby chamava `window.CS_ORIGAMI_APP`, que não existia: **biblioteca nunca carregava** no SketchUp | Objeto exposto em `window` |
| Interface | `1_000_000.0` quebrava o script inteiro no Chromium do SketchUp ≤ 2022 | Literal compatível |
| Interface | Chapa 2D era um retângulo desenhado à mão, sem relação com o DXF | Pré-visualização desenha a planificação real calculada pelo Ruby |
| Interface | Área falsa (`L×A×1,15`), todos os vincos como "montanha" | Mesma análise do Ruby (testada: resultados idênticos) |
| Interface | Carregar modelo só atualizava 3 campos; modo "por vão total" não tinha controle; `prompt()` para salvar | Todos os campos sincronizados, seletor de modo, formulário na aba Biblioteca |
| Interface | Materiais recriados a cada tecla (vazamento) e sombras inexistentes | Materiais em cache, câmera de sombra dimensionada em mm |

> **Ainda não testado dentro do SketchUp.** Os motores Ruby (geometria, planificação, DXF) foram executados e verificados fora do SketchUp, e a interface foi testada no navegador com dados reais do Ruby. As partes que dependem da API do SketchUp (menus, barra, grupos, componentes) precisam de um teste manual no SketchUp 2025 antes de distribuir o `.rbz`.

---

## Fase 1 — Fabricação confiável (prioridade alta)

O objetivo é que todo DXF exportado possa ir direto para a CNC sem conferência manual da geometria.

1. **Compensação da espessura do ACM.** A planificação usa a superfície teórica e ignora a chapa de 3/4 mm e a largura do sulco em V. Acrescentar `sheet_thickness` e `groove_allowance` por ângulo de dobra, ajustando a posição de cada vinco.
   *Aceite:* bloco dobrado a partir do DXF fecha dentro de ±0,5 mm nas medidas L×A.
2. **Abas de emenda.** As emendas hoje são só corte, sem como rebitar os dois lados. Gerar uma aba de sobreposição com rebites num dos lados da emenda, aparando-a onde a cunha da emenda é estreita perto do ápice.
3. **Resolver sobreposições em vez de só avisar.** O Yoshimura padrão (4×2) gera 8 sobreposições. Dividir automaticamente a planificação em 2 ou mais peças (cortando nas emendas que causam o conflito) e exportar uma peça por bloco no DXF.
4. **Ângulo e fresa por vinco.** Escrever o ângulo de cada dobra como texto no DXF (`CAMADA_TEXTOS`) e agrupar por fresa (V90, V135…), como a Especificação prevê com `CAMADA_VINCO_V135`.
5. **Contornos fechados no DXF.** Emitir o corte como `POLYLINE` fechada em vez de linhas soltas, o que facilita gerar o percurso de ferramenta no Aspire/ArtCAM.
6. **Validação física (Especificação 2.1).** Bloquear ou avisar sobre ângulo de dobra acima do limite do ACM, facetas menores que a fresa e abas que colidem em cantos côncavos.

## Fase 2 — Geometria fiel às fotos de referência

7. **Yoshimura real.** O padrão atual alterna alturas numa grade e não é planificável. Implementar a dobradura Yoshimura/chevron verdadeira, que é desenvolvível a partir de uma chapa plana, o que também elimina a maior parte das sobreposições do item 3.
8. **Controles que faltam na UI:** pontos da crista do Split Diagonal (`split_p1/p2`, `split_p2_ratio`), centro da pirâmide, furos de perfuração (diâmetro, passo e quais facetas), diâmetro do rebite.
9. **Malha livre (Especificação 2.1, item 4).** `custom_mesh` já existe no motor, mas não tem interface. Criar um editor de grade com altura Z por ponto.
10. **Ápice negativo** (diamante côncavo) e 4 ou 8 facetas no diamante, como diz a Especificação.

## Fase 3 — Fluxo no SketchUp

11. **Editar no lugar.** "Editar Bloco no Estúdio" hoje abre os parâmetros, mas cria um bloco novo. Acrescentar "Atualizar bloco selecionado", que substitui a geometria e mantém posição e atributos.
12. **Acabamento no modelo.** Aplicar a cor ACM escolhida no estúdio como material do grupo/componente no SketchUp.
13. **Rotação de 90° no painel** (Especificação 2.5 pede 0°/90°/180°) e junta limitada a 3–15 mm, como diz o Manual (a UI aceita 0–30).
14. **Lista de corte do painel.** Ao multiplicar, gerar um quadro com a quantidade de chapas por tipo, a área total de ACM e o número de rebites. Opcionalmente, aproveitamento (nesting) em chapas comerciais de 1250×5000 e 1500×5000.
15. **Importar/exportar componente `.skp`** do bloco (Especificação 2.6).

## Fase 4 — Biblioteca e interface

16. **Presets do usuário fora da pasta do plugin.** Hoje são salvos em `CS_Origami3D/presets/`, e reinstalar ou atualizar o `.rbz` pode apagá-los. Mover para a pasta de dados do usuário (`%APPDATA%`), mantendo os de fábrica no plugin.
17. **Miniaturas visíveis.** As miniaturas já são salvas (JPEG em base64), mas a lista não as mostra. Exibi-las e reduzir para ~200 px, porque hoje cada uma tem centenas de KB e todas trafegam a cada atualização da lista.
18. **Excluir, renomear e confirmar sobrescrita** de modelos (salvar com o mesmo nome sobrescreve sem aviso).
19. **Câmera:** enquadrar o bloco automaticamente quando as dimensões mudam e oferecer botões de vista (frente, isométrica).
20. **Acabamento "Bronze"** citado na Especificação 2.2.

## Fase 5 — Qualidade e distribuição

21. **Testes automatizados dos motores Ruby.** A verificação feita nesta varredura (comprimentos 2D = 3D, abas para fora, sobreposições, DXF bem formado, JS = Ruby) vira uma suíte `test/` executável fora do SketchUp.
22. **Uma só fonte de geometria.** A geometria existe duplicada em `geometry_engine.rb` e `dialog.js`. Enquanto isso durar, o teste de paridade do item 21 deve rodar sempre; a longo prazo, gerar a malha num só lugar.
23. **Script de build do `.rbz`** com versão tirada de `PLUGIN_VERSION`, para o instalador em `dist/` nunca ficar desatualizado em relação ao código (aconteceu na v1.0.0).
24. **Ícones para Mac** (`.pdf`; o SketchUp para Mac não usa SVG) e teste nas versões que o README promete (2017 a 2025).
25. **Assinatura da extensão** para distribuição pelo Extension Warehouse ou instalação sem aviso de segurança.

---

## Sugestão de sequência

| Entrega | Itens | Resultado |
| :--- | :--- | :--- |
| v1.0.2 | teste no SketchUp + 21, 23 | Base testada e build reproduzível |
| v1.1 | 1–6 | DXF pronto para CNC sem conferência manual |
| v1.2 | 7–10 | Tipologias fiéis às fotos, sem sobreposição |
| v1.3 | 11–20 | Fluxo completo no SketchUp e biblioteca segura |
| v2.0 | 22, 24, 25 | Distribuição multiplataforma |
