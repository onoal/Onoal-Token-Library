#[allow(unused_const, duplicate_alias, unused_variable)]
module otl::onoal_token;

use otl::base;
use otl::utils;
use std::option;
use std::string::{Self, String};
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
use sui::display;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::package;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::url;
use sui::vec_map::{Self, VecMap};

// ===== Constants =====
const DECIMALS: u8 = 9; // Standard SUI decimals
const MAX_SUPPLY: u64 = 1_000_000_000_000_000_000; // 1 billion ONOAL with 9 decimals
const INITIAL_MINT: u64 = 100_000_000_000_000_000; // 100 million initial mint
const FIXED_PRICE_SUI: u64 = 1_000_000_000; // 1 SUI = 1000 ONOAL (fixed rate)

// Token metadata
const TOKEN_NAME: vector<u8> = b"Onoal Token";
const TOKEN_SYMBOL: vector<u8> = b"ONOAL";
const TOKEN_DESCRIPTION: vector<u8> =
    b"The official utility token of the Onoal ecosystem - powering Web3 experiences, NFT marketplaces, and decentralized applications on Sui blockchain.";
const TOKEN_ICON_URL: vector<u8> = b"https://onoal.com/assets/onoal-token-icon.png";

// Minter categories for different use cases
const MINTER_ECOSYSTEM_REWARDS: u8 = 0;
const MINTER_PARTNERSHIPS: u8 = 1;
const MINTER_DEVELOPMENT: u8 = 2;
const MINTER_MARKETING: u8 = 3;
const MINTER_TREASURY: u8 = 4;

// ===== Core Structs =====

/// The Onoal Token - One Time Witness for coin creation
public struct ONOAL_TOKEN has drop {}

/// Token registry and management with comprehensive features
public struct OnoalTokenRegistry has key {
    id: UID,
    /// Token authority (can mint/burn/manage)
    authority: address,
    /// Treasury capability for minting
    treasury_cap: TreasuryCap<ONOAL_TOKEN>,
    /// Version tracking for upgrades
    version: u64,
    created_at: u64,
    last_upgraded: u64,
    /// Core token metadata
    name: String,
    symbol: String,
    description: String,
    icon_url: String,
    website_url: String,
    external_url: String,
    /// Supply management
    total_supply: u64,
    max_supply: u64,
    circulating_supply: u64,
    burned_supply: u64,
    locked_supply: u64, // For staking, vesting, etc.
    /// Fixed pricing
    fixed_price_sui: u64, // How much SUI for 1 ONOAL
    price_enabled: bool,
    /// Authorized minters with limits
    authorized_minters: Table<address, MinterInfo>,
    minter_categories: Table<u8, CategoryInfo>,
    /// Token utility features
    is_mintable: bool,
    is_burnable: bool,
    is_transferable: bool,
    is_stakeable: bool,
    /// Governance features
    governance_enabled: bool,
    voting_power_enabled: bool,
    /// Economics features
    inflation_rate: u64, // Basis points (100 = 1%)
    deflationary_rate: u64, // Basis points for auto-burn
    /// Extensible metadata
    token_attributes: VecMap<String, String>,
    /// Compliance
    kyc_required: bool,
    region_restrictions: VecMap<String, bool>,
    /// Upgrade management
    upgrade_policy: u8, // 0=compatible, 1=breaking_allowed
    migration_required: bool,
}

/// Comprehensive minter information
public struct MinterInfo has store {
    minter: address,
    category: u8,
    max_mint_amount: u64,
    minted_amount: u64,
    daily_limit: u64,
    daily_minted: u64,
    last_mint_day: u64,
    is_active: bool,
    authorized_at: u64,
    expires_at: u64, // 0 = never expires
    purpose: String,
    /// Minter-specific restrictions
    allowed_recipients: VecMap<address, bool>, // Empty = any recipient
    mint_schedule: VecMap<u64, u64>, // timestamp -> amount (for vesting)
}

/// Category configuration for different minter types
public struct CategoryInfo has store {
    category_id: u8,
    name: String,
    max_total_allocation: u64,
    current_allocation: u64,
    requires_approval: bool,
    auto_expire_days: u64,
}

