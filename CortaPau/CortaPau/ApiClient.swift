//
//  ApiClient.swift
//  CortaPau
//
//  Created by Lucas Malaguti on 11/20/25.
//

import Foundation

/// Erros básicos de rede/decodificação ao falar com a API do CortaPau.
enum ApiError: LocalizedError {
    case invalidURL
    case invalidStatusCode(Int)
    case backendError(String)
    case decodingError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL da API inválida."
        case .invalidStatusCode(let code):
            return "A API retornou um código de status inesperado: \(code)."
        case .backendError(let message):
            return "Erro na API: \(message)"
        case .decodingError(let message):
            return "Falha ao interpretar a resposta da API: \(message)"
        case .unknown:
            return "Ocorreu um erro desconhecido ao acessar a API."
        }
    }
}

/// Resposta da API ao criar uma nova solicitação.
struct ApiCreateSolicitacaoResponse: Codable {
    let status: String
    let item: ApiSolicitacao
}

/// Resposta da API ao fazer upload de uma imagem em base64.
struct ApiUploadBase64Response: Codable {
    let status: String
    let url: String
    let mime: String
}

/// Usuário retornado pela API ao fazer login.
struct ApiUser: Codable {
    let id: String
    let nome: String
    let login: String
    let role: String
}

/// Resposta da API ao fazer login.
struct ApiLoginResponse: Codable {
    let status: String
    let user: ApiUser
}

/// Evento retornado pela API ao consultar o histórico de uma solicitação.
struct ApiEvento: Codable, Identifiable {
    let id: String
    let tipo: String
    let descricao: String?
    let antigoStatus: String?
    let novoStatus: String?
    let createdAt: Date
    let autor: ApiUsuarioResumo?
}

/// Envelope de resposta para a rota GET /solicitacoes/:id/eventos.
struct ApiEventosResponse: Codable {
    let status: String
    let items: [ApiEvento]
}

/// Cliente HTTP bem simples para falar com a API Fastify.
///
/// - No simulador, `baseURL` pode ser `http://localhost:3333`.
/// - Em um dispositivo físico, no futuro, vamos trocar para o IP da máquina que roda a API.
struct ApiClient {
    static let shared = ApiClient()

    /// URL base da API (por padrão, localhost).
    let baseURL: URL

    private let decoder: JSONDecoder

