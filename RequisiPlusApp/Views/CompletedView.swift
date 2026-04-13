import SwiftUI

struct CreateRequisitionView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @State private var selectedMaterial: MaterialType?
    @State private var justification = ""

    var body: some View {
        ScreenContainer(
            title: "Fazer requisicao",
            subtitle: "Selecione o tipo de material e envie a solicitacao para acompanhamento."
        ) {
            SectionCard(title: "Nova requisicao", systemImage: "square.and.pencil") {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo de material")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.deepBlue)

                        Picker("Tipo de material", selection: $selectedMaterial) {
                            ForEach(appDataViewModel.materialTypes) { material in
                                Text(material.title).tag(Optional(material))
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppTheme.cardBlue.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if let selectedMaterial {
                        Text(selectedMaterial.description)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Observacao")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.deepBlue)

                        TextField("Descreva rapidamente a necessidade", text: $justification, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(AppTheme.cardBlue.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        HStack {
                            if appDataViewModel.createInProgress {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(appDataViewModel.createInProgress ? "Enviando..." : "Enviar requisicao")
                        }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedMaterial == nil || appDataViewModel.createInProgress)
                    .opacity(selectedMaterial == nil || appDataViewModel.createInProgress ? 0.7 : 1)
                }
            }

            if let successMessage = appDataViewModel.successMessage {
                SectionCard(title: "Solicitacao registrada", systemImage: "checkmark.circle.fill") {
                    Text("\(successMessage) Quando houver etapa de assinatura, ela sera concluida no computador.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = appDataViewModel.errorMessage, errorMessage.isEmpty == false {
                SectionCard(title: "Falha ao enviar", systemImage: "exclamationmark.triangle.fill") {
                    Text(errorMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
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
}