/// Token holder profile with comprehensive tracking
public struct TokenHolder has key, store {
    id: UID,
    holder: address,
    /// Balance tracking
    balance: u64,
    locked_balance: u64, // For staking, vesting
    /// Transaction history
    first_acquired: u64,
    last_transaction: u64,
    total_received: u64,
    total_sent: u64,
    /// Holder status
    loyalty_tier: u8, // 0=Bronze, 1=Silver, 2=Gold, 3=Platinum, 4=Diamond
    reputation_score: u64,
    /// Rewards and benefits
    staking_rewards: u64,
    governance_power: u64,
    voting_weight: u64,
    /// Compliance status
    kyc_verified: bool,
    kyc_level: u8, // 1=basic, 2=enhanced, 3=institutional
    region: String,
    /// Holder attributes
    holder_attributes: VecMap<String, String>,
}

/// One-time witness for Display creation
public struct TOKEN_DISPLAY has drop {}

// ===== Events =====

public struct TokenCreated has copy, drop {
    registry_id: ID,
    authority: address,
    name: String,
    symbol: String,
    max_supply: u64,
    fixed_price_sui: u64,
    initial_supply: u64,
    created_at: u64,
}

public struct TokenMinted has copy, drop {
    registry_id: ID,
    minted_by: address,
    recipient: address,
    amount: u64,
    new_total_supply: u64,
    minter_category: u8,
    purpose: String,
    timestamp: u64,
}

public struct TokenBurned has copy, drop {
    registry_id: ID,
    burned_by: address,
    amount: u64,
    new_total_supply: u64,
    new_burned_supply: u64,
    burn_reason: String,
    timestamp: u64,
}

public struct TokenPurchased has copy, drop {
    registry_id: ID,
    buyer: address,
    sui_paid: u64,
    tokens_received: u64,
    exchange_rate: u64,
    timestamp: u64,
}

public struct MinterAuthorized has copy, drop {
    registry_id: ID,
    minter: address,
    category: u8,
    max_mint_amount: u64,
    daily_limit: u64,
    purpose: String,
    expires_at: u64,
}

public struct TokenUpgraded has copy, drop {
    registry_id: ID,
    from_version: u64,
    to_version: u64,
    upgraded_by: address,
    upgrade_timestamp: u64,
    migration_required: bool,
}

public struct PriceUpdated has copy, drop {
    registry_id: ID,
    old_price: u64,
    new_price: u64,
    updated_by: address,
    timestamp: u64,
}

// ===== Token Creation & Initialization =====

