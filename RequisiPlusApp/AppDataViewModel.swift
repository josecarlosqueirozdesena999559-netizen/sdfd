import Foundation

@MainActor
final class AppDataViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var requisitions: [Requisition] = []
    @Published private(set) var summary: DashboardSummary = .empty
    @Published private(set) var materialTypes: [MaterialType] = []
    @Published private(set) var catalogItems: [MaterialCatalogItem] = []
    @Published var isLoading = false
    @Published var createInProgress = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let userSession: UserSession
    private let databaseService: SupabaseDatabaseService
    private let realtimeService: SupabaseRealtimeService

    init(
        userSession: UserSession,
        databaseService: SupabaseDatabaseService = SupabaseDatabaseService(),
        realtimeService: SupabaseRealtimeService = SupabaseRealtimeService()
    ) {
        self.userSession = userSession
        self.databaseService = databaseService
        self.realtimeService = realtimeService

        self.realtimeService.start(session: userSession) { [weak self] in
            Task {
                await self?.refreshFromRealtime()
            }
        }
    }

    var dashboardAlert: DashboardAlert {
        DashboardAlert(
            title: summary.pendingCount > 0
                ? "Voce tem requisicoes pendentes."
                : "Sem pendencias no momento.",
            message: summary.pendingCount > 0
                ? "Abra a aba de requisicoes para acompanhar o status e conferir os detalhes."
                : "Suas requisicoes estao em dia. Voce pode abrir uma nova solicitacao quando precisar.",
            actionTitle: summary.pendingCount > 0 ? "Ver requisicoes" : "Fazer requisicao"
        )
    }

    func load() async {
        await performLoad(showLoading: true)
    }

    private func performLoad(showLoading: Bool) async {
        if showLoading {
            isLoading = true
        }
        do {
            let profile = try await databaseService.fetchUserProfile(session: userSession)
            async let requisitionsTask = databaseService.fetchRequisitions(session: userSession, profile: profile)
            async let catalogItemsTask = databaseService.fetchCatalogItems(session: userSession, categories: profile.categoriasPermitidas)
            let requisitions = try await requisitionsTask
            let catalogItems = try await catalogItemsTask

            self.profile = profile
            self.requisitions = requisitions
            self.summary = Self.makeSummary(from: requisitions)
            self.materialTypes = profile.categoriasPermitidas.map(MaterialType.fromCategory)
            self.catalogItems = catalogItems
            self.errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        if showLoading {
            isLoading = false
        }
    }

    func createRequisition(
        materialType: MaterialType?,
        entries: [RequestedItemEntry],
        observation: String
    ) async {
        guard let profile, let materialType else {
            errorMessage = "Nao foi possivel identificar o usuario ou a categoria para criar a requisicao."
            return
        }

        createInProgress = true
        errorMessage = nil
        successMessage = nil

        defer {
            createInProgress = false
        }

        do {
            _ = try await databaseService.createRequisition(
                session: userSession,
                profile: profile,
                materialType: materialType,
                entries: entries,
                observation: observation.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            successMessage = "Requisicao enviada com sucesso."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeSummary(from requisitions: [Requisition]) -> DashboardSummary {
        DashboardSummary(
            pendingCount: requisitions.filter { $0.normalizedStatus.contains("pendente") }.count,
            conferenceCount: requisitions.filter {
                $0.normalizedStatus.contains("conferencia") || $0.normalizedStatus.contains("separ")
            }.count,
            desktopSignatureCount: requisitions.filter(\.requiresDesktopSignature).count
        )
    }

    private func refreshFromRealtime() async {
        guard createInProgress == false else { return }
        await performLoad(showLoading: false)
    }

    deinit {
        realtimeService.stop()
    }
}
