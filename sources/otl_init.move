#[allow(unused_const, duplicate_alias, unused_variable)]
module otl::otl_init;

use otl::base;
use otl::otl_interfaces;
use otl::otl_registry::{Self, OTLRegistry};
use std::string;
use sui::transfer;
use sui::tx_context::{Self, TxContext};

// ===== Module Dependencies =====

/// Initialize the complete OTL system (for internal use)
public fun setup_full_otl_system(registry: &mut OTLRegistry, ctx: &mut TxContext) {
    // Register core modules with dependencies
    register_core_modules(registry, ctx);

    // Register token modules
    register_token_modules(registry, ctx);

    // Register utility modules
    register_utility_modules(registry, ctx);

    // Register advanced modules
    register_advanced_modules(registry, ctx);

    // Enable default features
    enable_default_features(registry, ctx);
}

/// Entry point to create and setup complete OTL system
public entry fun initialize_complete_otl_system(ctx: &mut TxContext) {
    // Use the registry's own entry function to create and share
    otl_registry::create_and_share_otl_registry(ctx);
}

/// Register core foundational modules
fun register_core_modules(registry: &mut OTLRegistry, ctx: &mut TxContext) {
    // Register base module
    otl_registry::register_module(
        registry,
        string::utf8(b"base"),
        base::module_type_utility(),
        1, // version
        1, // api_version
        vector::empty(), // no dependencies
        vector[
            string::utf8(b"error_handling"),
            string::utf8(b"validation"),
            string::utf8(b"versioning"),
            string::utf8(b"feature_management"),
        ], // provides
        vector::empty(), // requires
        base::feature_analytics(), // features
        ctx,
    );

    // Register utils module
    otl_registry::register_module(
        registry,
        string::utf8(b"utils"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base")],
        vector[
            string::utf8(b"string_utils"),
            string::utf8(b"validation_utils"),
            string::utf8(b"time_utils"),
        ],
        vector[string::utf8(b"error_handling")],
        base::feature_batch_operations(),
        ctx,
    );

    // Register upgrade module
    otl_registry::register_module(
        registry,
        string::utf8(b"upgrade"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[string::utf8(b"package_upgrade"), string::utf8(b"version_management")],
        vector[string::utf8(b"versioning")],
        0, // no special features
        ctx,
    );
}

/// Register token-related modules
fun register_token_modules(registry: &mut OTLRegistry, ctx: &mut TxContext) {
    // Register ONOAL native token
    otl_registry::register_module(
        registry,
        string::utf8(b"onoal_token"),
        base::module_type_token(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"native_token"),
            string::utf8(b"fixed_pricing"),
            string::utf8(b"minter_management"),
            string::utf8(b"supply_management"),
        ],
        vector[string::utf8(b"validation"), string::utf8(b"error_handling")],
        base::feature_governance() | base::feature_compliance() | base::feature_analytics(),
        ctx,
    );

    // Register business coin utility
    otl_registry::register_module(
        registry,
        string::utf8(b"coin"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"business_tokens"),
            string::utf8(b"batch_minting"),
            string::utf8(b"discount_pricing"),
        ],
        vector[string::utf8(b"validation")],
        base::feature_batch_operations() | base::feature_advanced_pricing(),
        ctx,
    );

    // Register collectibles/NFTs
    otl_registry::register_module(
        registry,
        string::utf8(b"collectible"),
        base::module_type_collectible(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils"), string::utf8(b"kiosk_integration")],
        vector[
            string::utf8(b"nft_creation"),
            string::utf8(b"metadata_management"),
            string::utf8(b"royalties"),
        ],
        vector[string::utf8(b"validation"), string::utf8(b"kiosk_support")],
        base::feature_staking(),
        ctx,
    );

    // Register loyalty tokens
    otl_registry::register_module(
        registry,
        string::utf8(b"loyalty"),
        base::module_type_loyalty(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils"), string::utf8(b"onoal_token")],
        vector[
            string::utf8(b"loyalty_points"),
            string::utf8(b"reputation_system"),
            string::utf8(b"tier_management"),
        ],
        vector[string::utf8(b"native_token")],
        base::feature_staking() | base::feature_analytics(),
        ctx,
    );

    // Register tickets
    otl_registry::register_module(
        registry,
        string::utf8(b"ticket"),
        base::module_type_ticket(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils"), string::utf8(b"events_festivals")],
        vector[
            string::utf8(b"event_tickets"),
            string::utf8(b"access_control"),
            string::utf8(b"time_based_validation"),
        ],
        vector[string::utf8(b"event_management")],
        0,
        ctx,
    );
}

/// Register utility and infrastructure modules
fun register_utility_modules(registry: &mut OTLRegistry, ctx: &mut TxContext) {
    // Register batch utilities
    otl_registry::register_module(
        registry,
        string::utf8(b"batch_utils"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"batch_operations"),
            string::utf8(b"bulk_processing"),
            string::utf8(b"gas_optimization"),
        ],
        vector[string::utf8(b"validation")],
        base::feature_batch_operations(),
        ctx,
    );

    // Register permissions system
    otl_registry::register_module(
        registry,
        string::utf8(b"permissions"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"access_control"),
            string::utf8(b"role_management"),
            string::utf8(b"capability_system"),
        ],
        vector[string::utf8(b"validation")],
        0,
        ctx,
    );

    // Register payment system
    otl_registry::register_module(
        registry,
        string::utf8(b"payment_transfer"),
        base::module_type_payment(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils"), string::utf8(b"claim_escrow")],
        vector[
            string::utf8(b"payment_processing"),
            string::utf8(b"transfer_management"),
            string::utf8(b"fee_handling"),
        ],
        vector[string::utf8(b"escrow_support")],
        base::feature_batch_operations(),
        ctx,
    );

    // Register escrow system
    otl_registry::register_module(
        registry,
        string::utf8(b"claim_escrow"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"escrow_support"),
            string::utf8(b"secure_transactions"),
            string::utf8(b"dispute_resolution"),
        ],
        vector[string::utf8(b"validation")],
        0,
        ctx,
    );

    // Register wallet system
    otl_registry::register_module(
        registry,
        string::utf8(b"otl_wallet"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils"), string::utf8(b"onoal_token")],
        vector[
            string::utf8(b"wallet_management"),
            string::utf8(b"multi_token_support"),
            string::utf8(b"transaction_history"),
        ],
        vector[string::utf8(b"native_token")],
        base::feature_analytics(),
        ctx,
    );
}

/// Register advanced feature modules
fun register_advanced_modules(registry: &mut OTLRegistry, ctx: &mut TxContext) {
    // Register social features
    otl_registry::register_module(
        registry,
        string::utf8(b"social"),
        base::module_type_social(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils"), string::utf8(b"onoal_id")],
        vector[
            string::utf8(b"social_profiles"),
            string::utf8(b"reputation_system"),
            string::utf8(b"community_features"),
        ],
        vector[string::utf8(b"identity_system")],
        base::feature_analytics(),
        ctx,
    );

    // Register identity system
    otl_registry::register_module(
        registry,
        string::utf8(b"onoal_id"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"identity_system"),
            string::utf8(b"profile_management"),
            string::utf8(b"verification_system"),
        ],
        vector[string::utf8(b"validation")],
        base::feature_compliance(),
        ctx,
    );

    // Register namespace system
    otl_registry::register_module(
        registry,
        string::utf8(b"namespaces"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"namespace_management"),
            string::utf8(b"domain_resolution"),
            string::utf8(b"hierarchical_naming"),
        ],
        vector[string::utf8(b"validation")],
        0,
        ctx,
    );

    // Register Kiosk integration
    otl_registry::register_module(
        registry,
        string::utf8(b"kiosk_integration"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"kiosk_support"),
            string::utf8(b"marketplace_integration"),
            string::utf8(b"trading_support"),
        ],
        vector[string::utf8(b"validation")],
        0,
        ctx,
    );

    // Register events & festivals
    otl_registry::register_module(
        registry,
        string::utf8(b"events_festivals"),
        base::module_type_utility(),
        1,
        1,
        vector[string::utf8(b"base"), string::utf8(b"utils")],
        vector[
            string::utf8(b"event_management"),
            string::utf8(b"festival_coordination"),
            string::utf8(b"scheduling_system"),
        ],
        vector[string::utf8(b"validation")],
        base::feature_analytics(),
        ctx,
    );
}

