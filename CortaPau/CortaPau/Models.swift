//
//  Models.swift
//  CortaPau
//
//  Created by Lucas Malaguti on 11/20/25.
//

import Foundation
import SwiftUI
import Combine
import UIKit
import CoreLocation

extension LocationPermissionState {
    init(from status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .authorizedWhenInUse:
            self = .authorizedWhenInUse
        case .authorizedAlways:
            self = .authorizedAlways
        @unknown default:
            self = .unknown
        }
    }

    /// Indica se a permissão de localização está efetivamente concedida.
    var isAuthorized: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }
}

enum ProblemType: String, CaseIterable, Identifiable, Codable {
    case riscoEletrico = "Risco Elétrico"
    case riscoQueda = "Risco de Queda"
    case galhoQuebrado = "Galho Quebrado"
    case outro = "Outro"
    
    var id: String { rawValue }
}

enum SolicitacaoStatus: String, CaseIterable, Identifiable, Codable {
    case emAberto = "Em Aberto"
    case emAtendimento = "Em atendimento"
    case concluida = "Concluída"
    case naoConcluida = "Não concluída"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .emAberto:
            return Color.yellow
        case .emAtendimento:
            return Color.orange
        case .concluida:
            return Color.green
        case .naoConcluida:
            return Color.red
        }
    }

    /// Representação do status no backend (API Fastify/PostgreSQL).
    var apiRawValue: String {
        switch self {
        case .emAberto:
            return "NOVA"
        case .emAtendimento:
            return "EM_ATENDIMENTO"
        case .concluida:
            return "CONCLUIDA"
        case .naoConcluida:
            return "NAO_CONCLUIDA"
        }
    }
}

struct Solicitacao: Identifiable {
    let id: UUID
    let backendId: String?
    var tipoProblema: ProblemType
    var endereco: String
    var descricao: String
    var imagens: [UIImage]
    /// URLs de imagens vindas do backend (ex.: anexos salvos pela API).
    var remoteImageURLs: [String]
    /// Versão resolvida das URLs remotas, já como `URL` absoluta.
    var resolvedRemoteImageURLs: [URL] {
        remoteImageURLs.compactMap { resolveBackendURL(pathOrURL: $0) }
    }
    var status: SolicitacaoStatus
    var descricaoAtendimento: String?
    var encaminhamento: EncaminhamentoDestino?
    var coordenada: GeoPoint?
    let createdAt: Date
    let isMinha: Bool
    
    /// Eventos de histórico/auditoria desta solicitação
    /// (ex.: criação, mudanças de status, comentários de atendimento).
    var historico: [SolicitationEvent]
    
    var imagensCount: Int {
        imagens.count
    }
    
    init(
        id: UUID = UUID(),
        backendId: String? = nil,
        tipoProblema: ProblemType,
        endereco: String,
        descricao: String,
        imagens: [UIImage],
        remoteImageURLs: [String] = [],
        status: SolicitacaoStatus,
        descricaoAtendimento: String? = nil,
        encaminhamento: EncaminhamentoDestino? = nil,
        coordenada: GeoPoint? = nil,
        createdAt: Date,
        isMinha: Bool,
        historico: [SolicitationEvent] = []
    ) {
        self.id = id
        self.backendId = backendId
        self.tipoProblema = tipoProblema
        self.endereco = endereco
        self.descricao = descricao
        self.imagens = imagens
        self.remoteImageURLs = remoteImageURLs
        self.status = status
        self.descricaoAtendimento = descricaoAtendimento
        self.encaminhamento = encaminhamento
        self.coordenada = coordenada
        self.createdAt = createdAt
        self.isMinha = isMinha
        self.historico = historico
    }
}

