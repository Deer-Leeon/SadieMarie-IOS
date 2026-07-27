import SwiftUI

/// Step 2 — pick an existing CRM client or enter walk-in details
/// (mirrors web `ManualBookingClientStep`).
struct ManualBookingClientFormView: View {
    @Bindable var viewModel: ManualBookingViewModel
    var focusedField: FocusState<ManualBookingClientField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.lockedClient != nil {
                lockedClientBanner
            } else {
                modePicker
                if viewModel.clientEntryMode == .existing {
                    existingClientPicker
                } else {
                    freeTextFields
                }
            }
        }
        .task {
            if viewModel.clientEntryMode == .existing, viewModel.lockedClient == nil {
                await viewModel.loadDirectoryClientsIfNeeded()
            }
        }
        .onChange(of: viewModel.clientEntryMode) { _, mode in
            if mode == .existing {
                Task { await viewModel.loadDirectoryClientsIfNeeded() }
            }
        }
        .onChange(of: focusedField.wrappedValue) { old, new in
            if old == .phone, new != .phone {
                viewModel.phoneTouched = true
                viewModel.formatPhoneField()
            }
            if old == .email, new != .email {
                viewModel.emailTouched = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField.wrappedValue == .phone {
                    Spacer()
                    Button("Next") {
                        viewModel.phoneTouched = true
                        viewModel.formatPhoneField()
                        focusedField.wrappedValue = .email
                    }
                    .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                }
            }
        }
    }

    // MARK: - Mode

    private var modePicker: some View {
        HStack(spacing: 4) {
            modeButton(title: "Existing", systemImage: "person.2", mode: .existing)
            modeButton(title: "New client", systemImage: "person.badge.plus", mode: .new)
        }
        .padding(4)
        .background(AdminTheme.stone100)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private func modeButton(
        title: String,
        systemImage: String,
        mode: ManualBookingViewModel.ClientEntryMode
    ) -> some View {
        let selected = viewModel.clientEntryMode == mode
        return Button {
            viewModel.setClientEntryMode(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(title.uppercased())
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(1.4)
            }
            .foregroundStyle(selected ? AdminTheme.stone900 : AdminTheme.stone500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? AdminTheme.cardFill : Color.clear)
            .clipShape(Capsule())
            .shadow(color: selected ? Color.black.opacity(0.04) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Existing

    private var existingClientPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search and select a client to skip typing their details.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone600)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
                TextField("Search by name, email, or phone…", text: $viewModel.clientSearchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(AdminTheme.fontAdminSans(size: 15))
                    .foregroundStyle(AdminTheme.stone900)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )

            if viewModel.isLoadingDirectoryClients {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading clients…")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone500)
                }
                .padding(.vertical, 12)
            } else if let error = viewModel.directoryLoadError {
                Text(error)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(Color.semanticRed)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.semanticRed.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let selected = viewModel.selectedDirectoryClient {
                selectedClientCard(selected)
            }

            if !viewModel.isLoadingDirectoryClients, viewModel.directoryLoadError == nil {
                clientResultsList
            }
        }
    }

    private func selectedClientCard(_ client: Client) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AdminTheme.confirmedText)
            VStack(alignment: .leading, spacing: 4) {
                Text(client.displayName)
                    .font(AdminTheme.fontAdminSerif(size: 17))
                    .foregroundStyle(AdminTheme.stone900)
                let meta = [
                    client.formattedPhone.isEmpty ? nil : client.formattedPhone,
                    ClientEmail.usableDisplay(client.email),
                ].compactMap { $0 }
                if !meta.isEmpty {
                    Text(meta.joined(separator: " · "))
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone500)
                }
            }
            Spacer(minLength: 8)
            Button("Clear") {
                viewModel.clearSelectedDirectoryClient()
            }
            .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
            .foregroundStyle(AdminTheme.stone600)
        }
        .padding(12)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AdminTheme.stone300, lineWidth: 1)
        )
    }

    private var clientResultsList: some View {
        let results = viewModel.filteredDirectoryClients
        return VStack(spacing: 0) {
            if results.isEmpty {
                Text(
                    viewModel.clientSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "No clients in directory yet."
                        : "No clients match that search."
                )
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone500)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                ForEach(results) { client in
                    Button {
                        viewModel.selectDirectoryClient(client)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.displayName)
                                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                                    .foregroundStyle(AdminTheme.stone900)
                                let subtitle = [
                                    client.formattedPhone.isEmpty ? nil : client.formattedPhone,
                                    ClientEmail.usableDisplay(client.email),
                                ].compactMap { $0 }.joined(separator: " · ")
                                if !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(AdminTheme.fontAdminSans(size: 12))
                                        .foregroundStyle(AdminTheme.stone500)
                                }
                            }
                            Spacer()
                            if viewModel.selectedDirectoryClient?.id == client.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AdminTheme.stone900)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)

                    if client.id != results.last?.id {
                        Divider().overlay(AdminTheme.stone100)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    // MARK: - Locked / new

    private var lockedClientBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Booking for")
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(2.0)
                .foregroundStyle(AdminTheme.stone500)
                .textCase(.uppercase)
            Text(viewModel.clientDisplayName)
                .font(AdminTheme.fontAdminSerif(size: 20))
                .foregroundStyle(AdminTheme.stone900)
            let meta = [
                viewModel.clientPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : viewModel.clientPhone,
                ClientEmail.usableDisplay(viewModel.clientEmail),
            ].compactMap { $0 }
            if !meta.isEmpty {
                Text(meta.joined(separator: " · "))
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone600)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
    }

    private var freeTextFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Phone is required. Email is optional. Phone identifies the client in your CRM.")
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(AdminTheme.stone600)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                formField(title: "First name", field: .firstName, isInvalid: false) {
                    TextField("First name", text: $viewModel.clientFirstName)
                        .textInputAutocapitalization(.words)
                        .textContentType(.givenName)
                        .submitLabel(.next)
                        .focused(focusedField, equals: .firstName)
                        .onSubmit { focusedField.wrappedValue = .lastName }
                }
                formField(title: "Last name", field: .lastName, isInvalid: false) {
                    TextField("Last name", text: $viewModel.clientLastName)
                        .textInputAutocapitalization(.words)
                        .textContentType(.familyName)
                        .submitLabel(.next)
                        .focused(focusedField, equals: .lastName)
                        .onSubmit { focusedField.wrappedValue = .phone }
                }
            }

            formField(title: "Phone", field: .phone, isInvalid: viewModel.phoneInvalid) {
                TextField("(801) 555-1234", text: $viewModel.clientPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused(focusedField, equals: .phone)
            }

            if viewModel.phoneInvalid {
                Text(ClientPhone.validationMessage())
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(Color.semanticRed)
            } else {
                Text(ClientPhone.hint)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
            }

            formField(title: "Email (optional)", field: .email, isInvalid: viewModel.emailInvalid) {
                TextField("Email address", text: $viewModel.clientEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.done)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .focused(focusedField, equals: .email)
                    .onSubmit { focusedField.wrappedValue = nil }
            }

            if viewModel.emailInvalid {
                Text(ClientEmail.validationMessage)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(Color.semanticRed)
            }
        }
    }

    @ViewBuilder
    private func formField(
        title: String,
        field: ManualBookingClientField,
        isInvalid: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let isFocused = focusedField.wrappedValue == field

        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(AdminTheme.stone500)
                .textCase(.uppercase)

            content()
                .textFieldStyle(.plain)
                .font(AdminTheme.fontAdminSans(size: 15))
                .foregroundStyle(AdminTheme.stone900)
                .tint(AdminTheme.stone900)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor(isInvalid: isInvalid, isFocused: isFocused), lineWidth: 1)
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField.wrappedValue = field
        }
    }

    private func borderColor(isInvalid: Bool, isFocused: Bool) -> Color {
        if isInvalid { return Color.semanticRed.opacity(0.5) }
        if isFocused { return AdminTheme.stone500 }
        return AdminTheme.stone200
    }
}

enum ManualBookingClientField: Hashable {
    case firstName
    case lastName
    case phone
    case email
}