    init(baseURL: URL = ApiEnvironment.baseURL) {
        self.baseURL = baseURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    private func url(for path: String) -> URL? {
        // Garante que sempre haja uma "/" entre base e path
        if path.hasPrefix("/") {
            return baseURL.appendingPathComponent(String(path.dropFirst()))
        } else {
            return baseURL.appendingPathComponent(path)
        }
    }

    /// Payload para criação de nova solicitação na API.
    private struct CreateSolicitacaoPayload: Encodable {
        let titulo: String
        let descricao: String
        let categoria: String
        let latitude: Double
        let longitude: Double
        let autorId: String?
        let anexos: [CreateAnexoPayload]?
    }

    /// Payload interno para anexos enviados junto com a criação da solicitação.
    private struct CreateAnexoPayload: Encodable {
        let url: String
        let mime: String
    }

    /// Payload para atualização de uma solicitação existente na API.
    private struct UpdateSolicitacaoPayload: Encodable {
        let status: String?
        let descricao: String?
    }

    /// Payload para login na API.
    private struct LoginPayload: Encodable {
        let login: String
        let senha: String
    }

    /// Payload para registro de novo usuário na API.
    private struct RegisterPayload: Encodable {
        let nome: String
        let email: String
        let senha: String
    }

    /// Payload para upload de imagem em base64 na API.
    private struct UploadBase64Payload: Encodable {
        let imagemBase64: String
        let mime: String
    }

    /// Mapeia o `ProblemType` usado na UI para o texto esperado pela API (`Categoria` do Prisma).
    private func apiCategoria(from tipoProblema: ProblemType) -> String {
        switch tipoProblema {
        case .riscoEletrico:
            return "RISCO_ELETRICO"
        case .riscoQueda:
            return "RISCO_QUEDAS"
        default:
            return "OUTROS"
        }
    }

    /// Cria uma nova solicitação em POST /solicitacoes.
    ///
    /// - Parameters:
    ///   - anexos: lista de anexos já enviados para o backend (URLs + mime),
    ///             normalmente retornados por `uploadImageBase64`.
    ///
    /// Retorna a `ApiSolicitacao` criada pelo backend.
    func createSolicitacao(
        titulo: String,
        descricao: String,
        tipoProblema: ProblemType,
        coordenada: GeoPoint,
        autorId: String? = nil,
        anexos: [(url: String, mime: String)] = []
    ) async throws -> ApiSolicitacao {
        guard let url = url(for: "/solicitacoes") else {
            throw ApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let anexosPayload: [CreateAnexoPayload]? =
            anexos.isEmpty ? nil : anexos.map { CreateAnexoPayload(url: $0.url, mime: $0.mime) }

        let payload = CreateSolicitacaoPayload(
            titulo: titulo,
            descricao: descricao,
            categoria: apiCategoria(from: tipoProblema),
            latitude: coordenada.latitude,
            longitude: coordenada.longitude,
            autorId: autorId,
            anexos: anexosPayload
        )

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        request.httpBody = bodyData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.unknown
        }

        guard (200..<300).contains(http.statusCode) else {
            throw ApiError.invalidStatusCode(http.statusCode)
        }

        do {
            let decoded = try decoder.decode(ApiCreateSolicitacaoResponse.self, from: data)

            if decoded.status.lowercased() != "ok" {
                throw ApiError.backendError(decoded.status)
            }

            return decoded.item
        } catch let decodingError as DecodingError {
            return try handleDecodingError(decodingError, data: data)
        } catch let apiError as ApiError {
            throw apiError
        } catch {
            throw ApiError.decodingError(error.localizedDescription)
        }
    }

    /// Faz upload de uma imagem em base64 para a API em POST /uploads/base64.
    ///
    /// - Parameters:
    ///   - data: bytes da imagem (por exemplo, resultado de `jpegData(compressionQuality:)`).
    ///   - mime: tipo MIME da imagem, ex.: "image/jpeg" ou "image/png".
    ///
    /// - Returns: tupla com `url` (caminho a ser enviado em `anexos` no POST /solicitacoes)
    ///            e `mime` efetivo salvo pelo backend.
    func uploadImageBase64(data: Data, mime: String) async throws -> (url: String, mime: String) {
        guard let url = url(for: "/uploads/base64") else {
            throw ApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = UploadBase64Payload(
            imagemBase64: data.base64EncodedString(),
            mime: mime
        )

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        request.httpBody = bodyData

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.unknown
        }

        guard (200..<300).contains(http.statusCode) else {
            throw ApiError.invalidStatusCode(http.statusCode)
        }

        do {
            let decoded = try decoder.decode(ApiUploadBase64Response.self, from: responseData)

            if decoded.status.lowercased() != "ok" {
                throw ApiError.backendError(decoded.status)
            }

            return (url: decoded.url, mime: decoded.mime)
        } catch let decodingError as DecodingError {
            return try handleDecodingError(decodingError, data: responseData)
        } catch let apiError as ApiError {
            throw apiError
        } catch {
            throw ApiError.decodingError(error.localizedDescription)
        }
    }

    /// Atualiza uma solicitação existente em PATCH /solicitacoes/:id.
    /// Você pode mudar apenas o status, apenas a descrição ou ambos.
    func updateSolicitacao(
        id: String,
        status: String? = nil,
        descricao: String? = nil
    ) async throws -> ApiSolicitacao {
        guard let url = url(for: "/solicitacoes/\(id)") else {
            throw ApiError.invalidURL
        }

        // Se nada foi passado, não faz sentido chamar a API.
        if status == nil && descricao == nil {
            throw ApiError.backendError("Nada para atualizar.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = UpdateSolicitacaoPayload(status: status, descricao: descricao)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        request.httpBody = bodyData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.unknown
        }

        guard (200..<300).contains(http.statusCode) else {
            throw ApiError.invalidStatusCode(http.statusCode)
        }

        do {
            // A resposta de PATCH tem o mesmo formato de criação: { status, item }
            let decoded = try decoder.decode(ApiCreateSolicitacaoResponse.self, from: data)

            if decoded.status.lowercased() != "ok" {
                throw ApiError.backendError(decoded.status)
            }

            return decoded.item
        } catch let decodingError as DecodingError {
            return try handleDecodingError(decodingError, data: data)
        } catch let apiError as ApiError {
            throw apiError
        } catch {
            throw ApiError.decodingError(error.localizedDescription)
        }
    }

    /// Faz login na API em POST /auth/login.
    /// Retorna o `ApiUser` quando as credenciais são válidas.
    func login(login: String, senha: String) async throws -> ApiUser {
        guard let url = url(for: "/auth/login") else {
            throw ApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = LoginPayload(login: login, senha: senha)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        request.httpBody = bodyData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.unknown
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw ApiError.backendError("Credenciais inválidas")
            }
            throw ApiError.invalidStatusCode(http.statusCode)
        }

        do {
            let decoded = try decoder.decode(ApiLoginResponse.self, from: data)

            if decoded.status.lowercased() != "ok" {
                throw ApiError.backendError(decoded.status)
            }

            return decoded.user
        } catch let decodingError as DecodingError {
            return try handleDecodingError(decodingError, data: data)
        } catch let apiError as ApiError {
            throw apiError
        } catch {
            throw ApiError.decodingError(error.localizedDescription)
        }
    }

    /// Registra um novo usuário em POST /auth/register.
    /// Retorna o `ApiUser` criado quando o registro é bem-sucedido.
    func register(nome: String, email: String, senha: String) async throws -> ApiUser {
        guard let url = url(for: "/auth/register") else {
            throw ApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = RegisterPayload(nome: nome, email: email, senha: senha)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        request.httpBody = bodyData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.unknown
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 400 {
                // Tenta decodificar uma mensagem de erro do backend
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Erro 400 em /auth/register: \(jsonString)")
                }
                throw ApiError.backendError("Não foi possível registrar. Verifique os dados informados.")
            }
            throw ApiError.invalidStatusCode(http.statusCode)
        }

        do {
            // A resposta de /auth/register segue o mesmo formato de login: { status, user }
            let decoded = try decoder.decode(ApiLoginResponse.self, from: data)

            if decoded.status.lowercased() != "ok" {
                throw ApiError.backendError(decoded.status)
            }

            return decoded.user
        } catch let decodingError as DecodingError {
            return try handleDecodingError(decodingError, data: data)
        } catch let apiError as ApiError {
            throw apiError
        } catch {
            throw ApiError.decodingError(error.localizedDescription)
        }
    }

