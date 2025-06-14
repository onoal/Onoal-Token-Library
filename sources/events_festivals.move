// Events & Festivals Module - Complete Event Management System
module otl::events_festivals;

use otl::base;
use otl::utils;
use std::option::{Self, Option};
use std::string::{Self, String};
use sui::balance::{Self, Balance};
use sui::bcs;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::display;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::package;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

// ===== Constants =====
const MAX_BATCH_TICKETS: u64 = 1000;
const MAX_FESTIVAL_DURATION_DAYS: u64 = 30;
const MIN_TICKET_PRICE: u64 = 1000; // 0.001 SUI minimum
const MAX_LOYALTY_TIERS: u8 = 10;

// Ticket Status
const TICKET_STATUS_VALID: u8 = 0;
const TICKET_STATUS_USED: u8 = 1;
const TICKET_STATUS_EXPIRED: u8 = 2;
const TICKET_STATUS_CANCELLED: u8 = 3;

// Access Levels
const ACCESS_GENERAL: u8 = 0;
const ACCESS_VIP: u8 = 1;
const ACCESS_BACKSTAGE: u8 = 2;
const ACCESS_ARTIST: u8 = 3;

// Badge Types
const BADGE_EARLY_BIRD: u8 = 0;
const BADGE_REPEAT_VISITOR: u8 = 1;
const BADGE_VIP_MEMBER: u8 = 2;
const BADGE_SPECIAL_ACHIEVEMENT: u8 = 3;

// ===== Core Structs =====

/// Main event/festival registry
public struct EventRegistry has key {
    id: UID,
    /// Event organizer/authority
    authority: address,
    /// Event metadata
    name: String,
    description: String,
    venue: String,
    image_url: String,
    website_url: String,
    /// Event timing
    start_date: u64,
    end_date: u64,
    registration_deadline: u64,
    /// Festival coin configuration
    festival_coin_name: String,
    festival_coin_symbol: String,
    coin_to_fiat_rate: u64, // Rate: 1 EUR = X festival coins
    /// Ticket configuration
    ticket_types: Table<String, TicketType>, // ticket_type_name -> TicketType
    total_tickets_sold: u64,
    total_revenue: u64,
    /// Access control
    access_gates: Table<String, AccessGate>, // gate_name -> AccessGate
    /// Loyalty program
    loyalty_program: LoyaltyProgram,
    /// Event status
    is_active: bool,
    is_cancelled: bool,
    created_at: u64,
}

/// Festival coin type (One Time Witness)
public struct FESTIVAL_COIN has drop {}

/// Festival coin treasury and metadata
public struct FestivalCoinTreasury has key {
    id: UID,
    event_id: ID,
    treasury_cap: TreasuryCap<FESTIVAL_COIN>,
    /// Coin metadata
    name: String,
    symbol: String,
    decimals: u8,
    /// Supply tracking
    total_supply: u64,
    circulating_supply: u64,
    /// Exchange rates
    fiat_rate: u64, // 1 EUR = X coins
    sui_rate: u64, // 1 SUI = X coins
    /// Revenue tracking
    total_fiat_loaded: u64,
    total_crypto_loaded: u64,
}

/// Ticket type configuration
public struct TicketType has store {
    name: String,
    description: String,
    price_sui: u64,
    price_festival_coins: u64,
    max_supply: u64,
    current_supply: u64,
    access_level: u8,
    includes_perks: VecMap<String, String>, // perk_name -> perk_description
    valid_from: u64,
    valid_until: u64,
    is_transferable: bool,
}

/// Event ticket NFT
public struct EventTicket has key, store {
    id: UID,
    /// Ticket identification
    event_id: ID,
    ticket_type: String,
    ticket_number: u64,
    qr_code: String, // Unique QR code for verification
    /// Holder information
    holder: address,
    original_buyer: address,
    /// Ticket details
    access_level: u8,
    seat_info: String, // "General Admission", "Section A Row 5 Seat 12", etc.
    special_perks: VecMap<String, String>,
    /// Status and timing
    status: u8,
    purchased_at: u64,
    used_at: u64,
    /// Verification data
    verification_hash: String,
    /// Commemorative data (filled after use)
    commemorative_title: String,
    commemorative_description: String,
    commemorative_image: String,
}

