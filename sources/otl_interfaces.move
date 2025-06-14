#[allow(unused_const, duplicate_alias, unused_variable)]
module otl::otl_interfaces;

use otl::base;
use std::string::{Self, String};
use sui::object::ID;
use sui::vec_map::{Self, VecMap};

// ===== Standard Interface Types =====

/// Token interface for all token-like modules
public struct IToken has copy, drop, store {
    interface_version: u64,
    supports_transfer: bool,
    supports_burn: bool,
    supports_mint: bool,
    supports_metadata: bool,
    custom_capabilities: VecMap<String, bool>,
}

/// NFT interface for collectible modules
public struct INFTCollection has copy, drop, store {
    interface_version: u64,
    supports_royalties: bool,
    supports_attributes: bool,
    supports_evolution: bool,
    supports_staking: bool,
    supports_kiosk: bool,
    custom_capabilities: VecMap<String, bool>,
}

/// Payment interface for payment processing
public struct IPayment has copy, drop, store {
    interface_version: u64,
    supports_escrow: bool,
    supports_batch: bool,
    supports_recurring: bool,
    supports_multi_currency: bool,
    custom_capabilities: VecMap<String, bool>,
}

/// Social interface for social features
public struct ISocial has copy, drop, store {
    interface_version: u64,
    supports_profiles: bool,
    supports_reputation: bool,
    supports_messaging: bool,
    supports_groups: bool,
    custom_capabilities: VecMap<String, bool>,
}

/// Analytics interface for data tracking
public struct IAnalytics has copy, drop, store {
    interface_version: u64,
    supports_events: bool,
    supports_metrics: bool,
    supports_reporting: bool,
    supports_realtime: bool,
    custom_capabilities: VecMap<String, bool>,
}

// ===== Module Interface Registry =====

/// Interface implementation info
public struct InterfaceImplementation has store {
    module_id: String,
    interface_type: String,
    implementation_version: u64,
    is_compliant: bool,
    last_validated: u64,
    custom_extensions: VecMap<String, String>,
}

// ===== Interface Validation =====

/// Validate token interface compliance
public fun validate_token_interface(
    supports_transfer: bool,
    supports_burn: bool,
    supports_mint: bool,
    supports_metadata: bool,
): bool {
    // Minimum requirements for token interface
    supports_transfer && supports_metadata
}

/// Validate NFT interface compliance
public fun validate_nft_interface(supports_attributes: bool, supports_kiosk: bool): bool {
    // Minimum requirements for NFT interface
    supports_attributes
}

/// Validate payment interface compliance
public fun validate_payment_interface(supports_escrow: bool, supports_batch: bool): bool {
    // Minimum requirements for payment interface
    supports_escrow || supports_batch
}

// ===== Interface Creation =====

/// Create standard token interface
public fun create_token_interface(
    supports_transfer: bool,
    supports_burn: bool,
    supports_mint: bool,
    supports_metadata: bool,
): IToken {
    IToken {
        interface_version: base::get_api_version(),
        supports_transfer,
        supports_burn,
        supports_mint,
        supports_metadata,
        custom_capabilities: vec_map::empty(),
    }
}

/// Create NFT collection interface
public fun create_nft_interface(
    supports_royalties: bool,
    supports_attributes: bool,
    supports_evolution: bool,
    supports_staking: bool,
    supports_kiosk: bool,
): INFTCollection {
    INFTCollection {
        interface_version: base::get_api_version(),
        supports_royalties,
        supports_attributes,
        supports_evolution,
        supports_staking,
        supports_kiosk,
        custom_capabilities: vec_map::empty(),
    }
}

/// Create payment interface
public fun create_payment_interface(
    supports_escrow: bool,
    supports_batch: bool,
    supports_recurring: bool,
    supports_multi_currency: bool,
): IPayment {
    IPayment {
        interface_version: base::get_api_version(),
        supports_escrow,
        supports_batch,
        supports_recurring,
        supports_multi_currency,
        custom_capabilities: vec_map::empty(),
    }
}

/// Create social interface
public fun create_social_interface(
    supports_profiles: bool,
    supports_reputation: bool,
    supports_messaging: bool,
    supports_groups: bool,
): ISocial {
    ISocial {
        interface_version: base::get_api_version(),
        supports_profiles,
        supports_reputation,
        supports_messaging,
        supports_groups,
        custom_capabilities: vec_map::empty(),
    }
}

/// Create analytics interface
public fun create_analytics_interface(
    supports_events: bool,
    supports_metrics: bool,
    supports_reporting: bool,
    supports_realtime: bool,
): IAnalytics {
    IAnalytics {
        interface_version: base::get_api_version(),
        supports_events,
        supports_metrics,
        supports_reporting,
        supports_realtime,
        custom_capabilities: vec_map::empty(),
    }
}

