import SwiftUI

/// Confirm overlay before sending a consent or Google-review text.
struct ClientSendSmsConfirmPopup: View {
    let kind: ManualClientSmsKind
    let clientId: String
    let clientName: String
    let clientPhone: String
    var onClose: () -> Void
    var onSent: (ManualClientSmsKind) -> Void

    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geo in
            let maxWidth = min(geo.size.width - 40, 420)

            ZStack {
                ZStack {
                    AdminTheme.cream.opacity(0.72)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .light)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isSending { onClose() }
                }
                .accessibilityLabel("Dismiss send text")

                VStack(spacing: 0) {
                    header
                    Rectangle()
                        .fill(AdminTheme.stone200)
                        .frame(height: 1)
                    bodyCopy
                    Rectangle()
                        .fill(AdminTheme.stone200)
                        .frame(height: 1)
                    footer
                }
                .frame(width: maxWidth)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Send text")
                    .font(AdminTheme.fontAdminSans(size: 10, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(AdminTheme.stone500)
                    .textCase(.uppercase)
                Text(copy.title)
                    .font(AdminTheme.fontAdminSerif(size: 22))
                    .foregroundStyle(AdminTheme.stone900)
            }
            Spacer(minLength: 8)
            Button {
                if !isSending { onClose() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 28, height: 28)
                    .background(AdminTheme.stone100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSending)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bodyCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(clientName.isEmpty ? "This client" : clientName)
                    .font(AdminTheme.fontAdminSans(size: 15, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                Text(displayPhone)
                    .font(AdminTheme.fontAdminSans(size: 12))
                    .foregroundStyle(AdminTheme.stone500)
            }
            Text(copy.body)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone600)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(errorMessage)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(Color.semanticRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if didSend {
                Text("Text sent.")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.confirmedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()
            Button {
                if !isSending { onClose() }
            } label: {
                Text(didSend ? "Done" : "Cancel")
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AdminTheme.stone600)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(
                        Capsule().stroke(AdminTheme.stone200, lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSending)

            if !didSend {
                Button {
                    Task { await send() }
                } label: {
                    HStack(spacing: 6) {
                        if isSending {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        }
                        Text(isSending ? "Sending…" : "Send text")
                    }
                    .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AdminTheme.stone900)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var copy: (title: String, body: String) {
        switch kind {
        case .consentRequest:
            return (
                "Send consent text?",
                "They will get the consent form link by text, with the usual rates and STOP / HELP footer."
            )
        case .reviewRequest:
            return (
                "Send review text?",
                "They will get a general Google review request by text — no service name — with the usual rates and STOP / HELP footer. “Ask after next visit” will turn off so a scheduled send does not go out too."
            )
        }
    }

    private var displayPhone: String {
        if clientPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Unknown number"
        }
        return clientPhone
    }

    @MainActor
    private func send() async {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let response = try await AdminAPIClient.shared.sendManualClientSms(
                id: clientId,
                kind: kind
            )
            if response.ok == false {
                errorMessage = response.message
                    ?? response.error
                    ?? "Could not send this text."
                return
            }
            didSend = true
            onSent(kind)
        } catch {
            errorMessage = AdminAPIResponseParser.userFacingMessage(
                from: error,
                fallback: "Could not send this text."
            )
        }
    }
}