/// Access gate for entry control
public struct AccessGate has store {
    gate_name: String,
    location: String,
    required_access_level: u8,
    required_ticket_types: VecSet<String>,
    is_active: bool,
    total_entries: u64,
    last_entry_time: u64,
}

/// Loyalty program for repeat visitors
public struct LoyaltyProgram has store {
    program_name: String,
    tiers: Table<u8, LoyaltyTier>, // tier_level -> LoyaltyTier
    badges: Table<String, BadgeTemplate>, // badge_name -> BadgeTemplate
    member_count: u64,
    total_badges_issued: u64,
}

/// Loyalty tier configuration
public struct LoyaltyTier has store {
    tier_level: u8,
    tier_name: String,
    required_events: u64, // Number of events attended
    required_spending: u64, // Total spending in SUI
    benefits: VecMap<String, String>, // benefit_name -> benefit_description
    discount_percentage: u8, // 0-100
    early_access_hours: u64, // Hours before general sale
}

/// Badge template for achievements
public struct BadgeTemplate has store {
    badge_name: String,
    badge_description: String,
    badge_image: String,
    badge_type: u8,
    requirements: VecMap<String, String>, // requirement_name -> requirement_description
    is_active: bool,
    total_issued: u64,
}

/// Loyalty badge NFT
public struct LoyaltyBadge has key, store {
    id: UID,
    /// Badge identification
    event_id: ID,
    badge_name: String,
    badge_type: u8,
    /// Holder information
    holder: address,
    /// Badge metadata
    title: String,
    description: String,
    image_url: String,
    achievement_data: VecMap<String, String>, // achievement details
    /// Timing
    earned_at: u64,
    tier_level: u8,
}

/// User's event profile
public struct EventProfile has key {
    id: UID,
    user: address,
    /// Attendance history
    events_attended: VecSet<ID>,
    total_events: u64,
    total_spending: u64,
    /// Current loyalty status
    current_tier: u8,
    tier_name: String,
    /// Badges earned
    badges_earned: VecSet<ID>,
    /// Festival coins balance tracking
    festival_coins_earned: u64,
    festival_coins_spent: u64,
    /// Profile metadata
    display_name: String,
    avatar_url: String,
    created_at: u64,
    last_activity: u64,
}

/// One Time Witness for displays
public struct EVENTS_FESTIVALS has drop {}

// ===== Events =====

public struct EventCreated has copy, drop {
    event_id: ID,
    authority: address,
    name: String,
    start_date: u64,
    end_date: u64,
}

public struct TicketPurchased has copy, drop {
    event_id: ID,
    ticket_id: ID,
    buyer: address,
    ticket_type: String,
    price_paid: u64,
    payment_method: String, // "SUI" or "FESTIVAL_COINS"
}

public struct TicketUsed has copy, drop {
    event_id: ID,
    ticket_id: ID,
    holder: address,
    gate_name: String,
    used_at: u64,
}

public struct FestivalCoinsLoaded has copy, drop {
    event_id: ID,
    user: address,
    amount: u64,
    payment_method: String, // "FIAT" or "CRYPTO"
    exchange_rate: u64,
}

public struct BadgeEarned has copy, drop {
    event_id: ID,
    badge_id: ID,
    holder: address,
    badge_name: String,
    achievement_type: String,
}

public struct AccessGranted has copy, drop {
    event_id: ID,
    ticket_id: ID,
    gate_name: String,
    access_level: u8,
    timestamp: u64,
}

// ===== Initialization =====

