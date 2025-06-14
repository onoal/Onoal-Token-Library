#[allow(unused_const, duplicate_alias, unused_variable)]
module otl::otl_registry;

use otl::base::{Self, ModuleConfig, FeatureRegistry, CompatibilityInfo};
use otl::utils;
use std::string::{Self, String};
use sui::event;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};

// ===== Core Registry =====

/// Central OTL registry for all modules and features
public struct OTLRegistry has key {
    id: UID,
    /// Registry authority
    authority: address,
    /// Version and compatibility info
    version_info: CompatibilityInfo,
    /// Global feature registry
    feature_registry: FeatureRegistry,
    /// Registered modules
    modules: Table<String, ModuleInfo>,
    /// Module configurations
    module_configs: Table<String, ModuleConfig>,
    /// Extensible metadata
    registry_metadata: VecMap<String, String>,
    /// Plugin registry for future extensions
    plugin_registry: Table<String, PluginInfo>,
    /// Event hooks for cross-module communication
    event_hooks: Table<String, vector<String>>, // event_type -> module_names
    /// Registry statistics
    total_modules: u64,
    total_plugins: u64,
    created_at: u64,
    last_updated: u64,
}

/// Module information for registry
public struct ModuleInfo has store {
    module_id: String,
    module_type: u8,
    version: u64,
    api_version: u64,
    is_active: bool,
    dependencies: vector<String>,
    provides: vector<String>, // Services this module provides
    requires: vector<String>, // Services this module requires
    config: ModuleConfig,
    registered_at: u64,
    last_updated: u64,
}

/// Plugin information for extensibility
public struct PluginInfo has store {
    plugin_id: String,
    target_module: String,
    plugin_type: u8, // 0=extension, 1=middleware, 2=hook
    version: u64,
    is_enabled: bool,
    config: VecMap<String, String>,
    registered_at: u64,
}

/// Interface definition for module contracts
public struct ModuleInterface has store {
    interface_id: String,
    version: u64,
    required_functions: vector<String>,
    optional_functions: vector<String>,
    events: vector<String>,
    data_structures: vector<String>,
}

// ===== Events =====

public struct RegistryCreated has copy, drop {
    registry_id: ID,
    authority: address,
    version: u64,
    created_at: u64,
}

public struct ModuleRegistered has copy, drop {
    registry_id: ID,
    module_id: String,
    module_type: u8,
    version: u64,
    registered_by: address,
}

public struct PluginRegistered has copy, drop {
    registry_id: ID,
    plugin_id: String,
    target_module: String,
    plugin_type: u8,
    registered_by: address,
}

public struct FeatureToggled has copy, drop {
    registry_id: ID,
    feature_name: String,
    enabled: bool,
    toggled_by: address,
}

public struct ModuleUpdated has copy, drop {
    registry_id: ID,
    module_id: String,
    old_version: u64,
    new_version: u64,
    updated_by: address,
}

// ===== Registry Management =====

/// Create the central OTL registry
public fun create_otl_registry(ctx: &mut TxContext): OTLRegistry {
    let current_time = utils::current_time_ms();
    let authority = tx_context::sender(ctx);

    let version_info = base::create_compatibility_info(
        base::get_otl_version(),
        vector::empty(),
        vector::empty(),
        false,
    );

    let registry = OTLRegistry {
        id: object::new(ctx),
        authority,
        version_info,
        feature_registry: base::create_feature_registry(),
        modules: table::new(ctx),
        module_configs: table::new(ctx),
        registry_metadata: vec_map::empty(),
        plugin_registry: table::new(ctx),
        event_hooks: table::new(ctx),
        total_modules: 0,
        total_plugins: 0,
        created_at: current_time,
        last_updated: current_time,
    };

    event::emit(RegistryCreated {
        registry_id: object::id(&registry),
        authority,
        version: base::get_otl_version(),
        created_at: current_time,
    });

    registry
}

