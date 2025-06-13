#[allow(unused_const, duplicate_alias)]
module otl::kiosk_integration;

use otl::base;
use otl::coin::{Self as otl_coin, TokenWallet, TokenType, UtilityTokenRegistry};
use otl::collectible::{Self, Collectible, Collection};
use otl::ticket::{Self, Ticket, Event};
use otl::utils;
use std::option::{Self, Option};
use std::string::{Self, String};
use sui::address;
use sui::coin::{Self, Coin};
use sui::event;
use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
use sui::object::{Self, UID, ID};
use sui::sui::SUI;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};

// ===== Constants =====
const PLATFORM_FEE_BPS: u64 = 250; // 2.5% platform fee
const MERCHANT_FEE_BPS: u64 = 500; // 5% merchant fee (when using platform kiosk)
// Master kiosk verification levels
const VERIFICATION_NONE: u8 = 0;
const VERIFICATION_BASIC: u8 = 1;
const VERIFICATION_ONOAL_VERIFIED: u8 = 2;
const VERIFICATION_MASTER_KIOSK: u8 = 3;

// ===== Core Structs =====

/// Registry for managing both merchant and platform kiosks
public struct KioskRegistry has key {
    id: UID,
    /// Platform authority (Onoal)
    platform_authority: address,
    /// Platform's main marketplace kiosk
    platform_kiosk: ID,
    platform_kiosk_cap: ID,
    /// Master kiosk (Onoal's verified business kiosk)
    master_kiosk: Option<ID>,
    master_kiosk_cap: Option<ID>,
    /// Registered merchant kiosks
    merchant_kiosks: Table<address, MerchantKioskInfo>, // maps merchant address to kiosk info
    /// Onoal verified kiosks (special status)
    onoal_verified_kiosks: Table<address, bool>, // addresses that have Onoal verification
    /// Platform statistics
    total_merchants: u64,
    total_sales_volume: u64, // in SUI
    total_platform_fees: u64, // in SUI
    /// Fee configuration
    platform_fee_bps: u64,
    merchant_fee_bps: u64,
    /// Master kiosk settings
    master_kiosk_enabled: bool,
}

/// Information about a merchant's kiosk
public struct MerchantKioskInfo has store {
    merchant: address,
    kiosk_id: ID,
    kiosk_cap_id: ID,
    merchant_name: String,
    merchant_description: String,
    /// Verification levels
    is_verified: bool, // Basic platform verification
    is_onoal_verified: bool, // Special Onoal verification (only master kiosk can set)
    verification_level: u8, // 0=none, 1=basic, 2=onoal_verified, 3=master_kiosk
    /// Off-chain verification data
    verification_metadata: VecMap<String, String>, // KYC data, business license, etc.
    verified_at: u64, // timestamp of verification
    verified_by: address, // who verified this merchant
    /// Merchant statistics
    total_sales: u64,
    total_items_sold: u64,
    created_at: u64,
}

/// Listing information for items on platform kiosk
public struct PlatformListing has key, store {
    id: UID,
    /// Item details
    item_id: ID,
    item_type: String, // "collectible", "ticket", "token_wallet"
    /// Merchant who listed the item
    merchant: address,
    merchant_name: String,
    /// Pricing
    price: u64, // in SUI
    /// Listing metadata
    title: String,
    description: String,
    image_url: String,
    /// Listing status
    is_active: bool,
    listed_at: u64,
    /// Fee splits
    merchant_fee_amount: u64,
    platform_fee_amount: u64,
}

// ===== Events =====

public struct KioskRegistryCreated has copy, drop {
    registry_id: ID,
    platform_authority: address,
    platform_kiosk_id: ID,
}

public struct MerchantKioskCreated has copy, drop {
    registry_id: ID,
    merchant: address,
    merchant_name: String,
    kiosk_id: ID,
}

public struct ItemListedOnPlatform has copy, drop {
    listing_id: ID,
    item_id: ID,
    item_type: String,
    merchant: address,
    price: u64,
}

public struct ItemSoldOnPlatform has copy, drop {
    listing_id: ID,
    item_id: ID,
    buyer: address,
    seller: address,
    price: u64,
    platform_fee: u64,
    merchant_fee: u64,
}

public struct MerchantVerified has copy, drop {
    merchant: address,
    verified_by: address,
}

