import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: LoginField?

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topInset: geometry.safeAreaInsets.top)

                    ScrollView(showsIndicators: false) {
                        formCard
                            .padding(.horizontal, 16)
                            .padding(.top, -18)
                            .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 12))
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .frame(width: 126, height: 64)
                .overlay(
                    VStack(spacing: 4) {
                        Text("requisi+")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.deepBlue)

                        Text("controle")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                )

            VStack(spacing: 6) {
                Text("Requisi+")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Controle de frequencia inteligente")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, max(topInset + 16, 28))
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [AppTheme.deepBlue, AppTheme.midBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Entrar")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Acesse o sistema com suas credenciais")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }

            VStack(spacing: 16) {
                credentialField(
                    title: "E-mail",
                    text: $email,
                    prompt: "seu@email.com",
                    keyboardType: .emailAddress,
                    field: .email
                )

                secureCredentialField(
                    title: "Senha",
                    text: $password,
                    prompt: "********",
                    field: .password
                )

                if let errorMessage = authViewModel.errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    submit()
                } label: {
                    HStack(spacing: 10) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.right.to.line")
                                .font(.system(size: 16, weight: .semibold))
                        }

                        Text(authViewModel.isLoading ? "Entrando..." : "Entrar")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                .opacity(authViewModel.isLoading || email.isEmpty || password.isEmpty ? 0.7 : 1)
            }

            Text("Ao acessar, voce concorda com os termos de uso, politica de privacidade e aviso sobre biometria.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: AppTheme.deepBlue.opacity(0.08), radius: 18, x: 0, y: 8)
        )
    }

    private func credentialField(
        title: String,
        text: Binding<String>,
        prompt: String,
        keyboardType: UIKeyboardType,
        field: LoginField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("", text: text, prompt: Text(prompt).foregroundStyle(AppTheme.textMuted.opacity(0.65)))
                .textInputAutocapitalization(.never)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.deepBlue)
                .focused($focusedField, equals: field)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(focusedField == field ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: 1)
                )
        }
    }

    private func secureCredentialField(
        title: String,
        text: Binding<String>,
        prompt: String,
        field: LoginField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            SecureField("", text: text, prompt: Text(prompt).foregroundStyle(AppTheme.textMuted.opacity(0.65)))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.deepBlue)
                .focused($focusedField, equals: field)
                .submitLabel(.go)
                .onSubmit {
                    submit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(focusedField == field ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: 1)
                )
        }
    }

    private func submit() {
        guard authViewModel.isLoading == false, email.isEmpty == false, password.isEmpty == false else {
            return
        }

        focusedField = nil

        Task {
            await authViewModel.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password
            )
        }
    }
}

private enum LoginField {
    case email
    case password
}
