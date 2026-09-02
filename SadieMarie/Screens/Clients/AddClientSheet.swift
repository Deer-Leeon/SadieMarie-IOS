import SwiftUI

/// Directory-only client create. Does not book, text, email, or send consent.
struct AddClientSheet: View {
    var onCancel: () -> Void
    var onCreated: (Client) -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var phoneTouched = false
    @State private var emailTouched = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var parsedPhone: ParsedClientPhone? { ClientPhone.parse(phone) }
    private var phoneInvalid: Bool { phoneTouched && parsedPhone == nil }
    private var emailInvalid: Bool { emailTouched && !ClientEmail.isValidOptional(email) }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedPhone != nil
            && ClientEmail.isValidOptional(email)
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Saves them to the directory only. No text, email, or consent form is sent until you book them an appointment.")
                        .font(AdminTheme.fontAdminSans(size: 14))
                        .foregroundStyle(AdminTheme.stone600)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AdminTheme.fontAdminSans(size: 13))
                            .foregroundStyle(Color.semanticRed)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.semanticRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(alignment: .top, spacing: 12) {
                        fieldBlock(title: "First name") {
                            TextField("First name", text: $firstName)
                                .textContentType(.givenName)
                                .textInputAutocapitalization(.words)
                        }

                        fieldBlock(title: "Last name (optional)") {
                            TextField("Last name", text: $lastName)
                                .textContentType(.familyName)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    fieldBlock(title: "Phone", isInvalid: phoneInvalid) {
                        TextField("(801) 555-1234", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .onChange(of: phone) { _, newValue in
                                let formatted = ClientPhone.formatAsYouType(newValue)
                                if formatted != newValue {
                                    phone = formatted
                                }
                            }
                            .onSubmit { phoneTouched = true }
                    }

                    Text(ClientPhone.hint)
                        .font(AdminTheme.fontAdminSans(size: 12))
                        .foregroundStyle(AdminTheme.stone500)

                    if phoneInvalid {
                        Text(ClientPhone.validationMessage())
                            .font(AdminTheme.fontAdminSans(size: 12))
                            .foregroundStyle(Color.semanticRed)
                    }

                    fieldBlock(title: "Email (optional)", isInvalid: emailInvalid) {
                        TextField(
                            "Email",
                            text: $email,
                            prompt: Text(verbatim: "client@example.com")
                                .foregroundStyle(Color(uiColor: .placeholderText))
                        )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .onChange(of: email) { _, _ in
                                emailTouched = true
                            }
                    }

                    if emailInvalid {
                        Text(ClientEmail.validationMessage)
                            .font(AdminTheme.fontAdminSans(size: 12))
                            .foregroundStyle(Color.semanticRed)
                    }
                }
                .padding(AdminTheme.Spacing.listHorizontal)
                .padding(.vertical, 14)
            }
            .background(AdminTheme.cream)
            .navigationTitle("Add client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AdminTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .font(AdminTheme.fontAdminSans(size: 15))
                        .foregroundStyle(AdminTheme.stone700)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save client") {
                        Task { await save() }
                    }
                    .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                    .foregroundStyle(canSave ? AdminTheme.stone900 : AdminTheme.stone500)
                    .disabled(!canSave)
                }
            }
        }
        .tint(AdminTheme.stone900)
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isSaving)
    }

    @ViewBuilder
    private func fieldBlock(
        title: String,
        isInvalid: Bool = false,
        @ViewBuilder content: () -> some View
    ) -> some View {
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
                        .stroke(isInvalid ? Color.semanticRed.opacity(0.5) : AdminTheme.stone200, lineWidth: 1)
                )
        }
    }

    @MainActor
    private func save() async {
        phoneTouched = true
        emailTouched = true
        errorMessage = nil

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirst.isEmpty else {
            errorMessage = "Enter a first name."
            return
        }
        guard let parsedPhone else {
            errorMessage = ClientPhone.validationMessage()
            return
        }
        guard ClientEmail.isValidOptional(email) else {
            errorMessage = ClientEmail.validationMessage
            return
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let client = try await AdminAPIClient.shared.bootstrapClient(
                phone: parsedPhone.digits,
                firstName: trimmedFirst,
                lastName: trimmedLast.isEmpty ? nil : trimmedLast,
                email: ClientEmail.validatedOptional(email)
            )
            onCreated(client)
        } catch {
            errorMessage = AdminAPIResponseParser.userFacingMessage(
                from: error,
                fallback: "Could not save this client. Try again."
            )
        }
    }
}