public struct MasterKioskCreated has copy, drop {
    registry_id: ID,
    master_kiosk_id: ID,
    created_by: address,
}

public struct OnoalVerificationGranted has copy, drop {
    merchant: address,
    verified_by: address,
    verification_level: u8,
}

public struct VerificationMetadataUpdated has copy, drop {
    merchant: address,
    updated_by: address,
    metadata_key: String,
}

// ===== Registry Management =====

/// Create the main kiosk registry with platform kiosk
public fun create_kiosk_registry(ctx: &mut TxContext): KioskRegistry {
    let platform_authority = tx_context::sender(ctx);

    // Create platform kiosk
    let (platform_kiosk, platform_kiosk_cap) = kiosk::new(ctx);
    let platform_kiosk_id = object::id(&platform_kiosk);
    let platform_kiosk_cap_id = object::id(&platform_kiosk_cap);

    // Transfer platform kiosk to platform authority for management
    transfer::public_transfer(platform_kiosk, platform_authority);

    let registry = KioskRegistry {
        id: object::new(ctx),
        platform_authority,
        platform_kiosk: platform_kiosk_id,
        platform_kiosk_cap: platform_kiosk_cap_id,
        master_kiosk: option::none(),
        master_kiosk_cap: option::none(),
        merchant_kiosks: table::new(ctx),
        onoal_verified_kiosks: table::new(ctx),
        total_merchants: 0,
        total_sales_volume: 0,
        total_platform_fees: 0,
        platform_fee_bps: PLATFORM_FEE_BPS,
        merchant_fee_bps: MERCHANT_FEE_BPS,
        master_kiosk_enabled: false,
    };

    // Store the platform kiosk cap in registry (in real implementation, this would be more secure)
    transfer::public_transfer(platform_kiosk_cap, platform_authority);

    event::emit(KioskRegistryCreated {
        registry_id: object::id(&registry),
        platform_authority,
        platform_kiosk_id,
    });

    registry
}

/// Create registry and share it
public entry fun create_shared_kiosk_registry(ctx: &mut TxContext) {
    let registry = create_kiosk_registry(ctx);
    transfer::share_object(registry);
}

// ===== Master Kiosk Management =====

/// Create Onoal's master kiosk (only platform authority can do this)
public fun create_master_kiosk(
    registry: &mut KioskRegistry,
    ctx: &mut TxContext,
): (Kiosk, KioskOwnerCap) {
    assert!(tx_context::sender(ctx) == registry.platform_authority, base::not_authorized_error());
    assert!(option::is_none(&registry.master_kiosk), base::account_exists_error());

    // Create master kiosk
    let (master_kiosk, master_kiosk_cap) = kiosk::new(ctx);
    let master_kiosk_id = object::id(&master_kiosk);
    let master_kiosk_cap_id = object::id(&master_kiosk_cap);

    // Update registry
    registry.master_kiosk = option::some(master_kiosk_id);
    registry.master_kiosk_cap = option::some(master_kiosk_cap_id);
    registry.master_kiosk_enabled = true;

    // Add Onoal as verified merchant with master kiosk status
    if (!table::contains(&registry.merchant_kiosks, registry.platform_authority)) {
        let onoal_info = MerchantKioskInfo {
            merchant: registry.platform_authority,
            kiosk_id: master_kiosk_id,
            kiosk_cap_id: master_kiosk_cap_id,
            merchant_name: string::utf8(b"Onoal Official"),
            merchant_description: string::utf8(
                b"Official Onoal master kiosk - verified platform authority",
            ),
            is_verified: true,
            is_onoal_verified: true,
            verification_level: VERIFICATION_MASTER_KIOSK,
            verification_metadata: vec_map::empty(),
            verified_at: utils::current_time_ms(),
            verified_by: registry.platform_authority,
            total_sales: 0,
            total_items_sold: 0,
            created_at: utils::current_time_ms(),
        };
        table::add(&mut registry.merchant_kiosks, registry.platform_authority, onoal_info);
        registry.total_merchants = registry.total_merchants + 1;
    };

    // Add to Onoal verified list
    table::add(&mut registry.onoal_verified_kiosks, registry.platform_authority, true);

    event::emit(MasterKioskCreated {
        registry_id: object::id(registry),
        master_kiosk_id,
        created_by: registry.platform_authority,
    });

    (master_kiosk, master_kiosk_cap)
}

