import Foundation

// MARK: - Compute Template

/// A GPU compute template.
public struct ComputeTemplate: Codable, Sendable {
    /// Template identifier (e.g. "a100-80gb", "h100-sxm").
    public var id: String

    /// Human-readable name.
    public var name: String?

    /// What the template is for.
    public var description: String?

    /// `"cpu"` or `"gpu"`.
    public var category: String?

    /// GCE machine type.
    public var machineType: String?

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

    /// Boot disk size in GB.
    public var diskSizeGb: Int?

    /// The on-demand rate actually billed, in USD per hour. Refreshed from
    /// live pricing when the gateway has it configured.
    public var hourlyUsd: Double?

    /// The spot rate actually billed when provisioning with `spot: true`,
    /// in USD per hour. Zero when the template has no spot pricing.
    public var spotHourlyUsd: Double?

    /// The static catalogue price copied once at gateway start. Live pricing
    /// updates `hourlyUsd`, not this field, so read `hourlyUsd` for what a
    /// provision will charge.
    public var pricePerHourUsd: Double?

    /// Whether `spot: true` is accepted for this template.
    public var spotAllowed: Bool?

    /// Whether provisioning needs the explicit `confirm` flag (see
    /// ``QuantumClient/computeProvision(_:confirm:)``).
    public var requiresApproval: Bool?

    /// Minimum balance required to provision, in USD. Zero means one hour
    /// at the template rate.
    public var minDepositUsd: Double?

    /// Typical boot time in seconds.
    public var bootTimeSecs: Int?

    /// Available zones.
    public var zones: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, gpu, vcpus, zones
        case machineType = "machine_type"
        case gpuCount = "gpu_count"
        case vramGb = "vram_gb"
        case ramGb = "ram_gb"
        case diskSizeGb = "disk_size_gb"
        case hourlyUsd = "hourly_usd"
        case spotHourlyUsd = "spot_hourly_usd"
        case pricePerHourUsd = "price_per_hour_usd"
        case spotAllowed = "spot_allowed"
        case requiresApproval = "requires_approval"
        case minDepositUsd = "min_deposit_usd"
        case bootTimeSecs = "boot_time_secs"
    }
}

/// Response from the `/qai/v1/compute/templates` endpoint.
public struct TemplatesResponse: Codable, Sendable {
    /// Available templates.
    @NullToEmpty public var templates: [ComputeTemplate]
}

// MARK: - Provision

/// Request body for the `/qai/v1/compute/provision` endpoint.
public struct ProvisionRequest: Codable, Sendable {
    /// Template ID to provision.
    public var template: String

    /// Preferred zone (e.g. "us-central1-a"). Must be one of the template's
    /// zones; defaults to its first.
    public var zone: String?

    /// Use spot/preemptible pricing. Refused with 400 when the template has
    /// no spot allowance.
    public var spot: Bool?

    /// Auto-teardown after N minutes of inactivity. Values at or below zero
    /// become 30; values above 1440 (24 hours) become 1440.
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

/// Response from provisioning a compute instance (`201 Created`).
public struct ProvisionResponse: Codable, Sendable {
    /// Instance identifier.
    public var instanceId: String

    /// Status at acceptance: `"provisioning"`.
    public var status: String

    /// Zone the instance was placed in.
    public var zone: String?

    /// GCE machine type.
    public var machineType: String?

    /// GPU accelerator type.
    public var gpuType: String?

    /// Hourly rate the instance bills at, in USD.
    public var hourlyUsd: Double?

    /// Amount charged so far: the first hour, deducted before the VM
    /// exists.
    public var costUsd: Double?

    /// Public IP. Always absent at acceptance; poll
    /// ``QuantumClient/computeInstance(id:)`` for it.
    public var externalIp: String?

    /// Expected boot time in seconds.
    public var estimatedBootSecs: Int?

    enum CodingKeys: String, CodingKey {
        case status, zone
        case instanceId = "instance_id"
        case machineType = "machine_type"
        case gpuType = "gpu_type"
        case hourlyUsd = "hourly_usd"
        case costUsd = "cost_usd"
        case externalIp = "external_ip"
        case estimatedBootSecs = "estimated_boot_secs"
    }
}

// MARK: - Compute Instance

/// A compute instance, as returned by ``QuantumClient/computeInstance(id:)``
/// and, with fewer fields filled in, by ``QuantumClient/computeInstances()``.
///
/// The list omits `gcp_status`, `machine_type`, `spot`, `ssh_username` and
/// `error_message`; those are nil there.
public struct ComputeInstanceInfo: Codable, Sendable {
    /// Unique instance identifier.
    public var instanceId: String

    /// Template that was used.
    public var template: String?

    /// Current instance status ("provisioning", "running", "stopping", "terminated", "failed").
    public var status: String

    /// Live GCE instance status. Absent unless the instance is running.
    public var gcpStatus: String?

    /// GCP zone.
    public var zone: String?

    /// GCE machine type.
    public var machineType: String?

    /// Public IP address (available once running).
    public var externalIp: String?

    /// GPU accelerator type.
    public var gpuType: String?

    /// Number of GPUs.
    public var gpuCount: Int?

    /// Whether this is a spot/preemptible instance.
    public var spot: Bool?

    /// Hourly rate in USD.
    public var hourlyUsd: Double?

    /// Total cost so far in USD.
    public var costUsd: Double?

    /// Total uptime in minutes.
    public var uptimeMinutes: Int?

    /// Inactivity timeout in minutes.
    public var autoTeardownMinutes: Int?

    /// SSH username for the instance.
    public var sshUsername: String?

    /// ISO 8601 timestamp of last activity.
    public var lastActiveAt: String?

    /// ISO 8601 creation timestamp.
    public var createdAt: String?

    /// ISO 8601 termination timestamp (if terminated).
    public var terminatedAt: String?

    /// Error message if the instance failed.
    public var errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case template, status, zone, spot
        case instanceId = "instance_id"
        case gcpStatus = "gcp_status"
        case machineType = "machine_type"
        case externalIp = "external_ip"
        case gpuType = "gpu_type"
        case gpuCount = "gpu_count"
        case hourlyUsd = "hourly_usd"
        case costUsd = "cost_usd"
        case uptimeMinutes = "uptime_minutes"
        case autoTeardownMinutes = "auto_teardown_minutes"
        case sshUsername = "ssh_username"
        case lastActiveAt = "last_active_at"
        case createdAt = "created_at"
        case terminatedAt = "terminated_at"
        case errorMessage = "error_message"
    }
}

/// Response from listing compute instances.
public struct InstancesResponse: Codable, Sendable {
    /// The caller's instances, terminated ones included.
    @NullToEmpty public var instances: [ComputeInstanceInfo]
}

/// Request body for adding an SSH key to an instance.
public struct SSHKeyRequest: Codable, Sendable {
    /// SSH public key to add. Required.
    public var publicKey: String

    /// Login user the key is installed for. Defaults to `cosmic`.
    public var username: String?

    public init(publicKey: String, username: String? = nil) {
        self.publicKey = publicKey
        self.username = username
    }

    enum CodingKeys: String, CodingKey {
        case username
        case publicKey = "public_key"
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
