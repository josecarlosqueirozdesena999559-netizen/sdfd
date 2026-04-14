import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appDataViewModel: AppDataViewModel

    var body: some View {
        ScreenContainer(
            title: "",
            subtitle: ""
        ) {
            identityCard
            detailsCard
            logoutButton
        }
    }

    private var identityCard: some View {
        PrimaryCard {
            HStack(spacing: 16) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.deepBlue, AppTheme.primaryBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(appDataViewModel.profile?.name ?? authViewModel.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(appDataViewModel.profile?.funcao ?? "Usuario")
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
            SectionHeader(title: "Informacoes da conta", subtitle: "Dados usados para acompanhar suas requisicoes.")

            VStack(spacing: 0) {
                infoRow(icon: "building.2", title: "Setor", value: appDataViewModel.profile?.setor ?? "Nao informado")
                divider
                infoRow(icon: "person.text.rectangle", title: "Perfil", value: appDataViewModel.profile?.role ?? "Usuario")
                divider
                infoRow(icon: "clock", title: "Ultimo acesso", value: authViewModel.lastAccessDescription)
            }
        }
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 50)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(AppTheme.deepBlue)
                .frame(width: 4, height: 36)
                .overlay(
                    Color.clear
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)

                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding(.vertical, 14)
    }

    private var logoutButton: some View {
        Button {
            authViewModel.signOut()
        } label: {
            Text("Sair da conta")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.red.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.red.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 24)
    }
}
