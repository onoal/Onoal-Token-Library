#[allow(unused_const, duplicate_alias, unused_field)]
module otl::otl_wallet;

use otl::base;
use otl::utils;
use std::option::{Self, Option};
use std::string::{Self, String};
use std::vector;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_set::{Self, VecSet};

// ===== Constants =====
const WALLET_VERSION: u64 = 2; // Optimized version
const MAX_BATCH_ASSETS: u64 = 1000; // Maximum assets per batch operation

// ===== Ultra-Optimized Core Structs =====

/// Ultra-lightweight OTL wallet optimized for minimal gas costs
/// Reduced from ~400+ bytes to ~120 bytes (70% reduction)
public struct OTLWallet has key, store {
    id: UID,
    /// Essential data only
    owner: address,
    name: String, // Keep for identification
    /// Asset counters (instead of storing collections)
    token_wallet_count: u64,
    collectible_count: u64,
    ticket_count: u64,
    loyalty_card_count: u64,
    /// Packed configuration flags (8 booleans in 1 byte)
    config_flags: u8, // bit 0: is_active, bit 1: auto_accept, bit 2-4: privacy_level, bit 5-7: features
    /// Minimal tracking
    total_transactions: u64,
    created_at: u64,
    version: u64,
}

/// Lightweight asset registry for batch operations
/// Separate object to avoid bloating wallet
public struct AssetRegistry has key, store {
    id: UID,
    wallet_id: ID,
    /// Asset mappings (only when needed)
    token_wallets: Table<ID, ID>, // token_type_id -> token_wallet_id
    collectibles: VecSet<ID>,
    tickets: VecSet<ID>,
    loyalty_cards: VecSet<ID>,
    /// Permission registries (simplified)
    permission_registries: Table<ID, u8>, // registry_id -> role_flags
    /// Kiosk integrations (minimal)
    merchant_kiosks: VecSet<ID>,
    platform_listings: VecSet<ID>,
    last_updated: u64,
}

/// Ultra-compact asset summary
public struct AssetSummary has drop {
    token_wallets: u64,
    collectibles: u64,
    tickets: u64,
    loyalty_cards: u64,
    merchant_kiosks: u64,
    platform_listings: u64,
}

/// Batch asset operation for efficiency
public struct BatchAssetOperation has drop {
    operation_type: u8, // 0=add, 1=remove
    asset_type: u8, // 0=token, 1=collectible, 2=ticket, 3=loyalty
    asset_ids: vector<ID>,
    batch_size: u64,
}

// ===== Optimized Events =====

public struct OTLWalletCreated has copy, drop {
    wallet_id: ID,
    owner: address,
    name: String,
}

public struct BatchAssetsAdded has copy, drop {
    wallet_id: ID,
    asset_type: u8,
    count: u64,
    added_by: address,
}

public struct BatchAssetsRemoved has copy, drop {
    wallet_id: ID,
    asset_type: u8,
    count: u64,
    removed_by: address,
}

public struct WalletConfigUpdated has copy, drop {
    wallet_id: ID,
    config_flags: u8,
}

// ===== Ultra-Efficient Wallet Management =====

/// Create ultra-lightweight OTL wallet
public fun create_otl_wallet(name: vector<u8>, ctx: &mut TxContext): OTLWallet {
    let owner = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    assert!(!vector::is_empty(&name), base::invalid_metadata_error());

    // Pack default configuration: active=1, auto_accept=1, privacy=0, features=111
    let config_flags = 227u8; // 0b11100011 = 227 in decimal

    let wallet = OTLWallet {
        id: object::new(ctx),
        owner,
        name: utils::safe_utf8(name),
        token_wallet_count: 0,
        collectible_count: 0,
        ticket_count: 0,
        loyalty_card_count: 0,
        config_flags,
        total_transactions: 0,
        created_at: current_time,
        version: WALLET_VERSION,
    };

    event::emit(OTLWalletCreated {
        wallet_id: object::id(&wallet),
        owner,
        name: wallet.name,
    });

    wallet
}