/// Initialize displays for all NFT types
public fun init_displays(otw: EVENTS_FESTIVALS, ctx: &mut TxContext) {
    // Event Ticket Display
    let ticket_keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"ticket_type"),
        string::utf8(b"seat_info"),
        string::utf8(b"qr_code"),
        string::utf8(b"status"),
        string::utf8(b"event_name"),
    ];

    let ticket_values = vector[
        string::utf8(b"Event Ticket #{ticket_number}"),
        string::utf8(b"Digital event ticket for {event_name} - {ticket_type}"),
        string::utf8(b"https://api.onoal.com/tickets/{event_id}/{ticket_number}/image"),
        string::utf8(b"{ticket_type}"),
        string::utf8(b"{seat_info}"),
        string::utf8(b"{qr_code}"),
        string::utf8(b"{status}"),
        string::utf8(b"Onoal Events"),
    ];

    let publisher = package::claim(otw, ctx);
    let mut ticket_display = display::new_with_fields<EventTicket>(
        &publisher,
        ticket_keys,
        ticket_values,
        ctx,
    );
    display::update_version(&mut ticket_display);

    // Loyalty Badge Display
    let badge_keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"badge_type"),
        string::utf8(b"tier_level"),
        string::utf8(b"earned_at"),
    ];

    let badge_values = vector[
        string::utf8(b"{title}"),
        string::utf8(b"{description}"),
        string::utf8(b"{image_url}"),
        string::utf8(b"{badge_name}"),
        string::utf8(b"Tier {tier_level}"),
        string::utf8(b"{earned_at}"),
    ];

    let mut badge_display = display::new_with_fields<LoyaltyBadge>(
        &publisher,
        badge_keys,
        badge_values,
        ctx,
    );
    display::update_version(&mut badge_display);

    // Share displays
    transfer::public_share_object(ticket_display);
    transfer::public_share_object(badge_display);
    transfer::public_transfer(publisher, tx_context::sender(ctx));
}

// ===== Event Management =====

/// Create a new event/festival
public fun create_event(
    name: vector<u8>,
    description: vector<u8>,
    venue: vector<u8>,
    image_url: vector<u8>,
    website_url: vector<u8>,
    start_date: u64,
    end_date: u64,
    registration_deadline: u64,
    festival_coin_name: vector<u8>,
    festival_coin_symbol: vector<u8>,
    coin_to_fiat_rate: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): (EventRegistry, FestivalCoinTreasury) {
    let authority = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);

    // Validate timing
    assert!(start_date > current_time, base::invalid_metadata_error());
    assert!(end_date > start_date, base::invalid_metadata_error());
    assert!(registration_deadline <= start_date, base::invalid_metadata_error());
    assert!(
        end_date - start_date <= MAX_FESTIVAL_DURATION_DAYS * 24 * 60 * 60 * 1000,
        base::invalid_metadata_error(),
    );

    // Create festival coin treasury
    let (treasury_cap, coin_metadata) = coin::create_currency<FESTIVAL_COIN>(
        FESTIVAL_COIN {},
        9, // decimals
        festival_coin_symbol,
        festival_coin_name,
        b"Festival coins for event purchases and rewards",
        option::none(),
        ctx,
    );

    let coin_treasury = FestivalCoinTreasury {
        id: object::new(ctx),
        event_id: object::id_from_address(@0x0), // Will be updated after event creation
        treasury_cap,
        name: utils::safe_utf8(festival_coin_name),
        symbol: utils::safe_utf8(festival_coin_symbol),
        decimals: 9,
        total_supply: 0,
        circulating_supply: 0,
        fiat_rate: coin_to_fiat_rate,
        sui_rate: 1000, // Default: 1 SUI = 1000 festival coins
        total_fiat_loaded: 0,
        total_crypto_loaded: 0,
    };

    // Transfer coin metadata to authority
    transfer::public_transfer(coin_metadata, authority);

    // Create loyalty program
    let loyalty_program = LoyaltyProgram {
        program_name: utils::safe_utf8(name),
        tiers: table::new(ctx),
        badges: table::new(ctx),
        member_count: 0,
        total_badges_issued: 0,
    };

    // Create event registry
    let mut event_registry = EventRegistry {
        id: object::new(ctx),
        authority,
        name: utils::safe_utf8(name),
        description: utils::safe_utf8(description),
        venue: utils::safe_utf8(venue),
        image_url: utils::safe_utf8(image_url),
        website_url: utils::safe_utf8(website_url),
        start_date,
        end_date,
        registration_deadline,
        festival_coin_name: utils::safe_utf8(festival_coin_name),
        festival_coin_symbol: utils::safe_utf8(festival_coin_symbol),
        coin_to_fiat_rate,
        ticket_types: table::new(ctx),
        total_tickets_sold: 0,
        total_revenue: 0,
        access_gates: table::new(ctx),
        loyalty_program,
        is_active: true,
        is_cancelled: false,
        created_at: current_time,
    };

    // Update coin treasury with event ID
    let event_id = object::id(&event_registry);

    event::emit(EventCreated {
        event_id,
        authority,
        name: event_registry.name,
        start_date,
        end_date,
    });

    (event_registry, coin_treasury)
}

