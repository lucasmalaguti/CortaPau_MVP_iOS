//
//  CortaPauApp.swift
//  CortaPau
//
//  Created by Lucas Malaguti on 11/20/25.
//

import SwiftUI
import PhotosUI
import MapKit

// MARK: - Tema básico inspirado no ChatGPT

struct AppColors {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.10) // fundo bem escuro
    static let surface    = Color(red: 0.13, green: 0.14, blue: 0.18) // cards
    static let accent     = Color(red: 0.21, green: 0.78, blue: 0.39) // verde "chat"
    static let accentSoft = Color(red: 0.16, green: 0.56, blue: 0.31)
    static let textPrimary   = Color.white
    static let textSecondary = Color(red: 0.75, green: 0.77, blue: 0.80)
    static let border        = Color(red: 0.25, green: 0.27, blue: 0.32)
}

struct AppTypography {
    static func titleLarge() -> Font { .system(size: 28, weight: .semibold, design: .rounded) }
    static func titleMedium() -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 16, weight: .regular, design: .rounded) }
    static func caption() -> Font { .system(size: 13, weight: .regular, design: .rounded) }
}

// Distância aproximada entre dois pontos (Haversine), em metros
private func distanceInMeters(from: GeoPoint, to: GeoPoint) -> Double {
    let R = 6_371_000.0 // raio médio da Terra em metros
    
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let dLat = (to.latitude - from.latitude) * .pi / 180
    let dLon = (to.longitude - from.longitude) * .pi / 180
    
    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    
    return R * c
}

// MARK: - Navegação raiz (Login -> Home)

enum AppScreen {
    case login
    case home
    case novaSolicitacao
    case solicitacoes
    case atenderSolicitacoes
    case detalheSolicitacao
}

enum DetalheOrigin {
    case solicitacoes
    case atender
}


struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locationManager: LocationManager
    @State private var currentScreen: AppScreen = .login
    @State private var selectedSolicitacaoID: UUID?
    @State private var detalheOrigin: DetalheOrigin = .solicitacoes


    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            switch currentScreen {
            case .login:
                LoginView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentScreen = .home
                    }
                }
                
            case .home:
                HomeView(
                    onLogout: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .login
                        }
                    },
                    onNovaSolicitacao: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .novaSolicitacao
                        }
                    },
                    onSolicitacoes: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .solicitacoes
                        }
                    },
                    onAtenderSolicitacoes: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .atenderSolicitacoes
                        }
                    }
                )
                
            case .novaSolicitacao:
                NovaSolicitacaoView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentScreen = .home
                    }
                }
                
            case .solicitacoes:
                SolicitacoesView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .home
                        }
                    },
                    onSelectSolicitacao: { solicitacao in
                        selectedSolicitacaoID = solicitacao.id
                        detalheOrigin = .solicitacoes
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .detalheSolicitacao
                        }
                    }
                )
                
            case .atenderSolicitacoes:
                AtenderSolicitacoesView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .home
                        }
                    },
                    onSelectSolicitacao: { solicitacao in
                        selectedSolicitacaoID = solicitacao.id
                        detalheOrigin = .atender
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentScreen = .detalheSolicitacao
                        }
                    }
                )
                
            case .detalheSolicitacao:
                if let id = selectedSolicitacaoID,
                   let index = appState.solicitacoes.firstIndex(where: { $0.id == id }) {
                    DetalheSolicitacaoView(
                        solicitacao: $appState.solicitacoes[index],
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                switch detalheOrigin {
                                case .solicitacoes:
                                    currentScreen = .solicitacoes
                                case .atender:
                                    currentScreen = .atenderSolicitacoes
                                }
                            }
                        }
                    )
                } else {
                    HomeView(
                        onLogout: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .login
                            }
                        },
                        onNovaSolicitacao: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .novaSolicitacao
                            }
                        },
                        onSolicitacoes: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .solicitacoes
                            }
                        },
                        onAtenderSolicitacoes: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .atenderSolicitacoes
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Tela de Login

struct LoginView: View {
    var onLoginSuccess: () -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var email: String = ""
    @State private var senha: String = ""
    @State private var selectedRole: UserRole = .cidadao
    @State private var isLoading: Bool = false
    @State private var loginError: String? = nil
    @State private var isRegisterPresented: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            
            // Cabeçalho
            VStack(alignment: .leading, spacing: 8) {
                Text("Corta Pau")
                    .font(AppTypography.titleLarge())
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Solicite e acompanhe podas de árvores em situação de risco.")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Card de login
            VStack(spacing: 16) {
                // Login com gov.br (placeholder)
                Button(action: {
                    // TODO: integração futura com gov.br
                }, label: {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                        Text("Entrar com gov.br")
                            .font(AppTypography.body())
                    }
                    .frame(maxWidth: .infinity)
                })
                .buttonStyle(PrimaryButtonStyle(variant: .outline))
                
                DividerView(label: "ou use seu e-mail")
                
                // Campos de email e senha
                VStack(spacing: 12) {
                    LabeledField(title: "E-mail") {
                        TextField("seu@email.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .foregroundColor(AppColors.textPrimary)
                            .font(AppTypography.body())
                    }
                    
                    LabeledField(title: "Senha") {
                        SecureField("Digite sua senha", text: $senha)
                            .foregroundColor(AppColors.textPrimary)
                            .font(AppTypography.body())
                    }
                }
                
                // Perfil de acesso
                VStack(alignment: .leading, spacing: 8) {
                    Text("Perfil de acesso")
                        .font(AppTypography.caption().weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Picker("Perfil", selection: $selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppColors.accent)
                }
                
                // Botão de entrar
                Button(action: {
                    loginError = nil
                    isLoading = true
                    
                    Task {
                        do {
                            // Chama a API real de login (POST /auth/login) e captura o usuário retornado
                            let apiUser = try await ApiClient.shared.login(login: email, senha: senha)
                            
                            await MainActor.run {
                                // Mantemos o fluxo de perfil escolhido no app (cidadao/operario)
                                appState.currentRole = selectedRole
                                appState.currentUserEmail = apiUser.login
                                appState.currentUserName = apiUser.nome
                                appState.currentUserId = apiUser.id
                                
                                // Persiste sessão e carrega solicitações da API já vinculadas a este usuário
                                appState.saveSessionToDisk()
                                appState.carregarSolicitacoesDaApi()
                                
                                isLoading = false
                                onLoginSuccess()
                            }
                        } catch {
                            await MainActor.run {
                                isLoading = false
                                
                                if let apiError = error as? ApiError {
                                    switch apiError {
                                    case .backendError(let message):
                                        loginError = message
                                    default:
                                        loginError = "Falha ao conectar. Tente novamente."
                                    }
                                } else {
                                    loginError = "Falha ao conectar. Tente novamente."
                                }
                            }
                        }
                    }
                }, label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "Entrando..." : "Entrar")
                            .font(AppTypography.body().weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                })
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || senha.isEmpty || isLoading)
                .opacity((email.isEmpty || senha.isEmpty || isLoading) ? 0.6 : 1.0)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || senha.isEmpty || isLoading)
                .opacity((email.isEmpty || senha.isEmpty || isLoading) ? 0.6 : 1.0)
                