/// Versão persistível de `Solicitacao`, sem imagens em memória.
/// Usada para salvar/carregar em JSON.
struct PersistedSolicitacao: Identifiable, Codable {
    let id: UUID
    var backendId: String?
    var tipoProblema: ProblemType
    var endereco: String
    var descricao: String
    var status: SolicitacaoStatus
    var descricaoAtendimento: String?
    var encaminhamento: EncaminhamentoDestino?
    var coordenada: GeoPoint?
    let createdAt: Date
    let isMinha: Bool
    var historico: [SolicitationEvent]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case backendId
        case tipoProblema
        case endereco
        case descricao
        case status
        case descricaoAtendimento
        case encaminhamento
        case coordenada
        case createdAt
        case isMinha
        case historico
    }
    
    init(
        id: UUID,
        backendId: String? = nil,
        tipoProblema: ProblemType,
        endereco: String,
        descricao: String,
        status: SolicitacaoStatus,
        descricaoAtendimento: String? = nil,
        encaminhamento: EncaminhamentoDestino? = nil,
        coordenada: GeoPoint? = nil,
        createdAt: Date,
        isMinha: Bool,
        historico: [SolicitationEvent] = []
    ) {
        self.id = id
        self.backendId = backendId
        self.tipoProblema = tipoProblema
        self.endereco = endereco
        self.descricao = descricao
        self.status = status
        self.descricaoAtendimento = descricaoAtendimento
        self.encaminhamento = encaminhamento
        self.coordenada = coordenada
        self.createdAt = createdAt
        self.isMinha = isMinha
        self.historico = historico
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        backendId = try container.decodeIfPresent(String.self, forKey: .backendId)
        tipoProblema = try container.decode(ProblemType.self, forKey: .tipoProblema)
        endereco = try container.decode(String.self, forKey: .endereco)
        descricao = try container.decode(String.self, forKey: .descricao)
        status = try container.decode(SolicitacaoStatus.self, forKey: .status)
        descricaoAtendimento = try container.decodeIfPresent(String.self, forKey: .descricaoAtendimento)
        encaminhamento = try container.decodeIfPresent(EncaminhamentoDestino.self, forKey: .encaminhamento)
        coordenada = try container.decodeIfPresent(GeoPoint.self, forKey: .coordenada)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isMinha = try container.decode(Bool.self, forKey: .isMinha)
        historico = try container.decodeIfPresent([SolicitationEvent].self, forKey: .historico) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(backendId, forKey: .backendId)
        try container.encode(tipoProblema, forKey: .tipoProblema)
        try container.encode(endereco, forKey: .endereco)
        try container.encode(descricao, forKey: .descricao)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(descricaoAtendimento, forKey: .descricaoAtendimento)
        try container.encodeIfPresent(encaminhamento, forKey: .encaminhamento)
        try container.encodeIfPresent(coordenada, forKey: .coordenada)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isMinha, forKey: .isMinha)
        try container.encode(historico, forKey: .historico)
    }
}

extension PersistedSolicitacao {
    init(from solicitacao: Solicitacao) {
        self.id = solicitacao.id
        self.backendId = solicitacao.backendId
        self.tipoProblema = solicitacao.tipoProblema
        self.endereco = solicitacao.endereco
        self.descricao = solicitacao.descricao
        self.status = solicitacao.status
        self.descricaoAtendimento = solicitacao.descricaoAtendimento
        self.encaminhamento = solicitacao.encaminhamento
        self.coordenada = solicitacao.coordenada
        self.createdAt = solicitacao.createdAt
        self.isMinha = solicitacao.isMinha
        self.historico = solicitacao.historico
    }
}

extension Solicitacao {
    /// Constrói uma `Solicitacao` em memória a partir da versão persistida.
    /// As imagens são injetadas à parte (por enquanto, mantemos um array vazio).
    init(from persisted: PersistedSolicitacao, imagens: [UIImage] = []) {
        self.init(
            id: persisted.id,
            backendId: persisted.backendId,
            tipoProblema: persisted.tipoProblema,
            endereco: persisted.endereco,
            descricao: persisted.descricao,
            imagens: imagens,
            remoteImageURLs: [],
            status: persisted.status,
            descricaoAtendimento: persisted.descricaoAtendimento,
            encaminhamento: persisted.encaminhamento,
            coordenada: persisted.coordenada,
            createdAt: persisted.createdAt,
            isMinha: persisted.isMinha,
            historico: persisted.historico
        )
    }
}

