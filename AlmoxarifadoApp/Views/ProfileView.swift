import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScreenContainer(
            title: "Perfil",
            subtitle: "Dados do usuario responsavel e preferencias rapidas do painel."
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
                            Text("Jose Carlos")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(AppTheme.deepBlue)

                            Text("Administrador do Almoxarifado")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    userDataRow(title: "E-mail", value: "jose.carlos@prefeitura.gov")
                    userDataRow(title: "Unidade", value: "Almoxarifado Central")
                    userDataRow(title: "Ultimo acesso", value: "13/04/2026 as 16:17")
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
