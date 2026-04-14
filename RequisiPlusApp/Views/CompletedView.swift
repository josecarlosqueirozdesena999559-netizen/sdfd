import SwiftUI

struct CreateRequisitionView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel

    @State private var selectedMaterial: MaterialType?
    @State private var searchText = ""
    @State private var currentBalances: [String: String] = [:]
    @State private var requestedQuantities: [String: String] = [:]

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
            if appDataViewModel.materialTypes.isEmpty {
                PrimaryCard {
                    SectionHeader(
                        title: "Sem categorias disponíveis"
                    )

                    Text("Seu usuário não possui categorias liberadas no momento.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            } else if let selectedMaterial {
                materialItemsScreen(for: selectedMaterial)
            } else {
                categorySelectorCard
            }

            if let successMessage = appDataViewModel.successMessage {
                feedbackCard(
                    title: "Requisição enviada com sucesso",
                    message: successMessage,
                    tint: AppTheme.success,
                    icon: "checkmark.circle.fill"
                )
            }

            if let errorMessage = appDataViewModel.errorMessage, errorMessage.isEmpty == false {
                feedbackCard(
                    title: "Não foi possível enviar",
                    message: errorMessage,
                    tint: .red.opacity(0.82),
                    icon: "exclamationmark.triangle.fill"
                )
            }
        }
        .onChange(of: appDataViewModel.materialTypes) { _, newValue in
            if let selectedMaterial, newValue.contains(selectedMaterial) == false {
                self.selectedMaterial = nil
            }
        }
    }

    private var categorySelectorCard: some View {
        PrimaryCard {
            SectionHeader(
                title: "Menu de materiais",
                subtitle: "Escolha primeiro a categoria. Depois a tabela abre em tela cheia para facilitar a visualização."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(appDataViewModel.materialTypes) { material in
                    Button {
                        selectedMaterial = material
                        searchText = ""
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(shortTitle(for: material))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.leading)

                            Text(material.description)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(2)

                            Text("\(filteredCatalogCount(for: material)) itens")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(categoryBackground())
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.fieldBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func materialItemsScreen(for material: MaterialType) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                selectedMaterial = nil
                searchText = ""
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))

                    Text("Voltar para categorias")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(AppTheme.deepBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            InfoStrip(
                icon: "shippingbox.fill",
                title: "Categoria selecionada",
                value: shortTitle(for: material)
            )

            itemRequestCard(for: material)
        }
    }

    private func itemRequestCard(for material: MaterialType) -> some View {
        PrimaryCard {
            SectionHeader(
                title: "Itens de \(shortTitle(for: material))",
                subtitle: "Visualização ampliada para preencher com mais conforto."
            )

            SearchFieldRow(
                prompt: "Pesquisar item",
                text: $searchText
            )

            requestTableHeader

            ScrollView {
                LazyVStack(spacing: 14) {
                    if filteredItems(for: material).isEmpty {
                            Text("Não existem itens cadastrados no banco para essa categoria.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(filteredItems(for: material)) { item in
                            itemRow(for: item)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 320, maxHeight: 520)

            Button {
                Task {
                    await appDataViewModel.createRequisition(
                        materialType: material,
                        entries: selectedEntries(for: material),
                        observation: ""
                    )
                    if appDataViewModel.successMessage != nil {
                        currentBalances = [:]
                        requestedQuantities = [:]
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if appDataViewModel.createInProgress {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(appDataViewModel.createInProgress ? "Enviando requisição..." : "Enviar requisição")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    AppTheme.heroGradient,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedEntries(for: material).isEmpty || appDataViewModel.createInProgress)
            .opacity(selectedEntries(for: material).isEmpty || appDataViewModel.createInProgress ? 0.65 : 1)
        }
    }

    private var requestTableHeader: some View {
        HStack(spacing: 12) {
            Text("Item")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Saldo")
                .frame(width: 88, alignment: .center)

            Text("Qtd")
                .frame(width: 88, alignment: .center)
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(AppTheme.textMuted)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.skyBlue.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func itemRow(for item: MaterialCatalogItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(item.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            compactField(
                title: "Saldo atual",
                prompt: "0",
                text: Binding(
                    get: { currentBalances[item.id, default: ""] },
                    set: { currentBalances[item.id] = $0 }
                )
            )
            .frame(width: 88)

            compactField(
                title: "Quantidade",
                prompt: "0",
                text: Binding(
                    get: { requestedQuantities[item.id, default: ""] },
                    set: { requestedQuantities[item.id] = $0 }
                )
            )
            .frame(width: 88)
        }
        .padding(16)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder, lineWidth: 1)
        )
    }

    private func compactField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .center, spacing: 6) {
            TextField(prompt, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .frame(height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                )
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.deepBlue)
        }
        .accessibilityLabel(title)
    }

    private func filteredItems(for material: MaterialType) -> [MaterialCatalogItem] {
        let items = categoryItems(for: material)

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }

        let query = searchText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return items.filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(query) ||
            $0.detail.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(query)
        }
    }

    private func filteredCatalogCount(for material: MaterialType) -> Int {
        categoryItems(for: material).count
    }

    private func selectedEntries(for material: MaterialType) -> [RequestedItemEntry] {
        categoryItems(for: material).compactMap { item in
            let current = currentBalances[item.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let requested = requestedQuantities[item.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)

            guard current.isEmpty == false || requested.isEmpty == false else {
                return nil
            }

            return RequestedItemEntry(
                id: item.id,
                item: item,
                currentBalance: current,
                requestedQuantity: requested
            )
        }
    }

    private func shortTitle(for material: MaterialType) -> String {
        material.title
            .formattedCategoryTitle
    }

    private func categoryBackground() -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white)
    }

    private func categoryItems(for material: MaterialType) -> [MaterialCatalogItem] {
        let categoryId = material.id.normalizedSearchText
        return appDataViewModel.catalogItems.filter { $0.categoryId.normalizedSearchText == categoryId }
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
