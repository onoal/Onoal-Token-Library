#[allow(unused_const, duplicate_alias, lint(self_transfer))]
module otl::loyalty;

use otl::base;
use otl::utils;
use std::string::{Self, String};
use sui::clock::{Self, Clock};
use sui::display;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::package;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};

// ===== Constants =====
const TIER_BRONZE: u8 = 0;
const TIER_SILVER: u8 = 1;
const TIER_GOLD: u8 = 2;
const TIER_PLATINUM: u8 = 3;
const TIER_DIAMOND: u8 = 4;

const POINTS_ACTIVE: u8 = 0;
const POINTS_EXPIRED: u8 = 1;
const POINTS_SPENT: u8 = 2;

// ===== Core Structs =====

/// Loyalty program managed by merchants/partners
public struct LoyaltyProgram has key {
    id: UID,
    /// Program operator/merchant
    authority: address,
    /// Program metadata
    name: String,
    description: String,
    brand_logo: String,
    external_url: String,
    /// Program configuration
    points_per_dollar: u64, // How many points per dollar spent
    expiry_days: u64, // Days until points expire (0 = no expiry)
    /// Tier thresholds (total lifetime points needed)
    bronze_threshold: u64,
    silver_threshold: u64,
    gold_threshold: u64,
    platinum_threshold: u64,
    diamond_threshold: u64,
    /// Program statistics
    total_cards: u64,
    total_points_issued: u64,
    total_points_redeemed: u64,
    /// Card registry
    cards: Table<address, ID>, // maps holder address to their LoyaltyCard ID
    /// Authorized point issuers (merchants, POS systems, etc.)
    issuers: VecMap<address, bool>,
    /// Program attributes
    program_attributes: VecMap<String, String>,
}

/// Individual loyalty card for a user
public struct LoyaltyCard has key, store {
    id: UID,
    /// Reference to the loyalty program
    program: ID,
    /// Card holder
    holder: address,
    /// Point balances
    total_points: u64, // Current available points
    lifetime_points: u64, // Total points ever earned (for tier calculation)
    pending_points: u64, // Points not yet available (e.g., pending transaction)
    /// Current tier
    tier: u8,
    tier_name: String,
    /// Card metadata
    card_number: String, // Unique card identifier
    issued_at: u64,
    last_activity: u64,
    /// Point transactions history
    point_entries: Table<u64, PointEntry>, // maps entry_id to PointEntry
    next_entry_id: u64,
    /// Card-specific attributes
    card_attributes: VecMap<String, String>,
}

/// Individual point entry/transaction
public struct PointEntry has store {
    entry_id: u64,
    points: u64,
    entry_type: u8, // 0 = earned, 1 = spent, 2 = expired, 3 = transferred
    description: String, // "Purchase at Store #123", "Redeemed for coffee", etc.
    reference_id: String, // Transaction ID, order number, etc.
    created_at: u64,
    expires_at: u64, // 0 = no expiry
    status: u8, // 0 = active, 1 = expired, 2 = spent
}

/// One-time witness for creating Display
public struct LOYALTY has drop {}

// ===== Events =====

public struct LoyaltyProgramCreated has copy, drop {
    program_id: ID,
    authority: address,
    name: String,
    points_per_dollar: u64,
}

public struct LoyaltyCardIssued has copy, drop {
    program_id: ID,
    card_id: ID,
    holder: address,
    card_number: String,
}

public struct PointsEarned has copy, drop {
    program_id: ID,
    card_id: ID,
    holder: address,
    points: u64,
    description: String,
}

public struct PointsSpent has copy, drop {
    program_id: ID,
    card_id: ID,
    holder: address,
    points: u64,
    description: String,
}

public struct TierUpgraded has copy, drop {
    card_id: ID,
    holder: address,
    old_tier: u8,
    new_tier: u8,
    new_tier_name: String,
}

public struct PointsTransferred has copy, drop {
    program_id: ID,
    from_card: ID,
    to_card: ID,
    points: u64,
}

// ===== Program Management =====