/// Create master kiosk and transfer to platform authority
public entry fun create_master_kiosk_entry(registry: &mut KioskRegistry, ctx: &mut TxContext) {
    let (master_kiosk, master_kiosk_cap) = create_master_kiosk(registry, ctx);
    let platform_authority = registry.platform_authority;
    transfer::public_transfer(master_kiosk, platform_authority);
    transfer::public_transfer(master_kiosk_cap, platform_authority);
}

/// Grant Onoal verification to a merchant (only master kiosk can do this)
public fun grant_onoal_verification(
    registry: &mut KioskRegistry,
    merchant: address,
    verification_metadata_key: vector<u8>,
    verification_metadata_value: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.platform_authority, base::not_authorized_error());
    assert!(registry.master_kiosk_enabled, base::not_authorized_error());
    assert!(table::contains(&registry.merchant_kiosks, merchant), base::account_not_found_error());

    let merchant_info = table::borrow_mut(&mut registry.merchant_kiosks, merchant);

    // Upgrade verification level
    merchant_info.is_onoal_verified = true;
    merchant_info.verification_level = VERIFICATION_ONOAL_VERIFIED;
    merchant_info.verified_at = utils::current_time_ms();
    merchant_info.verified_by = tx_context::sender(ctx);

    // Add verification metadata
    let metadata_key = utils::safe_utf8(verification_metadata_key);
    let metadata_value = utils::safe_utf8(verification_metadata_value);

    if (vec_map::contains(&merchant_info.verification_metadata, &metadata_key)) {
        let (_, _) = vec_map::remove(&mut merchant_info.verification_metadata, &metadata_key);
    };
    vec_map::insert(&mut merchant_info.verification_metadata, metadata_key, metadata_value);

    // Add to Onoal verified list
    if (!table::contains(&registry.onoal_verified_kiosks, merchant)) {
        table::add(&mut registry.onoal_verified_kiosks, merchant, true);
    };

    event::emit(OnoalVerificationGranted {
        merchant,
        verified_by: tx_context::sender(ctx),
        verification_level: VERIFICATION_ONOAL_VERIFIED,
    });

    event::emit(VerificationMetadataUpdated {
        merchant,
        updated_by: tx_context::sender(ctx),
        metadata_key,
    });
}

/// Revoke Onoal verification (only master kiosk can do this)
public fun revoke_onoal_verification(
    registry: &mut KioskRegistry,
    merchant: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.platform_authority, base::not_authorized_error());
    assert!(registry.master_kiosk_enabled, base::not_authorized_error());
    assert!(table::contains(&registry.merchant_kiosks, merchant), base::account_not_found_error());

    let merchant_info = table::borrow_mut(&mut registry.merchant_kiosks, merchant);

    // Downgrade verification level
    merchant_info.is_onoal_verified = false;
    merchant_info.verification_level = if (merchant_info.is_verified) {
        VERIFICATION_BASIC
    } else {
        VERIFICATION_NONE
    };

    // Remove from Onoal verified list
    if (table::contains(&registry.onoal_verified_kiosks, merchant)) {
        let _ = table::remove(&mut registry.onoal_verified_kiosks, merchant);
    };
}

// ===== Merchant Kiosk Management =====

/// Create a merchant-specific kiosk
public fun create_merchant_kiosk(
    registry: &mut KioskRegistry,
    merchant_name: vector<u8>,
    merchant_description: vector<u8>,
    ctx: &mut TxContext,
): (Kiosk, KioskOwnerCap) {
    let merchant = tx_context::sender(ctx);
    assert!(!table::contains(&registry.merchant_kiosks, merchant), base::account_exists_error());
    assert!(!vector::is_empty(&merchant_name), base::invalid_metadata_error());

    // Create merchant kiosk
    let (merchant_kiosk, merchant_kiosk_cap) = kiosk::new(ctx);
    let kiosk_id = object::id(&merchant_kiosk);
    let kiosk_cap_id = object::id(&merchant_kiosk_cap);

    let merchant_info = MerchantKioskInfo {
        merchant,
        kiosk_id,
        kiosk_cap_id,
        merchant_name: utils::safe_utf8(merchant_name),
        merchant_description: utils::safe_utf8(merchant_description),
        is_verified: false,
        is_onoal_verified: false,
        verification_level: VERIFICATION_NONE,
        verification_metadata: vec_map::empty(),
        verified_at: 0,
        verified_by: @0x0,
        total_sales: 0,
        total_items_sold: 0,
        created_at: utils::current_time_ms(),
    };

    // Register merchant kiosk
    table::add(&mut registry.merchant_kiosks, merchant, merchant_info);
    registry.total_merchants = registry.total_merchants + 1;

    event::emit(MerchantKioskCreated {
        registry_id: object::id(registry),
        merchant,
        merchant_name: utils::safe_utf8(merchant_name),
        kiosk_id,
    });

    (merchant_kiosk, merchant_kiosk_cap)
}

