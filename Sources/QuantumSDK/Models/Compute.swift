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

// MARK: - Model deployments

/// A tested Model Garden deploy configuration from the catalogue.
///
/// Passing ``id`` as ``DeployModelRequest/model`` fills in the machine spec
/// and region server-side, so a caller need not repeat them.
public struct KnownModel: Codable, Sendable {
    /// Short catalogue id.
    public var id: String

    /// Display name.
    public var name: String?

    /// Model publisher.
    public var publisher: String?

    /// Full `publishers/<x>/models/<y>@<variant>` path.
    public var modelPath: String?

    /// Machine type the model is verified on.
    public var machineType: String?

    /// Accelerator type the model is verified on.
    public var acceleratorType: String?

    /// Number of accelerators.
    public var acceleratorCount: Int?

    /// Regions the configuration is known to deploy in.
    @NullToEmpty public var regions: [String]

    /// Serving container image override, when the model needs a specific one.
    public var containerImage: String?

    /// VRAM the configuration provides, in GB.
    public var vramGb: Int?

    /// What the model is for.
    public var description: String?

    /// Parameter count, as displayed (e.g. `"120B (12B active)"`).
    public var parameters: String?

    /// Hourly price, enriched from the live billing catalogue at response
    /// time.
    public var pricePerHourUsd: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, publisher, regions, description, parameters
        case modelPath = "model_path"
        case machineType = "machine_type"
        case acceleratorType = "accelerator_type"
        case acceleratorCount = "accelerator_count"
        case containerImage = "container_image"
        case vramGb = "vram_gb"
        case pricePerHourUsd = "price_per_hour_usd"
    }
}

/// Response from `GET /qai/v1/compute/catalog`.
public struct ComputeCatalogResponse: Codable, Sendable {
    /// Curated, tested configurations with live pricing.
    @NullToEmpty public var verifiedModels: [KnownModel]

    /// Models discovered dynamically from Model Garden. Absent when the
    /// catalogue fetch failed; the verified list is still returned.
    public var discoveredModels: [AnyCodable]?

    /// When the dynamic catalogue was fetched, RFC3339.
    public var cachedAt: String?

    /// When the cached dynamic catalogue goes stale, RFC3339.
    public var expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case verifiedModels = "verified_models"
        case discoveredModels = "discovered_models"
        case cachedAt = "cached_at"
        case expiresAt = "expires_at"
    }
}

/// Request body for `POST /qai/v1/compute/deploy-model`.
///
/// The endpoint is two-phase: ``QuantumClient/computeDeployModelEstimate(_:)``
/// sends it with `confirmed` off for a cost estimate that bills nothing, and
/// ``QuantumClient/computeDeployModel(_:)`` sends the same request with
/// `confirmed: true` to actually provision.
public struct DeployModelRequest: Codable, Sendable {
    /// A catalogue ``KnownModel/id``, or a full Model Garden model path.
    /// Required.
    public var model: String

    /// Machine type. Filled in from the catalogue when `model` is a known id.
    public var machineType: String?

    /// Accelerator type. Filled in from the catalogue when `model` is a known
    /// id.
    public var acceleratorType: String?

    /// Number of accelerators. Defaults to 1.
    public var acceleratorCount: Int?

    /// Deploy region. Defaults to the catalogue's first known-good region, or
    /// `us-east1`.
    public var region: String?

    /// How long to hold the deployment. Raised to the 2-hour minimum when
    /// lower.
    public var durationHours: Int?

    /// Auto-scaling minimum. Defaults to 1.
    public var minReplicas: Int?

    /// Auto-scaling maximum. Defaults to 1.
    public var maxReplicas: Int?

    /// Let other authenticated users call this deployment's inference
    /// endpoint. They are billed per token; the hourly cost stays with the
    /// owner. Wire key `public`.
    public var isPublic: Bool?