/// Enable default features for the system
fun enable_default_features(registry: &mut OTLRegistry, ctx: &mut TxContext) {
    // Enable core features
    otl_registry::enable_global_feature(registry, base::feature_batch_operations(), ctx);
    otl_registry::enable_global_feature(registry, base::feature_analytics(), ctx);

    // Add custom features for future use
    otl_registry::add_custom_feature(
        registry,
        string::utf8(b"defi_integration"),
        512, // custom feature ID
        ctx,
    );

    otl_registry::add_custom_feature(
        registry,
        string::utf8(b"cross_chain_bridge"),
        1024,
        ctx,
    );

    otl_registry::add_custom_feature(
        registry,
        string::utf8(b"ai_powered_analytics"),
        2048,
        ctx,
    );

    // Set up event hooks for cross-module communication
    setup_event_hooks(registry, ctx);
}

/// Set up event hooks for cross-module communication
fun setup_event_hooks(registry: &mut OTLRegistry, ctx: &mut TxContext) {
    // Token events
    otl_registry::add_event_hook(
        registry,
        string::utf8(b"token_minted"),
        string::utf8(b"otl_wallet"),
        ctx,
    );

    otl_registry::add_event_hook(
        registry,
        string::utf8(b"token_minted"),
        string::utf8(b"social"),
        ctx,
    );

    // Payment events
    otl_registry::add_event_hook(
        registry,
        string::utf8(b"payment_completed"),
        string::utf8(b"loyalty"),
        ctx,
    );

    // NFT events
    otl_registry::add_event_hook(
        registry,
        string::utf8(b"nft_created"),
        string::utf8(b"kiosk_integration"),
        ctx,
    );

    // Social events
    otl_registry::add_event_hook(
        registry,
        string::utf8(b"profile_updated"),
        string::utf8(b"loyalty"),
        ctx,
    );
}

