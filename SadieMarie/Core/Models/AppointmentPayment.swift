import Foundation

enum AppointmentPaymentKind: String, Codable, Hashable, Sendable {
    case servicePayment = "service_payment"
    case cash
    case complimentary
}

enum TerminalPaymentStatus: String, Codable, Hashable, Sendable {
    case pending
    case processing
    case succeeded
    case failed
    case canceled
}

struct AppointmentPaymentSummary: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let paymentKind: AppointmentPaymentKind
    let paymentIntentId: String?
    let readerId: String?
    let status: TerminalPaymentStatus
    let currency: String
    let baseAmountCents: Int
    let tipAmountCents: Int
    let totalAmountCents: Int
    let failureCode: String?
    let failureMessage: String?
    let note: String?
    let settledByEmail: String?
    let paidAt: String?

    var isSettled: Bool { status == .succeeded }
    var isActiveTerminalPayment: Bool {
        paymentKind == .servicePayment && (status == .pending || status == .processing)
    }
    var isRetryableTerminalPayment: Bool {
        paymentKind == .servicePayment && status == .failed
    }
    var canUndo: Bool {
        isSettled && (paymentKind == .cash || paymentKind == .complimentary)
    }
}

struct TerminalReaderSummary: Codable, Hashable, Sendable {
    let id: String?
    let label: String?
    let status: String?
    let actionStatus: String?
}

/// The Terminal endpoints use this envelope for both successful and
/// recoverable non-2xx responses. Keeping the payment snapshot lets the UI
/// resume an action instead of reducing every 409/502 to a generic alert.
struct TerminalPaymentAPIResponse: Codable, Hashable, Sendable {
    let payment: AppointmentPaymentSummary?
    let reader: TerminalReaderSummary?
    let error: String?
    let message: String?
}

struct SettlementAPIResponse: Codable, Hashable, Sendable {
    let payment: AppointmentPaymentSummary?
    let error: String?
    let message: String?
}

enum AppointmentSettlementMethod: String, Codable, Hashable, Sendable {
    case cash
    case complimentary
}

struct SettlementRequest: Encodable, Sendable {
    let method: AppointmentSettlementMethod
    let note: String?

    func encodedJSON() throws -> Data {
        try AdminRequestEncoder.encode(self)
    }
}

struct PaymentOperationResult: Hashable, Sendable {
    let response: TerminalPaymentAPIResponse
    let statusCode: Int

    var succeeded: Bool { (200..<300).contains(statusCode) }
}

struct SettlementOperationResult: Hashable, Sendable {
    let response: SettlementAPIResponse
    let statusCode: Int

    var succeeded: Bool { (200..<300).contains(statusCode) }
}
