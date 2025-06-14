#[allow(unused_const, duplicate_alias, unused_variable)]
module otl::base;

use std::string::{Self, String};
use sui::vec_map::{Self, VecMap};

// ===== Version Management =====
const OTL_VERSION: u64 = 1;
const MIN_COMPATIBLE_VERSION: u64 = 1;
const API_VERSION: u64 = 1;

// ===== Error Codes (Backward Compatible) =====
const INSUFFICIENT_BALANCE: u64 = 1001;
const INVALID_AMOUNT: u64 = 1002;
const NOT_AUTHORIZED: u64 = 1003;
const SUPPLY_EXCEEDED: u64 = 1004;
const INVALID_METADATA: u64 = 1005;
const TOKEN_NOT_FOUND: u64 = 1006;
const TOKEN_EXISTS: u64 = 1007;
const MINTER_EXISTS: u64 = 1008;
const INVALID_DESCRIPTION: u64 = 1009;
const INVALID_URL: u64 = 1010;
const INVALID_ADDRESS: u64 = 1011;
const BATCH_TOO_LARGE: u64 = 1012;
const FEATURE_NOT_ENABLED: u64 = 1013;
const VERSION_INCOMPATIBLE: u64 = 1014;
const MIGRATION_REQUIRED: u64 = 1015;
const ACCOUNT_EXISTS: u64 = 1016;
const ACCOUNT_NOT_FOUND: u64 = 1017;
const ROLE_EXISTS: u64 = 1018;
const ROLE_NOT_FOUND: u64 = 1019;
const INVALID_NAME: u64 = 1020;
const INVALID_SYMBOL: u64 = 1021;
const INVALID_SUPPLY: u64 = 1022;
const INVALID_DECIMALS: u64 = 1023;

// ===== Feature Flags (Extensible) =====
const FEATURE_STAKING: u64 = 1;
const FEATURE_GOVERNANCE: u64 = 2;
const FEATURE_YIELD_FARMING: u64 = 4;
const FEATURE_CROSS_CHAIN: u64 = 8;
const FEATURE_ANALYTICS: u64 = 16;
const FEATURE_BATCH_OPERATIONS: u64 = 32;
const FEATURE_ADVANCED_PRICING: u64 = 64;
const FEATURE_COMPLIANCE: u64 = 128;

// ===== Module Types (Registry) =====
const MODULE_TYPE_TOKEN: u8 = 1;
const MODULE_TYPE_COLLECTIBLE: u8 = 2;
const MODULE_TYPE_TICKET: u8 = 3;
const MODULE_TYPE_LOYALTY: u8 = 4;
const MODULE_TYPE_UTILITY: u8 = 5;
const MODULE_TYPE_SOCIAL: u8 = 6;
const MODULE_TYPE_PAYMENT: u8 = 7;
const MODULE_TYPE_ANALYTICS: u8 = 8;

// ===== Validation Limits (Configurable) =====
const MAX_NAME_LENGTH: u64 = 64;
const MAX_SYMBOL_LENGTH: u64 = 12;
const MAX_DESCRIPTION_LENGTH: u64 = 1024;
const MAX_URL_LENGTH: u64 = 256;
const MAX_BATCH_SIZE: u64 = 1000;
const MIN_BATCH_SIZE: u64 = 10;

// ===== Supply and Validation Limits =====
const MAX_SUPPLY: u64 = 1000000000000000000; // 1 quintillion max supply
const MAX_DECIMALS: u8 = 18; // Maximum decimal places for tokens

// ===== Extensible Configuration =====

/// Module configuration with versioning and feature flags
public struct ModuleConfig has copy, drop, store {
    version: u64,
    api_version: u64,
    feature_flags: u64,
    module_type: u8,
    is_enabled: bool,
    created_at: u64,
    updated_at: u64,
    config_attributes: VecMap<String, String>,
}

/// Backward compatibility info
public struct CompatibilityInfo has copy, drop, store {
    current_version: u64,
    min_compatible_version: u64,
    breaking_changes: vector<String>,
    deprecated_functions: vector<String>,
    migration_required: bool,
}

