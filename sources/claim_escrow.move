module otl::claim_escrow;

use otl::base;
use otl::coin::{Self, TokenWallet, TokenType};
use otl::collectible::{Self, Collectible, Collection};
use otl::utils;
use std::string::{Self, String};
use sui::clock::{Self, Clock};
use sui::event;
use sui::hash;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};

// ===== Constants =====
const CLAIM_STATUS_PENDING: u8 = 0;
const CLAIM_STATUS_CLAIMED: u8 = 1;
const CLAIM_STATUS_EXPIRED: u8 = 2;
const CLAIM_STATUS_CANCELLED: u8 = 3;

// ===== Core Structs =====

/// Registry for managing fiat-to-crypto claim escrows
public struct ClaimEscrowRegistry has key {
    id: UID,
    /// Registry operator (merchant, platform, etc.)
    authority: address,
    /// All pending claims
    claims: Table<String, ID>, // maps claim_hash to ClaimEscrow ID
    /// Merchant info
    merchant_name: String,
    merchant_id: String,
    /// Statistics
    total_claims_created: u64,
    total_claims_fulfilled: u64,
    total_claims_expired: u64,
    /// Configuration
    default_expiry_hours: u64, // How long claims are valid
    require_merchant_signature: bool, // Extra security layer
}

/// Individual claim escrow holding an asset until claimed
public struct ClaimEscrow has key, store {
    id: UID,
    /// Reference to registry
    registry: ID,
    /// Claim identification
    claim_hash: String, // Unique hash/code for claiming
    secret_verification: vector<u8>, // Additional verification (optional)
    /// Asset being held in escrow
    asset_type: String, // "collectible", "token_wallet", "ticket", etc.
    asset_id: ID,
    /// Purchase details (for fiat transaction reference)
    purchase_reference: String, // POS transaction ID, order number, etc.
    purchase_amount_fiat: u64, // Amount paid in fiat (in cents/smallest unit)
    fiat_currency: String, // "USD", "EUR", etc.
    purchased_at: u64,
    /// Claim details
    status: u8,
    claimer: Option<address>, // Who claimed it (if claimed)
    claimed_at: u64,
    expires_at: u64, // When this claim expires
    /// Metadata
    claim_title: String,
    claim_description: String,
    claim_image_url: String,
    /// Security features
    max_claim_attempts: u64,
    claim_attempts: u64,
    requires_additional_verification: bool,
    verification_metadata: VecMap<String, String>,
}

/// Temporary claim ticket for multi-step verification
public struct ClaimTicket has key {
    id: UID,
    claim_escrow_id: ID,
    claimer: address,
    verification_hash: vector<u8>,
    created_at: u64,
    expires_at: u64, // Short expiry for security
}

// ===== Events =====

public struct ClaimEscrowRegistryCreated has copy, drop {
    registry_id: ID,
    authority: address,
    merchant_name: String,
}

public struct ClaimEscrowCreated has copy, drop {
    registry_id: ID,
    escrow_id: ID,
    claim_hash: String,
    asset_type: String,
    asset_id: ID,
    purchase_reference: String,
    expires_at: u64,
}

public struct ClaimInitiated has copy, drop {
    escrow_id: ID,
    claim_hash: String,
    claimer: address,
    attempt_number: u64,
}

public struct ClaimSuccessful has copy, drop {
    escrow_id: ID,
    claim_hash: String,
    claimer: address,
    asset_type: String,
    asset_id: ID,
    claimed_at: u64,
}

public struct ClaimExpired has copy, drop {
    escrow_id: ID,
    claim_hash: String,
    asset_type: String,
    expired_at: u64,
}

// ===== Registry Management =====