/// Tipo de evento registrado no histórico da solicitação.
enum SolicitationEventType: String, CaseIterable, Identifiable, Codable {
    case criacao = "Criação"
    case statusAlterado = "Status alterado"
    case comentario = "Comentário"
    case encaminhamento = "Encaminhamento"
    
    var id: String { rawValue }
}

/// Evento de histórico/auditoria de uma solicitação.
struct SolicitationEvent: Identifiable, Codable {
    let id: UUID
    let tipo: SolicitationEventType
    let data: Date
    let autorRole: UserRole
    let descricao: String?
    let statusAnterior: SolicitacaoStatus?
    let statusNovo: SolicitacaoStatus?
    let encaminhamento: EncaminhamentoDestino?
    
    init(
        id: UUID = UUID(),
        tipo: SolicitationEventType,
        data: Date,
        autorRole: UserRole,
        descricao: String? = nil,
        statusAnterior: SolicitacaoStatus? = nil,
        statusNovo: SolicitacaoStatus? = nil,
        encaminhamento: EncaminhamentoDestino? = nil
    ) {
        self.id = id
        self.tipo = tipo
        self.data = data
        self.autorRole = autorRole
        self.descricao = descricao
        self.statusAnterior = statusAnterior
        self.statusNovo = statusNovo
        self.encaminhamento = encaminhamento
    }
}

extension UserRole {
    /// Constrói um `UserRole` a partir do valor de `role` vindo da API.
    /// No backend, os papéis são algo como "USER", "AGENTE", "ADMIN".
    /// Aqui fazemos um mapeamento simples:
    /// - USER -> .cidadao
    /// - AGENTE / ADMIN -> .operario
    init(fromApiRole raw: String?) {
        guard let raw = raw else {
            self = .cidadao
            return
        }
        switch raw.uppercased() {
        case "AGENTE", "ADMIN":
            self = .operario
        default:
            self = .cidadao
        }
    }
}

extension SolicitationEvent {
    /// Constrói um `SolicitationEvent` a partir de um `ApiEvento` retornado pela API.
    /// Essa conversão traduz:
    /// - tipo textual da API -> `SolicitationEventType`
    /// - antigoStatus/novoStatus -> `SolicitacaoStatus?`
    /// - role do autor (string) -> `UserRole`
    init(from api: ApiEvento) {
        let eventType: SolicitationEventType
        switch api.tipo.uppercased() {
        case "CRIACAO":
            eventType = .criacao
        case "STATUS_CHANGE", "STATUS_ALTERADO", "ALTERACAO_STATUS":
            eventType = .statusAlterado
        case "ENCAMINHAMENTO":
            eventType = .encaminhamento
        default:
            eventType = .comentario
        }
        
        let autorRole = UserRole(fromApiRole: api.autor?.role)
        
        let statusAnterior = api.antigoStatus.map { SolicitacaoStatus(fromApiStatus: $0) }
        let statusNovo = api.novoStatus.map { SolicitacaoStatus(fromApiStatus: $0) }
        
        self.init(
            tipo: eventType,
            data: api.createdAt,
            autorRole: autorRole,
            descricao: api.descricao,
            statusAnterior: statusAnterior,
            statusNovo: statusNovo,
            encaminhamento: nil // ainda não mapeamos um campo específico de encaminhamento vindo da API
        )
    }
}

struct GeoPoint: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Helpers de mapeamento a partir da API (backend)