/// Initialize the Onoal Token (called once during deployment)
fun init(witness: ONOAL_TOKEN, ctx: &mut TxContext) {
    // Create the coin with comprehensive metadata
    let (treasury_cap, metadata) = coin::create_currency<ONOAL_TOKEN>(
        witness,
        DECIMALS,
        TOKEN_SYMBOL,
        TOKEN_NAME,
        TOKEN_DESCRIPTION,
        option::some(url::new_unsafe_from_bytes(TOKEN_ICON_URL)),
        ctx,
    );

    let authority = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // Initialize minter categories
    let mut minter_categories = table::new<u8, CategoryInfo>(ctx);

    // Ecosystem rewards category
    table::add(
        &mut minter_categories,
        MINTER_ECOSYSTEM_REWARDS,
        CategoryInfo {
            category_id: MINTER_ECOSYSTEM_REWARDS,
            name: string::utf8(b"Ecosystem Rewards"),
            max_total_allocation: 200_000_000_000_000_000, // 200M tokens
            current_allocation: 0,
            requires_approval: false,
            auto_expire_days: 0, // Never expire
        },
    );

    // Partnership category
    table::add(
        &mut minter_categories,
        MINTER_PARTNERSHIPS,
        CategoryInfo {
            category_id: MINTER_PARTNERSHIPS,
            name: string::utf8(b"Partnerships"),
            max_total_allocation: 100_000_000_000_000_000, // 100M tokens
            current_allocation: 0,
            requires_approval: true,
            auto_expire_days: 365, // 1 year
        },
    );

    // Development category
    table::add(
        &mut minter_categories,
        MINTER_DEVELOPMENT,
        CategoryInfo {
            category_id: MINTER_DEVELOPMENT,
            name: string::utf8(b"Development"),
            max_total_allocation: 150_000_000_000_000_000, // 150M tokens
            current_allocation: 0,
            requires_approval: false,
            auto_expire_days: 0,
        },
    );

    // Marketing category
    table::add(
        &mut minter_categories,
        MINTER_MARKETING,
        CategoryInfo {
            category_id: MINTER_MARKETING,
            name: string::utf8(b"Marketing"),
            max_total_allocation: 50_000_000_000_000_000, // 50M tokens
            current_allocation: 0,
            requires_approval: true,
            auto_expire_days: 180, // 6 months
        },
    );

    // Treasury category
    table::add(
        &mut minter_categories,
        MINTER_TREASURY,
        CategoryInfo {
            category_id: MINTER_TREASURY,
            name: string::utf8(b"Treasury"),
            max_total_allocation: 300_000_000_000_000_000, // 300M tokens
            current_allocation: 0,
            requires_approval: false,
            auto_expire_days: 0,
        },
    );

    // Create comprehensive token registry
    let registry = OnoalTokenRegistry {
        id: object::new(ctx),
        authority,
        treasury_cap,
        version: 1,
        created_at: current_time,
        last_upgraded: current_time,
        name: utils::safe_utf8(TOKEN_NAME),
        symbol: utils::safe_utf8(TOKEN_SYMBOL),
        description: utils::safe_utf8(TOKEN_DESCRIPTION),
        icon_url: utils::safe_utf8(TOKEN_ICON_URL),
        website_url: string::utf8(b"https://onoal.com"),
        external_url: string::utf8(b"https://onoal.com/token"),
        total_supply: 0,
        max_supply: MAX_SUPPLY,
        circulating_supply: 0,
        burned_supply: 0,
        locked_supply: 0,
        fixed_price_sui: FIXED_PRICE_SUI,
        price_enabled: true,
        authorized_minters: table::new(ctx),
        minter_categories,
        is_mintable: true,
        is_burnable: true,
        is_transferable: true,
        is_stakeable: false, // Will be enabled later
        governance_enabled: false,
        voting_power_enabled: false,
        inflation_rate: 0, // No inflation initially
        deflationary_rate: 0, // No deflation initially
        token_attributes: vec_map::empty(),
        kyc_required: false,
        region_restrictions: vec_map::empty(),
        upgrade_policy: 0,
        migration_required: false,
    };

    let registry_id = object::id(&registry);

    // Emit creation event
    event::emit(TokenCreated {
        registry_id,
        authority,
        name: registry.name,
        symbol: registry.symbol,
        max_supply: MAX_SUPPLY,
        fixed_price_sui: FIXED_PRICE_SUI,
        initial_supply: 0,
        created_at: current_time,
    });

    // Create and set up Display for the token
    let display_keys = vector[
        string::utf8(b"name"),
        string::utf8(b"symbol"),
        string::utf8(b"description"),
        string::utf8(b"icon_url"),
        string::utf8(b"website_url"),
        string::utf8(b"decimals"),
        string::utf8(b"total_supply"),
        string::utf8(b"max_supply"),
    ];

    let display_values = vector[
        string::utf8(TOKEN_NAME),
        string::utf8(TOKEN_SYMBOL),
        string::utf8(TOKEN_DESCRIPTION),
        string::utf8(TOKEN_ICON_URL),
        string::utf8(b"https://onoal.com"),
        string::utf8(b"9"),
        string::utf8(b"{total_supply}"),
        string::utf8(b"1000000000000000000"),
    ];

    // Transfer metadata to authority for management
    transfer::public_transfer(metadata, authority);

    // Share the registry so it can be accessed by ecosystem
    transfer::share_object(registry);
}

// ===== Token Purchase Functions =====

