#[allow(unused_const, duplicate_alias)]
module otl::coin;

use otl::base;
use otl::utils;
use std::option::{Self, Option};
use std::string::{Self, String};
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, UID, ID};
use sui::sui::SUI;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};

// ===== Errors =====
const EInsufficientBalance: u64 = 0;
const EInvalidAmount: u64 = 1;
const ENotAuthorized: u64 = 2;
const ESupplyExceeded: u64 = 3;
const EInvalidMetadata: u64 = 4;
const ETokenNotFound: u64 = 5;

// ===== Core Structs =====

/// Registry that manages multiple utility token types
public struct UtilityTokenRegistry has key {
    id: UID,
    /// Registry owner/admin
    authority: address,
    /// All token types created through this registry
    token_types: Table<String, ID>, // maps token_name to TokenType ID
    /// Registry metadata
    registry_name: String,
    registry_description: String,
    /// Statistics
    total_token_types: u64,
    total_tokens_sold: u64,
    total_revenue: u64, // in SUI
}

/// Individual token type with its own pricing and metadata
public struct TokenType has key {
    id: UID,
    /// Reference to registry
    registry: ID,
    /// Token metadata
    name: String,
    symbol: String,
    description: String,
    icon_url: String,
    external_url: String,
    /// Pricing configuration
    price_per_token: u64, // Price in MIST (1 SUI = 1_000_000_000 MIST)
    is_price_adjustable: bool,
    /// Supply configuration
    max_supply: u64, // 0 = unlimited
    current_supply: u64,
    decimals: u8,
    /// Token configuration
    is_transferable: bool,
    is_burnable: bool,
    /// Sales tracking
    total_sold: u64,
    total_revenue: u64, // in MIST
    /// Authorized sellers (can sell tokens at set price)
    sellers: VecMap<address, bool>,
    /// Token holders registry
    holders: Table<address, ID>, // maps holder address to their TokenWallet ID
}

/// Individual wallet that holds tokens of a specific type for a user
public struct TokenWallet has key, store {
    id: UID,
    /// Reference to token type
    token_type: ID,
    /// Wallet owner
    owner: address,
    /// Token balance
    balance: u64,
    /// Purchase history - tracks at what price tokens were bought
    purchases: Table<u64, PurchaseRecord>, // maps purchase_id to PurchaseRecord
    next_purchase_id: u64,
    /// Wallet metadata
    created_at: u64,
    last_activity: u64,
}

/// Record of a token purchase
public struct PurchaseRecord has store {
    purchase_id: u64,
    amount: u64, // tokens purchased
    price_per_token: u64, // price paid per token in MIST
    total_paid: u64, // total SUI paid in MIST
    purchased_at: u64,
    seller: address, // who sold the tokens
    transaction_ref: String, // optional reference
}

/// Individual utility token object
public struct UtilityToken has key, store {
    id: UID,
    /// Reference to token type
    token_type: ID,
    /// Current owner
    owner: address,
    /// Token amount (for fractional tokens)
    amount: u64,
    /// Purchase info
    purchase_price: u64, // price paid per token in MIST
    purchased_at: u64,
    purchased_from: address,
    /// Token-specific metadata
    metadata: VecMap<String, String>,
}

// ===== Events =====

public struct UtilityTokenRegistryCreated has copy, drop {
    registry_id: ID,
    authority: address,
    registry_name: String,
}

public struct TokenTypeCreated has copy, drop {
    registry_id: ID,
    token_type_id: ID,
    name: String,
    symbol: String,
    price_per_token: u64,
    max_supply: u64,
}

public struct TokensPurchased has copy, drop {
    token_type_id: ID,
    buyer: address,
    seller: address,
    amount: u64,
    price_per_token: u64,
    total_paid: u64,
}

public struct TokenPriceUpdated has copy, drop {
    token_type_id: ID,
    old_price: u64,
    new_price: u64,
    updated_by: address,
}

public struct TokensTransferred has copy, drop {
    token_type_id: ID,
    from: address,
    to: address,
    amount: u64,
}

public struct TokensBurned has copy, drop {
    token_type_id: ID,
    owner: address,
    amount: u64,
}

// ===== Registry Management =====

/// Create a new utility token registry
public fun create_utility_token_registry(
    registry_name: vector<u8>,
    registry_description: vector<u8>,
    ctx: &mut TxContext,
): UtilityTokenRegistry {
    assert!(!vector::is_empty(&registry_name), base::invalid_metadata_error());

    let authority = tx_context::sender(ctx);
    assert!(utils::validate_address(authority), base::not_authorized_error());

    let registry = UtilityTokenRegistry {
        id: object::new(ctx),
        authority,
        token_types: table::new(ctx),
        registry_name: utils::safe_utf8(registry_name),
        registry_description: utils::safe_utf8(registry_description),
        total_token_types: 0,
        total_tokens_sold: 0,
        total_revenue: 0,
    };

    event::emit(UtilityTokenRegistryCreated {
        registry_id: object::id(&registry),
        authority,
        registry_name: registry.registry_name,
    });

    registry
}

