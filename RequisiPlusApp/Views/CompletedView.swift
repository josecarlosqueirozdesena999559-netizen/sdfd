import SwiftUI

struct CreateRequisitionView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel

    @State private var selectedMaterial: MaterialType?
    @State private var searchText = ""
    @State private var observation = ""
    @State private var currentBalances: [String: String] = [:]
    @State private var requestedQuantities: [String: String] = [:]

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
            if appDataViewModel.materialTypes.isEmpty {
                PrimaryCard {
                    SectionHeader(
                        title: "Sem categorias liberadas",
                        subtitle: "Seu usuario ainda nao possui categorias disponiveis para requisicao."
                    )

                    Text("Entre em contato com o administrador para liberar as categorias no cadastro do usuario.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            } else {
                categorySelectorCard

                if let selectedMaterial {
                    itemRequestCard(for: selectedMaterial)
                } else {
                    PrimaryCard {
                        Text("Escolha uma categoria para ver os itens disponiveis.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
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
            } else if let selectedMaterial, newValue.contains(selectedMaterial) == false {
                self.selectedMaterial = newValue.first
            }
        }
    }

    private var categorySelectorCard: some View {
        PrimaryCard {
            SectionHeader(
                title: "Categorias do usuario",
                subtitle: "Escolha uma categoria liberada no seu cadastro para montar a requisicao."
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
                                .foregroundStyle(selectedMaterial == material ? .white : AppTheme.textPrimary)
                                .multilineTextAlignment(.leading)

                            Text(material.description)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selectedMaterial == material ? Color.white.opacity(0.78) : AppTheme.textMuted)
                                .lineLimit(2)

                            Text("\(filteredCatalogCount(for: material)) itens")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selectedMaterial == material ? Color.white.opacity(0.84) : AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(categoryBackground(isSelected: selectedMaterial == material))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(selectedMaterial == material ? AppTheme.deepBlue : AppTheme.fieldBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func itemRequestCard(for material: MaterialType) -> some View {
        PrimaryCard {
            SectionHeader(
                title: "Itens de \(shortTitle(for: material))",
                subtitle: "Preencha a tabela e envie para gravar no banco que alimenta o PDF no site."
            )

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textMuted)

                TextField("Pesquisar item", text: $searchText)
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.deepBlue)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
            )

            VStack(spacing: 14) {
                if filteredItems(for: material).isEmpty {
                    Text("Nao existem itens cadastrados no banco para essa categoria.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                } else {
                    ForEach(filteredItems(for: material)) { item in
                        itemRow(for: item)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Observacao")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                TextField("Adicione uma observacao, se precisar", text: $observation, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .padding(16)
                    .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.fieldBorder, lineWidth: 1)
                    )
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.deepBlue)
            }

            Button {
                Task {
                    await appDataViewModel.createRequisition(
                        materialType: material,
                        entries: selectedEntries(for: material),
                        observation: observation
                    )
                    if appDataViewModel.successMessage != nil {
                        currentBalances = [:]
                        requestedQuantities = [:]
                        observation = ""
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
                    AppTheme.heroGradient,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedEntries(for: material).isEmpty || appDataViewModel.createInProgress)
            .opacity(selectedEntries(for: material).isEmpty || appDataViewModel.createInProgress ? 0.65 : 1)
        }
    }

    private func itemRow(for item: MaterialCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(item.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }

            HStack(spacing: 12) {
                compactField(
                    title: "Saldo atual",
                    prompt: "Digite aqui",
                    text: Binding(
                        get: { currentBalances[item.id, default: ""] },
                        set: { currentBalances[item.id] = $0 }
                    )
                )

                compactField(
                    title: "Quantidade",
                    prompt: "Digite aqui",
                    text: Binding(
                        get: { requestedQuantities[item.id, default: ""] },
                        set: { requestedQuantities[item.id] = $0 }
                    )
                )
            }
        }
        .padding(16)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder, lineWidth: 1)
        )
    }

    private func compactField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            TextField(prompt, text: text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                )
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.deepBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .replacingOccurrences(of: "Material de ", with: "")
            .replacingOccurrences(of: "Insumos de ", with: "")
    }

    private func categoryBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isSelected ? Color.clear : Color.white)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.heroGradient)
                }
            }
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