/// Initialize and create the complete OTL system
public entry fun initialize_and_create_otl(ctx: &mut TxContext) {
    // Create a basic registry and then set it up fully
    let mut registry = otl_registry::create_otl_registry(ctx);
    setup_full_otl_system(&mut registry, ctx);

    // The registry is consumed by this function scope
    // In a production system, you would typically share or transfer the registry
    // For now, we'll use a different approach to handle the registry lifecycle
    abort 0 // Temporary - this function needs redesign for proper registry handling
}

/// Get initialization status
public fun get_system_info(registry: &OTLRegistry): (u64, u64, bool, bool) {
    let (
        version,
        total_modules,
        total_plugins,
        created_at,
        last_updated,
    ) = otl_registry::get_registry_info(registry);

    let batch_enabled = otl_registry::is_feature_enabled(
        registry,
        base::feature_batch_operations(),
    );
    let analytics_enabled = otl_registry::is_feature_enabled(registry, base::feature_analytics());

    (total_modules, total_plugins, batch_enabled, analytics_enabled)
}

/// Check system health by validating all module dependencies
public fun check_system_health(registry: &OTLRegistry): bool {
    // Check core modules
    let core_modules = vector[
        string::utf8(b"base"),
        string::utf8(b"utils"),
        string::utf8(b"onoal_token"),
    ];

    let mut i = 0;
    while (i < vector::length(&core_modules)) {
        let module_id = *vector::borrow(&core_modules, i);
        if (!otl_registry::check_module_dependencies(registry, module_id)) {
            return false
        };
        i = i + 1;
    };

    true
}