                if let loginError {
                    Text(loginError)
                        .font(AppTypography.caption())
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Links secundários
                HStack {
                    Button(action: {
                        // TODO: fluxo de reset
                    }, label: {
                        Text("Esqueci minha senha")
                            .font(AppTypography.caption())
                    })
                    
                    Spacer()
                    
                    Button(action: {
                        isRegisterPresented = true
                    }, label: {
                        Text("Criar nova conta")
                            .font(AppTypography.caption().weight(.medium))
                    })
                }
                .foregroundColor(AppColors.textSecondary)
            }
            .padding(20)
            .background(AppColors.surface)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .sheet(isPresented: $isRegisterPresented) {
            RegisterView { newUser in
                Task {
                    await MainActor.run {
                        // Após registrar, tratamos como login bem-sucedido
                        appState.currentUserEmail = newUser.login
                        appState.currentUserName = newUser.nome
                        appState.currentUserId = newUser.id
                        appState.currentRole = .cidadao // novo usuário começa como cidadão
                        
                        appState.saveSessionToDisk()
                        appState.carregarSolicitacoesDaApi()
                        
                        isLoading = false
                        isRegisterPresented = false
                        onLoginSuccess()
                    }
                }
            }
        }
    }
}

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    
    var onRegisterSuccess: (ApiUser) -> Void
    
    @State private var nome: String = ""
    @State private var email: String = ""
    @State private var senha: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Criar conta")
                        .font(AppTypography.titleMedium())
                        .foregroundColor(AppColors.textPrimary)
                    Text("Cadastre-se para começar a usar o Corta Pau.")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 12) {
                    LabeledField(title: "Nome completo") {
                        TextField("Seu nome", text: $nome)
                            .textInputAutocapitalization(.words)
                            .foregroundColor(AppColors.textPrimary)
                            .font(AppTypography.body())
                    }
                    
                    LabeledField(title: "E-mail") {
                        TextField("seu@email.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .foregroundColor(AppColors.textPrimary)
                            .font(AppTypography.body())
                    }
                    
                    LabeledField(title: "Senha") {
                        SecureField("Crie uma senha", text: $senha)
                            .foregroundColor(AppColors.textPrimary)
                            .font(AppTypography.body())
                    }
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption())
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: {
                    errorMessage = nil
                    
                    let trimmedNome = nome.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedSenha = senha.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    guard !trimmedNome.isEmpty,
                          !trimmedEmail.isEmpty,
                          !trimmedSenha.isEmpty else {
                        errorMessage = "Preencha todos os campos para continuar."
                        return
                    }
                    
                    isLoading = true
                    
                    Task {
                        do {
                            let newUser = try await ApiClient.shared.register(
                                nome: trimmedNome,
                                email: trimmedEmail,
                                senha: trimmedSenha
                            )
                            
                            await MainActor.run {
                                isLoading = false
                                onRegisterSuccess(newUser)
                                dismiss()
                            }
                        } catch {
                            await MainActor.run {
                                isLoading = false
                                if let apiError = error as? ApiError {
                                    switch apiError {
                                    case .backendError(let message):
                                        errorMessage = message
                                    default:
                                        errorMessage = "Não foi possível criar a conta. Tente novamente."
                                    }
                                } else {
                                    errorMessage = "Não foi possível criar a conta. Tente novamente."
                                }
                            }
                        }
                    }
                }, label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "Criando conta..." : "Criar conta")
                            .font(AppTypography.body().weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                })
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1.0)
                
                Spacer()
            }
            .padding(20)
            .background(AppColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Tela Home (menu principal simples)

struct HomeView: View {
    var onLogout: () -> Void
    var onNovaSolicitacao: () -> Void
    var onSolicitacoes: () -> Void
    var onAtenderSolicitacoes: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            // Cabeçalho
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Olá!")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    Text("Corta Pau")
                        .font(AppTypography.titleMedium())
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                Button(action: {
                    // Limpa a sessão (id/nome/email/role e lista de solicitações)
                    appState.clearSession()
                    onLogout()
                }, label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                })
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Sair")
            }
            
            // Subtítulo
            Text("O que você deseja fazer hoje?")
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Botões principais
            VStack(spacing: 16) {
                if appState.currentRole == .cidadao {
                    PrimaryMenuButton(
                        title: "Nova Solicitação",
                        subtitle: "Registrar uma nova ocorrência de risco",
                        systemImage: "plus.circle"
                    ) {
                        onNovaSolicitacao()
                    }
                    
                    PrimaryMenuButton(
                        title: "Solicitações",
                        subtitle: "Consultar suas solicitações e próximas",
                        systemImage: "list.bullet.rectangle.portrait"
                    ) {
                        onSolicitacoes()
                    }
                } else if appState.currentRole == .operario {
                    PrimaryMenuButton(
                        title: "Atender Solicitações",
                        subtitle: "Operários e agentes podem atender ocorrências",
                        systemImage: "person.2.badge.gearshape"
                    ) {
                        onAtenderSolicitacoes()
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(AppColors.background.ignoresSafeArea())
    }
}

// MARK: - Telas placeholder

struct NovaSolicitacaoView: View {
    var onBack: () -> Void
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var selectedProblemType: ProblemType = .riscoEletrico
    @State private var addressText: String = ""
    @State private var descriptionText: String = ""
    
    @State private var enderecoFoiEditadoManualmente: Bool = false
    // @State private var showMapPickerInfo: Bool = false
    @State private var customCoordinate: GeoPoint? = nil
    @State private var isMapPickerPresented: Bool = false
    
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    /// Indica se o usuário optou por usar a localização atual do dispositivo
    /// como localização da solicitação. No futuro, isso usará a posição real via CoreLocation.
    @State private var useCurrentLocationForSolicitacao: Bool = false
    
    private var isFormValid: Bool {
        !addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedImages.isEmpty
    }
    private var locationStatusText: String {
        switch appState.locationPermissionState {
        case .authorizedWhenInUse, .authorizedAlways:
            return "A solicitação usará sua localização atual aproximada."
        case .denied, .restricted:
            return "Permissão de localização negada. Usando localização simulada."
        case .unknown, .notDetermined:
            return "Solicitando permissão de localização..."
        }
    }
    
    var body: some View {
        ScreenScaffold(
            title: "Nova Solicitação",
            subtitle: "Cadastre um novo pedido de poda.",
            onBack: onBack
        ) {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Tipo de problema
                    LabeledField(title: "Tipo de problema") {
                        Picker("Tipo de problema", selection: $selectedProblemType) {
                            ForEach(ProblemType.allCases) { tipo in
                                Text(tipo.rawValue).tag(tipo)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.textPrimary)
                    }
                    
                    // Endereço
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledField(title: "Endereço") {
                            TextField("Rua, número, bairro, cidade", text: $addressText)
                                .textInputAutocapitalization(.sentences)
                                .foregroundColor(AppColors.textPrimary)
                                .font(AppTypography.body())
                                .onChange(of: addressText) { _, _ in
                                    enderecoFoiEditadoManualmente = true
                                }
                        }
                        
                        HStack(spacing: 8) {
                            Button {
                                handleUseMyLocationTap()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                    Text("Usar minha localização")
                                        .font(AppTypography.caption())
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(variant: .outline))
                            .frame(maxWidth: .infinity)
                            
                            Button {
                                isMapPickerPresented = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "map")
                                    Text("Escolher no mapa")
                                        .font(AppTypography.caption())
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(variant: .outline))
                            .frame(maxWidth: .infinity)
                        }
                        if useCurrentLocationForSolicitacao {
                            Text(locationStatusText)
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    // Imagens
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Adicione imagens")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text(selectedImages.isEmpty ? "Adicionar fotos" : "Adicionar mais fotos")
                                    .font(AppTypography.body())
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(variant: .outline))
                        .onChange(of: photoItems) { oldItems, newItems in
                            Task {
                                selectedImages.removeAll()
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        selectedImages.append(image)
                                    }
                                }
                            }
                        }
                        
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, uiImage in
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipped()
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(AppColors.border, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        } else {
                            Text("Inclua pelo menos uma foto para registrar melhor o risco.")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    // Descrição
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Faça uma breve descrição")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $descriptionText)
                            .scrollContentBackground(.hidden) // esconde fundo branco padrão
                            .frame(minHeight: 120)
                            .padding(10)
                            .background(AppColors.surface.opacity(0.9)) // fundo escuro
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .foregroundColor(AppColors.textPrimary) // texto branco
                            .font(AppTypography.body())
                    }
                    
                    // Botão Cadastrar
                    Button {
                        Task {
                            let trimmedEndereco = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedDescricao = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Coordenada que vamos mandar para o backend:
                            // - se o usuário escolheu um ponto no mapa, usamos esse ponto;
                            // - senão, se o usuário optou por usar a localização atual e o LocationManager já tem
                            //   uma coordenada real, usamos essa coordenada do dispositivo;
                            // - caso contrário, caímos no fallback (localização efetiva do app, que pode ser simulada).
                            let backendCoord: GeoPoint
                            if let custom = customCoordinate {
                                backendCoord = custom
                            } else if useCurrentLocationForSolicitacao,
                                      let coord = locationManager.lastKnownLocation {
                                backendCoord = GeoPoint(latitude: coord.latitude, longitude: coord.longitude)
                            } else {
                                backendCoord = appState.effectiveUserLocation
                            }
                            
                            do {
                                // 0) Faz upload das imagens selecionadas para a API (POST /uploads/base64)
                                //    e coleta as URLs retornadas para enviar como anexos na criação da solicitação.
                                var anexosForBackend: [(url: String, mime: String)] = []
                                
                                for image in selectedImages {
                                    // Tentamos gerar JPEG com compressão 0.8; se falhar, pulamos esta imagem.
                                    guard let data = image.jpegData(compressionQuality: 0.8) else {
                                        continue
                                    }
                                    
                                    do {
                                        let uploaded = try await ApiClient.shared.uploadImageBase64(
                                            data: data,
                                            mime: "image/jpeg"
                                        )
                                        anexosForBackend.append(uploaded)
                                    } catch {
                                        // Para o MVP, apenas logamos o erro e seguimos com as demais imagens.
                                        print("Erro ao fazer upload de imagem: \(error)")
                                    }
                                }
                                
                                // 1) Cria no backend (POST /solicitacoes), agora incluindo os anexos.
                                let apiItem = try await ApiClient.shared.createSolicitacao(
                                    titulo: selectedProblemType.rawValue,          // usamos o tipo como título
                                    descricao: trimmedDescricao,
                                    tipoProblema: selectedProblemType,
                                    coordenada: backendCoord,
                                    autorId: appState.currentUserId,
                                    anexos: anexosForBackend
                                )
                                
                                // 2) Atualiza o estado local no MainActor
                                await MainActor.run {
                                    let createdAt = apiItem.createdAt
                                    
                                    // Mantemos a mesma estrutura que já existia antes (imagens locais + histórico),
                                    // mas agora preservamos também o ID real da solicitação no backend.
                                    var nova = Solicitacao(
                                        backendId: apiItem.id,
                                        tipoProblema: selectedProblemType,
                                        endereco: trimmedEndereco,
                                        descricao: trimmedDescricao,
                                        imagens: [],
                                        status: .emAberto,
                                        descricaoAtendimento: nil,
                                        encaminhamento: nil,
                                        coordenada: (useCurrentLocationForSolicitacao || customCoordinate != nil) ? backendCoord : nil,
                                        createdAt: createdAt,
                                        isMinha: true
                                    )
                                    
                                    // Anexos vindos do backend (URLs que serão usadas nas telas de detalhes)
                                    nova.remoteImageURLs = apiItem.anexos.map { $0.url }
                                    
                                    let eventoCriacao = SolicitationEvent(
                                        tipo: .criacao,
                                        data: createdAt,
                                        autorRole: appState.currentRole,
                                        descricao: "Solicitação criada pelo usuário (sincronizada com a API).",
                                        statusAnterior: nil,
                                        statusNovo: .emAberto,
                                        encaminhamento: nil
                                    )
                                    nova.historico.append(eventoCriacao)
                                    
                                    appState.upsertSolicitacao(nova)
                                    onBack()
                                }
                            } catch {
                                print("Erro ao criar solicitação na API: \(error)")
                                // TODO: no futuro podemos exibir um alerta amigável na UI
                            }
                        }
                    } label: {
                        Text("Cadastrar Solicitação")
                            .font(AppTypography.body().weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.6)
                    .padding(.top, 8)
                }
            }
            .onReceive(locationManager.$lastResolvedAddress) { newAddress in
                guard useCurrentLocationForSolicitacao,
                      let newAddress,
                      !newAddress.isEmpty else { return }
                
                if !enderecoFoiEditadoManualmente || addressText.isEmpty {
                    addressText = newAddress
                }
            }
            .onReceive(locationManager.$lastKnownLocation) { coord in
                guard let coord = coord else { return }
                appState.realUserLocation = GeoPoint(
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
                appState.isUsingSimulatedLocation = false
            }
            .sheet(isPresented: $isMapPickerPresented) {
                let effective = appState.effectiveUserLocation
                let center = CLLocationCoordinate2D(latitude: effective.latitude, longitude: effective.longitude)
                MapLocationPickerView(
                    initialCenter: center,
                    selectedCoordinate: $customCoordinate,
                    addressText: $addressText,
                    useCurrentLocationForSolicitacao: $useCurrentLocationForSolicitacao
                )
            }
        }
    }
    /// Trata o toque no botão "Usar minha localização".
    /// Para o MVP:
    /// - Se a permissão ainda não foi determinada, solicita autorização "When In Use".
    /// - Se já estiver autorizada, ativa o uso da localização atual para a solicitação
    ///   e pede ao LocationManager para iniciar as atualizações.
    /// - Se estiver negada ou restrita, ainda marcamos o uso da localização, mas ela continuará simulada.
    private func handleUseMyLocationTap() {
        switch appState.locationPermissionState {
        case .unknown, .notDetermined:
            useCurrentLocationForSolicitacao = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            useCurrentLocationForSolicitacao = true
            appState.isUsingSimulatedLocation = false
            locationManager.startUpdatingLocationIfNeeded()
        case .denied, .restricted:
            // Não conseguimos usar a localização real; permanecemos com a simulada,
            // mas ainda assim marcamos a intenção para que a solicitação use a localização efetiva.
            useCurrentLocationForSolicitacao = true
        }
    }
}

struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let initialCenter: CLLocationCoordinate2D
    @Binding var selectedCoordinate: GeoPoint?
    @Binding var addressText: String
    @Binding var useCurrentLocationForSolicitacao: Bool
    
    @State private var region: MKCoordinateRegion
    
    init(initialCenter: CLLocationCoordinate2D,
         selectedCoordinate: Binding<GeoPoint?>,
         addressText: Binding<String>,
         useCurrentLocationForSolicitacao: Binding<Bool>) {
        self.initialCenter = initialCenter
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        _selectedCoordinate = selectedCoordinate
        _addressText = addressText
        _useCurrentLocationForSolicitacao = useCurrentLocationForSolicitacao
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if #available(iOS 17.0, *) {
                    // API nova com MapContentBuilder
                    Map(initialPosition: .region(region)) {
                        // Sem anotações extras; usamos apenas o crosshair fixo no centro.
                    }
                    .ignoresSafeArea()
                    .onMapCameraChange { context in
                        region = context.region
                    }
                } else {
                    // API antiga (iOS 16 e anteriores)
                    Map(coordinateRegion: $region)
                        .ignoresSafeArea()
                }

                // Marcador central fixo (crosshair)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
                    .shadow(radius: 4)
                    .offset(y: -16)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Usar este ponto") {
                        let center = region.center
                        let geo = GeoPoint(latitude: center.latitude, longitude: center.longitude)

                        selectedCoordinate = geo
                        addressText = String(
                            format: "Lat %.5f, Lon %.5f (aprox.)",
                            center.latitude,
                            center.longitude
                        )
                        useCurrentLocationForSolicitacao = true
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MapPinLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct SolicitacoesView: View {
    var onBack: () -> Void
    var onSelectSolicitacao: (Solicitacao) -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: SolicitacaoFilter = .minhas
    
    private var filteredSolicitacoes: [Solicitacao] {
        switch selectedFilter {
        case .minhas:
            return appState.solicitacoes.filter { $0.isMinha }
        case .proximas:
            let userLocation = appState.effectiveUserLocation
            let withDistance: [(Solicitacao, Double)] = appState.solicitacoes.compactMap { solicitacao in
                guard let coord = solicitacao.coordenada else { return nil }
                let distance = distanceInMeters(from: userLocation, to: coord)
                return (solicitacao, distance)
            }
            
            // Se nenhuma solicitação tiver coordenada, cai no fallback "todas"
            if withDistance.isEmpty {
                return appState.solicitacoes
            }
            
            let sorted = withDistance.sorted { $0.1 < $1.1 }
            return sorted.map { $0.0 }
        case .todas:
            return appState.solicitacoes
        }
    }
    
    var body: some View {
        ScreenScaffold(
            title: "Solicitações",
            subtitle: "Visualize e acompanhe as solicitações.",
            onBack: onBack
        ) {
            VStack(spacing: 16) {
                
                // Filtros
                HStack(spacing: 8) {
                    ForEach(SolicitacaoFilter.allCases) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: filter == selectedFilter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                
                if selectedFilter == .proximas {
                    let helpText = appState.isUsingSimulatedLocation
                    ? "Mostrando solicitações ordenadas por proximidade da sua localização simulada."
                    : "Mostrando solicitações ordenadas por proximidade da sua localização atual."
                    
                    Text(helpText)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if filteredSolicitacoes.isEmpty {
                    VStack(spacing: 8) {
                        Text("Nenhuma solicitação encontrada.")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textSecondary)
                        Text("Cadastre uma nova solicitação para começar.")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredSolicitacoes) { solicitacao in
                                Button {
                                    onSelectSolicitacao(solicitacao)
                                } label: {
                                    SolicitacaoCardView(solicitacao: solicitacao)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        // Temporariamente desativado: se chamarmos a API aqui,
        // perdemos o endereço digitado e as imagens locais,
        // porque o backend ainda não armazena esses campos.
        // .task {
        //     appState.carregarSolicitacoesDaApi()
        // }
    }
}


struct SolicitacaoCardView: View {
    let solicitacao: Solicitacao
    
    private var titleText: String {
        solicitacao.tipoProblema.rawValue
    }
    
    private var subtitleText: String {
        solicitacao.endereco
    }
    
    private var createdAtText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: solicitacao.createdAt)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(AppTypography.body().weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitleText)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                StatusBadge(status: solicitacao.status)
            }
            
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(createdAtText)
                        .font(AppTypography.caption())
                }
                .foregroundColor(AppColors.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 12))
                    Text("\(solicitacao.imagensCount)")
                        .font(AppTypography.caption())
                }
                .foregroundColor(AppColors.textSecondary)
                
                if solicitacao.isMinha {
                    Spacer()
                    Text("Minha")
                        .font(AppTypography.caption().weight(.medium))
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accent.opacity(0.18))
                        .cornerRadius(999)
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(AppColors.accentSoft.opacity(0.8), lineWidth: 1)
                        )
                }
            }
        }
        .padding(14)
        .background(AppColors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let status: SolicitacaoStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.rawValue)
                .font(AppTypography.caption().weight(.medium))
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.18))
        .cornerRadius(999)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(status.color.opacity(0.7), lineWidth: 1)
        )
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption().weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .background {
            if isSelected {
                LinearGradient(
                    colors: [AppColors.accent, AppColors.accentSoft],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                AppColors.surface.opacity(0.7)
            }
        }
        .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .cornerRadius(999)
        .scaleEffect(isSelected ? 1.0 : 0.99)
    }
}

