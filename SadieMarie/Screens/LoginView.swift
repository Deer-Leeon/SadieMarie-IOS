import SwiftUI
import ClerkKit

/// Sign-in screen for the Sadie Marie admin app.
///
/// Uses a custom email + password form (not ClerkKitUI's `AuthView`) because
/// our Clerk instance uses password sign-in with email identification while
/// the email *attribute* is disabled — `AuthView` would render an empty form.
///
/// When Clerk requires MFA, we continue in-app: send the verification code
/// (email/SMS) or accept a TOTP / backup code, then complete sign-in.
struct LoginView: View {
    @Environment(Clerk.self) private var clerk

    @State private var step: Step = .credentials

    @State private var email = ""
    @State private var password = ""
    @State private var verificationCode = ""

    @State private var pendingSignIn: SignIn?
    @State private var selectedFactor: Factor?
    @State private var availableFactors: [Factor] = []
    @State private var codeDeliverySent = false

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private enum Step {
        case credentials
        case secondFactor
    }

    private var canSubmitCredentials: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !isSubmitting
    }

    private var canSubmitVerificationCode: Bool {
        !verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    private var usesDigitCodeEntry: Bool {
        switch selectedFactor?.strategy {
        case .emailCode, .phoneCode, .totp:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            AdminTheme.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    AdminAuthBrandHeader()
                        .padding(.top, 48)

                    Group {
                        switch step {
                        case .credentials:
                            credentialsCard
                        case .secondFactor:
                            secondFactorCard
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(.horizontal, AdminTheme.Spacing.listHorizontal)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.22), value: step)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.light)
        .tint(AdminTheme.stone900)
    }

    // MARK: - Credentials

    private var credentialsCard: some View {
        AdminAuthCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sign in")
                    .font(AdminTheme.fontAdminSerif(size: 28))
                    .foregroundStyle(AdminTheme.stone900)

                Text("Use the same admin email and password as the web portal.")
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone500)
            }

            VStack(spacing: 16) {
                AdminAuthField(
                    title: "Email",
                    placeholder: "you@example.com",
                    text: $email,
                    isSecure: false
                )
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                AdminAuthField(
                    title: "Password",
                    placeholder: "Enter your password",
                    text: $password,
                    isSecure: true
                )
                .textContentType(.password)
            }

            adminErrorBanner

            AdminAuthPrimaryButton(
                title: isSubmitting ? "Signing in…" : "Sign In",
                isLoading: isSubmitting,
                isEnabled: canSubmitCredentials
            ) {
                Task { await signInWithCredentials() }
            }
        }
    }

    // MARK: - Second factor (MFA)

    private var secondFactorCard: some View {
        AdminAuthCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(secondFactorTitle)
                    .font(AdminTheme.fontAdminSerif(size: 28))
                    .foregroundStyle(AdminTheme.stone900)

                Text(secondFactorSubtitle)
                    .font(AdminTheme.fontAdminSans(size: 13))
                    .foregroundStyle(AdminTheme.stone500)

                if let identifier = selectedFactor?.safeIdentifier, !identifier.isEmpty {
                    Text(identifier)
                        .font(AdminTheme.fontAdminSans(size: 13, weight: .medium))
                        .foregroundStyle(AdminTheme.stone700)
                        .padding(.top, 2)
                }
            }

            if availableFactors.count > 1 {
                factorPicker
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Verification code")
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)

                if usesDigitCodeEntry {
                    AdminVerificationCodeInput(code: $verificationCode, digitCount: 6)
                } else {
                    AdminAuthField(
                        title: "Code",
                        placeholder: "Enter your backup code",
                        text: $verificationCode,
                        isSecure: false,
                        showsTitle: false
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
            }

            if canResendCode {
                Button {
                    Task { await sendVerificationCode() }
                } label: {
                    Text(codeDeliverySent ? "Resend code" : "Send code")
                        .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                        .foregroundStyle(AdminTheme.stone900)
                        .underline(codeDeliverySent)
                }
                .disabled(isSubmitting)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            adminErrorBanner

            AdminAuthPrimaryButton(
                title: isSubmitting ? "Verifying…" : "Verify",
                isLoading: isSubmitting,
                isEnabled: canSubmitVerificationCode
            ) {
                Task { await verifySecondFactor() }
            }

            Button {
                resetToCredentials()
            } label: {
                Text("Back to sign in")
                    .font(AdminTheme.fontAdminSans(size: 14, weight: .medium))
                    .foregroundStyle(AdminTheme.stone600)
                    .frame(maxWidth: .infinity)
            }
            .disabled(isSubmitting)
        }
        .task(id: selectedFactor?.strategy) {
            await sendVerificationCodeIfNeeded()
        }
    }

    private var factorPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Verification method")
                .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                .foregroundStyle(AdminTheme.stone700)

            Picker("Verification method", selection: $selectedFactor) {
                ForEach(availableFactors, id: \.self) { factor in
                    Text(label(for: factor)).tag(Optional(factor))
                }
            }
            .pickerStyle(.menu)
            .font(AdminTheme.fontAdminSans(size: 15))
            .foregroundStyle(AdminTheme.stone900)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
            .onChange(of: selectedFactor) { _, _ in
                verificationCode = ""
                codeDeliverySent = false
                errorMessage = nil
            }
        }
    }

    @ViewBuilder
    private var adminErrorBanner: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(AdminTheme.fontAdminSans(size: 13))
                .foregroundStyle(Color.semanticRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.semanticRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var secondFactorTitle: String {
        switch selectedFactor?.strategy {
        case .emailCode:
            return "Check your email"
        case .phoneCode:
            return "Check your phone"
        case .totp:
            return "Authenticator app"
        case .backupCode:
            return "Backup code"
        default:
            return "Two-step verification"
        }
    }

    private var secondFactorSubtitle: String {
        switch selectedFactor?.strategy {
        case .emailCode:
            return codeDeliverySent
                ? "Enter the code we sent to your email."
                : "We'll send a verification code to your email."
        case .phoneCode:
            return codeDeliverySent
                ? "Enter the code we sent via SMS."
                : "We'll send a verification code to your phone."
        case .totp:
            return "Enter the 6-digit code from your authenticator app."
        case .backupCode:
            return "Enter one of your backup codes."
        default:
            return "Enter your verification code to finish signing in."
        }
    }

    private var canResendCode: Bool {
        switch selectedFactor?.strategy {
        case .emailCode, .phoneCode:
            return true
        default:
            return false
        }
    }

    // MARK: - Actions

    @MainActor
    private func signInWithCredentials() async {
        guard canSubmitCredentials else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let signIn = try await clerk.auth.signInWithPassword(
                identifier: trimmedEmail,
                password: password
            )
            try await handleSignInResult(signIn, email: trimmedEmail)
        } catch {
            AppLogger.authError("Clerk sign-in failed: \(error.localizedDescription)")
            errorMessage = friendlyMessage(for: error)
        }
    }

    @MainActor
    private func handleSignInResult(_ signIn: SignIn, email: String) async throws {
        switch signIn.status {
        case .complete:
            AppLogger.authInfo("Clerk sign-in complete for \(email).")

        case .needsSecondFactor:
            beginSecondFactor(with: signIn)

        case .needsNewPassword:
            errorMessage = "Your password must be reset before you can sign in. Use the web portal to set a new password."

        case .needsClientTrust:
            errorMessage = "Additional verification is required. Please try again."

        case .needsFirstFactor, .needsIdentifier:
            errorMessage = "Sign-in could not be completed. Check your email and password."

        case .unknown(let value):
            errorMessage = "Unexpected sign-in state (\(value)). Please try again."
        }
    }

    @MainActor
    private func beginSecondFactor(with signIn: SignIn) {
        let factors = signIn.supportedSecondFactors ?? []
        guard !factors.isEmpty else {
            errorMessage = "Two-factor authentication is required, but no verification method was returned. Try signing in on the web portal once, then retry."
            return
        }

        pendingSignIn = signIn
        availableFactors = factors
        selectedFactor = preferredSecondFactor(from: factors)
        verificationCode = ""
        codeDeliverySent = false
        errorMessage = nil
        step = .secondFactor
    }

    @MainActor
    private func sendVerificationCodeIfNeeded() async {
        guard !codeDeliverySent else { return }
        await sendVerificationCode()
    }

    @MainActor
    private func sendVerificationCode() async {
        guard let factor = selectedFactor else { return }
        guard requiresCodeDelivery(for: factor.strategy) else {
            codeDeliverySent = true
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let signIn = try await refreshedSignIn()
            pendingSignIn = try await deliverVerificationCode(signIn: signIn, factor: factor)
            codeDeliverySent = true
        } catch {
            AppLogger.authError("Failed to send MFA code: \(error.localizedDescription)")
            errorMessage = friendlyMessage(for: error)
        }
    }

    @MainActor
    private func verifySecondFactor() async {
        guard canSubmitVerificationCode, let factor = selectedFactor else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let code = verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var signIn = try await refreshedSignIn()
            signIn = try await verifyCode(code, signIn: signIn, factor: factor)
            try await handleSignInResult(signIn, email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            AppLogger.authError("MFA verification failed: \(error.localizedDescription)")
            errorMessage = friendlyMessage(for: error)
        }
    }

    @MainActor
    private func refreshedSignIn() async throws -> SignIn {
        if let pendingSignIn {
            return pendingSignIn
        }
        if let current = clerk.auth.currentSignIn {
            pendingSignIn = current
            return current
        }
        throw ClerkClientError(message: "Sign-in session expired. Please sign in again.")
    }

    @MainActor
    private func deliverVerificationCode(signIn: SignIn, factor: Factor) async throws -> SignIn {
        switch factor.strategy {
        case .emailCode:
            return try await signIn.sendMfaEmailCode(emailAddressId: factor.emailAddressId)
        case .phoneCode:
            return try await signIn.sendMfaPhoneCode(phoneNumberId: factor.phoneNumberId)
        case .totp, .backupCode:
            return signIn
        default:
            throw ClerkClientError(message: "This verification method isn't supported in the app yet.")
        }
    }

    @MainActor
    private func verifyCode(_ code: String, signIn: SignIn, factor: Factor) async throws -> SignIn {
        let mfaType: SignIn.MfaType
        switch factor.strategy {
        case .emailCode:
            mfaType = .emailCode
        case .phoneCode:
            mfaType = .phoneCode
        case .totp:
            mfaType = .totp
        case .backupCode:
            mfaType = .backupCode
        default:
            throw ClerkClientError(message: "This verification method isn't supported in the app yet.")
        }
        return try await signIn.verifyMfaCode(code, type: mfaType)
    }

    @MainActor
    private func resetToCredentials() {
        step = .credentials
        pendingSignIn = nil
        selectedFactor = nil
        availableFactors = []
        verificationCode = ""
        codeDeliverySent = false
        errorMessage = nil
    }

    // MARK: - Helpers

    private func preferredSecondFactor(from factors: [Factor]) -> Factor {
        if let primary = factors.first(where: { $0.primary == true }) {
            return primary
        }
        let priority: [FactorStrategy] = [.totp, .phoneCode, .emailCode, .backupCode]
        for strategy in priority {
            if let match = factors.first(where: { $0.strategy == strategy }) {
                return match
            }
        }
        return factors[0]
    }

    private func requiresCodeDelivery(for strategy: FactorStrategy) -> Bool {
        switch strategy {
        case .emailCode, .phoneCode:
            return true
        default:
            return false
        }
    }

    private func label(for factor: Factor) -> String {
        switch factor.strategy {
        case .emailCode:
            return "Email code"
        case .phoneCode:
            return "SMS code"
        case .totp:
            return "Authenticator app"
        case .backupCode:
            return "Backup code"
        default:
            return factor.strategy.rawValue
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let combined = "\(error.localizedDescription)\n\(String(reflecting: error))".lowercased()

        if combined.contains("invalid_credentials")
            || combined.contains("password is incorrect")
            || combined.contains("identifier is invalid") {
            return "Email or password is incorrect."
        }
        if combined.contains("form_code_incorrect") || combined.contains("incorrect code") {
            return "That verification code is incorrect. Please try again."
        }
        if combined.contains("rate_limit") || combined.contains("too many") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if combined.contains("network") || combined.contains("offline") {
            return "Couldn't reach the server. Check your connection and try again."
        }

        return error.localizedDescription
    }
}

