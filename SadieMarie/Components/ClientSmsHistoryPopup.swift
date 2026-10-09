import SwiftUI

/// Centered overlay of every outbound text sent to this client.
struct ClientSmsHistoryPopup: View {
    let clientId: String
    let clientName: String
    let clientPhone: String
    var onClose: () -> Void

    @State private var messages: [ClientSmsMessage] = []
    @State private var phoneLabel: String
    @State private var nextBefore: String?
    @State private var isLoading = false
    @State private var isLoadingOlder = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    init(clientId: String, clientName: String, clientPhone: String, onClose: @escaping () -> Void) {
        self.clientId = clientId
        self.clientName = clientName
        self.clientPhone = clientPhone
        self.onClose = onClose
        _phoneLabel = State(initialValue: clientPhone)
    }

    var body: some View {
        GeometryReader { geo in
            let maxWidth = min(geo.size.width - 40, 520)
            let maxHeight = max(geo.size.height - 48, 200)

            ZStack {
                ZStack {
                    AdminTheme.cream.opacity(0.72)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .light)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Dismiss text history")

                VStack(spacing: 0) {
                    header

                    Rectangle()
                        .fill(AdminTheme.stone200)
                        .frame(height: 1)

                    content
                        .frame(maxHeight: maxHeight - 56)
                }
                .frame(width: maxWidth)
                .background(AdminTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task {
            await load(before: nil, append: false)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Text history")
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
                Text(clientName)
                    .font(AdminTheme.fontAdminSerif(size: 20))
                    .foregroundStyle(AdminTheme.stone900)
                HStack(spacing: 4) {
                    Text("Sent to")
                        .font(AdminTheme.fontAdminSans(size: 13))
                        .foregroundStyle(AdminTheme.stone600)
                    CopyablePhoneButton(
                        phone: phoneLabel.isEmpty ? clientPhone : phoneLabel,
                        font: AdminTheme.fontAdminSans(size: 13),
                        color: AdminTheme.stone600,
                        icon: nil
                    )
                }
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdminTheme.stone700)
                    .frame(width: 28, height: 28)
                    .background(AdminTheme.stone100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && !didLoad {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(AdminTheme.stone900)
                Text("Loading texts, including older ones from Twilio…")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone600)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(Color.semanticRed)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await load(before: nil, append: false) }
                }
                .font(AdminTheme.fontAdminSans(size: 13, weight: .semibold))
                .foregroundStyle(AdminTheme.stone900)
            }
            .padding(24)
        } else if messages.isEmpty {
            Text("No texts found for this client. New sends will show up here.")
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone600)
                .multilineTextAlignment(.center)
                .padding(24)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { row in
                        messageRow(row)
                    }
                    if nextBefore != nil {
                        Button {
                            Task { await load(before: nextBefore, append: true) }
                        } label: {
                            Text(isLoadingOlder ? "Loading…" : "Load older")
                                .font(AdminTheme.fontAdminSans(size: 12, weight: .semibold))
                                .foregroundStyle(AdminTheme.stone700)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoadingOlder)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
    }

    private func messageRow(_ row: ClientSmsMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title)
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone900)
                Spacer(minLength: 8)
                Text(formattedTimestamp(row.createdAt))
                    .font(AdminTheme.fontAdminSans(size: 11))
                    .foregroundStyle(AdminTheme.stone500)
                    .monospacedDigit()
            }
            CopyablePhoneButton(
                phone: row.to,
                font: AdminTheme.fontAdminSans(size: 11, weight: .medium),
                color: AdminTheme.stone500,
                icon: nil
            )
            Text(row.body)
                .font(AdminTheme.fontAdminSans(size: 14))
                .foregroundStyle(AdminTheme.stone700)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AdminTheme.cream)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AdminTheme.stone200, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formattedTimestamp(_ iso: String) -> String {
        guard let date = Client.parseISO8601(iso) else { return iso }
        return Self.stampFormatter.string(from: date)
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Denver")
        formatter.dateFormat = "MMM d, yyyy, h:mm a"
        return formatter
    }()

    @MainActor
    private func load(before: String?, append: Bool) async {
        if append {
            isLoadingOlder = true
        } else {
            isLoading = true
            errorMessage = nil
        }
        defer {
            isLoading = false
            isLoadingOlder = false
        }
        do {
            let response = try await AdminAPIClient.shared.fetchClientSmsMessages(
                id: clientId,
                before: before
            )
            if let phone = response.phone, !phone.isEmpty {
                phoneLabel = Client(id: "sms", phone: phone).formattedPhone
            }
            if append {
                messages.append(contentsOf: response.messages)
            } else {
                messages = response.messages
            }
            nextBefore = response.nextBefore
            didLoad = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