struct AtendimentoStatusButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption().weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .background(isSelected ? AppColors.accent.opacity(0.25) : AppColors.surface.opacity(0.7))
        .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
        )
        .cornerRadius(999)
    }
}

// Filtro para tela de atendimento
enum AtenderFilter: String, CaseIterable, Identifiable {
    case pendentes = "Pendentes"
    case todas = "Todas"
    
    var id: String { rawValue }
}

enum AtendimentoDateFilter: String, CaseIterable, Identifiable {
    case todas = "Todas"
    case hoje = "Hoje"
    case ultimos7 = "Últimos 7 dias"
    case ultimos30 = "Últimos 30 dias"
    
    var id: String { rawValue }
}

struct AtenderSolicitacoesView: View {
    var onBack: () -> Void
    var onSelectSolicitacao: (Solicitacao) -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: AtenderFilter = .pendentes
    @State private var selectedProblema: ProblemType? = nil
    @State private var selectedDateFilter: AtendimentoDateFilter = .todas
    @State private var searchText: String = ""
    @State private var ordenarPorProximidade: Bool = false
    
    private var filteredSolicitacoes: [Solicitacao] {
        var result = appState.solicitacoes
        
        // Filtro por status (Pendentes / Todas)
        switch selectedFilter {
        case .pendentes:
            // Pendentes = Em aberto ou Em atendimento
            result = result.filter { $0.status == .emAberto || $0.status == .emAtendimento }
        case .todas:
            break
        }
        
        // Filtro por tipo de problema
        if let problema = selectedProblema {
            result = result.filter { $0.tipoProblema == problema }
        }
        
        // Filtro por data de abertura
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedDateFilter {
        case .todas:
            break
        case .hoje:
            result = result.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
        case .ultimos7:
            if let start = calendar.date(byAdding: .day, value: -7, to: now) {
                result = result.filter { $0.createdAt >= start }
            }
        case .ultimos30:
            if let start = calendar.date(byAdding: .day, value: -30, to: now) {
                result = result.filter { $0.createdAt >= start }
            }
        }
        
        // Filtro por texto (endereço, descrição ou tipo de problema)
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let query = trimmed.lowercased()
            result = result.filter { solicitacao in
                let endereco = solicitacao.endereco.lowercased()
                let descricao = solicitacao.descricao.lowercased()
                let tipo = solicitacao.tipoProblema.rawValue.lowercased()
                
                return endereco.contains(query)
                    || descricao.contains(query)
                    || tipo.contains(query)
            }
        }
        
