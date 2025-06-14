#[allow(unused_const, duplicate_alias, unused_variable)]
module otl::otl_adapters;

use otl::base;
use otl::otl_interfaces;
use otl::otl_registry::{Self, OTLRegistry};
use std::string::{Self, String};
use sui::tx_context::TxContext;

// ===== Module Adapter System =====

/// Generic module adapter for integrating existing modules
public struct ModuleAdapter has copy, drop, store {
    module_name: String,
    module_type: u8,
    version: u64,
    api_version: u64,
    features: u64,
    interface_compliance: bool,
    migration_status: u8, // 0=not_migrated, 1=partial, 2=complete
}

/// Feature compatibility checker
public struct FeatureChecker has copy, drop, store {
    required_features: u64,
    optional_features: u64,
    supported_interfaces: vector<String>,
}

// ===== Adapter Creation =====

/// Create adapter for token-like modules
public fun create_token_adapter(
    module_name: String,
    version: u64,
    supports_mint: bool,
    supports_burn: bool,
    supports_transfer: bool,
    supports_metadata: bool,
): ModuleAdapter {
    let mut features = 0u64;
    if (supports_mint || supports_burn) {
        features = features | base::feature_batch_operations();
    };

    let interface_compliance = otl_interfaces::validate_token_interface(
        supports_transfer,
        supports_burn,
        supports_mint,
        supports_metadata,
    );

    ModuleAdapter {
        module_name,
        module_type: base::module_type_token(),
        version,
        api_version: base::get_api_version(),
        features,
        interface_compliance,
        migration_status: 0,
    }
}

/// Create adapter for NFT/collectible modules
public fun create_nft_adapter(
    module_name: String,
    version: u64,
    supports_attributes: bool,
    supports_royalties: bool,
    supports_kiosk: bool,
): ModuleAdapter {
    let mut features = 0u64;
    if (supports_royalties) {
        features = features | base::feature_advanced_pricing();
    };

    let interface_compliance = otl_interfaces::validate_nft_interface(
        supports_attributes,
        supports_kiosk,
    );

    ModuleAdapter {
        module_name,
        module_type: base::module_type_collectible(),
        version,
        api_version: base::get_api_version(),
        features,
        interface_compliance,
        migration_status: 0,
    }
}

/// Create adapter for utility modules
public fun create_utility_adapter(
    module_name: String,
    version: u64,
    feature_flags: u64,
): ModuleAdapter {
    ModuleAdapter {
        module_name,
        module_type: base::module_type_utility(),
        version,
        api_version: base::get_api_version(),
        features: feature_flags,
        interface_compliance: true, // Utilities don't need specific interface compliance
        migration_status: 0,
    }
}

/// Create adapter for payment modules
public fun create_payment_adapter(
    module_name: String,
    version: u64,
    supports_escrow: bool,
    supports_batch: bool,
    supports_recurring: bool,
    supports_multi_currency: bool,
): ModuleAdapter {
    let mut features = base::feature_batch_operations();
    if (supports_recurring) {
        features = features | base::feature_analytics();
    };

    let interface_compliance = otl_interfaces::validate_payment_interface(
        supports_escrow,
        supports_batch,
    );

    ModuleAdapter {
        module_name,
        module_type: base::module_type_payment(),
        version,
        api_version: base::get_api_version(),
        features,
        interface_compliance,
        migration_status: 0,
    }
}

/// Create adapter for social modules
public fun create_social_adapter(
    module_name: String,
    version: u64,
    supports_profiles: bool,
    supports_reputation: bool,
    supports_messaging: bool,
): ModuleAdapter {
    let features = base::feature_analytics();

    ModuleAdapter {
        module_name,
        module_type: base::module_type_social(),
        version,
        api_version: base::get_api_version(),
        features,
        interface_compliance: supports_profiles, // Minimum requirement
        migration_status: 0,
    }
}

// ===== Registry Integration =====

/// Register module via adapter
public fun register_module_with_adapter(
    registry: &mut OTLRegistry,
    adapter: ModuleAdapter,
    dependencies: vector<String>,
    provides: vector<String>,
    requires: vector<String>,
    ctx: &mut TxContext,
) {
    otl_registry::register_module(
        registry,
        adapter.module_name,
        adapter.module_type,
        adapter.version,
        adapter.api_version,
        dependencies,
        provides,
        requires,
        adapter.features,
        ctx,
    );
}

/// Batch register multiple modules
public fun batch_register_modules(
    registry: &mut OTLRegistry,
    adapters: vector<ModuleAdapter>,
    ctx: &mut TxContext,
) {
    let mut i = 0;
    while (i < vector::length(&adapters)) {
        let adapter = *vector::borrow(&adapters, i);

        // Auto-determine basic dependencies based on module type
        let (dependencies, provides, requires) = get_default_module_info(adapter.module_type);

        register_module_with_adapter(
            registry,
            adapter,
            dependencies,
            provides,
            requires,
            ctx,
        );

        i = i + 1;
    }
}

