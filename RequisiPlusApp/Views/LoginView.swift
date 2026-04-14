import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: LoginField?

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 750
            let horizontalPadding = max(14, geometry.size.width * 0.04)
            let contentWidth = min(geometry.size.width - (horizontalPadding * 2), 620)

            ZStack {
                backgroundLayer

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header(topInset: geometry.safeAreaInsets.top, isCompact: isCompact)

                        formCard(isCompact: isCompact)
                            .frame(maxWidth: contentWidth)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, -28)
                            .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 12))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .ignoresSafeArea(edges: .top)
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            LinearGradient(
                colors: [
                    AppTheme.deepBlue.opacity(0.05),
                    Color.white,
                    AppTheme.primaryBlue.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func header(topInset: CGFloat, isCompact: Bool) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [AppTheme.deepBlue, AppTheme.midBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 240, height: 240)
                .offset(x: 130, y: -40)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 180, height: 180)
                .offset(x: -140, y: 80)

            VStack(spacing: isCompact ? 14 : 18) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 84, height: 84)
                    .overlay(
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )

                VStack(spacing: 8) {
                    Text("Requisi+")
                        .font(.system(size: isCompact ? 30 : 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Acesso ao almoxarifado")
                        .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.88))
                }
            }
            .padding(.top, max(topInset + 18, 30))
            .padding(.bottom, isCompact ? 62 : 78)
            .frame(maxWidth: .infinity)
        }
        .frame(height: isCompact ? 270 : 310)
    }

    private func formCard(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Entrar")
                .font(.system(size: isCompact ? 30 : 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 16) {
                inputField(
                    title: "E-mail",
                    icon: "envelope.fill",
                    text: $email,
                    prompt: "seu@email.com",
                    keyboardType: .emailAddress,
                    field: .email
                )

                secureInputField(
                    title: "Senha",
                    icon: "lock.fill",
                    text: $password,
                    prompt: "Digite sua senha",
                    field: .password
                )

                if let errorMessage = authViewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
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
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }

                        Text(authViewModel.isLoading ? "Entrando..." : "Entrar")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.deepBlue, AppTheme.primaryBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .shadow(color: AppTheme.deepBlue.opacity(0.22), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                .opacity(authViewModel.isLoading || email.isEmpty || password.isEmpty ? 0.65 : 1)
            }
        }
        .padding(.horizontal, isCompact ? 22 : 30)
        .padding(.vertical, isCompact ? 24 : 32)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 22, x: 0, y: 10)
                .shadow(color: AppTheme.deepBlue.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private func inputField(
        title: String,
        icon: String,
        text: Binding<String>,
        prompt: String,
        keyboardType: UIKeyboardType,
        field: LoginField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(focusedField == field ? AppTheme.deepBlue : AppTheme.textMuted)
                    .frame(width: 20)

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
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(focusedField == field ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: focusedField == field ? 1.4 : 1)
            )
        }
    }

    private func secureInputField(
        title: String,
        icon: String,
        text: Binding<String>,
        prompt: String,
        field: LoginField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(focusedField == field ? AppTheme.deepBlue : AppTheme.textMuted)
                    .frame(width: 20)

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
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(focusedField == field ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: focusedField == field ? 1.4 : 1)
            )
        }
    }

    private func submit() {
        guard !authViewModel.isLoading, !email.isEmpty, !password.isEmpty else {
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
