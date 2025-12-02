# CortaPau – App iOS

Aplicativo iOS de assistência urbana para registro e atendimento de ocorrências na cidade.

O CortaPau permite que cidadãos registrem riscos (ex: árvores oferecendo risco, fios expostos, risco elétrico) com fotos e localização, enquanto equipes operacionais acompanham, filtram e atualizam o status dessas solicitações.

---

## Visão geral

O projeto está dividido em dois perfis principais:

- **Cidadão**
  - Cria novas solicitações com:
    - Tipo de problema (ex.: Risco Elétrico, Queda de Árvore, etc.)
    - Endereço (manual ou via localização)
    - Localização aproximada no mapa
    - Fotos anexadas (enviadas para o backend)
    - Descrição textual
  - Acompanha as próprias solicitações.

- **Operário**
  - Visualiza solicitações para atendimento.
  - Filtra por:
    - Status (Pendentes / Todas)
    - Tipo de problema
    - Data de abertura
    - Proximidade (distância da localização do usuário)
  - Atualiza o status da solicitação:
    - Em aberto → Em atendimento → Concluída / Não concluída
  - Registra:
    - Encaminhamento (Defesa Civil, Bombeiros, Companhia de Energia, etc.)
    - Descrição do atendimento
  - Consulta o histórico completo de eventos (criação, alterações de status, encaminhamentos).

---

## Arquitetura (MVP)

- **Plataforma:** iOS (Swift / SwiftUI)
- **UI:**
  - SwiftUI
  - `MapKit` para mapa e seleção de localização
  - `PhotosUI.PhotosPicker` para seleção de imagens
  - Navegação baseada em `ScreenScaffold` customizado

- **Camada de rede:**
  - `ApiClient` centralizando chamadas HTTP
  - Backend exposto via REST (Fastify + PostgreSQL)
  - Serialização com `Codable` (`ApiSolicitacao`, `ApiAnexo`, etc.)

- **Modelo de domínio (simplificado):**
  - `Solicitacao`
    - `backendId`
    - `tipoProblema`
    - `endereco`
    - `descricao`
    - `coordenada` (`GeoPoint`)
    - `status` (`SolicitacaoStatus`)
    - `descricaoAtendimento`
    - `encaminhamento`
    - `createdAt`
    - `isMinha` (se foi criada pelo usuário logado)
    - `remoteImageURLs` (URLs dos anexos vindos da API)
    - `historico: [SolicitationEvent]`
  - `SolicitationEvent`
    - `tipo` (criação, status alterado, encaminhamento, comentário, etc.)
    - `data`
    - `descricao`
    - `statusAnterior` / `statusNovo`
    - `encaminhamento`

---

## Backend

O app iOS se conecta a um backend Node.js (Fastify) com banco de dados PostgreSQL.

- Endpoint principal (MVP):  
  `http://localhost:3333`

- Exemplos de rotas utilizadas:
  - `POST /uploads/base64` – upload de imagens em base64, retorna `{ url, mime }`
  - `POST /solicitacoes` – cria nova solicitação com anexos
  - `GET /solicitacoes` – lista solicitações
  - `PATCH /solicitacoes/:id` – atualiza status/descrição de atendimento

> **Importante:** a comunicação com o Postgres é responsabilidade do backend.  
> O app iOS fala apenas com a API HTTP.

Se o backend estiver em outro host ou porta, basta ajustar a base URL (ver seção de configuração abaixo).

---

## Configuração do app iOS

### Requisitos

- Xcode 15+ (de preferência a mesma versão que você já usa no projeto)
- iOS 17+ (simulador ou dispositivo físico)
- Backend rodando localmente ou acessível na rede:

  ```bash
  # Exemplo genérico no backend (ajustar conforme o seu projeto)
  npm install
  npm run dev
  # API disponível em http://localhost:3333
  ```

## Como rodar o app
  Backend
  • Sobe o backend (Fastify + Postgres) na porta configurada, ex.: http://localhost:3333.

  iOS App
  • Clone o repositório:
  ```
  git clone git@github.com:SEU_USUARIO/cortapau-ios.git
  cd cortapau-ios
  ```
  • Abra o projeto no Xcode (.xcodeproj ou .xcworkspace).
  • Verifique/ajuste a ApiEnvironment.baseURLString.
  • Selecione um simulador (ex.: iPhone 15).
  • ⌘ + R para rodar.


  