/// Create registry and share it
public entry fun create_shared_utility_token_registry(
    registry_name: vector<u8>,
    registry_description: vector<u8>,
    ctx: &mut TxContext,
) {
    let registry = create_utility_token_registry(registry_name, registry_description, ctx);
    transfer::share_object(registry);
}

// ===== Token Type Management =====

/// Create a new token type with pricing
public fun create_token_type(
    registry: &mut UtilityTokenRegistry,
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    icon_url: vector<u8>,
    external_url: vector<u8>,
    price_per_token: u64, // in MIST
    is_price_adjustable: bool,
    max_supply: u64,
    decimals: u8,
    is_transferable: bool,
    is_burnable: bool,
    ctx: &mut TxContext,
): TokenType {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());
    assert!(!vector::is_empty(&symbol), base::invalid_metadata_error());
    assert!(price_per_token > 0, base::invalid_amount_error());

    let name_str = utils::safe_utf8(name);
    assert!(!table::contains(&registry.token_types, name_str), base::token_exists_error());

    let token_type = TokenType {
        id: object::new(ctx),
        registry: object::id(registry),
        name: name_str,
        symbol: utils::safe_utf8(symbol),
        description: utils::safe_utf8(description),
        icon_url: utils::safe_utf8(icon_url),
        external_url: utils::safe_utf8(external_url),
        price_per_token,
        is_price_adjustable,
        max_supply,
        current_supply: 0,
        decimals,
        is_transferable,
        is_burnable,
        total_sold: 0,
        total_revenue: 0,
        sellers: vec_map::empty(),
        holders: table::new(ctx),
    };

    // Register token type in registry
    table::add(&mut registry.token_types, token_type.name, object::id(&token_type));
    registry.total_token_types = registry.total_token_types + 1;

    event::emit(TokenTypeCreated {
        registry_id: object::id(registry),
        token_type_id: object::id(&token_type),
        name: token_type.name,
        symbol: token_type.symbol,
        price_per_token,
        max_supply,
    });

    token_type
}

/// Create token type and share it
public entry fun create_shared_token_type(
    registry: &mut UtilityTokenRegistry,
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    icon_url: vector<u8>,
    external_url: vector<u8>,
    price_per_token: u64,
    is_price_adjustable: bool,
    max_supply: u64,
    decimals: u8,
    is_transferable: bool,
    is_burnable: bool,
    ctx: &mut TxContext,
) {
    let token_type = create_token_type(
        registry,
        name,
        symbol,
        description,
        icon_url,
        external_url,
        price_per_token,
        is_price_adjustable,
        max_supply,
        decimals,
        is_transferable,
        is_burnable,
        ctx,
    );
    transfer::share_object(token_type);
}

/// Update token price (only if adjustable)
public fun update_token_price(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    new_price: u64,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(token_type.registry == object::id(registry), base::token_not_found_error());
    assert!(token_type.is_price_adjustable, base::not_authorized_error());
    assert!(new_price > 0, base::invalid_amount_error());

    let old_price = token_type.price_per_token;
    token_type.price_per_token = new_price;

    event::emit(TokenPriceUpdated {
        token_type_id: object::id(token_type),
        old_price,
        new_price,
        updated_by: tx_context::sender(ctx),
    });
}

/// Add authorized seller
public fun add_seller(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    seller: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(token_type.registry == object::id(registry), base::token_not_found_error());
    assert!(utils::validate_address(seller), base::not_authorized_error());
    assert!(!vec_map::contains(&token_type.sellers, &seller), base::minter_exists_error());

    vec_map::insert(&mut token_type.sellers, seller, true);
}

// ===== Token Purchase & Sales =====