// MARK: - Admin auth chrome

private struct AdminAuthBrandHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Sadie Marie")
                .font(AdminTheme.fontAdminSerif(size: 32))
                .foregroundStyle(AdminTheme.stone900)

            Text("Admin")
                .font(AdminTheme.fontAdminSans(size: 11, weight: .medium))
                .tracking(2.8)
                .textCase(.uppercase)
                .foregroundStyle(AdminTheme.stone500)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AdminAuthCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            content()
        }
        .padding(AdminTheme.Spacing.listHorizontal)
        .background(AdminTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AdminTheme.Radius.card)
                .stroke(AdminTheme.stone200, lineWidth: 1)
        )
        .shadow(
            color: AdminTheme.cardShadow,
            radius: AdminTheme.Layout.cardShadowRadius,
            y: AdminTheme.Layout.cardShadowY
        )
    }
}

private struct AdminAuthField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsTitle {
                Text(title)
                    .font(AdminTheme.fontAdminSans(size: 12, weight: .medium))
                    .foregroundStyle(AdminTheme.stone700)
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(AdminTheme.fontAdminSans(size: 15))
            .foregroundStyle(AdminTheme.stone900)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AdminTheme.stone100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdminTheme.stone200, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// Six-box OTP entry — text field sits on the active box so the caret tracks the next digit.
private struct AdminVerificationCodeInput: View {
    @Binding var code: String
    let digitCount: Int