        // Ordenação: por proximidade (se ativado) ou por data (mais recentes primeiro)
        if ordenarPorProximidade {
            let userLocation = appState.effectiveUserLocation
            let withDistance: [(Solicitacao, Double)] = result.compactMap { solicitacao in
                guard let coord = solicitacao.coordenada else { return nil }
                let distance = distanceInMeters(from: userLocation, to: coord)
                return (solicitacao, distance)
            }
            
            if !withDistance.isEmpty {
                let sorted = withDistance.sorted { $0.1 < $1.1 }
                return sorted.map { $0.0 }
            }
        }
        
        // Fallback padrão: mais recentes primeiro
        return result.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ScreenScaffold(
            title: "Atender Solicitações",
            subtitle: "Área para operários e agentes.",
            onBack: onBack
        ) {
            if appState.currentRole != .operario {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Acesso restrito")
                        .font(AppTypography.body().weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Apenas usuários com perfil Operário podem acessar a área de atendimento de solicitações.")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Saia da conta atual e faça login novamente escolhendo o perfil Operário para testar este fluxo.")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 16) {
                    // Busca por texto
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Buscar atendimentos")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.textSecondary)
                            TextField("Endereço, bairro ou descrição", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .foregroundColor(AppColors.textPrimary)
                                .font(AppTypography.body())
                        }
                        .padding(10)
                        .background(AppColors.surface.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    
                    // Filtros de status (Pendentes / Todas)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack(spacing: 8) {
                            ForEach(AtenderFilter.allCases) { filter in
                                FilterChip(
                                    title: filter.rawValue,
                                    isSelected: filter == selectedFilter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    
                    // Filtro por tipo de problema
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo de problema")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Chip "Todos"
                                FilterChip(
                                    title: "Todos",
                                    isSelected: selectedProblema == nil
                                ) {
                                    selectedProblema = nil
                                }
                                
                                ForEach(ProblemType.allCases) { tipo in
                                    FilterChip(
                                        title: tipo.rawValue,
                                        isSelected: selectedProblema == tipo
                                    ) {
                                        selectedProblema = tipo
                                    }
                                }
                            }
                        }
                    }
                    
                    // Filtro por data de abertura
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data de abertura")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack(spacing: 8) {
                            ForEach(AtendimentoDateFilter.allCases) { dateFilter in
                                FilterChip(
                                    title: dateFilter.rawValue,
                                    isSelected: dateFilter == selectedDateFilter
                                ) {
                                    selectedDateFilter = dateFilter
                                }
                            }
                        }
                    }
                    
