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

                    fieldBlock(title: "Email") {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
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
                        onSave(
                            trimmedOrNil(firstName),
                            trimmedOrNil(lastName),
                            trimmedOrNil(email)?.lowercased()
                        )
                    }
                    .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone900)
                    .disabled(isSaving)
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

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