    private let boxSpacing: CGFloat = 8
    private let boxHeight: CGFloat = 52

    @FocusState private var isFocused: Bool

    /// Index of the box that receives the next digit (or last box when full).
    private var activeIndex: Int {
        min(code.count, digitCount - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let boxWidth = boxWidth(in: geometry.size.width)
            let fieldOffsetX = CGFloat(activeIndex) * (boxWidth + boxSpacing)

            ZStack(alignment: .leading) {
                HStack(spacing: boxSpacing) {
                    ForEach(0..<digitCount, id: \.self) { index in
                        digitBox(at: index, width: boxWidth)
                    }
                }
                .allowsHitTesting(false)

                TextField("", text: $code)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isFocused)
                    .font(AdminTheme.fontAdminSerif(size: 22))
                    .foregroundStyle(Color.clear)
                    .accentColor(AdminTheme.stone900)
                    .tint(AdminTheme.stone900)
                    .multilineTextAlignment(.center)
                    .frame(width: boxWidth, height: boxHeight)
                    .offset(x: fieldOffsetX)
                    .accessibilityLabel("Verification code")
            }
            .frame(width: geometry.size.width, height: boxHeight, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
        }
        .frame(height: boxHeight)
        .animation(.easeInOut(duration: 0.15), value: activeIndex)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
        .onChange(of: code) { _, newValue in
            let digits = newValue.filter(\.isNumber)
            let trimmed = String(digits.prefix(digitCount))
            if trimmed != newValue {
                code = trimmed
            }
        }
    }

    private func boxWidth(in totalWidth: CGFloat) -> CGFloat {
        let totalSpacing = boxSpacing * CGFloat(digitCount - 1)
        return max(0, (totalWidth - totalSpacing) / CGFloat(digitCount))
    }

    private func digitBox(at index: Int, width: CGFloat) -> some View {
        let character = digitCharacter(at: index)
        let isActive = isFocused && index == activeIndex

        return Text(character)
            .font(AdminTheme.fontAdminSerif(size: 22))
            .foregroundStyle(AdminTheme.stone900)
            .frame(width: width, height: boxHeight)
            .background(AdminTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isActive ? AdminTheme.stone900 : AdminTheme.stone200,
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
    }

    private func digitCharacter(at index: Int) -> String {
        guard index < code.count else { return " " }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }
}

private struct AdminAuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(AdminTheme.cardFill)
                } else {
                    Text(title)
                        .font(AdminTheme.fontAdminSans(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isEnabled ? AdminTheme.cardFill : AdminTheme.stone600)
            .background(isEnabled ? AdminTheme.stone900 : AdminTheme.stone200)
            .clipShape(RoundedRectangle(cornerRadius: AdminTheme.Radius.card))
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

#Preview {
    LoginView()
}