                    // Ordenação por proximidade
                    Toggle(isOn: $ordenarPorProximidade) {
                        Text("Ordenar por proximidade")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                    
                    if ordenarPorProximidade {
                        let subtitle = appState.isUsingSimulatedLocation
                            ? "Usando localização simulada do usuário."
                            : "Usando localização atual do dispositivo."
                        
                        Text(subtitle)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if filteredSolicitacoes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nenhuma solicitação para atender.")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textSecondary)
                            Text("Ajuste os filtros ou aguarde novas solicitações em aberto ou em atendimento.")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(filteredSolicitacoes) { solicitacao in
                                    Button {
                                        onSelectSolicitacao(solicitacao)
                                    } label: {
                                        SolicitacaoCardView(solicitacao: solicitacao)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// Layout base para telas internas com cabeçalho simples
struct ScreenScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    var onBack: () -> Void
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Button(action: onBack, label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                })
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Voltar")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.titleMedium())
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            content()
            
            Spacer()
        }
        .padding(20)
        .background(AppColors.background.ignoresSafeArea())
    }
}

// MARK: - Componentes reutilizáveis

struct PrimaryButtonStyle: ButtonStyle {
    enum Variant {
        case filled
        case outline
    }
    
    var variant: Variant = .filled
    
    func makeBody(configuration: Configuration) -> some View {
        switch variant {
        case .filled:
            configuration.label
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    LinearGradient(
                        colors: [
                            AppColors.accent,
                            AppColors.accentSoft
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(999)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
        case .outline:
            configuration.label
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(AppColors.surface.opacity(0.7))
                .foregroundColor(AppColors.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .cornerRadius(999)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(AppColors.surface)
            .foregroundColor(AppColors.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.caption().weight(.medium))
                .foregroundColor(AppColors.textSecondary)
            
            content()
                .padding(10)
                .background(AppColors.surface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .cornerRadius(12)
        }
    }
}

struct DividerView: View {
    let label: String
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
            Text(label)
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
}

struct PrimaryMenuButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action, label: {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.body().weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(14)
            .background(AppColors.surface)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        })
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        let locationManager = LocationManager()
        
        return Group {
            ContentView()
                .environmentObject(appState)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
            
            LoginView(onLoginSuccess: {})
                .environmentObject(appState)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
        }
    }
}

struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                Spacer()
                
                Button("Fechar") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 24)
                .padding(.horizontal, 20)
                .foregroundColor(.white)
            }
        }
    }
}


struct DetalheSolicitacaoView: View {
    @Binding var solicitacao: Solicitacao
    var onBack: () -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var selectedImageURLForViewer: URL?
    @State private var isImageViewerPresented = false
    @State private var isEditing = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showDescricaoObrigatoriaAlert = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var mapAnnotations: [MapPinLocation] = []
    @State private var isSavingAtendimento: Bool = false
    @State private var saveStatusMessage: String? = nil
    @State private var saveStatusIsError: Bool = false
    
    /// Apenas solicitações em aberto ou em atendimento podem ter o status alterado.
    private var canChangeStatus: Bool {
        solicitacao.status == .emAberto || solicitacao.status == .emAtendimento
    }