/// Purchase tokens with SUI at fixed price
public fun purchase_tokens_with_sui(
    registry: &mut OnoalTokenRegistry,
    sui_payment: Coin<sui::sui::SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<ONOAL_TOKEN> {
    assert!(registry.price_enabled, base::invalid_metadata_error());
    assert!(registry.is_mintable, base::invalid_metadata_error());

    let sui_amount = coin::value(&sui_payment);
    assert!(sui_amount > 0, base::invalid_amount_error());

    // Calculate tokens to mint based on fixed price
    // fixed_price_sui is how much SUI for 1 ONOAL token
    let tokens_to_mint = (sui_amount * 1_000_000_000) / registry.fixed_price_sui;
    assert!(tokens_to_mint > 0, base::invalid_amount_error());

    // Check supply limits
    assert!(
        utils::safe_add(registry.total_supply, tokens_to_mint) <= registry.max_supply,
        base::supply_exceeded_error(),
    );

    let buyer = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);

    // Transfer SUI to authority (treasury)
    transfer::public_transfer(sui_payment, registry.authority);

    // Mint tokens
    let minted_tokens = coin::mint(&mut registry.treasury_cap, tokens_to_mint, ctx);

    // Update supply tracking
    registry.total_supply = registry.total_supply + tokens_to_mint;
    registry.circulating_supply = registry.circulating_supply + tokens_to_mint;

    // Emit purchase event
    event::emit(TokenPurchased {
        registry_id: object::id(registry),
        buyer,
        sui_paid: sui_amount,
        tokens_received: tokens_to_mint,
        exchange_rate: registry.fixed_price_sui,
        timestamp: current_time,
    });

    minted_tokens
}

/// Entry function for token purchase
public entry fun purchase_tokens_entry(
    registry: &mut OnoalTokenRegistry,
    sui_payment: Coin<sui::sui::SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let tokens = purchase_tokens_with_sui(registry, sui_payment, clock, ctx);
    transfer::public_transfer(tokens, tx_context::sender(ctx));
}

// ===== Advanced Minting Functions =====