/// Create a new loyalty program
public fun create_loyalty_program(
    name: vector<u8>,
    description: vector<u8>,
    brand_logo: vector<u8>,
    external_url: vector<u8>,
    points_per_dollar: u64,
    expiry_days: u64,
    bronze_threshold: u64,
    silver_threshold: u64,
    gold_threshold: u64,
    platinum_threshold: u64,
    diamond_threshold: u64,
    ctx: &mut TxContext,
): LoyaltyProgram {
    // Validate parameters
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());
    assert!(points_per_dollar > 0, base::invalid_metadata_error());
    assert!(bronze_threshold < silver_threshold, base::invalid_metadata_error());
    assert!(silver_threshold < gold_threshold, base::invalid_metadata_error());
    assert!(gold_threshold < platinum_threshold, base::invalid_metadata_error());
    assert!(platinum_threshold < diamond_threshold, base::invalid_metadata_error());

    let authority = tx_context::sender(ctx);
    assert!(utils::validate_address(authority), base::not_authorized_error());

    let program = LoyaltyProgram {
        id: object::new(ctx),
        authority,
        name: utils::safe_utf8(name),
        description: utils::safe_utf8(description),
        brand_logo: utils::safe_utf8(brand_logo),
        external_url: utils::safe_utf8(external_url),
        points_per_dollar,
        expiry_days,
        bronze_threshold,
        silver_threshold,
        gold_threshold,
        platinum_threshold,
        diamond_threshold,
        total_cards: 0,
        total_points_issued: 0,
        total_points_redeemed: 0,
        cards: table::new(ctx),
        issuers: vec_map::empty(),
        program_attributes: vec_map::empty(),
    };

    event::emit(LoyaltyProgramCreated {
        program_id: object::id(&program),
        authority,
        name: program.name,
        points_per_dollar,
    });

    program
}

/// Create loyalty program and share it
public entry fun create_shared_loyalty_program(
    name: vector<u8>,
    description: vector<u8>,
    brand_logo: vector<u8>,
    external_url: vector<u8>,
    points_per_dollar: u64,
    expiry_days: u64,
    bronze_threshold: u64,
    silver_threshold: u64,
    gold_threshold: u64,
    platinum_threshold: u64,
    diamond_threshold: u64,
    ctx: &mut TxContext,
) {
    let program = create_loyalty_program(
        name,
        description,
        brand_logo,
        external_url,
        points_per_dollar,
        expiry_days,
        bronze_threshold,
        silver_threshold,
        gold_threshold,
        platinum_threshold,
        diamond_threshold,
        ctx,
    );
    transfer::share_object(program);
}

/// Initialize Display for Loyalty Cards
public fun init_display(otw: LOYALTY, ctx: &mut TxContext) {
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"card_number"),
        string::utf8(b"tier"),
        string::utf8(b"total_points"),
        string::utf8(b"lifetime_points"),
        string::utf8(b"program"),
    ];

    let values = vector[
        string::utf8(b"Loyalty Card #{card_number}"),
        string::utf8(b"Digital loyalty card for earning and redeeming points"),
        string::utf8(b"{brand_logo}"),
        string::utf8(b"{card_number}"),
        string::utf8(b"{tier_name}"),
        string::utf8(b"{total_points}"),
        string::utf8(b"{lifetime_points}"),
        string::utf8(b"Onoal Loyalty Program"),
    ];

    let publisher = package::claim(otw, ctx);
    let mut display = display::new_with_fields<LoyaltyCard>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display::update_version(&mut display);
    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
}

/// Add authorized point issuer
public fun add_issuer(program: &mut LoyaltyProgram, issuer: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == program.authority, base::not_authorized_error());
    assert!(utils::validate_address(issuer), base::not_authorized_error());
    assert!(!vec_map::contains(&program.issuers, &issuer), base::minter_exists_error());

    vec_map::insert(&mut program.issuers, issuer, true);
}

// ===== Card Operations =====

/// Issue a new loyalty card
public fun issue_loyalty_card(
    program: &mut LoyaltyProgram,
    recipient: address,
    card_number: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): LoyaltyCard {
    let sender = tx_context::sender(ctx);
    assert!(
        sender == program.authority || vec_map::contains(&program.issuers, &sender),
        base::not_authorized_error(),
    );
    assert!(utils::validate_address(recipient), base::not_authorized_error());
    assert!(!table::contains(&program.cards, recipient), base::account_exists_error());

    let current_time = clock::timestamp_ms(clock);
    program.total_cards = program.total_cards + 1;

    let card_number_str = if (vector::is_empty(&card_number)) {
        // Generate default card number
        string::utf8(b"CARD") // In real implementation, generate unique number
    } else {
        utils::safe_utf8(card_number)
    };

    let card = LoyaltyCard {
        id: object::new(ctx),
        program: object::id(program),
        holder: recipient,
        total_points: 0,
        lifetime_points: 0,
        pending_points: 0,
        tier: TIER_BRONZE,
        tier_name: string::utf8(b"Bronze"),
        card_number: card_number_str,
        issued_at: current_time,
        last_activity: current_time,
        point_entries: table::new(ctx),
        next_entry_id: 1,
        card_attributes: vec_map::empty(),
    };

    // Register card in program
    table::add(&mut program.cards, recipient, object::id(&card));

    event::emit(LoyaltyCardIssued {
        program_id: object::id(program),
        card_id: object::id(&card),
        holder: recipient,
        card_number: card.card_number,
    });

    card
}