    /// Formata a data dos eventos de histórico em formato brasileiro.
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR") // padrão Brasil
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Mapeia o status local (SolicitacaoStatus) para o enum da API (Status).
    private func backendStatusString(from status: SolicitacaoStatus) -> String? {
        switch status {
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

    /// Mapeia o status local para o campo atendimentoStatus da API
    /// (ATENDIDO_SUCESSO, NAO_ATENDIDO, ENCAMINHADO).
    private func backendAtendimentoStatus(from status: SolicitacaoStatus) -> String? {
        switch status {
        case .concluida:
            return "ATENDIDO_SUCESSO"
        case .naoConcluida:
            return "NAO_ATENDIDO"
        case .emAtendimento:
            return "ENCAMINHADO"
        case .emAberto:
            return nil
        }
    }

    /// Mapeia o encaminhamento local (EncaminhamentoDestino) para o enum textual esperado pela API.
    private func backendEncaminhamentoString(from destino: EncaminhamentoDestino?) -> String? {
        guard let destino = destino else { return nil }
        let label = destino.rawValue.lowercased()

        if label.contains("defesa") {
            return "DEFESA_CIVIL"
        } else if label.contains("bombeiro") {
            return "BOMBEIROS"
        } else if label.contains("energia") || label.contains("elétr") || label.contains("eletr") {
            return "COMPANHIA_ENERGIA"
        } else {
            return "OUTROS"
        }
    }

    /// Envia o atendimento atual para a API (PATCH /solicitacoes/:id)
    /// Para o MVP: sempre tenta enviar se existir backendId, sem otimizações.
    private func salvarAtendimentoNaAPI() async {
        guard let backendId = solicitacao.backendId else {
            print("[Atendimento] Solicitação sem backendId; nada para sincronizar.")
            return
        }

        let statusString = backendStatusString(from: solicitacao.status)
        let descricaoAtendimentoTrimmed = solicitacao.descricaoAtendimento?.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            isSavingAtendimento = true
        }

        do {
            _ = try await ApiClient.shared.updateSolicitacao(
                id: backendId,
                status: statusString,
                descricao: descricaoAtendimentoTrimmed
            )
            print("[Atendimento] PATCH enviado com sucesso para a API.")
        } catch {
            print("[Atendimento] Erro ao salvar atendimento na API: \(error)")
        }

        await MainActor.run {
            isSavingAtendimento = false
        }
    }

    private func handleBack() {
        Task {
            await salvarAtendimentoNaAPI()
            await MainActor.run {
                appState.upsertSolicitacao(solicitacao)
                onBack()
            }
        }
    }

    /// Eventos de histórico que devem ser exibidos na linha do tempo.
    /// Filtra comentários vazios (sem descrição) e ordena do mais recente para o mais antigo.
    private var visibleHistoricoEvents: [SolicitationEvent] {
        solicitacao.historico
            .filter { evento in
                let trimmedDescricao = evento.descricao?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                // Escondemos eventos de tipo "Comentário" sem descrição,
                // que hoje só poluem a linha do tempo.
                if trimmedDescricao.isEmpty && evento.tipo.rawValue == "Comentário" {
                    return false
                }

                return true
            }
            .sorted { $0.data > $1.data }
    }
    
    var body: some View {
        ScreenScaffold(
            title: "Detalhes da solicitação",
            subtitle: solicitacao.tipoProblema.rawValue,
            onBack: handleBack
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Status + botão Editar/Salvar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status")
                                .font(AppTypography.caption().weight(.medium))
                                .foregroundColor(AppColors.textSecondary)
                            
                            Spacer()
                            
                            if solicitacao.status == .emAberto {
                                Button(isEditing ? "Salvar" : "Editar") {
                                    if isEditing {
                                        // Ao salvar, tentamos sincronizar a descrição com a API, se houver backendId.
                                        let trimmedDescricao = solicitacao.descricao
                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                                        
                                        if let backendId = solicitacao.backendId {
                                            Task {
                                                do {
                                                    _ = try await ApiClient.shared.updateSolicitacao(
                                                        id: backendId,
                                                        status: nil, // status permanece "em aberto" neste fluxo
                                                        descricao: trimmedDescricao.isEmpty ? nil : trimmedDescricao
                                                    )
                                                } catch {
                                                    print("Erro ao atualizar solicitação na API: \(error)")
                                                    // No futuro podemos exibir um alerta amigável na UI.
                                                }
                                            }
                                        }
                                    }
                                    
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                }
                                .font(AppTypography.caption().weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppColors.surface.opacity(0.9))
                                .cornerRadius(999)
                            }
                        }
                        
                        StatusBadge(status: solicitacao.status)
                    }
                    
                    // Endereço
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Endereço")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if isEditing {
                            TextField("Endereço", text: $solicitacao.endereco)
                                .textInputAutocapitalization(.sentences)
                                .foregroundColor(AppColors.textPrimary)
                                .font(AppTypography.body())
                                .padding(10)
                                .background(AppColors.surface.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                                .cornerRadius(12)
                        } else {
                            Text(solicitacao.endereco)
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    // Mapa (localização aproximada)
                    if !mapAnnotations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Localização aproximada")
                                .font(AppTypography.caption().weight(.medium))
                                .foregroundColor(AppColors.textSecondary)
                            
                            if #available(iOS 17.0, *) {
                                Map(initialPosition: .region(mapRegion)) {
                                    ForEach(mapAnnotations) { item in
                                        Marker(
                                            "",
                                            coordinate: item.coordinate
                                        )
                                        .tint(AppColors.accent)
                                    }
                                }
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                            } else {
                                Map(coordinateRegion: $mapRegion, annotationItems: mapAnnotations) { item in
                                    MapMarker(coordinate: item.coordinate, tint: AppColors.accent)
                                }
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    // Descrição
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descrição")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if isEditing {
                            TextEditor(text: $solicitacao.descricao)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(10)
                                .background(AppColors.surface.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                                .cornerRadius(12)
                                .foregroundColor(AppColors.textPrimary)
                                .font(AppTypography.body())
                        } else {
                            Text(solicitacao.descricao)
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    
                    // Imagens vindas do backend (URLs)
                    if !solicitacao.resolvedRemoteImageURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fotos anexadas")
                                .font(AppTypography.caption().weight(.medium))
                                .foregroundColor(AppColors.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(solicitacao.resolvedRemoteImageURLs, id: \.self) { url in
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(AppColors.surface.opacity(0.6))
                                                    ProgressView()
                                                }
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            case .failure:
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(AppColors.surface.opacity(0.6))
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .foregroundColor(.yellow)
                                                }
                                            @unknown default:
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(AppColors.surface.opacity(0.6))
                                                    Image(systemName: "questionmark")
                                                }
                                            }
                                        }
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.border, lineWidth: 1)
                                        )
                                        .onTapGesture {
                                            selectedImageURLForViewer = url
                                            isImageViewerPresented = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Informações adicionais
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Informações adicionais")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text(formatEventDate(solicitacao.createdAt))
                                    .font(AppTypography.caption())
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 12))
                                Text("\(solicitacao.imagensCount) foto(s)")
                                    .font(AppTypography.caption())
                            }
                            
                            if solicitacao.isMinha {
                                Text("Minha solicitação")
                                    .font(AppTypography.caption().weight(.medium))
                                    .foregroundColor(AppColors.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.accent.opacity(0.18))
                                    .cornerRadius(999)
                            }
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                    
                    // Atendimento / Ações
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Atendimento")
                            .font(AppTypography.caption().weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if appState.currentRole == .operario {
                            // Controles para o operário registrar o atendimento
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Resultado do atendimento")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: 8) {
                                    AtendimentoStatusButton(
                                        title: "Atendido com sucesso",
                                        isSelected: solicitacao.status == .concluida
                                    ) {
                                        // Para concluir com sucesso, exigimos que haja uma descrição de atendimento.
                                        let texto = solicitacao.descricaoAtendimento?
                                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                        
                                        if texto.isEmpty {
                                            showDescricaoObrigatoriaAlert = true
                                        } else if canChangeStatus {
                                            let antigoStatus = solicitacao.status
                                            solicitacao.status = .concluida
                                            
                                            let evento = SolicitationEvent(
                                                tipo: .statusAlterado,
                                                data: Date(),
                                                autorRole: appState.currentRole,
                                                descricao: "Status alterado para \"Atendido com sucesso\".",
                                                statusAnterior: antigoStatus,
                                                statusNovo: solicitacao.status,
                                                encaminhamento: solicitacao.encaminhamento
                                            )
                                            solicitacao.historico.append(evento)
                                        }
                                    }
                                    .disabled(!canChangeStatus)
                                    
                                    AtendimentoStatusButton(
                                        title: "Não atendido",
                                        isSelected: solicitacao.status == .naoConcluida
                                    ) {
                                        if canChangeStatus {
                                            let antigoStatus = solicitacao.status
                                            solicitacao.status = .naoConcluida
                                            
                                            let evento = SolicitationEvent(
                                                tipo: .statusAlterado,
                                                data: Date(),
                                                autorRole: appState.currentRole,
                                                descricao: "Status alterado para \"Não atendido\".",
                                                statusAnterior: antigoStatus,
                                                statusNovo: solicitacao.status,
                                                encaminhamento: solicitacao.encaminhamento
                                            )
                                            solicitacao.historico.append(evento)
                                        }
                                    }
                                    .disabled(!canChangeStatus)
                                }
                                
                                HStack(spacing: 8) {
                                    AtendimentoStatusButton(
                                        title: "Encaminhado",
                                        isSelected: solicitacao.status == .emAtendimento
                                    ) {
                                        if canChangeStatus {
                                            let antigoStatus = solicitacao.status
                                            solicitacao.status = .emAtendimento
                                            
                                            let evento = SolicitationEvent(
                                                tipo: .statusAlterado,
                                                data: Date(),
                                                autorRole: appState.currentRole,
                                                descricao: "Status alterado para \"Encaminhado\".",
                                                statusAnterior: antigoStatus,
                                                statusNovo: solicitacao.status,
                                                encaminhamento: solicitacao.encaminhamento
                                            )
                                            solicitacao.historico.append(evento)
                                        }
                                    }
                                    .disabled(!canChangeStatus)
                                }
                            }
                            
                            // Encaminhamento
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Encaminhamento para")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        AtendimentoStatusButton(
                                            title: "Nenhum",
                                            isSelected: solicitacao.encaminhamento == nil
                                        ) {
                                            let evento = SolicitationEvent(
                                                tipo: .encaminhamento,
                                                data: Date(),
                                                autorRole: appState.currentRole,
                                                descricao: "Encaminhamento removido.",
                                                statusAnterior: solicitacao.status,
                                                statusNovo: solicitacao.status,
                                                encaminhamento: nil
                                            )
                                            solicitacao.encaminhamento = nil
                                            solicitacao.historico.append(evento)
                                        }
                                        
                                        ForEach(EncaminhamentoDestino.allCases) { destino in
                                            AtendimentoStatusButton(
                                                title: destino.rawValue,
                                                isSelected: solicitacao.encaminhamento == destino
                                            ) {
                                                let evento = SolicitationEvent(
                                                    tipo: .encaminhamento,
                                                    data: Date(),
                                                    autorRole: appState.currentRole,
                                                    descricao: "Encaminhado para \(destino.rawValue).",
                                                    statusAnterior: solicitacao.status,
                                                    statusNovo: solicitacao.status,
                                                    encaminhamento: destino
                                                )
                                                solicitacao.encaminhamento = destino
                                                solicitacao.historico.append(evento)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Descrição do atendimento")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextEditor(
                                    text: Binding(
                                        get: { solicitacao.descricaoAtendimento ?? "" },
                                        set: { solicitacao.descricaoAtendimento = $0.isEmpty ? nil : $0 }
                                    )
                                )
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .padding(10)
                                .background(AppColors.surface.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                                .cornerRadius(12)
                                .foregroundColor(AppColors.textPrimary)
                                .font(AppTypography.body())
                            }
                        } else {
                            // Para cidadãos, apenas leitura do que foi registrado
                            VStack(alignment: .leading, spacing: 6) {
                                if let destino = solicitacao.encaminhamento {
                                    Text("Encaminhado para \(destino.rawValue)")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                if let texto = solicitacao.descricaoAtendimento, !texto.isEmpty {
                                    Text(texto)
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                } else {
                                    Text("Nenhum atendimento registrado até o momento.")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                    }

                    // Histórico / Linha do tempo
                    if !visibleHistoricoEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Histórico")
                                .font(AppTypography.caption().weight(.medium))
                                .foregroundColor(AppColors.textSecondary)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(visibleHistoricoEvents) { evento in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(AppColors.accent)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 4)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(evento.tipo.rawValue)
                                                .font(AppTypography.caption().weight(.semibold))
                                                .foregroundColor(AppColors.textPrimary)

                                            if let descricao = evento.descricao, !descricao.isEmpty {
                                                Text(descricao)
                                                    .font(AppTypography.caption())
                                                    .foregroundColor(AppColors.textSecondary)
                                            }

                                            Text(formatEventDate(evento.data))
                                                .font(AppTypography.caption())
                                                .foregroundColor(AppColors.textSecondary.opacity(0.8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isImageViewerPresented) {
                if let url = selectedImageURLForViewer {
                    ZStack {
                        Color.black
                            .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                @unknown default:
                                    Image(systemName: "questionmark")
                                }
                            }
                            .padding()
                            Spacer()
                            
                            Button("Fechar") {
                                isImageViewerPresented = false
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.bottom, 24)
                            .padding(.horizontal, 20)
                            .foregroundColor(.white)
                        }
                    }
                }
            }
            .alert("Descrição obrigatória", isPresented: $showDescricaoObrigatoriaAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Para marcar como \"Atendido com sucesso\", preencha a descrição do atendimento.")
            }
            .onAppear {
                if let coord = solicitacao.coordenada {
                    let center = CLLocationCoordinate2D(latitude: coord.latitude,
                                                        longitude: coord.longitude)
                    mapRegion = MKCoordinateRegion(
                        center: center,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    mapAnnotations = [MapPinLocation(coordinate: center)]
                } else {
                    mapAnnotations = []
                }
            }
        }
    }
}