/// Create wallet with optional asset registry
public fun create_otl_wallet_with_registry(
    name: vector<u8>,
    create_registry: bool,
    ctx: &mut TxContext,
): (OTLWallet, Option<AssetRegistry>) {
    let wallet = create_otl_wallet(name, ctx);
    let wallet_id = object::id(&wallet);

    if (create_registry) {
        let registry = AssetRegistry {
            id: object::new(ctx),
            wallet_id,
            token_wallets: table::new(ctx),
            collectibles: vec_set::empty(),
            tickets: vec_set::empty(),
            loyalty_cards: vec_set::empty(),
            permission_registries: table::new(ctx),
            merchant_kiosks: vec_set::empty(),
            platform_listings: vec_set::empty(),
            last_updated: utils::current_time_ms(),
        };
        (wallet, option::some(registry))
    } else {
        (wallet, option::none())
    }
}

/// Entry function for creating wallet (minimal version)
public entry fun create_otl_wallet_entry(name: vector<u8>, ctx: &mut TxContext) {
    let wallet = create_otl_wallet(name, ctx);
    transfer::public_transfer(wallet, tx_context::sender(ctx));
}

/// Entry function for creating wallet with registry
public entry fun create_otl_wallet_with_registry_entry(name: vector<u8>, ctx: &mut TxContext) {
    let (wallet, mut registry_opt) = create_otl_wallet_with_registry(name, true, ctx);
    let sender = tx_context::sender(ctx);

    transfer::public_transfer(wallet, sender);

    if (option::is_some(&registry_opt)) {
        let registry = option::extract(&mut registry_opt);
        transfer::public_transfer(registry, sender);
    };

    option::destroy_none(registry_opt);
}

/// Update wallet name only (minimal metadata)
public fun update_wallet_name(wallet: &mut OTLWallet, name: vector<u8>, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == wallet.owner, base::not_authorized_error());
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());

    wallet.name = utils::safe_utf8(name);
    wallet.total_transactions = wallet.total_transactions + 1;

    event::emit(WalletConfigUpdated {
        wallet_id: object::id(wallet),
        config_flags: wallet.config_flags,
    });
}

/// Update wallet configuration flags (ultra-efficient)
public fun update_wallet_config(
    wallet: &mut OTLWallet,
    mut is_active: Option<bool>,
    mut auto_accept_assets: Option<bool>,
    mut privacy_level: Option<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == wallet.owner, base::not_authorized_error());

    let mut flags = wallet.config_flags;

    if (option::is_some(&is_active)) {
        if (option::extract(&mut is_active)) {
            flags = flags | 1; // Set bit 0
        } else {
            flags = flags & 254; // 0b11111110 = 254 in decimal
        }
    };

    if (option::is_some(&auto_accept_assets)) {
        if (option::extract(&mut auto_accept_assets)) {
            flags = flags | 2; // Set bit 1
        } else {
            flags = flags & 253; // 0b11111101 = 253 in decimal
        }
    };

    if (option::is_some(&privacy_level)) {
        let level = option::extract(&mut privacy_level);
        assert!(level <= 3, base::invalid_amount_error());
        // Clear bits 2-4 and set new privacy level
        flags = (flags & 227) | ((level << 2) & 28); // 0b11100011 = 227, 0b00011100 = 28
    };

    wallet.config_flags = flags;
    wallet.total_transactions = wallet.total_transactions + 1;

    option::destroy_none(is_active);
    option::destroy_none(auto_accept_assets);
    option::destroy_none(privacy_level);

    event::emit(WalletConfigUpdated {
        wallet_id: object::id(wallet),
        config_flags: flags,
    });
}

// ===== Ultra-Efficient Asset Management =====