/// Create a new claim escrow registry for a merchant
public fun create_claim_escrow_registry(
    merchant_name: vector<u8>,
    merchant_id: vector<u8>,
    default_expiry_hours: u64,
    require_merchant_signature: bool,
    ctx: &mut TxContext,
): ClaimEscrowRegistry {
    assert!(!vector::is_empty(&merchant_name), base::invalid_metadata_error());
    assert!(default_expiry_hours > 0, base::invalid_metadata_error());

    let authority = tx_context::sender(ctx);

    let registry = ClaimEscrowRegistry {
        id: object::new(ctx),
        authority,
        claims: table::new(ctx),
        merchant_name: utils::safe_utf8(merchant_name),
        merchant_id: utils::safe_utf8(merchant_id),
        total_claims_created: 0,
        total_claims_fulfilled: 0,
        total_claims_expired: 0,
        default_expiry_hours,
        require_merchant_signature,
    };

    event::emit(ClaimEscrowRegistryCreated {
        registry_id: object::id(&registry),
        authority,
        merchant_name: registry.merchant_name,
    });

    registry
}

/// Create registry and share it
public entry fun create_shared_claim_escrow_registry(
    merchant_name: vector<u8>,
    merchant_id: vector<u8>,
    default_expiry_hours: u64,
    require_merchant_signature: bool,
    ctx: &mut TxContext,
) {
    let registry = create_claim_escrow_registry(
        merchant_name,
        merchant_id,
        default_expiry_hours,
        require_merchant_signature,
        ctx,
    );
    transfer::share_object(registry);
}

// ===== Escrow Creation (Merchant Side) =====

/// Create a claim escrow for a collectible NFT (after fiat purchase)
public fun create_collectible_claim_escrow(
    registry: &mut ClaimEscrowRegistry,
    collectible: Collectible,
    claim_hash: vector<u8>,
    purchase_reference: vector<u8>,
    purchase_amount_fiat: u64,
    fiat_currency: vector<u8>,
    claim_title: vector<u8>,
    claim_description: vector<u8>,
    claim_image_url: vector<u8>,
    custom_expiry_hours: Option<u64>,
    clock: &Clock,
    ctx: &mut TxContext,
): ClaimEscrow {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!vector::is_empty(&claim_hash), base::invalid_metadata_error());
    assert!(purchase_amount_fiat > 0, base::invalid_amount_error());

    let claim_hash_string = utils::safe_utf8(claim_hash);
    assert!(!table::contains(&registry.claims, claim_hash_string), base::token_exists_error());

    let current_time = clock::timestamp_ms(clock);
    let expiry_hours = if (option::is_some(&custom_expiry_hours)) {
        option::destroy_some(custom_expiry_hours)
    } else {
        registry.default_expiry_hours
    };
    let expires_at = current_time + (expiry_hours * 60 * 60 * 1000); // Convert hours to ms

    let asset_id = object::id(&collectible);

    let escrow = ClaimEscrow {
        id: object::new(ctx),
        registry: object::id(registry),
        claim_hash: claim_hash_string,
        secret_verification: vector::empty(), // Can be set later if needed
        asset_type: string::utf8(b"collectible"),
        asset_id,
        purchase_reference: utils::safe_utf8(purchase_reference),
        purchase_amount_fiat,
        fiat_currency: utils::safe_utf8(fiat_currency),
        purchased_at: current_time,
        status: CLAIM_STATUS_PENDING,
        claimer: option::none(),
        claimed_at: 0,
        expires_at,
        claim_title: utils::safe_utf8(claim_title),
        claim_description: utils::safe_utf8(claim_description),
        claim_image_url: utils::safe_utf8(claim_image_url),
        max_claim_attempts: 5,
        claim_attempts: 0,
        requires_additional_verification: false,
        verification_metadata: vec_map::empty(),
    };

    // Store collectible in the escrow (transfer to escrow object)
    transfer::public_transfer(collectible, object::id_to_address(&object::id(&escrow)));

    // Register the claim
    table::add(&mut registry.claims, claim_hash_string, object::id(&escrow));
    registry.total_claims_created = registry.total_claims_created + 1;

    event::emit(ClaimEscrowCreated {
        registry_id: object::id(registry),
        escrow_id: object::id(&escrow),
        claim_hash: claim_hash_string,
        asset_type: string::utf8(b"collectible"),
        asset_id,
        purchase_reference: utils::safe_utf8(purchase_reference),
        expires_at,
    });

    escrow
}