// ===== Festival Coins Management =====

/// Load festival coins with SUI payment
public fun load_festival_coins_sui(
    event: &EventRegistry,
    treasury: &mut FestivalCoinTreasury,
    sui_payment: Coin<sui::sui::SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<FESTIVAL_COIN> {
    assert!(event.is_active && !event.is_cancelled, base::invalid_metadata_error());

    let sui_amount = coin::value(&sui_payment);
    let coins_to_mint = sui_amount * treasury.sui_rate;
    let event_id = object::id(event);
    let sender = tx_context::sender(ctx);

    // Transfer SUI to event authority
    transfer::public_transfer(sui_payment, event.authority);

    // Mint festival coins
    let festival_coins = coin::mint(&mut treasury.treasury_cap, coins_to_mint, ctx);

    // Update treasury stats
    treasury.total_supply = treasury.total_supply + coins_to_mint;
    treasury.circulating_supply = treasury.circulating_supply + coins_to_mint;
    treasury.total_crypto_loaded = treasury.total_crypto_loaded + sui_amount;

    event::emit(FestivalCoinsLoaded {
        event_id,
        user: sender,
        amount: coins_to_mint,
        payment_method: string::utf8(b"CRYPTO"),
        exchange_rate: treasury.sui_rate,
    });

    festival_coins
}

// ===== View Functions =====

/// Get event information
public fun get_event_info(event: &EventRegistry): (String, String, String, u64, u64, u64, bool) {
    (
        event.name,
        event.description,
        event.venue,
        event.start_date,
        event.end_date,
        event.total_tickets_sold,
        event.is_active,
    )
}

/// Get festival coin treasury info
public fun get_treasury_info(
    treasury: &FestivalCoinTreasury,
): (String, String, u64, u64, u64, u64) {
    (
        treasury.name,
        treasury.symbol,
        treasury.total_supply,
        treasury.circulating_supply,
        treasury.fiat_rate,
        treasury.sui_rate,
    )
}

// ===== Entry Functions =====

/// Entry function to create event
public entry fun create_event_entry(
    name: vector<u8>,
    description: vector<u8>,
    venue: vector<u8>,
    image_url: vector<u8>,
    website_url: vector<u8>,
    start_date: u64,
    end_date: u64,
    registration_deadline: u64,
    festival_coin_name: vector<u8>,
    festival_coin_symbol: vector<u8>,
    coin_to_fiat_rate: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (event_registry, coin_treasury) = create_event(
        name,
        description,
        venue,
        image_url,
        website_url,
        start_date,
        end_date,
        registration_deadline,
        festival_coin_name,
        festival_coin_symbol,
        coin_to_fiat_rate,
        clock,
        ctx,
    );

    transfer::share_object(event_registry);
    transfer::share_object(coin_treasury);
}

/// Entry function to load festival coins with SUI
public entry fun load_festival_coins_sui_entry(
    event: &EventRegistry,
    treasury: &mut FestivalCoinTreasury,
    sui_payment: Coin<sui::sui::SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let festival_coins = load_festival_coins_sui(
        event,
        treasury,
        sui_payment,
        clock,
        ctx,
    );

    transfer::public_transfer(festival_coins, tx_context::sender(ctx));
}
