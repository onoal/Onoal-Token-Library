#[allow(unused_const, duplicate_alias, unused_variable)]
module otl::upgrade;

use otl::base;
use otl::utils;
use std::string::{Self, String};
use sui::event;
use sui::object::{Self, UID, ID};
use sui::package::{Self, UpgradeCap};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

// ===== Constants =====
const CURRENT_VERSION: u64 = 1;

// ===== Minimal Structs =====

/// Simplified upgrade manager
public struct UpgradeManager has key {
    id: UID,
    /// Package authority
    authority: address,
    /// Upgrade capability
    upgrade_cap: UpgradeCap,
    /// Version tracking
    current_version: u64,
    /// Emergency controls
    emergency_pause: bool,
    emergency_admin: address,
}

// ===== Events =====

public struct PackageUpgraded has copy, drop {
    manager_id: ID,
    from_version: u64,
    to_version: u64,
    upgraded_by: address,
}

public struct EmergencyPauseActivated has copy, drop {
    manager_id: ID,
    activated_by: address,
    reason: String,
}

// ===== Core Functions =====

/// Create minimal upgrade manager
public fun create_upgrade_manager(
    upgrade_cap: UpgradeCap,
    emergency_admin: address,
    ctx: &mut TxContext,
): UpgradeManager {
    UpgradeManager {
        id: object::new(ctx),
        authority: tx_context::sender(ctx),
        upgrade_cap,
        current_version: CURRENT_VERSION,
        emergency_pause: false,
        emergency_admin,
    }
}

/// Execute package upgrade
public fun execute_upgrade(manager: &mut UpgradeManager, new_version: u64, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == manager.authority, base::not_authorized_error());
    assert!(!manager.emergency_pause, base::invalid_metadata_error());
    assert!(new_version > manager.current_version, base::invalid_metadata_error());

    let old_version = manager.current_version;
    manager.current_version = new_version;

    event::emit(PackageUpgraded {
        manager_id: object::id(manager),
        from_version: old_version,
        to_version: new_version,
        upgraded_by: manager.authority,
    });
}

// ===== Emergency Controls =====

/// Activate emergency pause
public fun activate_emergency_pause(
    manager: &mut UpgradeManager,
    reason: vector<u8>,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(
        sender == manager.authority || sender == manager.emergency_admin,
        base::not_authorized_error(),
    );

    manager.emergency_pause = true;

    event::emit(EmergencyPauseActivated {
        manager_id: object::id(manager),
        activated_by: sender,
        reason: utils::safe_utf8(reason),
    });
}

/// Deactivate emergency pause
public fun deactivate_emergency_pause(manager: &mut UpgradeManager, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == manager.authority, base::not_authorized_error());
    manager.emergency_pause = false;
}

// ===== View Functions =====

/// Get basic upgrade info
public fun get_upgrade_info(manager: &UpgradeManager): (u64, bool, address) {
    (manager.current_version, manager.emergency_pause, manager.emergency_admin)
}

/// Check if upgrade is paused
public fun is_upgrade_paused(manager: &UpgradeManager): bool {
    manager.emergency_pause
}

/// Get upgrade capability (for actual package upgrade)
public fun borrow_upgrade_cap(manager: &UpgradeManager): &UpgradeCap {
    &manager.upgrade_cap
}

// ===== Administrative Functions =====

/// Transfer upgrade authority
public fun transfer_upgrade_authority(
    manager: &mut UpgradeManager,
    new_authority: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == manager.authority, base::not_authorized_error());
    assert!(utils::validate_address(new_authority), base::not_authorized_error());
    manager.authority = new_authority;
}

/// Update emergency admin
public fun update_emergency_admin(
    manager: &mut UpgradeManager,
    new_admin: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == manager.authority, base::not_authorized_error());
    manager.emergency_admin = new_admin;
}

/// Create and share upgrade manager
public entry fun create_and_share_upgrade_manager(
    upgrade_cap: UpgradeCap,
    emergency_admin: address,
    ctx: &mut TxContext,
) {
    let manager = create_upgrade_manager(upgrade_cap, emergency_admin, ctx);
    transfer::share_object(manager);
}