/// Create claim escrow for token wallet
public fun create_token_wallet_claim_escrow(
    registry: &mut ClaimEscrowRegistry,
    token_wallet: TokenWallet,
    claim_hash: vector<u8>,
    purchase_reference: vector<u8>,
    purchase_amount_fiat: u64,
    fiat_currency: vector<u8>,
    claim_title: vector<u8>,
    claim_description: vector<u8>,
    custom_expiry_hours: Option<u64>,
    clock: &Clock,
    ctx: &mut TxContext,
): ClaimEscrow {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    let claim_hash_string = utils::safe_utf8(claim_hash);
    assert!(!table::contains(&registry.claims, claim_hash_string), base::token_exists_error());

    let current_time = clock::timestamp_ms(clock);
    let expiry_hours = if (option::is_some(&custom_expiry_hours)) {
        option::destroy_some(custom_expiry_hours)
    } else {
        registry.default_expiry_hours
    };
    let expires_at = current_time + (expiry_hours * 60 * 60 * 1000);

    let asset_id = object::id(&token_wallet);

    let escrow = ClaimEscrow {
        id: object::new(ctx),
        registry: object::id(registry),
        claim_hash: claim_hash_string,
        secret_verification: vector::empty(),
        asset_type: string::utf8(b"token_wallet"),
        asset_id,
        purchase_reference: utils::safe_utf8(purchase_reference),
        purchase_amount_fiat,
        fiat_currency: utils::safe_utf8(fiat_currency),
        purchased_at: current_time,
        status: CLAIM_STATUS_PENDING,
        claimer: option::none(),
        claimed_at: 0,
        expires_at,
        claim_title: utils::safe_utf8(claim_title),
        claim_description: utils::safe_utf8(claim_description),
        claim_image_url: string::utf8(b""),
        max_claim_attempts: 5,
        claim_attempts: 0,
        requires_additional_verification: false,
        verification_metadata: vec_map::empty(),
    };

    // Store token wallet in the escrow
    transfer::public_transfer(token_wallet, object::id_to_address(&object::id(&escrow)));

    // Register the claim
    table::add(&mut registry.claims, claim_hash_string, object::id(&escrow));
    registry.total_claims_created = registry.total_claims_created + 1;

    event::emit(ClaimEscrowCreated {
        registry_id: object::id(registry),
        escrow_id: object::id(&escrow),
        claim_hash: claim_hash_string,
        asset_type: string::utf8(b"token_wallet"),
        asset_id,
        purchase_reference: utils::safe_utf8(purchase_reference),
        expires_at,
    });

    escrow
}

// ===== Claiming Functions (User Side) =====

/// Initiate a claim using the claim hash
public fun initiate_claim(
    registry: &mut ClaimEscrowRegistry,
    escrow: &mut ClaimEscrow,
    claim_hash: vector<u8>,
    additional_verification: Option<vector<u8>>,
    clock: &Clock,
    ctx: &mut TxContext,
): ClaimTicket {
    let claim_hash_string = utils::safe_utf8(claim_hash);
    let claimer = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);

    // Validate claim
    assert!(escrow.claim_hash == claim_hash_string, base::invalid_metadata_error());
    assert!(escrow.status == CLAIM_STATUS_PENDING, base::invalid_metadata_error());
    assert!(current_time < escrow.expires_at, base::invalid_metadata_error());
    assert!(escrow.claim_attempts < escrow.max_claim_attempts, base::invalid_amount_error());

    // Update attempt counter
    escrow.claim_attempts = escrow.claim_attempts + 1;

    // Additional verification if required
    if (escrow.requires_additional_verification) {
        assert!(option::is_some(&additional_verification), base::invalid_metadata_error());
        let verification = option::destroy_some(additional_verification);
        // Custom verification logic here
        assert!(!vector::is_empty(&verification), base::invalid_metadata_error());
    };

    // Create verification hash for this attempt
    let mut hash_input = *string::as_bytes(&claim_hash_string);
    vector::append(&mut hash_input, sui::address::to_bytes(claimer));
    let verification_hash = hash_input; // Simple approach using concatenated bytes

    // Create claim ticket (short-lived for security)
    let ticket = ClaimTicket {
        id: object::new(ctx),
        claim_escrow_id: object::id(escrow),
        claimer,
        verification_hash,
        created_at: current_time,
        expires_at: current_time + (10 * 60 * 1000), // 10 minutes to complete claim
    };

    event::emit(ClaimInitiated {
        escrow_id: object::id(escrow),
        claim_hash: claim_hash_string,
        claimer,
        attempt_number: escrow.claim_attempts,
    });

    ticket
}