/// Smart purchase function - automatically creates new wallet or adds to existing one
public fun smart_purchase_tokens(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    amount: u64,
    payment: Coin<SUI>,
    mut existing_wallet_opt: Option<TokenWallet>,
    ctx: &mut TxContext,
): TokenWallet {
    assert!(token_type.registry == object::id(registry), base::token_not_found_error());
    assert!(amount > 0, base::invalid_amount_error());

    // Check supply limit
    if (token_type.max_supply > 0) {
        assert!(
            utils::safe_add(token_type.current_supply, amount) <= token_type.max_supply,
            base::supply_exceeded_error(),
        );
    };

    // Calculate required payment
    let total_cost = utils::safe_mul(amount, token_type.price_per_token);
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= total_cost, base::insufficient_balance_error());

    let buyer = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // Handle payment - transfer to registry authority
    transfer::public_transfer(payment, registry.authority);

    // Check if we have an existing wallet to add to
    let mut wallet = if (option::is_some(&existing_wallet_opt)) {
        let existing_wallet = option::extract(&mut existing_wallet_opt);

        // Validate the existing wallet belongs to the buyer and correct token type
        assert!(existing_wallet.owner == buyer, base::not_authorized_error());
        assert!(
            existing_wallet.token_type == object::id(token_type),
            base::token_not_found_error(),
        );

        existing_wallet
    } else {
        // Create new wallet
        let wallet_uid = object::new(ctx);
        let wallet_id = object::uid_to_inner(&wallet_uid);

        // Register new wallet in token type holders
        if (!table::contains(&token_type.holders, buyer)) {
            table::add(&mut token_type.holders, buyer, wallet_id);
        } else {
            // Update existing entry
            let _old_wallet_id = table::remove(&mut token_type.holders, buyer);
            table::add(&mut token_type.holders, buyer, wallet_id);
        };

        TokenWallet {
            id: wallet_uid,
            token_type: object::id(token_type),
            owner: buyer,
            balance: 0,
            purchases: table::new(ctx),
            next_purchase_id: 1,
            created_at: current_time,
            last_activity: current_time,
        }
    };

    // Add purchase record
    let purchase_id = wallet.next_purchase_id;
    let purchase_record = PurchaseRecord {
        purchase_id,
        amount,
        price_per_token: token_type.price_per_token,
        total_paid: total_cost,
        purchased_at: current_time,
        seller: registry.authority,
        transaction_ref: string::utf8(b""),
    };

    table::add(&mut wallet.purchases, purchase_id, purchase_record);
    wallet.next_purchase_id = wallet.next_purchase_id + 1;
    wallet.balance = utils::safe_add(wallet.balance, amount);
    wallet.last_activity = current_time;

    // Update token type stats
    token_type.current_supply = utils::safe_add(token_type.current_supply, amount);
    token_type.total_sold = utils::safe_add(token_type.total_sold, amount);
    token_type.total_revenue = utils::safe_add(token_type.total_revenue, total_cost);

    // Update registry stats
    registry.total_tokens_sold = utils::safe_add(registry.total_tokens_sold, amount);
    registry.total_revenue = utils::safe_add(registry.total_revenue, total_cost);

    // Destroy the empty option
    option::destroy_none(existing_wallet_opt);

    event::emit(TokensPurchased {
        token_type_id: object::id(token_type),
        buyer,
        seller: registry.authority,
        amount,
        price_per_token: token_type.price_per_token,
        total_paid: total_cost,
    });

    wallet
}

/// Entry function for smart purchase - automatically handles new/existing wallets
public entry fun smart_purchase_tokens_entry(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    amount: u64,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    let wallet = smart_purchase_tokens(
        registry,
        token_type,
        amount,
        payment,
        option::none<TokenWallet>(), // No existing wallet provided
        ctx,
    );
    transfer::public_transfer(wallet, tx_context::sender(ctx));
}

/// Entry function for adding to existing wallet
public entry fun smart_add_to_wallet_entry(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    existing_wallet: TokenWallet,
    amount: u64,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    let wallet = smart_purchase_tokens(
        registry,
        token_type,
        amount,
        payment,
        option::some(existing_wallet), // Existing wallet provided
        ctx,
    );
    transfer::public_transfer(wallet, tx_context::sender(ctx));
}

// ===== View Functions =====

/// Get registry info
public fun get_registry_info(
    registry: &UtilityTokenRegistry,
): (String, String, address, u64, u64, u64) {
    (
        registry.registry_name,
        registry.registry_description,
        registry.authority,
        registry.total_token_types,
        registry.total_tokens_sold,
        registry.total_revenue,
    )
}

/// Get token type info
public fun get_token_type_info(
    token_type: &TokenType,
): (String, String, String, u64, u64, u64, u64) {
    (
        token_type.name,
        token_type.symbol,
        token_type.description,
        token_type.price_per_token,
        token_type.max_supply,
        token_type.current_supply,
        token_type.total_revenue,
    )
}

/// Get wallet info
public fun get_wallet_info(wallet: &TokenWallet): (ID, address, u64, u64, u64) {
    (wallet.token_type, wallet.owner, wallet.balance, wallet.created_at, wallet.last_activity)
}

/// Get purchase history count
public fun get_purchase_count(wallet: &TokenWallet): u64 {
    wallet.next_purchase_id - 1
}

/// Check if user has wallet for token type
public fun has_wallet(token_type: &TokenType, user: address): bool {
    table::contains(&token_type.holders, user)
}

/// Get current token price
public fun get_current_price(token_type: &TokenType): u64 {
    token_type.price_per_token
}

/// Check if price is adjustable
public fun is_price_adjustable(token_type: &TokenType): bool {
    token_type.is_price_adjustable
}

/// Get token type configuration
public fun get_token_config(token_type: &TokenType): (bool, bool, u8) {
    (token_type.is_transferable, token_type.is_burnable, token_type.decimals)
}