/// Register a module with the registry
public fun register_module(
    registry: &mut OTLRegistry,
    module_id: String,
    module_type: u8,
    version: u64,
    api_version: u64,
    dependencies: vector<String>,
    provides: vector<String>,
    requires: vector<String>,
    initial_features: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!table::contains(&registry.modules, module_id), base::token_exists_error());

    let current_time = utils::current_time_ms();
    let config = base::create_module_config(module_type, initial_features);

    let module_info = ModuleInfo {
        module_id,
        module_type,
        version,
        api_version,
        is_active: true,
        dependencies,
        provides,
        requires,
        config,
        registered_at: current_time,
        last_updated: current_time,
    };

    table::add(&mut registry.modules, module_info.module_id, module_info);
    registry.total_modules = registry.total_modules + 1;
    registry.last_updated = current_time;

    event::emit(ModuleRegistered {
        registry_id: object::id(registry),
        module_id,
        module_type,
        version,
        registered_by: registry.authority,
    });
}

/// Register a plugin for extensibility
public fun register_plugin(
    registry: &mut OTLRegistry,
    plugin_id: String,
    target_module: String,
    plugin_type: u8,
    version: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!table::contains(&registry.plugin_registry, plugin_id), base::token_exists_error());
    assert!(table::contains(&registry.modules, target_module), base::token_not_found_error());

    let current_time = utils::current_time_ms();

    let plugin_info = PluginInfo {
        plugin_id,
        target_module,
        plugin_type,
        version,
        is_enabled: true,
        config: vec_map::empty(),
        registered_at: current_time,
    };

    table::add(&mut registry.plugin_registry, plugin_info.plugin_id, plugin_info);
    registry.total_plugins = registry.total_plugins + 1;
    registry.last_updated = current_time;

    event::emit(PluginRegistered {
        registry_id: object::id(registry),
        plugin_id,
        target_module,
        plugin_type,
        registered_by: registry.authority,
    });
}

// ===== Feature Management =====

/// Enable global feature
public fun enable_global_feature(
    registry: &mut OTLRegistry,
    feature_flag: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    base::enable_feature(&mut registry.feature_registry, feature_flag);
    registry.last_updated = utils::current_time_ms();
}

/// Disable global feature
public fun disable_global_feature(
    registry: &mut OTLRegistry,
    feature_flag: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    base::disable_feature(&mut registry.feature_registry, feature_flag);
    registry.last_updated = utils::current_time_ms();
}

/// Add custom feature
public fun add_custom_feature(
    registry: &mut OTLRegistry,
    feature_name: String,
    feature_id: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    base::add_custom_feature(&mut registry.feature_registry, feature_name, feature_id);
    registry.last_updated = utils::current_time_ms();
}

/// Toggle custom feature
public fun toggle_custom_feature(
    registry: &mut OTLRegistry,
    feature_name: String,
    enable: bool,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    if (base::is_custom_feature_enabled(&registry.feature_registry, &feature_name) != enable) {
        if (enable) {
            // Enable custom feature by finding its ID and enabling it
            if (base::has_custom_feature(&registry.feature_registry, &feature_name)) {
                let feature_id = base::get_custom_feature_id(
                    &registry.feature_registry,
                    &feature_name,
                );
                base::enable_feature(&mut registry.feature_registry, feature_id);
            };
        } else {
            // Disable custom feature
            if (base::has_custom_feature(&registry.feature_registry, &feature_name)) {
                let feature_id = base::get_custom_feature_id(
                    &registry.feature_registry,
                    &feature_name,
                );
                base::disable_feature(&mut registry.feature_registry, feature_id);
            };
        };

        event::emit(FeatureToggled {
            registry_id: object::id(registry),
            feature_name,
            enabled: enable,
            toggled_by: registry.authority,
        });
    };
}

// ===== Module Management =====

/// Update module version
public fun update_module_version(
    registry: &mut OTLRegistry,
    module_id: String,
    new_version: u64,
    new_api_version: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(table::contains(&registry.modules, module_id), base::token_not_found_error());

    let module_info = table::borrow_mut(&mut registry.modules, module_id);
    let old_version = module_info.version;

    assert!(new_version > old_version, base::invalid_metadata_error());

    module_info.version = new_version;
    module_info.api_version = new_api_version;
    module_info.last_updated = utils::current_time_ms();

    event::emit(ModuleUpdated {
        registry_id: object::id(registry),
        module_id,
        old_version,
        new_version,
        updated_by: registry.authority,
    });
}