/// Mint initial supply (only authority, only once)
public fun mint_initial_supply(
    registry: &mut OnoalTokenRegistry,
    recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<ONOAL_TOKEN> {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(registry.total_supply == 0, base::token_exists_error()); // Only once
    assert!(registry.is_mintable, base::invalid_metadata_error());

    let mint_amount = INITIAL_MINT;
    assert!(mint_amount <= registry.max_supply, base::supply_exceeded_error());

    let current_time = clock::timestamp_ms(clock);

    // Mint tokens
    let minted_coin = coin::mint(&mut registry.treasury_cap, mint_amount, ctx);

    // Update supply tracking
    registry.total_supply = mint_amount;
    registry.circulating_supply = mint_amount;

    event::emit(TokenMinted {
        registry_id: object::id(registry),
        minted_by: registry.authority,
        recipient,
        amount: mint_amount,
        new_total_supply: registry.total_supply,
        minter_category: MINTER_TREASURY,
        purpose: string::utf8(b"initial_supply"),
        timestamp: current_time,
    });

    minted_coin
}

/// Mint tokens with comprehensive validation and limits
public fun mint_tokens(
    registry: &mut OnoalTokenRegistry,
    recipient: address,
    amount: u64,
    purpose: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<ONOAL_TOKEN> {
    let minter = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);
    let current_day = current_time / (24 * 60 * 60 * 1000); // Day number

    assert!(registry.is_mintable, base::invalid_metadata_error());
    assert!(amount > 0, base::invalid_amount_error());
    assert!(
        minter == registry.authority || table::contains(&registry.authorized_minters, minter),
        base::not_authorized_error(),
    );

    // Check overall supply limits
    assert!(
        utils::safe_add(registry.total_supply, amount) <= registry.max_supply,
        base::supply_exceeded_error(),
    );

    let mut minter_category = MINTER_TREASURY;

    // Check minter-specific limits (if not authority)
    if (minter != registry.authority) {
        let minter_info = table::borrow_mut(&mut registry.authorized_minters, minter);
        assert!(minter_info.is_active, base::not_authorized_error());

        // Check expiration
        if (minter_info.expires_at > 0 && current_time > minter_info.expires_at) {
            minter_info.is_active = false;
            assert!(false, base::not_authorized_error());
        };

        // Check total mint limit
        assert!(
            utils::safe_add(minter_info.minted_amount, amount) <= minter_info.max_mint_amount,
            base::supply_exceeded_error(),
        );

        // Check daily limit
        if (current_day > minter_info.last_mint_day) {
            minter_info.daily_minted = 0;
            minter_info.last_mint_day = current_day;
        };
        assert!(
            utils::safe_add(minter_info.daily_minted, amount) <= minter_info.daily_limit,
            base::supply_exceeded_error(),
        );

        // Check category limits
        minter_category = minter_info.category;
        let category_info = table::borrow_mut(&mut registry.minter_categories, minter_category);
        assert!(
            utils::safe_add(category_info.current_allocation, amount) <= category_info.max_total_allocation,
            base::supply_exceeded_error(),
        );

        // Update minter and category stats
        minter_info.minted_amount = minter_info.minted_amount + amount;
        minter_info.daily_minted = minter_info.daily_minted + amount;
        category_info.current_allocation = category_info.current_allocation + amount;
    };

    // Mint tokens
    let minted_coin = coin::mint(&mut registry.treasury_cap, amount, ctx);

    // Update supply tracking
    registry.total_supply = registry.total_supply + amount;
    registry.circulating_supply = registry.circulating_supply + amount;

    event::emit(TokenMinted {
        registry_id: object::id(registry),
        minted_by: minter,
        recipient,
        amount,
        new_total_supply: registry.total_supply,
        minter_category,
        purpose: utils::safe_utf8(purpose),
        timestamp: current_time,
    });

    minted_coin
}

/// Entry function to mint and transfer tokens
public entry fun mint_and_transfer(
    registry: &mut OnoalTokenRegistry,
    recipient: address,
    amount: u64,
    purpose: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let minted_coin = mint_tokens(registry, recipient, amount, purpose, clock, ctx);
    transfer::public_transfer(minted_coin, recipient);
}

// ===== Enhanced Burning Functions =====

/// Burn tokens with reason tracking
public fun burn_tokens_with_reason(
    registry: &mut OnoalTokenRegistry,
    coin_to_burn: Coin<ONOAL_TOKEN>,
    reason: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): u64 {
    assert!(registry.is_burnable, base::invalid_metadata_error());

    let burn_amount = coin::value(&coin_to_burn);
    assert!(burn_amount > 0, base::invalid_amount_error());

    let current_time = clock::timestamp_ms(clock);

    // Burn the tokens
    coin::burn(&mut registry.treasury_cap, coin_to_burn);

    // Update supply tracking
    registry.circulating_supply = registry.circulating_supply - burn_amount;
    registry.burned_supply = registry.burned_supply + burn_amount;

    event::emit(TokenBurned {
        registry_id: object::id(registry),
        burned_by: tx_context::sender(ctx),
        amount: burn_amount,
        new_total_supply: registry.total_supply,
        new_burned_supply: registry.burned_supply,
        burn_reason: utils::safe_utf8(reason),
        timestamp: current_time,
    });

    burn_amount
}

/// Entry function to burn tokens with reason
public entry fun burn_tokens_entry(
    registry: &mut OnoalTokenRegistry,
    coin_to_burn: Coin<ONOAL_TOKEN>,
    reason: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    burn_tokens_with_reason(registry, coin_to_burn, reason, clock, ctx);
}

// ===== Enhanced Authorization Management =====

/// Authorize a new minter with comprehensive configuration
public fun authorize_minter(
    registry: &mut OnoalTokenRegistry,
    minter: address,
    category: u8,
    max_mint_amount: u64,
    daily_limit: u64,
    expires_at: u64,
    purpose: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!table::contains(&registry.authorized_minters, minter), base::minter_exists_error());
    assert!(max_mint_amount > 0, base::invalid_amount_error());
    assert!(daily_limit > 0, base::invalid_amount_error());
    assert!(category <= MINTER_TREASURY, base::invalid_metadata_error());
    assert!(table::contains(&registry.minter_categories, category), base::token_not_found_error());

    let current_time = clock::timestamp_ms(clock);

    // Check if category requires approval and has capacity
    let category_info = table::borrow(&registry.minter_categories, category);
    assert!(
        utils::safe_add(category_info.current_allocation, max_mint_amount) <= category_info.max_total_allocation,
        base::supply_exceeded_error(),
    );

    // Set expiration if category has auto-expire
    let final_expires_at = if (expires_at == 0 && category_info.auto_expire_days > 0) {
        current_time + (category_info.auto_expire_days * 24 * 60 * 60 * 1000)
    } else {
        expires_at
    };

    let minter_info = MinterInfo {
        minter,
        category,
        max_mint_amount,
        minted_amount: 0,
        daily_limit,
        daily_minted: 0,
        last_mint_day: 0,
        is_active: true,
        authorized_at: current_time,
        expires_at: final_expires_at,
        purpose: utils::safe_utf8(purpose),
        allowed_recipients: vec_map::empty(),
        mint_schedule: vec_map::empty(),
    };

    table::add(&mut registry.authorized_minters, minter, minter_info);

    event::emit(MinterAuthorized {
        registry_id: object::id(registry),
        minter,
        category,
        max_mint_amount,
        daily_limit,
        purpose: utils::safe_utf8(purpose),
        expires_at: final_expires_at,
    });
}