// ===== Interface Extension =====

/// Add custom capability to token interface
public fun add_token_capability(
    interface: &mut IToken,
    capability_name: String,
    is_supported: bool,
) {
    vec_map::insert(&mut interface.custom_capabilities, capability_name, is_supported);
}

/// Add custom capability to NFT interface
public fun add_nft_capability(
    interface: &mut INFTCollection,
    capability_name: String,
    is_supported: bool,
) {
    vec_map::insert(&mut interface.custom_capabilities, capability_name, is_supported);
}

/// Add custom capability to payment interface
public fun add_payment_capability(
    interface: &mut IPayment,
    capability_name: String,
    is_supported: bool,
) {
    vec_map::insert(&mut interface.custom_capabilities, capability_name, is_supported);
}

// ===== Interface Queries =====

/// Check if token interface supports capability
public fun token_supports_capability(interface: &IToken, capability: &String): bool {
    if (vec_map::contains(&interface.custom_capabilities, capability)) {
        *vec_map::get(&interface.custom_capabilities, capability)
    } else {
        false
    }
}

/// Check if NFT interface supports capability
public fun nft_supports_capability(interface: &INFTCollection, capability: &String): bool {
    if (vec_map::contains(&interface.custom_capabilities, capability)) {
        *vec_map::get(&interface.custom_capabilities, capability)
    } else {
        false
    }
}

/// Check if payment interface supports capability
public fun payment_supports_capability(interface: &IPayment, capability: &String): bool {
    if (vec_map::contains(&interface.custom_capabilities, capability)) {
        *vec_map::get(&interface.custom_capabilities, capability)
    } else {
        false
    }
}

// ===== Interface Information =====

/// Get token interface capabilities
public fun get_token_capabilities(interface: &IToken): (bool, bool, bool, bool, u64) {
    (
        interface.supports_transfer,
        interface.supports_burn,
        interface.supports_mint,
        interface.supports_metadata,
        interface.interface_version,
    )
}

/// Get NFT interface capabilities
public fun get_nft_capabilities(interface: &INFTCollection): (bool, bool, bool, bool, bool, u64) {
    (
        interface.supports_royalties,
        interface.supports_attributes,
        interface.supports_evolution,
        interface.supports_staking,
        interface.supports_kiosk,
        interface.interface_version,
    )
}

/// Get payment interface capabilities
public fun get_payment_capabilities(interface: &IPayment): (bool, bool, bool, bool, u64) {
    (
        interface.supports_escrow,
        interface.supports_batch,
        interface.supports_recurring,
        interface.supports_multi_currency,
        interface.interface_version,
    )
}

/// Get social interface capabilities
public fun get_social_capabilities(interface: &ISocial): (bool, bool, bool, bool, u64) {
    (
        interface.supports_profiles,
        interface.supports_reputation,
        interface.supports_messaging,
        interface.supports_groups,
        interface.interface_version,
    )
}

/// Get analytics interface capabilities
public fun get_analytics_capabilities(interface: &IAnalytics): (bool, bool, bool, bool, u64) {
    (
        interface.supports_events,
        interface.supports_metrics,
        interface.supports_reporting,
        interface.supports_realtime,
        interface.interface_version,
    )
}

// ===== Compatibility Checking =====

/// Check interface version compatibility
public fun is_interface_compatible(interface_version: u64): bool {
    base::is_version_compatible(interface_version)
}

/// Check if two token interfaces are compatible
public fun are_token_interfaces_compatible(interface1: &IToken, interface2: &IToken): bool {
    // Interfaces are compatible if they support the same base features
    interface1.supports_transfer == interface2.supports_transfer &&
    interface1.supports_metadata == interface2.supports_metadata
}

/// Create implementation info
public fun create_interface_implementation(
    module_id: String,
    interface_type: String,
    implementation_version: u64,
    is_compliant: bool,
    last_validated: u64,
): InterfaceImplementation {
    InterfaceImplementation {
        module_id,
        interface_type,
        implementation_version,
        is_compliant,
        last_validated,
        custom_extensions: vec_map::empty(),
    }
}

/// Add custom extension to implementation
public fun add_implementation_extension(
    implementation: &mut InterfaceImplementation,
    extension_name: String,
    extension_value: String,
) {
    vec_map::insert(&mut implementation.custom_extensions, extension_name, extension_value);
}

/// Get implementation info
public fun get_implementation_info(
    implementation: &InterfaceImplementation,
): (String, String, u64, bool, u64) {
    (
        implementation.module_id,
        implementation.interface_type,
        implementation.implementation_version,
        implementation.is_compliant,
        implementation.last_validated,
    )
}