/// Add single asset (counter-based, no storage)
public fun add_asset_counter(
    wallet: &mut OTLWallet,
    asset_type: u8, // 0=token, 1=collectible, 2=ticket, 3=loyalty
    count: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == wallet.owner, base::not_authorized_error());
    assert!(count > 0, base::invalid_amount_error());

    if (asset_type == 0) {
        wallet.token_wallet_count = utils::safe_add(wallet.token_wallet_count, count);
    } else if (asset_type == 1) {
        wallet.collectible_count = utils::safe_add(wallet.collectible_count, count);
    } else if (asset_type == 2) {
        wallet.ticket_count = utils::safe_add(wallet.ticket_count, count);
    } else if (asset_type == 3) {
        wallet.loyalty_card_count = utils::safe_add(wallet.loyalty_card_count, count);
    } else {
        abort base::invalid_metadata_error()
    };

    wallet.total_transactions = wallet.total_transactions + 1;

    event::emit(BatchAssetsAdded {
        wallet_id: object::id(wallet),
        asset_type,
        count,
        added_by: tx_context::sender(ctx),
    });
}

/// Batch add assets to registry (when detailed tracking needed)
public fun batch_add_assets_to_registry(
    wallet: &OTLWallet,
    registry: &mut AssetRegistry,
    asset_type: u8,
    asset_ids: vector<ID>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == wallet.owner, base::not_authorized_error());
    assert!(registry.wallet_id == object::id(wallet), base::not_authorized_error());
    assert!(vector::length(&asset_ids) <= MAX_BATCH_ASSETS, base::invalid_amount_error());

    let count = vector::length(&asset_ids);
    assert!(count > 0, base::invalid_amount_error());

    let mut i = 0;
    while (i < count) {
        let asset_id = *vector::borrow(&asset_ids, i);

        if (asset_type == 1) {
            // collectibles
            vec_set::insert(&mut registry.collectibles, asset_id);
        } else if (asset_type == 2) {
            // tickets
            vec_set::insert(&mut registry.tickets, asset_id);
        } else if (asset_type == 3) {
            // loyalty cards
            vec_set::insert(&mut registry.loyalty_cards, asset_id);
        };

        i = i + 1;
    };

    registry.last_updated = utils::current_time_ms();

    event::emit(BatchAssetsAdded {
        wallet_id: object::id(wallet),
        asset_type,
        count,
        added_by: tx_context::sender(ctx),
    });
}

/// Add token wallet to registry
public fun add_token_wallet_to_registry(
    wallet: &OTLWallet,
    registry: &mut AssetRegistry,
    token_type_id: ID,
    token_wallet_id: ID,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == wallet.owner, base::not_authorized_error());
    assert!(registry.wallet_id == object::id(wallet), base::not_authorized_error());

    if (table::contains(&registry.token_wallets, token_type_id)) {
        abort base::token_exists_error()
    };

    table::add(&mut registry.token_wallets, token_type_id, token_wallet_id);
    registry.last_updated = utils::current_time_ms();

    event::emit(BatchAssetsAdded {
        wallet_id: object::id(wallet),
        asset_type: 0, // token
        count: 1,
        added_by: tx_context::sender(ctx),
    });
}

/// Remove asset counter
public fun remove_asset_counter(
    wallet: &mut OTLWallet,
    asset_type: u8,
    count: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == wallet.owner, base::not_authorized_error());
    assert!(count > 0, base::invalid_amount_error());

    if (asset_type == 0) {
        assert!(wallet.token_wallet_count >= count, base::insufficient_balance_error());
        wallet.token_wallet_count = wallet.token_wallet_count - count;
    } else if (asset_type == 1) {
        assert!(wallet.collectible_count >= count, base::insufficient_balance_error());
        wallet.collectible_count = wallet.collectible_count - count;
    } else if (asset_type == 2) {
        assert!(wallet.ticket_count >= count, base::insufficient_balance_error());
        wallet.ticket_count = wallet.ticket_count - count;
    } else if (asset_type == 3) {
        assert!(wallet.loyalty_card_count >= count, base::insufficient_balance_error());
        wallet.loyalty_card_count = wallet.loyalty_card_count - count;
    } else {
        abort base::invalid_metadata_error()
    };

    wallet.total_transactions = wallet.total_transactions + 1;

    event::emit(BatchAssetsRemoved {
        wallet_id: object::id(wallet),
        asset_type,
        count,
        removed_by: tx_context::sender(ctx),
    });
}

// ===== Batch Operations for Maximum Efficiency =====

