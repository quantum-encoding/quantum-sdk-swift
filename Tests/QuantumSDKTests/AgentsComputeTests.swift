import XCTest
@testable import QuantumSDK

/// Compute rentals and model deployments against routes_compute.go and
/// compute/templates.go.
final class AgentsComputeTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testTemplateExposesTheBilledRateBesideTheCataloguePrice() throws {
        let fixture = """
        {"templates":[{"id":"h100-8x","label":"8x H100","description":"training",
          "category":"gpu","machine_type":"a3-highgpu-8g","vcpus":208,"memory_gb":1872,
          "gpu_type":"nvidia-h100-80gb","gpu_count":8,"vram_gb":640,"disk_size_gb":500,
          "hourly_usd":98.5,"spot_hourly_usd":41.2,"spot_allowed":true,"boot_time_secs":120,
          "available_zones":["us-central1-a"],"use_cases":["training"],"preinstalled":["cuda"],
          "name":"8x H100","gpu":"nvidia-h100-80gb","ram_gb":1872,"price_per_hour_usd":88.0,
          "zones":["us-central1-a"],"min_deposit_usd":200,"requires_approval":true}]}
        """
        let response = try JSONDecoder().decode(TemplatesResponse.self, from: Data(fixture.utf8))
        let template = response.templates[0]
        XCTAssertEqual(template.hourlyUsd, 98.5)
        XCTAssertEqual(template.spotHourlyUsd, 41.2)
        XCTAssertEqual(template.pricePerHourUsd, 88.0)
        XCTAssertEqual(template.requiresApproval, true)
        XCTAssertEqual(template.minDepositUsd, 200)
        XCTAssertEqual(template.zones, ["us-central1-a"])
    }

    func testConfirmFlagRidesTheQueryString() {
        XCTAssertEqual(QuantumClient.provisionPath(confirm: true), "/qai/v1/compute/provision?confirm=yes")
        XCTAssertEqual(QuantumClient.provisionPath(confirm: false), "/qai/v1/compute/provision")
    }

    func testProvisionRequestKeys() throws {
        let json = try encodeToObject(ProvisionRequest(template: "l4-1x", spot: true, autoTeardownMinutes: 60, sshPublicKey: "ssh-ed25519 AAAA"))
        XCTAssertEqual(json["template"] as? String, "l4-1x")
        XCTAssertEqual(json["spot"] as? Bool, true)
        XCTAssertEqual(json["auto_teardown_minutes"] as? Int, 60)
        XCTAssertEqual(json["ssh_public_key"] as? String, "ssh-ed25519 AAAA")
        XCTAssertNil(json["zone"])
        XCTAssertEqual(Set(json.keys), ["template", "spot", "auto_teardown_minutes", "ssh_public_key"])
    }

    func testProvisionResponseDecodesTheHandlerShape() throws {
        let fixture = """
        {"instance_id":"i1","status":"provisioning","zone":"us-central1-a",
         "machine_type":"g2-standard-4","gpu_type":"nvidia-l4","hourly_usd":1.25,
         "cost_usd":1.25,"external_ip":null,"estimated_boot_secs":60}
        """
        let response = try JSONDecoder().decode(ProvisionResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(response.instanceId, "i1")
        XCTAssertEqual(response.hourlyUsd, 1.25)
        XCTAssertNil(response.externalIp)
        XCTAssertEqual(response.estimatedBootSecs, 60)
    }

    func testInstanceListDecodesTheHandlerEntries() throws {
        let fixture = """
        {"instances":[{"instance_id":"i1","template":"l4-1x","status":"running",
          "zone":"us-central1-a","external_ip":"34.1.2.3","gpu_type":"nvidia-l4",
          "gpu_count":1,"hourly_usd":1.25,"cost_usd":2.5,"uptime_minutes":95,
          "auto_teardown_minutes":30,"last_active_at":"2026-01-01T01:00:00Z",
          "created_at":"2026-01-01T00:00:00Z"}]}
        """
        let response = try JSONDecoder().decode(InstancesResponse.self, from: Data(fixture.utf8))
        let instance = response.instances[0]
        XCTAssertEqual(instance.instanceId, "i1")
        XCTAssertEqual(instance.externalIp, "34.1.2.3")
        XCTAssertEqual(instance.hourlyUsd, 1.25)
        XCTAssertNil(instance.machineType)
        XCTAssertNil(instance.terminatedAt)

        let empty = try JSONDecoder().decode(InstancesResponse.self, from: Data(#"{"instances":null}"#.utf8))
        XCTAssertTrue(empty.instances.isEmpty)
    }

    func testSingleInstanceDecodesFlat() throws {
        let fixture = """
        {"instance_id":"i1","template":"l4-1x","status":"running","gcp_status":"RUNNING",
         "zone":"us-central1-a","machine_type":"g2-standard-4","external_ip":"34.1.2.3",
         "gpu_type":"nvidia-l4","gpu_count":1,"spot":false,"hourly_usd":1.25,"cost_usd":2.5,
         "uptime_minutes":95,"auto_teardown_minutes":30,"ssh_username":"cosmic",
         "last_active_at":"2026-01-01T01:00:00Z","created_at":"2026-01-01T00:00:00Z",
         "error_message":"","terminated_at":"2026-01-01T02:00:00Z"}
        """
        let instance = try JSONDecoder().decode(ComputeInstanceInfo.self, from: Data(fixture.utf8))
        XCTAssertEqual(instance.gcpStatus, "RUNNING")
        XCTAssertEqual(instance.sshUsername, "cosmic")
        XCTAssertEqual(instance.terminatedAt, "2026-01-01T02:00:00Z")
    }

    func testSSHKeyRequestSendsPublicKey() throws {
        let json = try encodeToObject(SSHKeyRequest(publicKey: "ssh-ed25519 AAAA"))
        XCTAssertEqual(json["public_key"] as? String, "ssh-ed25519 AAAA")
        XCTAssertNil(json["username"])
        XCTAssertNil(json["ssh_public_key"])
        XCTAssertEqual(Set(json.keys), ["public_key"])
    }

    // MARK: - Deployments

    func testKnownModelIdCarriesNoMachineSpec() throws {
        let json = try encodeToObject(DeployModelRequest(model: "nemotron-3-super-120b", durationHours: 4, isPublic: true))
        XCTAssertEqual(json["model"] as? String, "nemotron-3-super-120b")
        XCTAssertEqual(json["duration_hours"] as? Int, 4)
        XCTAssertEqual(json["public"] as? Bool, true)
        XCTAssertNil(json["machine_type"])
        XCTAssertNil(json["accelerator_type"])
        XCTAssertNil(json["confirmed"])
        XCTAssertEqual(Set(json.keys), ["model", "duration_hours", "public"])
    }

    func testExtendRequestKey() throws {
        XCTAssertEqual(try encodeToObject(ExtendDeploymentRequest(hours: 3))["hours"] as? Int, 3)
    }

    func testDeploymentMapsTheErrorKeyToErrorMessage() throws {
        let fixture = """
        {"id":"d1","user_id":"u1","model":"publishers/x/models/y",
         "status":"failed","error":"quota exhausted","cost_per_hour_usd":12.5}
        """
        let deployment = try JSONDecoder().decode(ModelDeployment.self, from: Data(fixture.utf8))
        XCTAssertEqual(deployment.errorMessage, "quota exhausted")
        XCTAssertEqual(deployment.status, "failed")
        XCTAssertNil(deployment.readyAt)
    }

    func testCatalogDecodesWithoutTheDynamicHalf() throws {
        let fixture = """
        {"verified_models":[{"id":"m1","name":"M1","machine_type":"a4-highgpu-8g",
                             "regions":null,"price_per_hour_usd":30.0}]}
        """
        let catalog = try JSONDecoder().decode(ComputeCatalogResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(catalog.verifiedModels.count, 1)
        XCTAssertTrue(catalog.verifiedModels[0].regions.isEmpty)
        XCTAssertNil(catalog.discoveredModels)
    }

    func testEstimateAndAcceptedShapes() throws {
        let estimate = try JSONDecoder().decode(DeployModelEstimate.self, from: Data("""
        {"cost_per_hour_usd":12.5,"total_estimate_usd":25,"total_ticks":250000000000,"duration_hours":2,
         "model_display_name":"M1","model":"publishers/x/models/y","machine_type":"a2","accelerator_type":"nvidia-a100",
         "accelerator_count":1,"region":"us-east1","note":"resubmit with confirmed:true to deploy"}
        """.utf8))
        XCTAssertEqual(estimate.totalTicks, 250_000_000_000)
        XCTAssertEqual(estimate.durationHours, 2)

        let accepted = try JSONDecoder().decode(DeployModelAccepted.self, from: Data("""
        {"deployment_id":"d1","status":"provisioning","model_display_name":"M1","cost_per_hour_usd":12.5,
         "total_cost_usd":25,"expires_at":"2026-01-01T02:00:00Z","operation":"op/1","note":"poll"}
        """.utf8))
        XCTAssertEqual(accepted.deploymentId, "d1")
        XCTAssertEqual(accepted.totalCostUsd, 25)
    }
}
