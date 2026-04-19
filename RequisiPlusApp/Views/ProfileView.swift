import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @State private var showingDeleteAccountAlert = false

    var body: some View {
        ScreenContainer(
            title: "",
            subtitle: ""
        ) {
            identityCard
            detailsCard
            deleteAccountButton
            logoutButton
        }
        .alert("Excluir conta", isPresented: $showingDeleteAccountAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Confirmar", role: .destructive) {
                authViewModel.errorMessage = "A exclusão definitiva da conta ainda precisa ser concluída no serviço do sistema."
                authViewModel.signOut()
            }
        } message: {
            Text("Sua sessão será encerrada. Se a exclusão definitiva ainda não estiver habilitada no servidor, finalize esse pedido no sistema administrativo.")
        }
    }

    private var identityCard: some View {
        PrimaryCard {
            HStack(spacing: 16) {
                Circle()
                    .fill(AppTheme.heroGradient)
                    .frame(width: 74, height: 74)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(appDataViewModel.profile?.name ?? authViewModel.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(appDataViewModel.profile?.funcao ?? "Usuário")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)

                    Text(appDataViewModel.profile?.email ?? authViewModel.email)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.primaryBlue)
                }

                Spacer()
            }
        }
    }

    private var detailsCard: some View {
        PrimaryCard {
            SectionHeader(title: "Informações da conta", subtitle: "Dados usados para acompanhar suas requisições no app.")

            VStack(spacing: 12) {
                InfoStrip(icon: "envelope", title: "E-mail", value: appDataViewModel.profile?.email ?? authViewModel.email)
                InfoStrip(icon: "building.2", title: "Setor", value: appDataViewModel.profile?.setor ?? "Não informado")
                InfoStrip(icon: "person.text.rectangle", title: "Perfil", value: appDataViewModel.profile?.role ?? "Usuário")
                InfoStrip(icon: "clock", title: "Último acesso", value: authViewModel.lastAccessDescription)
            }
        }
    }

    private var deleteAccountButton: some View {
        Button {
            showingDeleteAccountAlert = true
        } label: {
            Text("Excluir conta")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.danger)
                )
        }
        .buttonStyle(.plain)
    }

    private var logoutButton: some View {
        Button {
            authViewModel.signOut()
        } label: {
            Text("Sair da conta")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.danger.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 24)
    }

    private var initials: String {
        let source = appDataViewModel.profile?.name ?? authViewModel.displayName
        let parts = source.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "U"
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return first + second
    }
}