/// Enable/disable module
public fun set_module_active(
    registry: &mut OTLRegistry,
    module_id: String,
    is_active: bool,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(table::contains(&registry.modules, module_id), base::token_not_found_error());

    let module_info = table::borrow_mut(&mut registry.modules, module_id);
    module_info.is_active = is_active;
    module_info.last_updated = utils::current_time_ms();
}

/// Add event hook for cross-module communication
public fun add_event_hook(
    registry: &mut OTLRegistry,
    event_type: String,
    module_id: String,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(table::contains(&registry.modules, module_id), base::token_not_found_error());

    if (!table::contains(&registry.event_hooks, event_type)) {
        table::add(&mut registry.event_hooks, event_type, vector::empty());
    };

    let hooks = table::borrow_mut(&mut registry.event_hooks, event_type);
    if (!vector::contains(hooks, &module_id)) {
        vector::push_back(hooks, module_id);
    };
}

// ===== View Functions =====

/// Get registry information
public fun get_registry_info(registry: &OTLRegistry): (u64, u64, u64, u64, u64) {
    (
        base::get_current_version(&registry.version_info),
        registry.total_modules,
        registry.total_plugins,
        registry.created_at,
        registry.last_updated,
    )
}

/// Get module information
public fun get_module_info(registry: &OTLRegistry, module_id: String): (u8, u64, u64, bool) {
    assert!(table::contains(&registry.modules, module_id), base::token_not_found_error());
    let module_info = table::borrow(&registry.modules, module_id);

    (module_info.module_type, module_info.version, module_info.api_version, module_info.is_active)
}

/// Check if feature is enabled
public fun is_feature_enabled(registry: &OTLRegistry, feature_flag: u64): bool {
    base::is_feature_enabled(&registry.feature_registry, feature_flag)
}

/// Check if custom feature is enabled
public fun is_custom_feature_enabled(registry: &OTLRegistry, feature_name: &String): bool {
    base::is_custom_feature_enabled(&registry.feature_registry, feature_name)
}

/// Get all modules for an event type
public fun get_event_hooks(registry: &OTLRegistry, event_type: String): vector<String> {
    if (table::contains(&registry.event_hooks, event_type)) {
        *table::borrow(&registry.event_hooks, event_type)
    } else {
        vector::empty()
    }
}

/// Check module dependencies
public fun check_module_dependencies(registry: &OTLRegistry, module_id: String): bool {
    assert!(table::contains(&registry.modules, module_id), base::token_not_found_error());
    let module_info = table::borrow(&registry.modules, module_id);

    // Check if all dependencies are registered and active
    let mut i = 0;
    while (i < vector::length(&module_info.dependencies)) {
        let dep_id = *vector::borrow(&module_info.dependencies, i);
        if (!table::contains(&registry.modules, dep_id)) {
            return false
        };

        let dep_info = table::borrow(&registry.modules, dep_id);
        if (!dep_info.is_active) {
            return false
        };

        i = i + 1;
    };

    true
}

/// Get compatibility info
public fun get_compatibility_info(registry: &OTLRegistry): CompatibilityInfo {
    registry.version_info
}

// ===== Administrative Functions =====

/// Transfer registry authority
public fun transfer_registry_authority(
    registry: &mut OTLRegistry,
    new_authority: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(utils::validate_address(new_authority), base::invalid_address_error());

    registry.authority = new_authority;
    registry.last_updated = utils::current_time_ms();
}

/// Add registry metadata
public fun add_registry_metadata(
    registry: &mut OTLRegistry,
    key: String,
    value: String,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    if (vec_map::contains(&registry.registry_metadata, &key)) {
        *vec_map::get_mut(&mut registry.registry_metadata, &key) = value;
    } else {
        vec_map::insert(&mut registry.registry_metadata, key, value);
    };

    registry.last_updated = utils::current_time_ms();
}

/// Create and share registry
public entry fun create_and_share_otl_registry(ctx: &mut TxContext) {
    let registry = create_otl_registry(ctx);
    transfer::share_object(registry);
}