extension ProblemType {
    /// Constrói um `ProblemType` a partir do valor de `categoria` vindo da API.
    /// Ex.: "RISCO_ELETRICO" -> .riscoEletrico
    init(fromApiCategoria raw: String) {
        switch raw.uppercased() {
        case "RISCO_ELETRICO":
            self = .riscoEletrico
        case "RISCO_QUEDAS":
            self = .riscoQueda
        default:
            self = .outro
        }
    }
}

extension SolicitacaoStatus {
    /// Constrói um `SolicitacaoStatus` a partir do valor de `status` vindo da API.
    /// Ex.: "NOVA" -> .emAberto
    init(fromApiStatus raw: String) {
        switch raw.uppercased() {
        case "NOVA":
            self = .emAberto
        case "EM_ATENDIMENTO":
            self = .emAtendimento
        case "CONCLUIDA":
            self = .concluida
        case "NAO_CONCLUIDA":
            self = .naoConcluida
        default:
            self = .emAberto
        }
    }
}

enum SolicitacaoFilter: String, CaseIterable, Identifiable {
    case minhas = "Minhas"
    case proximas = "Próximas"
    case todas = "Todas"

    var id: String { rawValue }
}

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case cidadao = "Cidadão"
    case operario = "Operário"
    
    var id: String { rawValue }
}

/// Sessão persistida do usuário autenticado.
/// Usada para manter login entre aberturas do app.
struct PersistedSession: Codable {
    let userId: String
    let nome: String
    let email: String
    let role: UserRole
}

enum EncaminhamentoDestino: String, CaseIterable, Identifiable, Codable {
    case defesaCivil = "Defesa Civil"
    case bombeiros = "Bombeiros"
    case companhiaEnergia = "Companhia de Energia"
    
    var id: String { rawValue }
}

/// Estado de permissão de localização em um formato independente de CoreLocation.
/// No futuro, será atualizado a partir de CLAuthorizationStatus.
enum LocationPermissionState {
    case unknown          // estado inicial, antes de checarmos
    case notDetermined    // usuário ainda não foi perguntado
    case denied           // usuário negou permissão
    case restricted       // restrição por controles de sistema (ex.: tempo de tela)
    case authorizedWhenInUse   // autorizado enquanto o app está em uso
    case authorizedAlways      // autorizado sempre
}

final class AppState: ObservableObject {
    @Published var currentRole: UserRole = .cidadao
    @Published var solicitacoes: [Solicitacao] = []

    /// Identidade básica do usuário autenticado no backend (quando houver login bem-sucedido).
    @Published var currentUserId: String? = nil
    @Published var currentUserName: String? = nil
    @Published var currentUserEmail: String? = nil

    /// Indica se há um usuário autenticado no app (baseado em `currentUserId`).
    var isLoggedIn: Bool {
        currentUserId != nil
    }
    
    // Localização simulada do usuário (Centro de São Paulo, por exemplo)
    @Published var mockUserLocation: GeoPoint = GeoPoint(
        latitude: -23.5505,
        longitude: -46.6333
    )
    
    // Localização real reportada pelo dispositivo (quando integrarmos CoreLocation)
    @Published var realUserLocation: GeoPoint? = nil
    
    // Estado atual da permissão de localização
    @Published var locationPermissionState: LocationPermissionState = .unknown
    
    // Define se o app deve usar a localização simulada (mock) ou a real, quando disponível.
    // No MVP, preferimos a localização real; o mock fica apenas como fallback/debug.
    @Published var isUsingSimulatedLocation: Bool = false
    
    /// Localização "efetiva" usada nas telas (filtros de proximidade, etc.).
    /// - Se `isUsingSimulatedLocation` for true ou `realUserLocation` for nil, retorna o mock.
    /// - Caso contrário, retorna a localização real.
    var effectiveUserLocation: GeoPoint {
        if isUsingSimulatedLocation || realUserLocation == nil {
            return mockUserLocation
        } else {
            return realUserLocation!
        }
    }
    
