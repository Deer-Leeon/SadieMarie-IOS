import SwiftUI

/// Step 2 — client CRM fields (mirrors web `ManualBookingModal` step 2).
struct ManualBookingClientFormView: View {
    @Bindable var viewModel: ManualBookingViewModel
    var focusedField: FocusState<ManualBookingClientField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Client details")
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone600)

            Text("Phone is required and identifies the client in your CRM. Email is optional — you can add it later from the client profile.")
                .font(AdminTheme.fontAdminSans(size: 12))
                .foregroundStyle(AdminTheme.stone500)

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

            formField(title: "Email (optional)", field: .email, isInvalid: false) {
                TextField("Leave blank if unknown", text: $viewModel.clientEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.done)
                    .focused(focusedField, equals: .email)
                    .onSubmit { focusedField.wrappedValue = nil }
            }
        }
        .onChange(of: focusedField.wrappedValue) { old, new in
            if old == .phone, new != .phone {
                viewModel.phoneTouched = true
                viewModel.formatPhoneField()
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

    @ViewBuilder
    private func formField(
        title: String,
        field: ManualBookingClientField,
        isInvalid: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(AdminTheme.stone500)
                .textCase(.uppercase)

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
                        .stroke(
                            isInvalid ? Color.semanticRed.opacity(0.5) : AdminTheme.stone200,
                            lineWidth: 1
                        )
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField.wrappedValue = field
        }
    }
}

enum ManualBookingClientField: Hashable {
    case firstName
    case lastName
    case phone
    case email
}
