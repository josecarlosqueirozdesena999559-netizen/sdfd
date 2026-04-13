import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appDataViewModel: AppDataViewModel

    var body: some View {
        ScreenContainer(
            title: "Perfil",
            subtitle: "Dados do usuario autenticado e acesso controlado pelo Supabase."
        ) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.softBlue)
                            .frame(width: 82, height: 82)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryBlue)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(appDataViewModel.profile?.name ?? authViewModel.displayName)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(AppTheme.deepBlue)

                            Text(appDataViewModel.profile?.funcao ?? "Sessao autenticada pelo Supabase")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    userDataRow(title: "E-mail", value: appDataViewModel.profile?.email ?? authViewModel.email)
                    userDataRow(title: "Unidade", value: appDataViewModel.profile?.setor ?? "Setor nao informado")
                    userDataRow(title: "Perfil", value: appDataViewModel.profile?.role ?? "usuario")
                    userDataRow(title: "Ultimo acesso", value: authViewModel.lastAccessDescription)

                    Button {
                        authViewModel.signOut()
                    } label: {
                        Text("Sair")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(Color.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }

    private func userDataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.deepBlue)
        }
    }
}
