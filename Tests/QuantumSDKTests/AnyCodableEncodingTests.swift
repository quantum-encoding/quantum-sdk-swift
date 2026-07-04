// AnyCodableEncodingTests — regression coverage for nested-box encoding.
//
// createJob(type:params:) wraps its `[String: AnyCodable]` params in another
// AnyCodable; the dict branch of encode() then re-boxes each value, producing
// AnyCodable(AnyCodable(x)). Before the nested-unwrap case, that matched no
// branch and threw EncodingError ("The data couldn't be written…"), breaking
// every jobs-API call that carried params (e.g. 3D generation).
//
// Copyright (c) 2025-2026 Quantum Encoding Ltd

import XCTest
@testable import QuantumSDK

final class AnyCodableEncodingTests: XCTestCase {

    /// The exact shape createJob produces: AnyCodable([String: AnyCodable]).
    func testNestedAnyCodableDictionaryEncodes() throws {
        let params: [String: AnyCodable] = [
            "model": AnyCodable("meshy-6"),
            "image_url": AnyCodable("data:image/png;base64,AAAA"),
            "enable_pbr": AnyCodable(true),
            "topology": AnyCodable("triangle"),
            "target_polycount": AnyCodable(30000),
        ]
        let data = try JSONEncoder().encode(AnyCodable(params))
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(decoded["model"] as? String, "meshy-6")
        XCTAssertEqual(decoded["enable_pbr"] as? Bool, true)
        XCTAssertEqual(decoded["target_polycount"] as? Int, 30000)
    }

    /// Deeper nesting (arrays of boxed dicts) must also survive.
    func testDeeplyNestedBoxesEncode() throws {
        let inner: [String: AnyCodable] = ["voice": AnyCodable("alloy")]
        let value = AnyCodable([
            "turns": AnyCodable([AnyCodable(inner), AnyCodable(inner)]),
        ] as [String: AnyCodable])
        let data = try JSONEncoder().encode(value)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let turns = try XCTUnwrap(decoded["turns"] as? [[String: Any]])
        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(turns[0]["voice"] as? String, "alloy")
    }
}
