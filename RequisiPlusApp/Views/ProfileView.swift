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
            VStack(alignment: .leading, spacing: 18) {
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

                        Text(appDataViewModel.profile?.funcao ?? "Usuario")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)

                        Text(appDataViewModel.profile?.email ?? authViewModel.email)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.primaryBlue)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    profilePill(title: "Setor", value: appDataViewModel.profile?.setor ?? "Nao informado")
                    profilePill(title: "Perfil", value: appDataViewModel.profile?.role ?? "Usuario")
                }
            }
        }
    }

    private var detailsCard: some View {
        PrimaryCard {
            SectionHeader(title: "Informacoes da conta", subtitle: "Dados usados para acompanhar suas requisicoes no app.")

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
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.deepBlue)
                .frame(width: 5, height: 40)

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

    private func profilePill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
