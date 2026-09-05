import XCTest
@testable import QuantumSDK

final class CoreErrorCodeTests: XCTestCase {

    func testCanonicalCodesMapToTheirOwnCases() {
        XCTAssertEqual(ErrorCode(wire: "KEY_ROTATED"), .keyRotated)
        XCTAssertEqual(ErrorCode(wire: "ACCOUNT_DELETED"), .accountDeleted)
        XCTAssertEqual(ErrorCode(wire: "APP_SCOPE_MISMATCH"), .appScopeMismatch)
        XCTAssertEqual(ErrorCode(wire: "FILE_MIME_UNSUPPORTED"), .fileMimeUnsupported)
        XCTAssertEqual(ErrorCode(wire: "NOT_FOUND"), .notFound)
        XCTAssertEqual(ErrorCode(wire: "PERMISSION_DENIED"), .permissionDenied)
        XCTAssertEqual(ErrorCode(wire: "INVALID_REQUEST"), .invalidRequest)
        XCTAssertEqual(ErrorCode(wire: "PROVIDER_FEATURE_DISALLOWED"), .providerFeatureDisallowed)
        XCTAssertEqual(ErrorCode(wire: "RATE_LIMITED_PER_KEY"), .rateLimitedPerKey)
        XCTAssertEqual(ErrorCode(wire: "INSUFFICIENT_BALANCE"), .insufficientBalance)
    }

    func testLegacyLowercaseTypesFoldOntoTheMatchingCase() {
        // writeError copies the lowercase `type` into `code`.
        XCTAssertEqual(ErrorCode(wire: "invalid_request"), .invalidRequest)
        XCTAssertEqual(ErrorCode(wire: "authentication_error"), .authenticationError)
        XCTAssertEqual(ErrorCode(wire: "invalid_key"), .keyNotFound)
        XCTAssertEqual(ErrorCode(wire: "invalid_state"), .invalidState)
        XCTAssertEqual(ErrorCode(wire: "forbidden"), .permissionDenied)
        XCTAssertEqual(ErrorCode(wire: "provider_error"), .providerError)
        XCTAssertEqual(ErrorCode(wire: "not_found"), .notFound)
        XCTAssertEqual(ErrorCode(wire: "internal_error"), .internalError)
        XCTAssertEqual(ErrorCode(wire: "rate_limit_exceeded"), .rateLimited)
    }

    func testUnknownAndEmptyStayUnknown() {
        XCTAssertEqual(ErrorCode(wire: ""), .unknown)
        XCTAssertEqual(ErrorCode(wire: "SOMETHING_NEW"), .unknown)
        let err = QuantumError.api(statusCode: 418, code: "teapot", message: "", requestId: nil)
        XCTAssertEqual(err.typedCode, .unknown)
        XCTAssertEqual(err.code, "teapot")
        XCTAssertEqual(QuantumError.cancelled.typedCode, .unknown)
    }

    func testBooleansReadStatusOrCode() {
        XCTAssertTrue(QuantumError.api(statusCode: 429, code: "x", message: "", requestId: nil).isRateLimit)
        XCTAssertTrue(QuantumError.api(statusCode: 200, code: "RATE_LIMITED_PER_IP", message: "", requestId: nil).isRateLimit)
        XCTAssertTrue(QuantumError.api(statusCode: 403, code: "forbidden", message: "", requestId: nil).isAuth)
        XCTAssertTrue(QuantumError.api(statusCode: 404, code: "not_found", message: "", requestId: nil).isNotFound)
        XCTAssertFalse(QuantumError.emptyResponse.isAuth)
    }

    func testDescriptionsCarryStatusCodeAndRequestId() {
        let err = QuantumError.api(statusCode: 402, code: "INSUFFICIENT_BALANCE", message: "no funds", requestId: "req_9")
        XCTAssertEqual(err.localizedDescription, "qai: 402 INSUFFICIENT_BALANCE: no funds (request_id=req_9)")
        XCTAssertEqual(err.requestId, "req_9")
    }

    func testEnvelopeParsing() {
        let nested = parseErrorEnvelope(Data(#"{"error":{"message":"m","type":"t","code":"C"}}"#.utf8))
        XCTAssertEqual(nested?.code, "C")
        XCTAssertEqual(nested?.message, "m")
        let typed = parseErrorEnvelope(Data(#"{"error":{"message":"m","type":"t"}}"#.utf8))
        XCTAssertEqual(typed?.code, "t")
        let flat = parseErrorEnvelope(Data(#"{"error":"invalid_request","message":"m"}"#.utf8))
        XCTAssertEqual(flat?.code, "invalid_request")
        XCTAssertNil(parseErrorEnvelope(Data("busy".utf8)))
        XCTAssertNil(parseErrorEnvelope(Data(#"{"ok":true}"#.utf8)))
    }
}