/// Create merchant kiosk and transfer ownership
public entry fun create_merchant_kiosk_entry(
    registry: &mut KioskRegistry,
    merchant_name: vector<u8>,
    merchant_description: vector<u8>,
    ctx: &mut TxContext,
) {
    let (merchant_kiosk, merchant_kiosk_cap) = create_merchant_kiosk(
        registry,
        merchant_name,
        merchant_description,
        ctx,
    );

    let merchant = tx_context::sender(ctx);
    transfer::public_transfer(merchant_kiosk, merchant);
    transfer::public_transfer(merchant_kiosk_cap, merchant);
}

/// Verify a merchant (only platform authority can do this)
public fun verify_merchant(registry: &mut KioskRegistry, merchant: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == registry.platform_authority, base::not_authorized_error());
    assert!(table::contains(&registry.merchant_kiosks, merchant), base::account_not_found_error());

    let merchant_info = table::borrow_mut(&mut registry.merchant_kiosks, merchant);
    merchant_info.is_verified = true;
    merchant_info.verified_at = utils::current_time_ms();
    merchant_info.verified_by = tx_context::sender(ctx);

    // Update verification level if not already Onoal verified
    if (merchant_info.verification_level == VERIFICATION_NONE) {
        merchant_info.verification_level = VERIFICATION_BASIC;
    };

    event::emit(MerchantVerified {
        merchant,
        verified_by: tx_context::sender(ctx),
    });
}

// ===== Collectible Kiosk Integration =====

/// List collectible on merchant's own kiosk
public fun list_collectible_on_merchant_kiosk(
    merchant_kiosk: &mut Kiosk,
    merchant_cap: &KioskOwnerCap,
    collectible: Collectible,
    price: u64,
    ctx: &mut TxContext,
) {
    assert!(price > 0, base::invalid_amount_error());
    let collectible_id = object::id(&collectible);
    kiosk::place(merchant_kiosk, merchant_cap, collectible);
    kiosk::list<Collectible>(merchant_kiosk, merchant_cap, collectible_id, price);
}

/// List collectible on platform kiosk (with fee sharing)
public fun list_collectible_on_platform_kiosk(
    registry: &mut KioskRegistry,
    _platform_kiosk: &mut Kiosk,
    collectible: Collectible,
    price: u64,
    title: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    ctx: &mut TxContext,
): PlatformListing {
    let merchant = tx_context::sender(ctx);
    assert!(table::contains(&registry.merchant_kiosks, merchant), base::account_not_found_error());
    assert!(price > 0, base::invalid_amount_error());

    let collectible_id = object::id(&collectible);
    let merchant_info = table::borrow(&registry.merchant_kiosks, merchant);

    // Calculate fees
    let merchant_fee_amount = (price * registry.merchant_fee_bps) / 10000;
    let platform_fee_amount = (price * registry.platform_fee_bps) / 10000;

    // Create platform listing
    let listing = PlatformListing {
        id: object::new(ctx),
        item_id: collectible_id,
        item_type: string::utf8(b"collectible"),
        merchant,
        merchant_name: merchant_info.merchant_name,
        price,
        title: utils::safe_utf8(title),
        description: utils::safe_utf8(description),
        image_url: utils::safe_utf8(image_url),
        is_active: true,
        listed_at: utils::current_time_ms(),
        merchant_fee_amount,
        platform_fee_amount,
    };

    // Transfer collectible to platform for escrow (in real implementation, would place in kiosk)
    transfer::public_transfer(collectible, registry.platform_authority);

    event::emit(ItemListedOnPlatform {
        listing_id: object::id(&listing),
        item_id: collectible_id,
        item_type: string::utf8(b"collectible"),
        merchant,
        price,
    });

    listing
}