    init() {
        // Tenta carregar sessão de usuário persistida (login).
        loadSessionFromDisk()
        
        // Carrega as solicitações direto da API (Postgres como fonte de verdade).
        carregarSolicitacoesDaApi()
    }
}

// MARK: - DTOs de API (Fastify/PostgreSQL)

/// Anexo retornado pela API, normalmente representando uma imagem.
struct ApiAnexo: Codable, Identifiable {
    let id: String
    let url: String
    let mime: String
}

/// Estrutura da resposta da API em GET /solicitacoes.
struct ApiSolicitacoesResponse: Codable {
    let status: String
    let total: Int
    let items: [ApiSolicitacao]
}

/// Representa uma solicitação vinda da API.
struct ApiSolicitacao: Codable, Identifiable {
    let id: String
    let titulo: String
    let descricao: String
    let categoria: String
    let status: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date
    let autor: ApiUsuarioResumo
    let anexos: [ApiAnexo]
}

/// Autor resumido retornado pela API na lista de solicitações.
///
/// Observação:
/// - `email` e `login` são opcionais para manter compatibilidade mesmo que o backend
///   ainda não envie esses campos em todas as respostas.
struct ApiUsuarioResumo: Codable {
    let id: String
    let nome: String
    let role: String
    let email: String?
    let login: String?
}

// MARK: - Configuração de API (URL base e helpers)

/// Ambiente de API usado pelo app (dev/homolog/produção).
/// Ajuste `baseURLString` conforme necessário.
enum ApiEnvironment {
    /// Base URL do backend Fastify/PostgreSQL (sem barra no final).
    /// No momento está apontando para o servidor local de desenvolvimento.
    static let baseURLString = "http://localhost:3333"

    static var baseURL: URL {
        URL(string: baseURLString)!
    }
}

/// Resolve uma string vinda do backend (que pode ser absoluta ou relativa)
/// em uma URL absoluta utilizável pelo iOS.
///
/// Exemplos:
/// - "https://meu-servidor/uploads/abc.jpg" -> mesma URL
/// - "/uploads/abc.jpg" -> ApiEnvironment.baseURL + "/uploads/abc.jpg"
/// - "uploads/abc.jpg" -> ApiEnvironment.baseURLString + "/uploads/abc.jpg"
func resolveBackendURL(pathOrURL: String) -> URL? {
    let trimmed = pathOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }

    // Se já vier com http/https, usamos direto.
    if trimmed.lowercased().hasPrefix("http://") ||
        trimmed.lowercased().hasPrefix("https://") {
        return URL(string: trimmed)
    }

    // Se vier começando com "/", anexamos à base.
    if trimmed.hasPrefix("/") {
        return URL(string: trimmed, relativeTo: ApiEnvironment.baseURL)
    }

    // Caso contrário, consideramos como path relativo sem barra
    return URL(string: ApiEnvironment.baseURLString + "/" + trimmed)
}

extension Solicitacao {
    /// Constrói uma `Solicitacao` (modelo de UI) a partir de uma `ApiSolicitacao` (DTO da API),
    /// assumindo `isMinha = false` por padrão.
    init(from api: ApiSolicitacao) {
        self.init(from: api, isMinha: false)
    }

    /// Constrói uma `Solicitacao` (modelo de UI) a partir de uma `ApiSolicitacao` (DTO da API),
    /// permitindo informar se ela pertence ao usuário logado (`isMinha`).
    init(from api: ApiSolicitacao, isMinha: Bool) {
        self.init(
            id: UUID(), // identificador local para a UI
            backendId: api.id, // ID real da solicitação no backend
            tipoProblema: ProblemType(fromApiCategoria: api.categoria),
            endereco: String(
                format: "Lat: %.5f, Lon: %.5f",
                api.latitude,
                api.longitude
            ),
            descricao: api.descricao,
            imagens: [],
            remoteImageURLs: api.anexos.map { $0.url },
            status: SolicitacaoStatus(fromApiStatus: api.status),
            descricaoAtendimento: nil,
            encaminhamento: nil,
            coordenada: GeoPoint(latitude: api.latitude, longitude: api.longitude),
            createdAt: api.createdAt,
            isMinha: isMinha,
            historico: []
        )
    }
}