/// Revoke minter authorization
public fun revoke_minter(registry: &mut OnoalTokenRegistry, minter: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(table::contains(&registry.authorized_minters, minter), base::token_not_found_error());

    let minter_info = table::borrow_mut(&mut registry.authorized_minters, minter);
    minter_info.is_active = false;
}

// ===== Price Management =====

/// Update fixed token price (only authority)
public fun update_fixed_price(
    registry: &mut OnoalTokenRegistry,
    new_price_sui: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(new_price_sui > 0, base::invalid_amount_error());

    let old_price = registry.fixed_price_sui;
    registry.fixed_price_sui = new_price_sui;

    event::emit(PriceUpdated {
        registry_id: object::id(registry),
        old_price,
        new_price: new_price_sui,
        updated_by: registry.authority,
        timestamp: clock::timestamp_ms(clock),
    });
}

/// Enable or disable token purchasing
public fun set_price_enabled(
    registry: &mut OnoalTokenRegistry,
    enabled: bool,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    registry.price_enabled = enabled;
}

// ===== Token Utility Functions =====

/// Split coin with validation
public fun split_coin(
    coin: &mut Coin<ONOAL_TOKEN>,
    amount: u64,
    ctx: &mut TxContext,
): Coin<ONOAL_TOKEN> {
    assert!(coin::value(coin) >= amount, base::insufficient_balance_error());
    assert!(amount > 0, base::invalid_amount_error());
    coin::split(coin, amount, ctx)
}

/// Join coins with validation
public fun join_coins(coin1: &mut Coin<ONOAL_TOKEN>, coin2: Coin<ONOAL_TOKEN>) {
    assert!(coin::value(&coin2) > 0, base::invalid_amount_error());
    coin::join(coin1, coin2);
}

/// Convert to display format (human readable)
public fun to_display_amount(amount: u64): u64 {
    amount / 1_000_000_000 // Convert from base units to whole tokens
}

/// Convert from display format to base units
public fun from_display_amount(display_amount: u64): u64 {
    display_amount * 1_000_000_000 // Convert to base units
}

/// Calculate SUI cost for token amount
public fun calculate_sui_cost(registry: &OnoalTokenRegistry, token_amount: u64): u64 {
    (token_amount * registry.fixed_price_sui) / 1_000_000_000
}

/// Calculate token amount for SUI payment
public fun calculate_token_amount(registry: &OnoalTokenRegistry, sui_amount: u64): u64 {
    (sui_amount * 1_000_000_000) / registry.fixed_price_sui
}

// ===== View Functions =====

/// Get comprehensive token information
public fun get_token_info(
    registry: &OnoalTokenRegistry,
): (String, String, String, String, u64, u64, u64, u64, u64, u64) {
    (
        registry.name,
        registry.symbol,
        registry.description,
        registry.icon_url,
        registry.total_supply,
        registry.max_supply,
        registry.circulating_supply,
        registry.burned_supply,
        registry.locked_supply,
        registry.fixed_price_sui,
    )
}

/// Get detailed supply statistics
public fun get_supply_stats(registry: &OnoalTokenRegistry): (u64, u64, u64, u64, u64) {
    (
        registry.total_supply,
        registry.circulating_supply,
        registry.burned_supply,
        registry.locked_supply,
        registry.max_supply - registry.total_supply, // remaining mintable
    )
}

/// Get token configuration
public fun get_token_config(
    registry: &OnoalTokenRegistry,
): (bool, bool, bool, bool, bool, bool, bool) {
    (
        registry.is_mintable,
        registry.is_burnable,
        registry.is_transferable,
        registry.is_stakeable,
        registry.governance_enabled,
        registry.voting_power_enabled,
        registry.price_enabled,
    )
}

/// Get pricing information
public fun get_pricing_info(registry: &OnoalTokenRegistry): (u64, bool, u64, u64) {
    (
        registry.fixed_price_sui,
        registry.price_enabled,
        registry.inflation_rate,
        registry.deflationary_rate,
    )
}

