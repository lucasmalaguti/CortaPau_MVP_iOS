# Corta Pau – MVP iOS (Swift)

Aplicativo móvel para registro e acompanhamento de solicitações de poda de árvores em situação de risco.

## Objetivo deste MVP

- Criar um app **iOS nativo em Swift**, compilado via Xcode.
- Foco na experiência do usuário inspirada na interface do ChatGPT (layout limpo, tipografia moderna, tons escuros/neutros).
- Implementar as telas principais:
  - Login (com placeholder para login gov.br)
  - Tela Principal (menu com 3 ações)
  - Nova Solicitação
  - Solicitações (listagem + detalhes com status colorido)
  - Atender Solicitações (filtro e tela de atendimento)

## Organização do projeto

- Repositório raiz: `/Users/malaguti/Univali/HOW10/primeira_entrega/appCortaPauiOS`
- Ambiente Python isolado: `.venv/` (usado apenas para scripts auxiliares e ferramentas, não interfere no sistema).
- Código iOS em Swift será criado dentro deste diretório como projeto Xcode.

## Notas de desenvolvimento

- O projeto deve ser **totalmente auto-contido**: tudo necessário para desenvolvimento deve viver dentro deste diretório.
- Nada será instalado globalmente via `pip`.
- O app não será publicado na App Store (sem conta developer), apenas rodado em modo desenvolvimento.