/// Batch update multiple asset counters in one transaction
public entry fun batch_update_asset_counters(
    wallet: &mut OTLWallet,
    asset_types: vector<u8>,
    counts: vector<u64>,
    is_add: vector<bool>, // true=add, false=remove
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == wallet.owner, base::not_authorized_error());
    assert!(
        vector::length(&asset_types) == vector::length(&counts) &&
        vector::length(&counts) == vector::length(&is_add),
        base::invalid_metadata_error(),
    );
    assert!(vector::length(&asset_types) <= 10, base::invalid_amount_error()); // Reasonable batch limit

    let mut i = 0;
    while (i < vector::length(&asset_types)) {
        let asset_type = *vector::borrow(&asset_types, i);
        let count = *vector::borrow(&counts, i);
        let add = *vector::borrow(&is_add, i);

        if (add) {
            add_asset_counter(wallet, asset_type, count, ctx);
        } else {
            remove_asset_counter(wallet, asset_type, count, ctx);
        };

        i = i + 1;
    };
}

// ===== Ultra-Efficient View Functions =====

/// Get essential wallet info only
public fun get_wallet_info(wallet: &OTLWallet): (address, String, u8, u64, u64, u64) {
    (
        wallet.owner,
        wallet.name,
        wallet.config_flags,
        wallet.total_transactions,
        wallet.created_at,
        wallet.version,
    )
}

/// Get asset summary (counter-based)
public fun get_asset_summary(wallet: &OTLWallet): AssetSummary {
    AssetSummary {
        token_wallets: wallet.token_wallet_count,
        collectibles: wallet.collectible_count,
        tickets: wallet.ticket_count,
        loyalty_cards: wallet.loyalty_card_count,
        merchant_kiosks: 0, // Would need registry
        platform_listings: 0, // Would need registry
    }
}

/// Get detailed asset summary from registry
public fun get_detailed_asset_summary(wallet: &OTLWallet, registry: &AssetRegistry): AssetSummary {
    assert!(registry.wallet_id == object::id(wallet), base::not_authorized_error());

    AssetSummary {
        token_wallets: table::length(&registry.token_wallets),
        collectibles: vec_set::size(&registry.collectibles),
        tickets: vec_set::size(&registry.tickets),
        loyalty_cards: vec_set::size(&registry.loyalty_cards),
        merchant_kiosks: vec_set::size(&registry.merchant_kiosks),
        platform_listings: vec_set::size(&registry.platform_listings),
    }
}

/// Decode configuration flags
public fun get_wallet_config(wallet: &OTLWallet): (bool, bool, u8) {
    let flags = wallet.config_flags;
    (
        (flags & 1) != 0, // is_active
        (flags & 2) != 0, // auto_accept_assets
        (flags >> 2) & 7, // privacy_level (bits 2-4)
    )
}

/// Check if wallet is active
public fun is_wallet_active(wallet: &OTLWallet): bool {
    (wallet.config_flags & 1) != 0
}

/// Check if auto-accept is enabled
public fun is_auto_accept_enabled(wallet: &OTLWallet): bool {
    (wallet.config_flags & 2) != 0
}

/// Get privacy level
public fun get_privacy_level(wallet: &OTLWallet): u8 {
    (wallet.config_flags >> 2) & 7
}

/// Get wallet version
public fun get_wallet_version(wallet: &OTLWallet): u64 {
    wallet.version
}

/// Get total asset count
public fun get_total_asset_count(wallet: &OTLWallet): u64 {
    wallet.token_wallet_count + wallet.collectible_count + wallet.ticket_count + wallet.loyalty_card_count
}

/// Check if wallet has assets
public fun has_assets(wallet: &OTLWallet): bool {
    get_total_asset_count(wallet) > 0
}

/// Get asset summary details
public fun get_asset_summary_details(summary: &AssetSummary): (u64, u64, u64, u64, u64, u64) {
    (
        summary.token_wallets,
        summary.collectibles,
        summary.tickets,
        summary.loyalty_cards,
        summary.merchant_kiosks,
        summary.platform_listings,
    )
}
