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

                        Text(appDataViewModel.profile?.funcao ?? "Usuário")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)

                        Text(appDataViewModel.profile?.email ?? authViewModel.email)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.primaryBlue)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    profilePill(title: "Setor", value: appDataViewModel.profile?.setor ?? "Não informado")
                    profilePill(title: "Perfil", value: appDataViewModel.profile?.role ?? "Usuário")
                }
            }
        }
    }

    private var detailsCard: some View {
        PrimaryCard {
            SectionHeader(title: "Informações da conta", subtitle: "Dados usados para acompanhar suas requisições no app.")

            VStack(spacing: 12) {
                InfoStrip(icon: "building.2", title: "Setor", value: appDataViewModel.profile?.setor ?? "Não informado")
                InfoStrip(icon: "person.text.rectangle", title: "Perfil", value: appDataViewModel.profile?.role ?? "Usuário")
                InfoStrip(icon: "clock", title: "Último acesso", value: authViewModel.lastAccessDescription)
            }
        }
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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.85), lineWidth: 1)
        )
    }
}