/// Get default module information based on type
fun get_default_module_info(module_type: u8): (vector<String>, vector<String>, vector<String>) {
    if (module_type == base::module_type_token()) {
        (
            vector[string::utf8(b"base"), string::utf8(b"utils")],
            vector[string::utf8(b"token_interface")],
            vector[string::utf8(b"validation")],
        )
    } else if (module_type == base::module_type_collectible()) {
        (
            vector[string::utf8(b"base"), string::utf8(b"utils")],
            vector[string::utf8(b"nft_interface")],
            vector[string::utf8(b"validation")],
        )
    } else if (module_type == base::module_type_payment()) {
        (
            vector[string::utf8(b"base"), string::utf8(b"utils")],
            vector[string::utf8(b"payment_interface")],
            vector[string::utf8(b"validation")],
        )
    } else if (module_type == base::module_type_social()) {
        (
            vector[string::utf8(b"base"), string::utf8(b"utils")],
            vector[string::utf8(b"social_interface")],
            vector[string::utf8(b"validation")],
        )
    } else {
        // Utility modules
        (
            vector[string::utf8(b"base")],
            vector[string::utf8(b"utility_interface")],
            vector[string::utf8(b"validation")],
        )
    }
}

// ===== Adapter Validation =====

/// Check if adapter is compatible with registry
public fun is_adapter_compatible(adapter: &ModuleAdapter, registry: &OTLRegistry): bool {
    // Check version compatibility
    if (!base::is_version_compatible(adapter.version)) {
        return false
    };

    // Check interface compliance
    if (!adapter.interface_compliance) {
        return false
    };

    // Check if required features are enabled
    let required_features = adapter.features;
    if (required_features > 0) {
        return otl_registry::is_feature_enabled(registry, required_features)
    };

    true
}

/// Create feature checker for module requirements
public fun create_feature_checker(
    required_features: u64,
    optional_features: u64,
    supported_interfaces: vector<String>,
): FeatureChecker {
    FeatureChecker {
        required_features,
        optional_features,
        supported_interfaces,
    }
}

/// Validate module against feature checker
public fun check_module_features(
    registry: &OTLRegistry,
    checker: &FeatureChecker,
): (bool, vector<String>) {
    let mut missing_features = vector::empty<String>();
    let mut all_required_met = true;

    // Check required features
    if (checker.required_features > 0) {
        if (!otl_registry::is_feature_enabled(registry, checker.required_features)) {
            all_required_met = false;
            vector::push_back(&mut missing_features, string::utf8(b"required_features"));
        };
    };

    (all_required_met, missing_features)
}

/// Update adapter migration status
public fun update_migration_status(adapter: &mut ModuleAdapter, status: u8) {
    assert!(status <= 2, base::invalid_metadata_error());
    adapter.migration_status = status;
}

/// Get adapter information
public fun get_adapter_info(adapter: &ModuleAdapter): (String, u8, u64, u64, bool, u8) {
    (
        adapter.module_name,
        adapter.module_type,
        adapter.version,
        adapter.api_version,
        adapter.interface_compliance,
        adapter.migration_status,
    )
}

// ===== Pre-built Adapters for Existing Modules =====

/// Create adapters for all existing OTL modules
public fun create_otl_module_adapters(): vector<ModuleAdapter> {
    let mut adapters = vector::empty<ModuleAdapter>();

    // Core modules
    vector::push_back(
        &mut adapters,
        create_utility_adapter(
            string::utf8(b"base"),
            1,
            base::feature_analytics(),
        ),
    );

    vector::push_back(
        &mut adapters,
        create_utility_adapter(
            string::utf8(b"utils"),
            1,
            base::feature_batch_operations(),
        ),
    );

    // Token modules
    vector::push_back(
        &mut adapters,
        create_token_adapter(
            string::utf8(b"onoal_token"),
            1,
            true, // supports_mint
            true, // supports_burn
            true, // supports_transfer
            true, // supports_metadata
        ),
    );

    vector::push_back(
        &mut adapters,
        create_token_adapter(
            string::utf8(b"coin"),
            1,
            true, // supports_mint
            false, // supports_burn
            true, // supports_transfer
            true, // supports_metadata
        ),
    );

    // NFT modules
    vector::push_back(
        &mut adapters,
        create_nft_adapter(
            string::utf8(b"collectible"),
            1,
            true, // supports_attributes
            true, // supports_royalties
            true, // supports_kiosk
        ),
    );

    // Other modules
    vector::push_back(
        &mut adapters,
        create_utility_adapter(
            string::utf8(b"loyalty"),
            1,
            base::feature_staking() | base::feature_analytics(),
        ),
    );

    vector::push_back(
        &mut adapters,
        create_utility_adapter(
            string::utf8(b"ticket"),
            1,
            0,
        ),
    );

    vector::push_back(
        &mut adapters,
        create_payment_adapter(
            string::utf8(b"payment_transfer"),
            1,
            true, // supports_escrow
            true, // supports_batch
            false, // supports_recurring
            false, // supports_multi_currency
        ),
    );

    vector::push_back(
        &mut adapters,
        create_social_adapter(
            string::utf8(b"social"),
            1,
            true, // supports_profiles
            true, // supports_reputation
            false, // supports_messaging
        ),
    );

    adapters
}
