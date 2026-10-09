import SwiftUI

/// Service picker plus editable alt text and file name, matching the website photo editor.
struct WebsitePhotoMetaFields: View {
    let services: [PhotoServiceOption]
    @Binding var subject: String
    @Binding var altText: String
    @Binding var fileName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("What this photo shows")
                subjectMenu
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Alt text")
                styledField("Alt text", text: $altText)
                    .onChange(of: altText) { _, newValue in
                        if newValue.count > PhotoMeta.altMaxLength {
                            altText = String(newValue.prefix(PhotoMeta.altMaxLength))
                        }
                    }
                Text("Choosing a service fills this in. Your edit is what gets saved.")
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("File name")
                styledField("File name", text: $fileName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: fileName) { _, newValue in
                        if newValue.count > PhotoMeta.fileNameMaxLength {
                            fileName = String(newValue.prefix(PhotoMeta.fileNameMaxLength))
                        }
                    }
            }
        }
        .onChange(of: subject) { _, newValue in
            let copy = PhotoMeta.suggest(subject: newValue, services: services)
            altText = copy.alt
            fileName = copy.fileName
        }
    }

    private var subjectMenu: some View {
        Menu {
            Button("Choose a service") { subject = "" }
            Button("Portrait / studio") { subject = PhotoMeta.portraitSubject }
            ForEach(services) { service in
                Button(service.title) { subject = service.slug }
            }
        } label: {
            HStack(spacing: 8) {
                Text(subjectLabel)
                    .font(AdminTheme.fontAdminSans(size: 15))
                    .foregroundStyle(subject.isEmpty ? AdminTheme.stone500 : AdminTheme.stone900)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdminTheme.stone500)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
        }
    }

    private var subjectLabel: String {
        if subject.isEmpty { return "Choose a service" }
        if subject == PhotoMeta.portraitSubject { return "Portrait / studio" }
        if let match = services.first(where: { $0.slug == subject }) {
            return match.title
        }
        return subject
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
            .foregroundStyle(AdminTheme.stone700)
    }

    private func styledField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(AdminTheme.fontAdminSans(size: 15))
            .foregroundStyle(AdminTheme.stone900)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
    }
}