    /// Set to `true` to provision. Unset returns an estimate and bills
    /// nothing. The two client methods override this flag.
    public var confirmed: Bool?

    public init(
        model: String,
        machineType: String? = nil,
        acceleratorType: String? = nil,
        acceleratorCount: Int? = nil,
        region: String? = nil,
        durationHours: Int? = nil,
        minReplicas: Int? = nil,
        maxReplicas: Int? = nil,
        isPublic: Bool? = nil,
        confirmed: Bool? = nil
    ) {
        self.model = model
        self.machineType = machineType
        self.acceleratorType = acceleratorType
        self.acceleratorCount = acceleratorCount
        self.region = region
        self.durationHours = durationHours
        self.minReplicas = minReplicas
        self.maxReplicas = maxReplicas
        self.isPublic = isPublic
        self.confirmed = confirmed
    }

    enum CodingKeys: String, CodingKey {
        case model, region, confirmed
        case machineType = "machine_type"
        case acceleratorType = "accelerator_type"
        case acceleratorCount = "accelerator_count"
        case durationHours = "duration_hours"
        case minReplicas = "min_replicas"
        case maxReplicas = "max_replicas"
        case isPublic = "public"
    }
}

/// The estimate returned when a deploy request is not confirmed.
public struct DeployModelEstimate: Codable, Sendable {
    /// Hourly price including margin.
    public var costPerHourUsd: Double?

    /// Total for the requested duration.
    public var totalEstimateUsd: Double?

    /// The same total in ticks.
    public var totalTicks: Int64?

    /// Duration the estimate covers, after the 2-hour minimum is applied.
    public var durationHours: Int?

    /// Display name resolved for the model.
    public var modelDisplayName: String?

    /// Resolved full model path.
    public var model: String?

    /// Resolved machine type.
    public var machineType: String?

    /// Resolved accelerator type.
    public var acceleratorType: String?

    /// Resolved accelerator count.
    public var acceleratorCount: Int?

    /// Resolved region.
    public var region: String?

    /// How to proceed: `"resubmit with confirmed:true to deploy"`.
    public var note: String?

    enum CodingKeys: String, CodingKey {
        case model, region, note
        case costPerHourUsd = "cost_per_hour_usd"
        case totalEstimateUsd = "total_estimate_usd"
        case totalTicks = "total_ticks"
        case durationHours = "duration_hours"
        case modelDisplayName = "model_display_name"
        case machineType = "machine_type"
        case acceleratorType = "accelerator_type"
        case acceleratorCount = "accelerator_count"
    }
}

/// The acceptance returned when a deploy request is confirmed. Provisioning
/// runs asynchronously; poll ``QuantumClient/computeDeployment(id:)`` until
/// the status reaches `ready`.
public struct DeployModelAccepted: Codable, Sendable {
    /// The deployment to poll.
    public var deploymentId: String

    /// Status at acceptance: `"provisioning"`.
    public var status: String?

    /// Display name resolved for the model.
    public var modelDisplayName: String?

    /// Hourly price including margin.
    public var costPerHourUsd: Double?

    /// Amount deducted up front, refunded if provisioning fails.
    public var totalCostUsd: Double?

    /// RFC3339 time the deployment is torn down.
    public var expiresAt: String?

    /// Provider long-running operation backing the provision.
    public var operation: String?

    /// Where to poll for status.
    public var note: String?

    enum CodingKeys: String, CodingKey {
        case status, operation, note
        case deploymentId = "deployment_id"
        case modelDisplayName = "model_display_name"
        case costPerHourUsd = "cost_per_hour_usd"
        case totalCostUsd = "total_cost_usd"
        case expiresAt = "expires_at"
    }
}

/// A model deployment record.
public struct ModelDeployment: Codable, Sendable {
    /// Deployment identifier.
    public var id: String

    /// Owning user.
    public var userId: String?

    /// Full model path deployed.
    public var model: String?

    /// Display name for the model.
    public var modelDisplayName: String?

