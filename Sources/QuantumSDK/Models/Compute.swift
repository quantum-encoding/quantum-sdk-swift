import Foundation

// MARK: - Compute Template

/// A GPU compute template.
public struct ComputeTemplate: Codable, Sendable {
    /// Template ID.
    public var id: String

    /// Template name.
    public var name: String

    /// GPU type.
    public var gpuType: String

    /// Number of GPUs.
    public var gpuCount: Int

    /// Number of virtual CPUs.
    public var vcpus: Int

    /// RAM in GB.
    public var ramGb: Int

    /// Disk space in GB.
    public var diskGb: Int

    /// Price per hour in USD.
    public var pricePerHour: Double

    enum CodingKeys: String, CodingKey {
        case id, name, vcpus
        case gpuType = "gpu_type"
        case gpuCount = "gpu_count"
        case ramGb = "ram_gb"
        case diskGb = "disk_gb"
        case pricePerHour = "price_per_hour"
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
    public var templateId: String

    /// Preferred region.
    public var region: String?

    /// SSH public key for access.
    public var sshPublicKey: String?

    public init(templateId: String, region: String? = nil, sshPublicKey: String? = nil) {
        self.templateId = templateId
        self.region = region
        self.sshPublicKey = sshPublicKey
    }

    enum CodingKeys: String, CodingKey {
        case region
        case templateId = "template_id"
        case sshPublicKey = "ssh_public_key"
    }
}

/// Response from provisioning a compute instance.
public struct ProvisionResponse: Codable, Sendable {
    /// Instance ID.
    public var instanceId: String

    /// Current status.
    public var status: String

    enum CodingKeys: String, CodingKey {
        case status
        case instanceId = "instance_id"
    }
}

// MARK: - Instances

/// Basic compute instance information.
public struct ComputeInstanceInfo: Codable, Sendable {
    /// Instance ID.
    public var id: String

    /// Current status.
    public var status: String

    /// Template ID.
    public var templateId: String

    /// Creation timestamp.
    public var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case templateId = "template_id"
        case createdAt = "created_at"
    }
}

/// Response from listing compute instances.
public struct InstancesResponse: Codable, Sendable {
    /// Active instances.
    public var instances: [ComputeInstanceInfo]
}

/// Detailed compute instance information.
public struct InstanceDetailInfo: Codable, Sendable {
    /// Instance ID.
    public var id: String

    /// Current status.
    public var status: String

    /// Template ID.
    public var templateId: String

    /// Creation timestamp.
    public var createdAt: String

    /// IP address.
    public var ipAddress: String?

    /// SSH host.
    public var sshHost: String?

    /// SSH port.
    public var sshPort: Int?

    enum CodingKeys: String, CodingKey {
        case id, status
        case templateId = "template_id"
        case createdAt = "created_at"
        case ipAddress = "ip_address"
        case sshHost = "ssh_host"
        case sshPort = "ssh_port"
    }
}

/// Response from getting a single compute instance.
public struct InstanceResponse: Codable, Sendable {
    /// Instance details.
    public var instance: InstanceDetailInfo
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

    /// Final cost in ticks.
    public var costTicks: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case costTicks = "cost_ticks"
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
