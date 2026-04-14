import SwiftUI

struct CreateRequisitionView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @State private var selectedMaterial: MaterialType?
    @State private var justification = ""

    var body: some View {
        ScreenContainer(
            title: "Fazer requisicao",
            subtitle: "Envie um novo pedido de material com um fluxo rapido e organizado."
        ) {
            PrimaryCard {
                SectionHeader(
                    title: "Nova requisicao",
                    subtitle: "Preencha os dados essenciais para registrar seu pedido."
                )

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo de material")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Picker("Tipo de material", selection: $selectedMaterial) {
                            ForEach(appDataViewModel.materialTypes) { material in
                                Text(material.title).tag(Optional(material))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.fieldBorder, lineWidth: 1)
                        )
                    }

                    if let selectedMaterial {
                        Text(selectedMaterial.description)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Observacao")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        TextField("Descreva brevemente o que voce precisa", text: $justification, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .padding(16)
                            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
                            )
                            .foregroundStyle(AppTheme.textPrimary)
                            .tint(AppTheme.deepBlue)
                    }

                    Button {
                        Task {
                            await appDataViewModel.createRequisition(
                                materialType: selectedMaterial,
                                observation: justification
                            )
                            if appDataViewModel.successMessage != nil {
                                justification = ""
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if appDataViewModel.createInProgress {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(appDataViewModel.createInProgress ? "Enviando..." : "Enviar requisicao")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.deepBlue, AppTheme.primaryBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .shadow(color: AppTheme.deepBlue.opacity(0.18), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedMaterial == nil || appDataViewModel.createInProgress)
                    .opacity(selectedMaterial == nil || appDataViewModel.createInProgress ? 0.65 : 1)
                }
            }

            if let successMessage = appDataViewModel.successMessage {
                feedbackCard(
                    title: "Requisicao enviada",
                    message: successMessage,
                    tint: AppTheme.success,
                    icon: "checkmark.circle.fill"
                )
            }

            if let errorMessage = appDataViewModel.errorMessage, errorMessage.isEmpty == false {
                feedbackCard(
                    title: "Nao foi possivel enviar",
                    message: errorMessage,
                    tint: .red.opacity(0.82),
                    icon: "exclamationmark.triangle.fill"
                )
            }
        }
        .onAppear {
            if selectedMaterial == nil {
                selectedMaterial = appDataViewModel.materialTypes.first
            }
        }
        .onChange(of: appDataViewModel.materialTypes) { _, newValue in
            if selectedMaterial == nil {
                selectedMaterial = newValue.first
            }
        }
    }

    private func feedbackCard(title: String, message: String, tint: Color, icon: String) -> some View {
        PrimaryCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
    }
}