/// Check if address is authorized minter
public fun is_authorized_minter(registry: &OnoalTokenRegistry, minter: address): bool {
    if (minter == registry.authority) {
        true
    } else if (table::contains(&registry.authorized_minters, minter)) {
        let minter_info = table::borrow(&registry.authorized_minters, minter);
        minter_info.is_active
    } else {
        false
    }
}

/// Get comprehensive minter information
public fun get_minter_info(
    registry: &OnoalTokenRegistry,
    minter: address,
): (u8, u64, u64, u64, u64, bool, u64, String) {
    assert!(table::contains(&registry.authorized_minters, minter), base::token_not_found_error());
    let minter_info = table::borrow(&registry.authorized_minters, minter);

    (
        minter_info.category,
        minter_info.max_mint_amount,
        minter_info.minted_amount,
        minter_info.daily_limit,
        minter_info.daily_minted,
        minter_info.is_active,
        minter_info.expires_at,
        minter_info.purpose,
    )
}

/// Get category information
public fun get_category_info(
    registry: &OnoalTokenRegistry,
    category: u8,
): (String, u64, u64, bool, u64) {
    assert!(table::contains(&registry.minter_categories, category), base::token_not_found_error());
    let category_info = table::borrow(&registry.minter_categories, category);

    (
        category_info.name,
        category_info.max_total_allocation,
        category_info.current_allocation,
        category_info.requires_approval,
        category_info.auto_expire_days,
    )
}

/// Get coin value in display format
public fun get_coin_display_value(coin: &Coin<ONOAL_TOKEN>): u64 {
    to_display_amount(coin::value(coin))
}

/// Calculate percentage of total supply
public fun calculate_supply_percentage(registry: &OnoalTokenRegistry, amount: u64): u64 {
    if (registry.total_supply == 0) {
        0
    } else {
        (amount * 10000) / registry.total_supply // Returns basis points (0.01%)
    }
}

/// Get token economics data
public fun get_economics_data(registry: &OnoalTokenRegistry): (u64, u64, bool, bool, u8) {
    (
        registry.inflation_rate,
        registry.deflationary_rate,
        registry.kyc_required,
        registry.migration_required,
        registry.upgrade_policy,
    )
}

// ===== Administrative Functions =====

/// Update comprehensive token metadata
public fun update_token_metadata(
    registry: &mut OnoalTokenRegistry,
    new_description: vector<u8>,
    new_website_url: vector<u8>,
    new_external_url: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    if (!vector::is_empty(&new_description)) {
        assert!(utils::validate_description(&new_description), base::invalid_description_error());
        registry.description = utils::safe_utf8(new_description);
    };

    if (!vector::is_empty(&new_website_url)) {
        assert!(utils::validate_url(&new_website_url), base::invalid_url_error());
        registry.website_url = utils::safe_utf8(new_website_url);
    };

    if (!vector::is_empty(&new_external_url)) {
        assert!(utils::validate_url(&new_external_url), base::invalid_url_error());
        registry.external_url = utils::safe_utf8(new_external_url);
    };
}

/// Update token features comprehensively
public fun update_token_features(
    registry: &mut OnoalTokenRegistry,
    is_mintable: bool,
    is_burnable: bool,
    is_transferable: bool,
    is_stakeable: bool,
    governance_enabled: bool,
    voting_power_enabled: bool,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());

    registry.is_mintable = is_mintable;
    registry.is_burnable = is_burnable;
    registry.is_transferable = is_transferable;
    registry.is_stakeable = is_stakeable;
    registry.governance_enabled = governance_enabled;
    registry.voting_power_enabled = voting_power_enabled;
}

/// Update economic parameters
public fun update_economics(
    registry: &mut OnoalTokenRegistry,
    inflation_rate: u64,
    deflationary_rate: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(inflation_rate <= 10000, base::invalid_amount_error()); // Max 100%
    assert!(deflationary_rate <= 1000, base::invalid_amount_error()); // Max 10%

    registry.inflation_rate = inflation_rate;
    registry.deflationary_rate = deflationary_rate;
}

/// Add/update token attribute
public fun add_token_attribute(
    registry: &mut OnoalTokenRegistry,
    key: vector<u8>,
    value: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!vector::is_empty(&key), base::invalid_metadata_error());

    let key_str = utils::safe_utf8(key);
    let value_str = utils::safe_utf8(value);

    if (vec_map::contains(&registry.token_attributes, &key_str)) {
        *vec_map::get_mut(&mut registry.token_attributes, &key_str) = value_str;
    } else {
        vec_map::insert(&mut registry.token_attributes, key_str, value_str);
    };
}