// ===== Ticket Kiosk Integration =====

/// List ticket on merchant kiosk (for event organizers)
public fun list_ticket_on_merchant_kiosk(
    merchant_kiosk: &mut Kiosk,
    merchant_cap: &KioskOwnerCap,
    ticket: Ticket,
    price: u64,
    ctx: &mut TxContext,
) {
    assert!(price > 0, base::invalid_amount_error());
    // Additional validation: check if ticket is transferable, not expired, etc.
    let ticket_id = object::id(&ticket);
    kiosk::place(merchant_kiosk, merchant_cap, ticket);
    kiosk::list<Ticket>(merchant_kiosk, merchant_cap, ticket_id, price);
}

/// List ticket on platform kiosk (for resale market)
public fun list_ticket_on_platform_kiosk(
    registry: &mut KioskRegistry,
    _platform_kiosk: &mut Kiosk,
    ticket: Ticket,
    price: u64,
    max_resale_price: u64, // Anti-scalping measure
    title: vector<u8>,
    description: vector<u8>,
    _ctx: &mut TxContext,
): PlatformListing {
    let merchant = tx_context::sender(_ctx);
    assert!(price > 0, base::invalid_amount_error());
    assert!(price <= max_resale_price, base::invalid_amount_error()); // Anti-scalping

    let ticket_id = object::id(&ticket);

    // Calculate fees
    let merchant_fee_amount = (price * registry.merchant_fee_bps) / 10000;
    let platform_fee_amount = (price * registry.platform_fee_bps) / 10000;

    let listing = PlatformListing {
        id: object::new(_ctx),
        item_id: ticket_id,
        item_type: string::utf8(b"ticket"),
        merchant,
        merchant_name: string::utf8(b"Individual Seller"), // Default for non-merchant sellers
        price,
        title: utils::safe_utf8(title),
        description: utils::safe_utf8(description),
        image_url: string::utf8(b""), // Tickets might not have images
        is_active: true,
        listed_at: utils::current_time_ms(),
        merchant_fee_amount,
        platform_fee_amount,
    };

    // Transfer ticket to platform for escrow
    transfer::public_transfer(ticket, registry.platform_authority);

    event::emit(ItemListedOnPlatform {
        listing_id: object::id(&listing),
        item_id: ticket_id,
        item_type: string::utf8(b"ticket"),
        merchant,
        price,
    });

    listing
}

// ===== Token Wallet Kiosk Integration =====

/// List token wallet on platform kiosk
public fun list_token_wallet_on_platform_kiosk(
    registry: &mut KioskRegistry,
    _platform_kiosk: &mut Kiosk,
    token_wallet: TokenWallet,
    price_per_token: u64,
    title: vector<u8>,
    description: vector<u8>,
    ctx: &mut TxContext,
): PlatformListing {
    let merchant = tx_context::sender(ctx);
    assert!(price_per_token > 0, base::invalid_amount_error());

    let wallet_id = object::id(&token_wallet);
    let (_, _, balance, _, _) = otl_coin::get_wallet_info(&token_wallet);
    let total_price = balance * price_per_token;

    // Calculate fees
    let merchant_fee_amount = (total_price * registry.merchant_fee_bps) / 10000;
    let platform_fee_amount = (total_price * registry.platform_fee_bps) / 10000;

    let listing = PlatformListing {
        id: object::new(ctx),
        item_id: wallet_id,
        item_type: string::utf8(b"token_wallet"),
        merchant,
        merchant_name: string::utf8(b"Token Holder"),
        price: total_price,
        title: utils::safe_utf8(title),
        description: utils::safe_utf8(description),
        image_url: string::utf8(b""),
        is_active: true,
        listed_at: utils::current_time_ms(),
        merchant_fee_amount,
        platform_fee_amount,
    };

    // Transfer token wallet to platform for escrow
    transfer::public_transfer(token_wallet, registry.platform_authority);

    event::emit(ItemListedOnPlatform {
        listing_id: object::id(&listing),
        item_id: wallet_id,
        item_type: string::utf8(b"token_wallet"),
        merchant,
        price: total_price,
    });

    listing
}

// ===== View Functions =====

