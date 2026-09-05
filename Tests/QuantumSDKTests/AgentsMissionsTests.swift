import XCTest
@testable import QuantumSDK

/// Mission request keys (routes_missions.go `MissionRequest`), the Firestore
/// map shapes the list/get routes return, and the SSE payloads
/// `handleMissions` writes.
final class AgentsMissionsTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Requests

    func testMissionRequestCarriesOnlyGatewayFields() throws {
        let request = MissionRequest(
            goal: "ship it",
            strategy: "codegen",
            conductorTier: "cheap",
            workers: ["coder": MissionWorker(model: "m", tier: "mid", escalateTo: "senior", maxRetries: 2)],
            buildCommand: "cargo build",
            workspacePath: "proj"
        )
        let json = try encodeToObject(request)
        XCTAssertEqual(json["goal"] as? String, "ship it")
        XCTAssertEqual(json["strategy"] as? String, "codegen")
        XCTAssertEqual(json["conductor_tier"] as? String, "cheap")
        XCTAssertEqual(json["workspace_path"] as? String, "proj")
        XCTAssertEqual(json["build_command"] as? String, "cargo build")
        let coder = try XCTUnwrap((json["workers"] as? [String: Any])?["coder"] as? [String: Any])
        XCTAssertEqual(coder["escalate_to"] as? String, "senior")
        XCTAssertEqual(coder["max_retries"] as? Int, 2)
        XCTAssertNil(json["auto_plan"])
        XCTAssertNil(json["worker_model"])
        XCTAssertNil(json["capabilities"])
        XCTAssertEqual(Set(json.keys), ["goal", "strategy", "conductor_tier", "workers", "build_command", "workspace_path"])
    }

    func testWorkersEncodeAsAMapKeyedByName() throws {
        let json = try encodeToObject(MissionCreateRequest(
            goal: "g",
            conductorTier: "expensive",
            workers: ["reader": MissionWorkerDetail(model: "m", tier: "cheap")]
        ))
        let workers = try XCTUnwrap(json["workers"] as? [String: Any])
        XCTAssertEqual((workers["reader"] as? [String: Any])?["tier"] as? String, "cheap")
        XCTAssertEqual(json["conductor_tier"] as? String, "expensive")
        XCTAssertEqual(Set(json.keys), ["goal", "conductor_tier", "workers"])
    }

    func testPlanUpdateSendsOnlyTheFieldsTheRouteApplies() throws {
        let update = MissionPlanUpdate(
            tasks: [["name": AnyCodable("write tests")]],
            maxSteps: 30,
            context: "prefer tokio"
        )
        let json = try encodeToObject(update)
        XCTAssertEqual(((json["tasks"] as? [[String: Any]])?.first)?["name"] as? String, "write tests")
        XCTAssertEqual(json["max_steps"] as? Int, 30)
        XCTAssertEqual(json["context"] as? String, "prefer tokio")
        XCTAssertNil(json["workers"])
        XCTAssertNil(json["system_prompt"])
        XCTAssertEqual(Set(json.keys), ["tasks", "max_steps", "context"])
    }

    // MARK: - Responses

    func testListRowWithoutTasksOrApprovedDecodes() throws {
        // routes_missions_crud.go handleMissionList: doc.Data() + id, no tasks key.
        let fixture = """
        {"missions":[{"id":"m1","user_id":"u1","goal":"g","strategy":"wave",
          "conductor_model":"claude-sonnet-4-6","status":"running",
          "created_at":"2026-01-01T00:00:00Z","cost_ticks":0,"total_steps":0,
          "session_id":"s1"}]}
        """
        let response = try JSONDecoder().decode(MissionListResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(response.missions.count, 1)
        XCTAssertTrue(response.missions[0].tasks.isEmpty)
        XCTAssertFalse(response.missions[0].approved)
        XCTAssertEqual(response.missions[0].status, "running")
    }

    func testListDecodesNullMissions() throws {
        let response = try JSONDecoder().decode(MissionListResponse.self, from: Data(#"{"missions":null}"#.utf8))
        XCTAssertTrue(response.missions.isEmpty)
    }

    func testGetDecodesExecutorTasksWithoutTokenCounts() throws {
        // Executor task docs carry name/status/step/created_at[/result/worker/model].
        let fixture = """
        {"id":"m1","goal":"g","status":"completed","cost_ticks":42,
         "tasks":[{"id":"task_001","name":"task_001","status":"task_completed","step":3,
                   "result":"done","worker":"coder","model":"m"}]}
        """
        let detail = try JSONDecoder().decode(MissionDetail.self, from: Data(fixture.utf8))
        XCTAssertEqual(detail.costTicks, 42)
        XCTAssertEqual(detail.tasks[0].step, 3)
        XCTAssertEqual(detail.tasks[0].tokensIn, 0)
        XCTAssertEqual(detail.tasks[0].tokensOut, 0)
        XCTAssertFalse(detail.approved)
    }

    func testRetryResponseDecodesTheHandlerShape() throws {
        let fixture = """
        {"mission_id":"m1","task_id":"task_002","status":"task_completed",
         "result":"fn main() {}","model":"claude-sonnet-4-6"}
        """
        let response = try JSONDecoder().decode(MissionRetryResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(response.taskId, "task_002")
        XCTAssertEqual(response.result, "fn main() {}")
        XCTAssertEqual(response.model, "claude-sonnet-4-6")
    }

    func testStatusResponseDecodesTheCancelShape() throws {
        let response = try JSONDecoder().decode(
            MissionStatusResponse.self,
            from: Data(#"{"mission_id":"m1","status":"cancelled","cancellation_cost":0.04}"#.utf8)
        )
        XCTAssertEqual(response.status, "cancelled")
        XCTAssertEqual(response.cancellationCost, 0.04)
        XCTAssertNil(response.updated)
    }

    // MARK: - Stream events

    func testMissionCompletedCostDecodesTheTokenCountObjects() throws {
        // routes_missions.go: cost.cheap = agent.TokenCount{Prompt, Completion} (no json tags).
        let payload = """
        {"type":"mission_completed","content":"final answer",
         "cost":{"cheap":{"Prompt":10,"Completion":4},"mid":{"Prompt":0,"Completion":0},"expensive":{"Prompt":7,"Completion":9}},
         "total_steps":3,"duration_ms":1234}
        """
        let event = QuantumClient.parseMissionStreamEvent(Data(payload.utf8))
        XCTAssertEqual(event.type, "mission_completed")
        XCTAssertFalse(event.done, "the stream continues until [DONE] so usage is delivered")
        XCTAssertEqual(event.content, "final answer")
        XCTAssertEqual(event.cost?.cheap?.prompt, 10)
        XCTAssertEqual(event.cost?.expensive?.completion, 9)
        XCTAssertEqual(event.totalSteps, 3)
        XCTAssertEqual(event.durationMs, 1234)
        XCTAssertEqual(event.raw["total_steps"]?.value as? Int, 3)
    }

    func testCodegenCompletedCarriesItsOwnKeys() {
        let payload = """
        {"type":"mission_completed","strategy":"codegen","workspace_path":"proj",
         "files_generated":4,"files_failed":1,"build_passed":true,"fix_iterations":2,"duration_ms":10}
        """
        let event = QuantumClient.parseMissionStreamEvent(Data(payload.utf8))
        XCTAssertEqual(event.strategy, "codegen")
        XCTAssertEqual(event.filesFailed, 1)
        XCTAssertEqual(event.fixIterations, 2)
        XCTAssertEqual(event.buildPassed, true)
        XCTAssertNil(event.content)
    }

    func testStepDetailReadsTheDurationKey() {
        let payload = #"{"type":"step_detail","step":2,"role":"conductor","tier":"expensive","duration":850,"delegated":false}"#
        let event = QuantumClient.parseMissionStreamEvent(Data(payload.utf8))
        XCTAssertEqual(event.durationMs, 850)
        XCTAssertEqual(event.role, "conductor")
    }

    func testMissionStartedClampFieldsAndWorkers() {
        let payload = """
        {"type":"mission_started","session_id":"s1","conductor":"m","strategy":"wave",
         "workers":{"coder":{"model":"m","tier":"mid"}},"max_steps":50,
         "max_steps_requested":80,"max_steps_clamped_to_ceiling":50}
        """
        let event = QuantumClient.parseMissionStreamEvent(Data(payload.utf8))
        XCTAssertEqual(event.workers?["coder"]?.tier, "mid")
        XCTAssertEqual(event.maxSteps, 50)
        XCTAssertEqual(event.maxStepsRequested, 80)
        XCTAssertEqual(event.maxStepsClampedToCeiling, 50)
    }

    func testMissionFailedReasonComesFromMessage() {
        let event = QuantumClient.parseMissionStreamEvent(Data(#"{"type":"mission_failed","message":"budget exhausted"}"#.utf8))
        XCTAssertEqual(event.error, "budget exhausted")
        XCTAssertFalse(event.done)
    }

    func testBudgetHaltAndUnknownEventsKeepTheirPayload() {
        let halt = QuantumClient.parseMissionStreamEvent(Data(
            #"{"type":"mission_budget_exhausted","message":"halted","steps_completed":4,"max_steps_target":25}"#.utf8
        ))
        XCTAssertEqual(halt.stepsCompleted, 4)
        XCTAssertEqual(halt.maxStepsTarget, 25)
        XCTAssertEqual(halt.message, "halted")

        let wave = QuantumClient.parseMissionStreamEvent(Data(
            #"{"type":"wave_started","mission_id":"m1","message":"wave 1","wave":1}"#.utf8
        ))
        XCTAssertEqual(wave.type, "wave_started")
        XCTAssertEqual(wave.missionId, "m1")
        XCTAssertEqual(wave.raw["wave"]?.value as? Int, 1)
    }

    func testUnparsablePayloadBecomesAnErrorEvent() {
        let event = QuantumClient.parseMissionStreamEvent(Data("[1,2]".utf8))
        XCTAssertEqual(event.type, "error")
        XCTAssertTrue(event.error?.hasPrefix("parse SSE: ") ?? false)
        XCTAssertFalse(event.transport)
    }
}
