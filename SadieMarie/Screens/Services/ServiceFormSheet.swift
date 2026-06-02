import SwiftUI

enum ServiceFormMode: Identifiable, Hashable {
    case create
    case edit(Service)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let service): return "edit-\(service.id)"
        }
    }

    var navigationTitle: String {
        switch self {
        case .create: return "Add service"
        case .edit: return "Edit service"
        }
    }
}

struct ServiceFormDraft: Equatable {
    var title: String = ""
    var category: String = ServiceCatalog.categories[0]
    var description: String = ""
    var price: String = ""
    var length: String = ""
    var isGroup: Bool = false
    var parentId: String = ""

    init() {}

    init(service: Service) {
        title = service.title
        category = service.category
        description = service.description
        price = service.price.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(service.price))
            : String(service.price)
        length = service.durationMins.map(String.init) ?? ""
        isGroup = service.isGroup
        parentId = service.parentId.map(String.init) ?? ""
    }
}

/// Create / edit slide-over for the services catalogue.
struct ServiceFormSheet: View {
    let mode: ServiceFormMode
    let allServices: [Service]
    var isSubmitting: Bool
    var submitError: String?
    var onCancel: () -> Void
    var onSubmitCreate: (CreateServicePayload) -> Void
    var onSubmitUpdate: (UpdateServicePayload) -> Void

    @State private var draft = ServiceFormDraft()
    @State private var validationMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editingService: Service? {
        if case .edit(let service) = mode { return service }
        return nil
    }

    private var candidateParents: [Service] {
        let excludingId = editingService?.id
        return allServices
            .filter { $0.isGroup && $0.category == draft.category && $0.id != excludingId }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var parentMenuLabel: String {
        guard let id = Int(draft.parentId),
              let parent = candidateParents.first(where: { $0.id == id }) else {
            return "None (standalone)"
        }
        return parent.title
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let validationMessage {
                        formErrorBanner(validationMessage)
                    }
                    if let submitError {
                        formErrorBanner(submitError)
                    }

                    fieldBlock(title: "Title") {
                        TextField("Service name", text: $draft.title)
                            .textInputAutocapitalization(.words)
                    }

                    fieldBlock(title: "Category") {
                        Menu {
                            ForEach(ServiceCatalog.categories, id: \.self) { category in
                                Button(category) {
                                    draft.category = category
                                    if !candidateParents.contains(where: { String($0.id) == draft.parentId }) {
                                        draft.parentId = ""
                                    }
                                }
                            }
                        } label: {
                            menuRowLabel(draft.category)
                        }
                    }

                    fieldBlock(title: "Description") {
                        TextEditor(text: $draft.description)
                            .frame(minHeight: 88)
                            .scrollContentBackground(.hidden)
                    }

                    fieldBlock(title: "Price") {
                        TextField("0", text: $draft.price)
                            .keyboardType(.decimalPad)
                    }

                    fieldBlock(title: "This is a group header") {
                        HStack {
                            Spacer(minLength: 0)
                            Toggle("", isOn: $draft.isGroup)
                                .labelsHidden()
                                .tint(AdminTheme.stone900)
                        }
                    }
                    .disabled(isEditing)
                    .opacity(isEditing ? 0.55 : 1)

                    if !draft.isGroup {
                        fieldBlock(title: "Duration (minutes)") {
                            TextField("60", text: $draft.length)
                                .keyboardType(.numberPad)
                        }

                        if !candidateParents.isEmpty {
                            fieldBlock(title: "Nest under") {
                                Menu {
                                    Button("None (standalone)") {
                                        draft.parentId = ""
                                    }
                                    ForEach(candidateParents) { parent in
                                        Button(parent.title) {
                                            draft.parentId = String(parent.id)
                                        }
                                    }
                                } label: {
                                    menuRowLabel(parentMenuLabel)
                                }
                            }
                        }
                    }
                }
                .padding(AdminTheme.Spacing.listHorizontal)
                .padding(.vertical, 14)
            }
            .background(AdminTheme.cream)
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AdminTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .font(AdminTheme.fontAdminSans(size: 15))
                        .foregroundStyle(AdminTheme.stone700)
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        submit()
                    }
                    .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone900)
                    .disabled(isSubmitting)
                }
            }
            .onAppear {
                switch mode {
                case .create:
                    draft = ServiceFormDraft()
                case .edit(let service):
                    draft = ServiceFormDraft(service: service)
                }
            }
        }
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isSubmitting)
    }

    @ViewBuilder
    private func fieldBlock(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)

            content()
                .font(AdminTheme.fontAdminSans(size: 15))
                .foregroundStyle(AdminTheme.stone900)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
        }
    }

    private func menuRowLabel(_ value: String) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(AdminTheme.fontAdminSans(size: 15))
                .foregroundStyle(AdminTheme.stone900)
                .lineLimit(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AdminTheme.stone500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formErrorBanner(_ message: String) -> some View {
        Text(message)
            .font(AdminTheme.fontAdminSans(size: 13))
            .foregroundStyle(Color.semanticRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.semanticRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func submit() {
        validationMessage = nil

        guard let payload = buildPayload() else { return }

        switch mode {
        case .create:
            onSubmitCreate(payload)
        case .edit(let service):
            onSubmitUpdate(
                UpdateServicePayload(
                    dbId: service.id,
                    calEventId: service.calEventId,
                    title: payload.title,
                    description: payload.description,
                    length: payload.length,
                    price: payload.price,
                    category: payload.category,
                    isGroup: payload.isGroup,
                    parentId: payload.parentId,
                    color: service.color
                )
            )
        }
    }

    private func buildPayload() -> CreateServicePayload? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = draft.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            validationMessage = "Title is required."
            return nil
        }

        guard let price = Double(draft.price.trimmingCharacters(in: .whitespacesAndNewlines)),
              price >= 0 else {
            validationMessage = "Price must be a non-negative number."
            return nil
        }

        let parentId = draft.parentId.isEmpty ? nil : Int(draft.parentId)

        var length: Int?
        if !draft.isGroup {
            guard let duration = Int(draft.length.trimmingCharacters(in: .whitespacesAndNewlines)),
                  duration >= 5 else {
                validationMessage = "Duration must be a whole number of at least 5 minutes."
                return nil
            }
            length = duration
        }

        if draft.isGroup && parentId != nil {
            validationMessage = "A group header cannot be nested under another group."
            return nil
        }

        return CreateServicePayload(
            title: title,
            description: description,
            length: length,
            price: price,
            category: category,
            isGroup: draft.isGroup,
            parentId: draft.isGroup ? nil : parentId,
            color: editingService?.color
        )
    }
}