/// Feature registry for dynamic loading
public struct FeatureRegistry has store {
    enabled_features: u64, // Bitfield
    feature_configs: VecMap<String, String>,
    custom_features: VecMap<String, u64>, // Custom feature IDs
}

// ===== Error Functions (Backward Compatible) =====

public fun insufficient_balance_error(): u64 { INSUFFICIENT_BALANCE }

public fun invalid_amount_error(): u64 { INVALID_AMOUNT }

public fun not_authorized_error(): u64 { NOT_AUTHORIZED }

public fun supply_exceeded_error(): u64 { SUPPLY_EXCEEDED }

public fun invalid_metadata_error(): u64 { INVALID_METADATA }

public fun token_not_found_error(): u64 { TOKEN_NOT_FOUND }

public fun token_exists_error(): u64 { TOKEN_EXISTS }

public fun minter_exists_error(): u64 { MINTER_EXISTS }

public fun invalid_description_error(): u64 { INVALID_DESCRIPTION }

public fun invalid_url_error(): u64 { INVALID_URL }

public fun invalid_address_error(): u64 { INVALID_ADDRESS }

public fun batch_too_large_error(): u64 { BATCH_TOO_LARGE }

public fun feature_not_enabled_error(): u64 { FEATURE_NOT_ENABLED }

public fun version_incompatible_error(): u64 { VERSION_INCOMPATIBLE }

public fun migration_required_error(): u64 { MIGRATION_REQUIRED }

public fun account_exists_error(): u64 { ACCOUNT_EXISTS }

public fun account_not_found_error(): u64 { ACCOUNT_NOT_FOUND }

public fun role_exists_error(): u64 { ROLE_EXISTS }

public fun role_not_found_error(): u64 { ROLE_NOT_FOUND }

public fun invalid_name_error(): u64 { INVALID_NAME }

public fun invalid_symbol_error(): u64 { INVALID_SYMBOL }

public fun invalid_supply_error(): u64 { INVALID_SUPPLY }

public fun invalid_decimals_error(): u64 { INVALID_DECIMALS }

// ===== Version Management =====

public fun get_otl_version(): u64 { OTL_VERSION }

public fun get_api_version(): u64 { API_VERSION }

public fun get_min_compatible_version(): u64 { MIN_COMPATIBLE_VERSION }

public fun is_version_compatible(version: u64): bool {
    version >= MIN_COMPATIBLE_VERSION && version <= OTL_VERSION
}

public fun create_compatibility_info(
    current_version: u64,
    breaking_changes: vector<String>,
    deprecated_functions: vector<String>,
    migration_required: bool,
): CompatibilityInfo {
    CompatibilityInfo {
        current_version,
        min_compatible_version: MIN_COMPATIBLE_VERSION,
        breaking_changes,
        deprecated_functions,
        migration_required,
    }
}

// ===== Feature Management =====

public fun create_feature_registry(): FeatureRegistry {
    FeatureRegistry {
        enabled_features: 0,
        feature_configs: vec_map::empty(),
        custom_features: vec_map::empty(),
    }
}

public fun enable_feature(registry: &mut FeatureRegistry, feature_flag: u64) {
    registry.enabled_features = registry.enabled_features | feature_flag;
}

public fun disable_feature(registry: &mut FeatureRegistry, feature_flag: u64) {
    registry.enabled_features = registry.enabled_features & (18446744073709551615 ^ feature_flag);
}

public fun is_feature_enabled(registry: &FeatureRegistry, feature_flag: u64): bool {
    (registry.enabled_features & feature_flag) != 0
}

public fun add_custom_feature(
    registry: &mut FeatureRegistry,
    feature_name: String,
    feature_id: u64,
) {
    vec_map::insert(&mut registry.custom_features, feature_name, feature_id);
}

public fun is_custom_feature_enabled(registry: &FeatureRegistry, feature_name: &String): bool {
    if (vec_map::contains(&registry.custom_features, feature_name)) {
        let feature_id = *vec_map::get(&registry.custom_features, feature_name);
        is_feature_enabled(registry, feature_id)
    } else {
        false
    }
}

