import Foundation

// MARK: - Compute Template

/// A GPU compute template.
public struct ComputeTemplate: Codable, Sendable {
    /// Template ID.
    public var id: String

    /// Template name.
    public var name: String?

    /// GPU type description.
    public var gpu: String?

    /// Number of GPUs.
    public var gpuCount: Int?

    /// VRAM per GPU in GB.
    public var vramGb: Int?

    /// Number of virtual CPUs.
    public var vcpus: Int?

    /// RAM in GB.
    public var ramGb: Int?

    /// Price per hour in USD.
    public var pricePerHourUsd: Double?

    /// Available zones.
    public var zones: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, gpu, vcpus, zones
        case gpuCount = "gpu_count"
        case vramGb = "vram_gb"
        case ramGb = "ram_gb"
        case pricePerHourUsd = "price_per_hour_usd"
    }
}

/// Response from the `/qai/v1/compute/templates` endpoint.
public struct TemplatesResponse: Codable, Sendable {
    /// Available templates.
    public var templates: [ComputeTemplate]
}

// MARK: - Provision

/// Request body for the `/qai/v1/compute/provision` endpoint.
public struct ProvisionRequest: Codable, Sendable {
    /// Template ID to provision.
    public var template: String

    /// Preferred zone (e.g. "us-central1-a").
    public var zone: String?

    /// Use spot/preemptible pricing.
    public var spot: Bool?

    /// Auto-teardown after N minutes of inactivity.
    public var autoTeardownMinutes: Int?

    /// SSH public key for access.
    public var sshPublicKey: String?

    public init(template: String, zone: String? = nil, spot: Bool? = nil, autoTeardownMinutes: Int? = nil, sshPublicKey: String? = nil) {
        self.template = template
        self.zone = zone
        self.spot = spot
        self.autoTeardownMinutes = autoTeardownMinutes
        self.sshPublicKey = sshPublicKey
    }

    enum CodingKeys: String, CodingKey {
        case template, zone, spot
        case autoTeardownMinutes = "auto_teardown_minutes"
        case sshPublicKey = "ssh_public_key"
    }
}

/// Response from provisioning a compute instance.
public struct ProvisionResponse: Codable, Sendable {
    /// Instance ID.
    public var instanceId: String

    /// Current status.
    public var status: String

    /// Template that was provisioned.
    public var template: String?

    /// Zone the instance was placed in.
    public var zone: String?

    /// SSH connection address.
    public var sshAddress: String?

    /// Estimated price per hour.
    public var pricePerHourUsd: Double?

    enum CodingKeys: String, CodingKey {
        case status, template, zone
        case instanceId = "instance_id"
        case sshAddress = "ssh_address"
        case pricePerHourUsd = "price_per_hour_usd"
    }
}

// MARK: - Compute Instance

/// A running compute instance.
public struct ComputeInstance: Codable, Sendable {
    /// Instance identifier.
    public var id: String

    /// Current status (e.g. "running", "provisioning", "stopped").
    public var status: String

    /// Template used.
    public var template: String?

    /// Zone.
    public var zone: String?

    /// SSH connection address.
    public var sshAddress: String?

    /// Creation timestamp.
    public var createdAt: String?

    /// Price per hour.
    public var pricePerHourUsd: Double?

    /// Auto-teardown setting in minutes.
    public var autoTeardownMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case id, status, template, zone
        case sshAddress = "ssh_address"
        case createdAt = "created_at"
        case pricePerHourUsd = "price_per_hour_usd"
        case autoTeardownMinutes = "auto_teardown_minutes"
    }
}

/// Response from listing compute instances.
public struct InstancesResponse: Codable, Sendable {
    /// Active instances.
    public var instances: [ComputeInstance]
}

/// Response from getting a single compute instance.
public struct InstanceResponse: Codable, Sendable {
    /// Instance details.
    public var instance: ComputeInstance
}

/// Request body for injecting an SSH key.
public struct SSHKeyRequest: Codable, Sendable {
    /// SSH public key.
    public var sshPublicKey: String

    public init(sshPublicKey: String) {
        self.sshPublicKey = sshPublicKey
    }

    enum CodingKeys: String, CodingKey {
        case sshPublicKey = "ssh_public_key"
    }
}

/// Response from deleting a compute instance.
public struct DeleteResponse: Codable, Sendable {
    /// Status.
    public var status: String

    /// Instance that was deleted.
    public var instanceId: String?

    enum CodingKeys: String, CodingKey {
        case status
        case instanceId = "instance_id"
    }
}

// MARK: - Compute Billing

/// Request body for querying compute billing.
public struct BillingRequest: Codable, Sendable {
    /// Filter by instance ID.
    public var instanceId: String?

    /// Start date for billing period (ISO 8601).
    public var startDate: String?

    /// End date for billing period (ISO 8601).
    public var endDate: String?

    public init(instanceId: String? = nil, startDate: String? = nil, endDate: String? = nil) {
        self.instanceId = instanceId
        self.startDate = startDate
        self.endDate = endDate
    }

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

/// A single billing line item.
public struct BillingEntry: Codable, Sendable {
    /// Instance identifier.
    public var instanceId: String

    /// Instance name.
    public var instanceName: String?

    /// Total cost in USD.
    public var costUsd: Double

    /// Usage duration in hours.
    public var usageHours: Double?

    /// SKU description.
    public var skuDescription: String?

    /// Billing period start.
    public var startTime: String?

    /// Billing period end.
    public var endTime: String?

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case instanceName = "instance_name"
        case costUsd = "cost_usd"
        case usageHours = "usage_hours"
        case skuDescription = "sku_description"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

/// Response from a compute billing query.
public struct BillingResponse: Codable, Sendable {
    /// Individual billing entries.
    public var entries: [BillingEntry]

    /// Total cost across all entries.
    public var totalCostUsd: Double

    enum CodingKeys: String, CodingKey {
        case entries
        case totalCostUsd = "total_cost_usd"
    }
}