/// Issue card and transfer to recipient
public entry fun issue_loyalty_card_to_recipient(
    program: &mut LoyaltyProgram,
    recipient: address,
    card_number: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let card = issue_loyalty_card(program, recipient, card_number, clock, ctx);
    transfer::public_transfer(card, recipient);
}

/// Earn points on a loyalty card
public fun earn_points(
    program: &mut LoyaltyProgram,
    card: &mut LoyaltyCard,
    points: u64,
    description: vector<u8>,
    reference_id: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(
        sender == program.authority || vec_map::contains(&program.issuers, &sender),
        base::not_authorized_error(),
    );
    assert!(card.program == object::id(program), base::token_not_found_error());
    assert!(points > 0, base::invalid_amount_error());

    let current_time = clock::timestamp_ms(clock);
    let expires_at = if (program.expiry_days > 0) {
        current_time + (program.expiry_days * 24 * 60 * 60 * 1000) // Convert days to ms
    } else {
        0 // No expiry
    };

    // Create point entry
    let entry = PointEntry {
        entry_id: card.next_entry_id,
        points,
        entry_type: 0, // earned
        description: utils::safe_utf8(description),
        reference_id: utils::safe_utf8(reference_id),
        created_at: current_time,
        expires_at,
        status: POINTS_ACTIVE,
    };

    table::add(&mut card.point_entries, card.next_entry_id, entry);
    card.next_entry_id = card.next_entry_id + 1;

    // Update balances
    card.total_points = card.total_points + points;
    card.lifetime_points = card.lifetime_points + points;
    card.last_activity = current_time;

    // Update program stats
    program.total_points_issued = program.total_points_issued + points;

    // Check for tier upgrade
    check_tier_upgrade(card, program);

    event::emit(PointsEarned {
        program_id: object::id(program),
        card_id: object::id(card),
        holder: card.holder,
        points,
        description: utils::safe_utf8(description),
    });
}

/// Spend points from a loyalty card
public fun spend_points(
    program: &mut LoyaltyProgram,
    card: &mut LoyaltyCard,
    points: u64,
    description: vector<u8>,
    reference_id: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(
        sender == program.authority || vec_map::contains(&program.issuers, &sender) || sender == card.holder,
        base::not_authorized_error(),
    );
    assert!(card.program == object::id(program), base::token_not_found_error());
    assert!(points > 0, base::invalid_amount_error());
    assert!(card.total_points >= points, base::insufficient_balance_error());

    let current_time = clock::timestamp_ms(clock);

    // Create spending entry
    let entry = PointEntry {
        entry_id: card.next_entry_id,
        points,
        entry_type: 1, // spent
        description: utils::safe_utf8(description),
        reference_id: utils::safe_utf8(reference_id),
        created_at: current_time,
        expires_at: 0,
        status: POINTS_SPENT,
    };

    table::add(&mut card.point_entries, card.next_entry_id, entry);
    card.next_entry_id = card.next_entry_id + 1;

    // Update balances
    card.total_points = card.total_points - points;
    card.last_activity = current_time;

    // Update program stats
    program.total_points_redeemed = program.total_points_redeemed + points;

    event::emit(PointsSpent {
        program_id: object::id(program),
        card_id: object::id(card),
        holder: card.holder,
        points,
        description: utils::safe_utf8(description),
    });
}