// ===== Module Configuration =====

public fun create_module_config(module_type: u8, initial_features: u64): ModuleConfig {
    ModuleConfig {
        version: OTL_VERSION,
        api_version: API_VERSION,
        feature_flags: initial_features,
        module_type,
        is_enabled: true,
        created_at: 0, // Will be set by caller
        updated_at: 0,
        config_attributes: vec_map::empty(),
    }
}

public fun update_module_config(config: &mut ModuleConfig, new_features: u64, updated_at: u64) {
    config.feature_flags = new_features;
    config.updated_at = updated_at;
}

public fun add_config_attribute(config: &mut ModuleConfig, key: String, value: String) {
    if (vec_map::contains(&config.config_attributes, &key)) {
        *vec_map::get_mut(&mut config.config_attributes, &key) = value;
    } else {
        vec_map::insert(&mut config.config_attributes, key, value);
    }
}

public fun get_config_attribute(config: &ModuleConfig, key: &String): String {
    if (vec_map::contains(&config.config_attributes, key)) {
        *vec_map::get(&config.config_attributes, key)
    } else {
        string::utf8(b"")
    }
}

// ===== Validation Constants =====

public fun max_name_length(): u64 { MAX_NAME_LENGTH }

public fun max_symbol_length(): u64 { MAX_SYMBOL_LENGTH }

public fun max_description_length(): u64 { MAX_DESCRIPTION_LENGTH }

public fun max_url_length(): u64 { MAX_URL_LENGTH }

public fun max_batch_size(): u64 { MAX_BATCH_SIZE }

public fun min_batch_size(): u64 { MIN_BATCH_SIZE }

public fun max_supply(): u64 { MAX_SUPPLY }

public fun max_decimals(): u8 { MAX_DECIMALS }

// ===== Module Type Constants =====

public fun module_type_token(): u8 { MODULE_TYPE_TOKEN }

public fun module_type_collectible(): u8 { MODULE_TYPE_COLLECTIBLE }

public fun module_type_ticket(): u8 { MODULE_TYPE_TICKET }

public fun module_type_loyalty(): u8 { MODULE_TYPE_LOYALTY }

public fun module_type_utility(): u8 { MODULE_TYPE_UTILITY }

public fun module_type_social(): u8 { MODULE_TYPE_SOCIAL }

public fun module_type_payment(): u8 { MODULE_TYPE_PAYMENT }

public fun module_type_analytics(): u8 { MODULE_TYPE_ANALYTICS }

// ===== Feature Flag Constants =====

public fun feature_staking(): u64 { FEATURE_STAKING }

public fun feature_governance(): u64 { FEATURE_GOVERNANCE }

public fun feature_yield_farming(): u64 { FEATURE_YIELD_FARMING }

public fun feature_cross_chain(): u64 { FEATURE_CROSS_CHAIN }

public fun feature_analytics(): u64 { FEATURE_ANALYTICS }

public fun feature_batch_operations(): u64 { FEATURE_BATCH_OPERATIONS }

public fun feature_advanced_pricing(): u64 { FEATURE_ADVANCED_PRICING }

public fun feature_compliance(): u64 { FEATURE_COMPLIANCE }

// ===== Getter Functions for Private Fields =====

/// Get current version from compatibility info
public fun get_current_version(info: &CompatibilityInfo): u64 {
    info.current_version
}

/// Get custom features map reference
public fun get_custom_features_map(registry: &FeatureRegistry): &VecMap<String, u64> {
    &registry.custom_features
}

/// Check if custom feature exists in registry
public fun has_custom_feature(registry: &FeatureRegistry, feature_name: &String): bool {
    vec_map::contains(&registry.custom_features, feature_name)
}

/// Get custom feature ID
public fun get_custom_feature_id(registry: &FeatureRegistry, feature_name: &String): u64 {
    assert!(vec_map::contains(&registry.custom_features, feature_name), token_not_found_error());
    *vec_map::get(&registry.custom_features, feature_name)
}