/// Complete the claim using the claim ticket (for collectibles)
public fun complete_collectible_claim(
    registry: &mut ClaimEscrowRegistry,
    escrow: &mut ClaimEscrow,
    ticket: ClaimTicket,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let ClaimTicket {
        id: ticket_id,
        claim_escrow_id,
        claimer,
        verification_hash: _,
        created_at: _,
        expires_at,
    } = ticket;

    let current_time = clock::timestamp_ms(clock);
    let sender = tx_context::sender(ctx);

    // Validate ticket and timing
    assert!(object::id(escrow) == claim_escrow_id, base::invalid_metadata_error());
    assert!(claimer == sender, base::not_authorized_error());
    assert!(current_time < expires_at, base::invalid_metadata_error());
    assert!(escrow.status == CLAIM_STATUS_PENDING, base::invalid_metadata_error());

    // Update escrow status
    escrow.status = CLAIM_STATUS_CLAIMED;
    escrow.claimer = option::some(claimer);
    escrow.claimed_at = current_time;

    // Update registry stats
    registry.total_claims_fulfilled = registry.total_claims_fulfilled + 1;

    // Clean up ticket
    ticket_id.delete();

    event::emit(ClaimSuccessful {
        escrow_id: object::id(escrow),
        claim_hash: escrow.claim_hash,
        claimer,
        asset_type: escrow.asset_type,
        asset_id: escrow.asset_id,
        claimed_at: current_time,
    });

    // Return the asset ID for the frontend to handle the actual transfer
    // The actual collectible retrieval would be handled by the claiming interface
    escrow.asset_id
}

// ===== View Functions =====

/// Check if a claim hash exists and get basic info
public fun claim_exists(registry: &ClaimEscrowRegistry, claim_hash: String): bool {
    table::contains(&registry.claims, claim_hash)
}

/// Get claim escrow info
public fun get_claim_info(
    escrow: &ClaimEscrow,
): (
    String, // claim_hash
    String, // asset_type
    ID, // asset_id
    String, // purchase_reference
    u64, // purchase_amount_fiat
    String, // fiat_currency
    u8, // status
    u64, // expires_at
    u64, // claim_attempts
    u64, // max_claim_attempts
) {
    (
        escrow.claim_hash,
        escrow.asset_type,
        escrow.asset_id,
        escrow.purchase_reference,
        escrow.purchase_amount_fiat,
        escrow.fiat_currency,
        escrow.status,
        escrow.expires_at,
        escrow.claim_attempts,
        escrow.max_claim_attempts,
    )
}

/// Get registry statistics
public fun get_registry_stats(registry: &ClaimEscrowRegistry): (u64, u64, u64) {
    (registry.total_claims_created, registry.total_claims_fulfilled, registry.total_claims_expired)
}

// ===== Admin Functions =====

/// Cancel a claim (merchant only)
public fun cancel_claim(
    registry: &mut ClaimEscrowRegistry,
    escrow: &mut ClaimEscrow,
    reason: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(escrow.status == CLAIM_STATUS_PENDING, base::invalid_metadata_error());

    escrow.status = CLAIM_STATUS_CANCELLED;

    // Could emit an event with cancellation reason
    // Event implementation would go here
}

/// Extend claim expiry (merchant only)
public fun extend_claim_expiry(
    registry: &ClaimEscrowRegistry,
    escrow: &mut ClaimEscrow,
    additional_hours: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(escrow.status == CLAIM_STATUS_PENDING, base::invalid_metadata_error());
    assert!(additional_hours > 0, base::invalid_amount_error());

    escrow.expires_at = escrow.expires_at + (additional_hours * 60 * 60 * 1000);
}