extension AppState {
    /// Carrega as solicitações a partir da API Fastify/PostgreSQL e atualiza o estado,
    /// preservando imagens e alguns campos locais ao recarregar da API.
    func carregarSolicitacoesDaApi() {
        Task {
            do {
                let apiItems = try await ApiClient.shared.fetchSolicitacoes()
                
                // Capturamos um snapshot das solicitações atuais em memória
                // para poder reaproveitar dados que existem só no app,
                // como imagens e alguns campos locais.
                let antigos = await MainActor.run { self.solicitacoes }
                
                // Usamos tanto o ID quanto o e-mail/login do usuário atual
                // para determinar se uma solicitação é "minha".
                let currentUserId = self.currentUserId
                let currentEmail = self.currentUserEmail?.lowercased()
                
                var mapped: [Solicitacao] = []
                
                for api in apiItems {
                    let autorId = api.autor.id
                    let autorEmailOrLogin = api.autor.email?.lowercased()
                        ?? api.autor.login?.lowercased()
                    
                    let matchById = (currentUserId != nil && autorId == currentUserId)
                    let matchByEmail = (currentEmail != nil && autorEmailOrLogin == currentEmail)
                    
                    let isMinha = matchById || matchByEmail
                    
                    // Tenta encontrar uma solicitação já existente em memória
                    // com o mesmo backendId, para reaproveitar imagens e alguns campos.
                    let existente = antigos.first { $0.backendId == api.id }
                    
                    let imagens = existente?.imagens ?? []
                    let descricaoAtendimento = existente?.descricaoAtendimento
                    let encaminhamento = existente?.encaminhamento
                    let localId = existente?.id ?? UUID()
                    
                    // Busca o histórico real da API para esta solicitação.
                    var historico: [SolicitationEvent] = []
                    do {
                        let eventosApi = try await ApiClient.shared.fetchEventos(for: api.id)
                        historico = eventosApi.map { SolicitationEvent(from: $0) }
                    } catch {
                        // Se falhar o carregamento do histórico, reaproveitamos o que já tínhamos (se houver)
                        if let historicoExistente = existente?.historico {
                            historico = historicoExistente
                        }
                        print("Erro ao carregar eventos para solicitação \(api.id): \(error)")
                    }
                    
                    let solicitacao = Solicitacao(
                        id: localId,
                        backendId: api.id,
                        tipoProblema: ProblemType(fromApiCategoria: api.categoria),
                        endereco: String(
                            format: "Lat: %.5f, Lon: %.5f",
                            api.latitude,
                            api.longitude
                        ),
                        descricao: api.descricao,
                        imagens: imagens,
                        remoteImageURLs: api.anexos.map { $0.url },
                        status: SolicitacaoStatus(fromApiStatus: api.status),
                        descricaoAtendimento: descricaoAtendimento,
                        encaminhamento: encaminhamento,
                        coordenada: GeoPoint(latitude: api.latitude, longitude: api.longitude),
                        createdAt: api.createdAt,
                        isMinha: isMinha,
                        historico: historico
                    )
                    
                    mapped.append(solicitacao)
                }
                
                await MainActor.run {
                    self.solicitacoes = mapped
                }
            } catch {
                print("Erro ao carregar solicitações da API: \(error.localizedDescription)")
            }
        }
    }

