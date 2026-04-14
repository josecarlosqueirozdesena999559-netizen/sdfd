import Foundation

@MainActor
final class AppDataViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var requisitions: [Requisition] = []
    @Published private(set) var summary: DashboardSummary = .empty
    @Published private(set) var materialTypes: [MaterialType] = MockData.materialTypes
    @Published var isLoading = false
    @Published var createInProgress = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let userSession: UserSession
    private let databaseService: SupabaseDatabaseService

    init(
        userSession: UserSession,
        databaseService: SupabaseDatabaseService = SupabaseDatabaseService()
    ) {
        self.userSession = userSession
        self.databaseService = databaseService
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
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let profile = try await databaseService.fetchUserProfile(session: userSession)
            let requisitions = try await databaseService.fetchRequisitions(session: userSession, profile: profile)

            self.profile = profile
            self.requisitions = requisitions
            self.summary = Self.makeSummary(from: requisitions)
            self.materialTypes = profile.categoriasPermitidas.isEmpty
                ? MockData.materialTypes
                : profile.categoriasPermitidas.map(MaterialType.fromCategory)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createRequisition(
        materialType: MaterialType?,
        currentBalance: String,
        requestedBalance: String,
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
                currentBalance: currentBalance.trimmingCharacters(in: .whitespacesAndNewlines),
                requestedBalance: requestedBalance.trimmingCharacters(in: .whitespacesAndNewlines),
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
}