/// Get token attribute
public fun get_token_attribute(registry: &OnoalTokenRegistry, key: &String): String {
    if (vec_map::contains(&registry.token_attributes, key)) {
        *vec_map::get(&registry.token_attributes, key)
    } else {
        string::utf8(b"")
    }
}

/// Transfer authority to new address
public fun transfer_authority(
    registry: &mut OnoalTokenRegistry,
    new_authority: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(utils::validate_address(new_authority), base::not_authorized_error());
    assert!(new_authority != registry.authority, base::invalid_metadata_error());

    registry.authority = new_authority;
}

// ===== Upgrade Functions =====

/// Execute comprehensive token upgrade
public fun execute_token_upgrade(
    registry: &mut OnoalTokenRegistry,
    new_version: u64,
    migration_required: bool,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(new_version > registry.version, base::invalid_metadata_error());

    let old_version = registry.version;
    let current_time = clock::timestamp_ms(clock);

    registry.version = new_version;
    registry.last_upgraded = current_time;
    registry.migration_required = migration_required;

    // Emit upgrade event
    event::emit(TokenUpgraded {
        registry_id: object::id(registry),
        from_version: old_version,
        to_version: new_version,
        upgraded_by: registry.authority,
        upgrade_timestamp: current_time,
        migration_required,
    });
}

/// Get version information
public fun get_version_info(registry: &OnoalTokenRegistry): (u64, u64, u64, bool, u8) {
    (
        registry.version,
        registry.created_at,
        registry.last_upgraded,
        registry.migration_required,
        registry.upgrade_policy,
    )
}

#[test_only]
/// Create registry for testing
public fun create_test_registry(
    ctx: &mut TxContext,
): (OnoalTokenRegistry, TreasuryCap<ONOAL_TOKEN>) {
    let (treasury_cap, metadata) = coin::create_currency<ONOAL_TOKEN>(
        ONOAL_TOKEN {},
        DECIMALS,
        TOKEN_SYMBOL,
        TOKEN_NAME,
        TOKEN_DESCRIPTION,
        option::none(),
        ctx,
    );

    // Transfer metadata to sender for proper cleanup
    transfer::public_transfer(metadata, tx_context::sender(ctx));

    let registry = OnoalTokenRegistry {
        id: object::new(ctx),
        authority: tx_context::sender(ctx),
        treasury_cap,
        version: 1,
        created_at: 0,
        last_upgraded: 0,
        name: utils::safe_utf8(TOKEN_NAME),
        symbol: utils::safe_utf8(TOKEN_SYMBOL),
        description: utils::safe_utf8(TOKEN_DESCRIPTION),
        icon_url: utils::safe_utf8(TOKEN_ICON_URL),
        website_url: string::utf8(b"https://onoal.com"),
        external_url: string::utf8(b"https://onoal.com/token"),
        total_supply: 0,
        max_supply: MAX_SUPPLY,
        circulating_supply: 0,
        burned_supply: 0,
        locked_supply: 0,
        fixed_price_sui: FIXED_PRICE_SUI,
        price_enabled: true,
        authorized_minters: table::new(ctx),
        minter_categories: table::new(ctx),
        is_mintable: true,
        is_burnable: true,
        is_transferable: true,
        is_stakeable: false,
        governance_enabled: false,
        voting_power_enabled: false,
        inflation_rate: 0,
        deflationary_rate: 0,
        token_attributes: vec_map::empty(),
        kyc_required: false,
        region_restrictions: vec_map::empty(),
        upgrade_policy: 0,
        migration_required: false,
    };

    // Create a separate treasury cap for testing
    let (test_treasury_cap, test_metadata) = coin::create_currency<ONOAL_TOKEN>(
        ONOAL_TOKEN {},
        DECIMALS,
        TOKEN_SYMBOL,
        TOKEN_NAME,
        TOKEN_DESCRIPTION,
        option::none(),
        ctx,
    );

    // Transfer test metadata to sender for proper cleanup
    transfer::public_transfer(test_metadata, tx_context::sender(ctx));

    (registry, test_treasury_cap)
}