    /// Cria uma nova solicitação no backend já enviando as imagens como anexos.
    ///
    /// Este método:
    /// - faz upload de cada imagem usando a rota de upload da API;
    /// - monta o payload de anexos (url + mime);
    /// - chama `createSolicitacao` no `ApiClient`;
    /// - converte o DTO retornado em `Solicitacao` de UI;
    /// - atualiza a lista em memória via `upsertSolicitacao`.
    @MainActor
    func criarSolicitacaoComImagens(
        titulo: String,
        descricao: String,
        tipoProblema: ProblemType,
        coordenada: GeoPoint,
        imagens: [UIImage]
    ) async {
        guard let userId = currentUserId else {
            print("[AppState] Sem usuário logado; não é possível criar solicitação.")
            return
        }

        do {
            // 1) Faz upload de cada imagem e acumula os anexos (url + mime).
            var anexosPayload: [(url: String, mime: String)] = []

            for imagem in imagens {
                guard let data = imagem.jpegData(compressionQuality: 0.8) else {
                    continue
                }

                let uploaded = try await ApiClient.shared.uploadImageBase64(
                    data: data,
                    mime: "image/jpeg"
                )
                anexosPayload.append(uploaded)
            }

            // 2) Cria a solicitação na API já com os anexos.
            let apiItem = try await ApiClient.shared.createSolicitacao(
                titulo: titulo,
                descricao: descricao,
                tipoProblema: tipoProblema,
                coordenada: coordenada,
                autorId: userId,
                anexos: anexosPayload
            )

            // 3) Converte o DTO da API para o modelo de UI.
            let novaSolicitacao = Solicitacao(
                from: apiItem,
                isMinha: true
            )

            // 4) Atualiza a lista em memória (e consequentemente a UI).
            upsertSolicitacao(novaSolicitacao)
        } catch {
            print("[AppState] Erro ao criar solicitação com imagens: \(error)")
        }
    }
    func upsertSolicitacao(_ nova: Solicitacao) {
        if let backendId = nova.backendId,
           let index = solicitacoes.firstIndex(where: { $0.backendId == backendId }) {
            solicitacoes[index] = nova
        } else if let index = solicitacoes.firstIndex(where: { $0.id == nova.id }) {
            solicitacoes[index] = nova
        } else {
            solicitacoes.append(nova)
        }
    }
    func replaceSolicitacoes(_ novas: [Solicitacao]) {
        solicitacoes = novas
    }

    // MARK: - Persistência de sessão (login)

    /// Chave usada no UserDefaults para persistir a sessão.
    private var sessionDefaultsKey: String { "CortaPauSession_v1" }

    /// Carrega a sessão de usuário (se existir) do UserDefaults.
    func loadSessionFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: sessionDefaultsKey) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode(PersistedSession.self, from: data)
            DispatchQueue.main.async {
                self.currentUserId = decoded.userId
                self.currentUserName = decoded.nome
                self.currentUserEmail = decoded.email
                self.currentRole = decoded.role
            }
        } catch {
            print("Erro ao carregar sessão do usuário: \(error)")
        }
    }

    /// Salva a sessão atual (se houver usuário logado) no UserDefaults.
    func saveSessionToDisk() {
        guard let userId = currentUserId,
              let nome = currentUserName,
              let email = currentUserEmail else {
            // Se não há sessão válida, garante que removemos qualquer resquício salvo.
            UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
            return
        }

        let session = PersistedSession(userId: userId, nome: nome, email: email, role: currentRole)

        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: sessionDefaultsKey)
        } catch {
            print("Erro ao salvar sessão do usuário: \(error)")
        }
    }

    /// Limpa os dados de sessão em memória e no UserDefaults.
    ///
    /// Mantemos a lista de solicitações em memória para que dados locais
    /// (como imagens não persistidas no backend) possam ser reaproveitados
    /// após novo login, desde que as solicitações tenham o mesmo `backendId`.
    func clearSession() {
        DispatchQueue.main.async {
            self.currentUserId = nil
            self.currentUserName = nil
            self.currentUserEmail = nil
        }
        UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
    }
}
