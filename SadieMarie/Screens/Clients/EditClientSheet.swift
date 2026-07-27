import SwiftUI

struct EditClientSheet: View {
    let client: Client
    var isSaving: Bool
    var errorMessage: String?
    var onCancel: () -> Void
    var onSave: (String?, String?, String?) -> Void

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var emailTouched = false

    private var emailInvalid: Bool {
        emailTouched && !ClientEmail.isValidOptional(email)
    }

    private var canSave: Bool {
        ClientEmail.isValidOptional(email) && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AdminTheme.fontAdminSans(size: 13))
                            .foregroundStyle(Color.semanticRed)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.semanticRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    fieldBlock(title: "First name") {
                        TextField("First name", text: $firstName)
                            .textInputAutocapitalization(.words)
                    }

                    fieldBlock(title: "Last name") {
                        TextField("Last name", text: $lastName)
                            .textInputAutocapitalization(.words)
                    }

                    fieldBlock(title: "Email (optional)", isInvalid: emailInvalid) {
                        TextField("jane@example.com", text: $email)
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

                    if let phone = client.phone, !phone.isEmpty {
                        fieldBlock(title: "Phone") {
                            Text(client.formattedPhone)
                                .foregroundStyle(AdminTheme.stone700)
                        }
                    }
                }
                .padding(AdminTheme.Spacing.listHorizontal)
                .padding(.vertical, 14)
            }
            .background(AdminTheme.cream)
            .navigationTitle("Edit client")
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
                    Button("Save") {
                        emailTouched = true
                        guard ClientEmail.isValidOptional(email) else { return }
                        onSave(
                            trimmedOrNil(firstName),
                            trimmedOrNil(lastName),
                            ClientEmail.validatedOptional(email)
                        )
                    }
                    .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                    .foregroundStyle(canSave ? AdminTheme.stone900 : AdminTheme.stone500)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                firstName = client.firstName ?? ""
                lastName = client.lastName ?? ""
                email = client.email ?? ""
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

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