/// Transfer points between cards
public fun transfer_points(
    program: &mut LoyaltyProgram,
    from_card: &mut LoyaltyCard,
    to_card: &mut LoyaltyCard,
    points: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == from_card.holder, base::not_authorized_error());
    assert!(from_card.program == object::id(program), base::token_not_found_error());
    assert!(to_card.program == object::id(program), base::token_not_found_error());
    assert!(points > 0, base::invalid_amount_error());
    assert!(from_card.total_points >= points, base::insufficient_balance_error());

    let current_time = clock::timestamp_ms(clock);

    // Deduct from sender
    from_card.total_points = from_card.total_points - points;
    from_card.last_activity = current_time;

    // Add to recipient
    to_card.total_points = to_card.total_points + points;
    to_card.lifetime_points = to_card.lifetime_points + points;
    to_card.last_activity = current_time;

    // Check tier upgrade for recipient
    check_tier_upgrade(to_card, program);

    event::emit(PointsTransferred {
        program_id: object::id(program),
        from_card: object::id(from_card),
        to_card: object::id(to_card),
        points,
    });
}

/// Check and perform tier upgrade if applicable
fun check_tier_upgrade(card: &mut LoyaltyCard, program: &LoyaltyProgram) {
    let old_tier = card.tier;
    let new_tier = calculate_tier(card.lifetime_points, program);

    if (new_tier > old_tier) {
        card.tier = new_tier;
        card.tier_name = get_tier_name(new_tier);

        event::emit(TierUpgraded {
            card_id: object::id(card),
            holder: card.holder,
            old_tier,
            new_tier,
            new_tier_name: card.tier_name,
        });
    }
}

/// Calculate tier based on lifetime points
fun calculate_tier(lifetime_points: u64, program: &LoyaltyProgram): u8 {
    if (lifetime_points >= program.diamond_threshold) {
        TIER_DIAMOND
    } else if (lifetime_points >= program.platinum_threshold) {
        TIER_PLATINUM
    } else if (lifetime_points >= program.gold_threshold) {
        TIER_GOLD
    } else if (lifetime_points >= program.silver_threshold) {
        TIER_SILVER
    } else {
        TIER_BRONZE
    }
}

/// Get tier name string
fun get_tier_name(tier: u8): String {
    if (tier == TIER_DIAMOND) {
        string::utf8(b"Diamond")
    } else if (tier == TIER_PLATINUM) {
        string::utf8(b"Platinum")
    } else if (tier == TIER_GOLD) {
        string::utf8(b"Gold")
    } else if (tier == TIER_SILVER) {
        string::utf8(b"Silver")
    } else {
        string::utf8(b"Bronze")
    }
}

// ===== View Functions =====

/// Get program info
public fun get_program_info(program: &LoyaltyProgram): (String, String, u64, u64, u64, u64, u64) {
    (
        program.name,
        program.description,
        program.points_per_dollar,
        program.total_cards,
        program.total_points_issued,
        program.total_points_redeemed,
        program.expiry_days,
    )
}

/// Get card info
public fun get_card_info(card: &LoyaltyCard): (ID, address, String, u8, String, u64, u64, u64) {
    (
        card.program,
        card.holder,
        card.card_number,
        card.tier,
        card.tier_name,
        card.total_points,
        card.lifetime_points,
        card.issued_at,
    )
}

/// Get tier thresholds
public fun get_tier_thresholds(program: &LoyaltyProgram): (u64, u64, u64, u64, u64) {
    (
        program.bronze_threshold,
        program.silver_threshold,
        program.gold_threshold,
        program.platinum_threshold,
        program.diamond_threshold,
    )
}

/// Check if address is authorized issuer
public fun is_authorized_issuer(program: &LoyaltyProgram, issuer: address): bool {
    issuer == program.authority || vec_map::contains(&program.issuers, &issuer)
}

/// Get program statistics
public fun get_program_stats(program: &LoyaltyProgram): (u64, u64, u64) {
    (program.total_cards, program.total_points_issued, program.total_points_redeemed)
}

// ===== Entry Functions =====

/// Earn points entry function
public entry fun earn_points_entry(
    program: &mut LoyaltyProgram,
    card: &mut LoyaltyCard,
    points: u64,
    description: vector<u8>,
    reference_id: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    earn_points(program, card, points, description, reference_id, clock, ctx);
}

/// Spend points entry function
public entry fun spend_points_entry(
    program: &mut LoyaltyProgram,
    card: &mut LoyaltyCard,
    points: u64,
    description: vector<u8>,
    reference_id: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    spend_points(program, card, points, description, reference_id, clock, ctx);
}

/// Transfer points entry function
public entry fun transfer_points_entry(
    program: &mut LoyaltyProgram,
    from_card: &mut LoyaltyCard,
    to_card: &mut LoyaltyCard,
    points: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    transfer_points(program, from_card, to_card, points, clock, ctx);
}