    /// Busca a lista de solicitações em GET /solicitacoes.
    ///
    /// Retorna um array de `ApiSolicitacao` (DTO definido em Models.swift),
    /// que depois é convertido em `Solicitacao` para uso na UI.
    func fetchSolicitacoes() async throws -> [ApiSolicitacao] {
        guard let url = url(for: "/solicitacoes") else {
            throw ApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.unknown
        }

        guard (200..<300).contains(http.statusCode) else {
            throw ApiError.invalidStatusCode(http.statusCode)
        }

        do {
            let decoded = try decoder.decode(ApiSolicitacoesResponse.self, from: data)

            // A nossa API retorna um campo "status" textual; se for diferente de "ok",
            // consideramos um erro de backend.
            if decoded.status.lowercased() != "ok" {
                throw ApiError.backendError(decoded.status)
            }

            return decoded.items
        } catch let decodingError as DecodingError {
            // Só para facilitar debug se algo quebrar na estrutura do JSON
            return try handleDecodingError(decodingError, data: data)
        } catch let apiError as ApiError {
            throw apiError
        } catch {
            throw ApiError.decodingError(error.localizedDescription)
        }
    }

    /// Busca o histórico de eventos de uma solicitação em
    /// GET /solicitacoes/:id/eventos.
    ///
    /// - Parameter solicitacaoId: ID da solicitação no backend (campo `backendId` no app).
    /// - Returns: Lista de `ApiEvento` em ordem cronológica.
    func fetchEventos(for solicitacaoId: String) async throws -> [ApiEvento] {
        guard let url = url(for: "/solicitacoes/\(solicitacaoId)/eventos") else {
            throw ApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiError.unknown
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 {
                // Se a API disser que a solicitação não existe, tratamos como erro de backend sem quebrar o app.
                throw ApiError.backendError("Solicitação não encontrada para carregar histórico.")
            }
            throw ApiError.invalidStatusCode(http.statusCode)
        }

        do {
            let decoded = try decoder.decode(ApiEventosResponse.self, from: data)

            if decoded.status.lowercased() != "ok" {
                throw ApiError.backendError(decoded.status)
            }

            return decoded.items
        } catch let decodingError as DecodingError {
            return try handleDecodingError(decodingError, data: data)
        } catch let apiError as ApiError {
            throw apiError
        } catch {
            throw ApiError.decodingError(error.localizedDescription)
        }
    }

    /// Helper para logar e detalhar erros de decodificação.
    private func handleDecodingError<T>(_ error: DecodingError, data: Data) throws -> T {
        let message: String

        switch error {
        case .typeMismatch(let type, let context):
            message = "Type mismatch para \(type): \(context.debugDescription) em \(context.codingPath)"
        case .valueNotFound(let type, let context):
            message = "Value not found para \(type): \(context.debugDescription) em \(context.codingPath)"
        case .keyNotFound(let key, let context):
            message = "Key not found: \(key.stringValue): \(context.debugDescription) em \(context.codingPath)"
        case .dataCorrupted(let context):
            message = "Data corrupted: \(context.debugDescription) em \(context.codingPath)"
        @unknown default:
            message = "Erro de decodificação desconhecido."
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            print("DecodingError: \(message)\nPayload bruto:\n\(jsonString)")
        } else {
            print("DecodingError: \(message)\nPayload binário de \(data.count) bytes.")
        }

        throw ApiError.decodingError(message)
    }
}