    /// Machine type.
    public var machineType: String?

    /// Accelerator type.
    public var acceleratorType: String?

    /// Number of accelerators.
    public var acceleratorCount: Int?

    /// Deploy region.
    public var region: String?

    /// Hours the deployment was booked for.
    public var durationHours: Int?

    /// Lifecycle status (`provisioning`, `deploying`, `ready`, `terminated`,
    /// `failed`).
    public var status: String?

    /// Provider long-running operation name.
    public var vertexOperation: String?

    /// Endpoint URL once the deployment is serving.
    public var endpointUrl: String?

    /// Provider endpoint id.
    public var endpointId: String?

    /// Provider model id on the endpoint.
    public var modelId: String?

    /// Failure reason, when the deployment failed. Wire key `error`.
    public var errorMessage: String?

    /// Hourly price including margin.
    public var costPerHourUsd: Double?

    /// Total charged in ticks.
    public var totalCostTicks: Int64?

    /// Margin applied over the raw hardware price, as a percentage.
    public var marginPct: Double?

    /// Auto-scaling minimum.
    public var minReplicas: Int?

    /// Auto-scaling maximum.
    public var maxReplicas: Int?

    /// Whether other authenticated users may run inference against it.
    /// Wire key `public`.
    public var isPublic: Bool?

    /// Partner the spend is attributed to, or `"direct"`.
    public var consumer: String?

    /// RFC3339 creation timestamp.
    public var createdAt: String?

    /// RFC3339 time the deployment became ready.
    public var readyAt: String?

    /// RFC3339 teardown time.
    public var expiresAt: String?

    /// RFC3339 time the deployment was torn down.
    public var terminatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, model, region, status, consumer
        case userId = "user_id"
        case modelDisplayName = "model_display_name"
        case machineType = "machine_type"
        case acceleratorType = "accelerator_type"
        case acceleratorCount = "accelerator_count"
        case durationHours = "duration_hours"
        case vertexOperation = "vertex_operation"
        case endpointUrl = "endpoint_url"
        case endpointId = "endpoint_id"
        case modelId = "model_id"
        case errorMessage = "error"
        case costPerHourUsd = "cost_per_hour_usd"
        case totalCostTicks = "total_cost_ticks"
        case marginPct = "margin_pct"
        case minReplicas = "min_replicas"
        case maxReplicas = "max_replicas"
        case isPublic = "public"
        case createdAt = "created_at"
        case readyAt = "ready_at"
        case expiresAt = "expires_at"
        case terminatedAt = "terminated_at"
    }
}

/// Response from `GET /qai/v1/compute/deployments`.
public struct DeploymentsResponse: Codable, Sendable {
    /// The caller's deployments.
    @NullToEmpty public var deployments: [ModelDeployment]
}

/// Request body for `POST /qai/v1/compute/deployments/{id}/extend`.
public struct ExtendDeploymentRequest: Codable, Sendable {
    /// Hours to add. Values at or below zero become 1.
    public var hours: Int

    public init(hours: Int) {
        self.hours = hours
    }
}

/// Response from `POST /qai/v1/compute/deployments/{id}/extend`.
public struct ExtendDeploymentResponse: Codable, Sendable {
    /// The deployment that was extended.
    public var deploymentId: String?

    /// RFC3339 teardown time after the extension.
    public var newExpiry: String?

    /// Hours actually added.
    public var extendedHours: Int?

    /// Amount charged for the extension.
    public var costUsd: Double?

    enum CodingKeys: String, CodingKey {
        case deploymentId = "deployment_id"
        case newExpiry = "new_expiry"
        case extendedHours = "extended_hours"
        case costUsd = "cost_usd"
    }
}

/// Response from `DELETE /qai/v1/compute/deployments/{id}`.
public struct DeploymentDeleteResponse: Codable, Sendable {
    /// Status after teardown: `"terminated"`.
    public var status: String?
}