/// Get registry information
public fun get_registry_info(registry: &KioskRegistry): (address, ID, u64, u64, u64, u64, u64) {
    (
        registry.platform_authority,
        registry.platform_kiosk,
        registry.total_merchants,
        registry.total_sales_volume,
        registry.total_platform_fees,
        registry.platform_fee_bps,
        registry.merchant_fee_bps,
    )
}

/// Get extended registry information including master kiosk
public fun get_extended_registry_info(
    registry: &KioskRegistry,
): (address, ID, Option<ID>, bool, u64, u64, u64, u64, u64) {
    (
        registry.platform_authority,
        registry.platform_kiosk,
        registry.master_kiosk,
        registry.master_kiosk_enabled,
        registry.total_merchants,
        registry.total_sales_volume,
        registry.total_platform_fees,
        registry.platform_fee_bps,
        registry.merchant_fee_bps,
    )
}

/// Get merchant kiosk info
public fun get_merchant_info(
    registry: &KioskRegistry,
    merchant: address,
): (String, String, ID, u64, u64, bool) {
    assert!(table::contains(&registry.merchant_kiosks, merchant), base::account_not_found_error());
    let info = table::borrow(&registry.merchant_kiosks, merchant);
    (
        info.merchant_name,
        info.merchant_description,
        info.kiosk_id,
        info.total_sales,
        info.total_items_sold,
        info.is_verified,
    )
}

/// Get extended merchant info including verification details
public fun get_extended_merchant_info(
    registry: &KioskRegistry,
    merchant: address,
): (String, String, ID, u64, u64, bool, bool, u8, u64, address) {
    assert!(table::contains(&registry.merchant_kiosks, merchant), base::account_not_found_error());
    let info = table::borrow(&registry.merchant_kiosks, merchant);
    (
        info.merchant_name,
        info.merchant_description,
        info.kiosk_id,
        info.total_sales,
        info.total_items_sold,
        info.is_verified,
        info.is_onoal_verified,
        info.verification_level,
        info.verified_at,
        info.verified_by,
    )
}

/// Get platform listing info
public fun get_listing_info(
    listing: &PlatformListing,
): (ID, String, address, u64, String, String, bool, u64, u64) {
    (
        listing.item_id,
        listing.item_type,
        listing.merchant,
        listing.price,
        listing.title,
        listing.description,
        listing.is_active,
        listing.merchant_fee_amount,
        listing.platform_fee_amount,
    )
}

/// Check if merchant has kiosk
public fun has_merchant_kiosk(registry: &KioskRegistry, merchant: address): bool {
    table::contains(&registry.merchant_kiosks, merchant)
}

/// Check if merchant is verified
public fun is_merchant_verified(registry: &KioskRegistry, merchant: address): bool {
    if (table::contains(&registry.merchant_kiosks, merchant)) {
        let info = table::borrow(&registry.merchant_kiosks, merchant);
        info.is_verified
    } else {
        false
    }
}

/// Check if merchant has Onoal verification
public fun is_merchant_onoal_verified(registry: &KioskRegistry, merchant: address): bool {
    if (table::contains(&registry.merchant_kiosks, merchant)) {
        let info = table::borrow(&registry.merchant_kiosks, merchant);
        info.is_onoal_verified
    } else {
        false
    }
}

/// Get merchant verification level
public fun get_merchant_verification_level(registry: &KioskRegistry, merchant: address): u8 {
    if (table::contains(&registry.merchant_kiosks, merchant)) {
        let info = table::borrow(&registry.merchant_kiosks, merchant);
        info.verification_level
    } else {
        VERIFICATION_NONE
    }
}

/// Check if master kiosk is enabled
public fun is_master_kiosk_enabled(registry: &KioskRegistry): bool {
    registry.master_kiosk_enabled
}

/// Get master kiosk ID (if exists)
public fun get_master_kiosk_id(registry: &KioskRegistry): Option<ID> {
    registry.master_kiosk
}

/// Check if address is in Onoal verified list
public fun is_in_onoal_verified_list(registry: &KioskRegistry, merchant: address): bool {
    table::contains(&registry.onoal_verified_kiosks, merchant)
}

/// Get verification constants for external use
public fun get_verification_levels(): (u8, u8, u8, u8) {
    (VERIFICATION_NONE, VERIFICATION_BASIC, VERIFICATION_ONOAL_VERIFIED, VERIFICATION_MASTER_KIOSK)
}
