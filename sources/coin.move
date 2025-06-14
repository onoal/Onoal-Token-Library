#[allow(unused_const, duplicate_alias, unused_field)]
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
const EBatchTooLarge: u64 = 6;

// ===== Constants =====
const MAX_BATCH_SIZE: u64 = 10000; // Maximum tokens per batch operation
const MIN_BATCH_SIZE: u64 = 100; // Minimum for batch discount

// ===== Optimized Core Structs =====

/// Lightweight registry for utility tokens - optimized for gas efficiency
public struct UtilityTokenRegistry has key {
    id: UID,
    /// Registry owner/admin
    authority: address,
    /// All token types (simplified mapping)
    token_types: Table<String, ID>,
    /// Registry metadata (minimal)
    registry_name: String,
    /// Statistics (aggregated only)
    total_token_types: u64,
    total_supply_minted: u64, // Total across all token types
}

/// Highly optimized token type for batch operations
public struct TokenType has key {
    id: UID,
    /// Basic metadata (minimal storage)
    name: String,
    symbol: String,
    description: String,
    /// Pricing (simplified)
    price_per_token: u64, // Price in MIST
    /// Supply tracking (essential only)
    max_supply: u64, // 0 = unlimited
    current_supply: u64,
    decimals: u8,
    /// Configuration flags (packed for efficiency)
    config_flags: u8, // bit 0: transferable, bit 1: burnable, bit 2: price_adjustable
    /// Batch pricing discounts
    batch_discount_threshold: u64, // Minimum tokens for discount
    batch_discount_percent: u8, // Discount percentage (0-100)
    /// Authorized issuers (simplified)
    issuers: Table<address, bool>,
}

/// Ultra-lightweight token wallet - optimized for batch operations
public struct TokenWallet has key, store {
    id: UID,
    /// Essential data only
    token_type: ID,
    owner: address,
    balance: u64,
    /// Minimal metadata
    created_at: u64,
}

/// Batch mint receipt for tracking large operations
public struct BatchMintReceipt has key, store {
    id: UID,
    token_type: ID,
    recipient: address,
    amount_minted: u64,
    total_cost: u64,
    batch_discount_applied: u8,
    minted_at: u64,
    batch_id: String, // For tracking/reference
}

// ===== Optimized Events =====

public struct TokenTypeCreated has copy, drop {
    token_type_id: ID,
    name: String,
    symbol: String,
    price_per_token: u64,
    max_supply: u64,
}

public struct BatchTokensMinted has copy, drop {
    token_type_id: ID,
    recipient: address,
    amount: u64,
    total_cost: u64,
    discount_applied: u8,
    batch_id: String,
}

public struct TokensTransferred has copy, drop {
    token_type_id: ID,
    from: address,
    to: address,
    amount: u64,
}

// ===== Registry Management (Simplified) =====

/// Create optimized utility token registry
public fun create_utility_token_registry(
    registry_name: vector<u8>,
    ctx: &mut TxContext,
): UtilityTokenRegistry {
    assert!(!vector::is_empty(&registry_name), base::invalid_metadata_error());

    let registry = UtilityTokenRegistry {
        id: object::new(ctx),
        authority: tx_context::sender(ctx),
        token_types: table::new(ctx),
        registry_name: utils::safe_utf8(registry_name),
        total_token_types: 0,
        total_supply_minted: 0,
    };

    registry
}

/// Create and share registry
public entry fun create_shared_utility_token_registry(
    registry_name: vector<u8>,
    ctx: &mut TxContext,
) {
    let registry = create_utility_token_registry(registry_name, ctx);
    transfer::share_object(registry);
}

// ===== Optimized Token Type Management =====

/// Create highly optimized token type for batch operations
public fun create_token_type(
    registry: &mut UtilityTokenRegistry,
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    price_per_token: u64,
    max_supply: u64,
    decimals: u8,
    is_transferable: bool,
    is_burnable: bool,
    is_price_adjustable: bool,
    batch_discount_threshold: u64,
    batch_discount_percent: u8,
    ctx: &mut TxContext,
): TokenType {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());
    assert!(price_per_token > 0, base::invalid_amount_error());
    assert!(batch_discount_percent <= 100, base::invalid_amount_error());

    let name_str = utils::safe_utf8(name);
    assert!(!table::contains(&registry.token_types, name_str), base::token_exists_error());

    // Pack configuration flags for gas efficiency
    let mut config_flags = 0u8;
    if (is_transferable) config_flags = config_flags | 1;
    if (is_burnable) config_flags = config_flags | 2;
    if (is_price_adjustable) config_flags = config_flags | 4;

    let token_type = TokenType {
        id: object::new(ctx),
        name: name_str,
        symbol: utils::safe_utf8(symbol),
        description: utils::safe_utf8(description),
        price_per_token,
        max_supply,
        current_supply: 0,
        decimals,
        config_flags,
        batch_discount_threshold,
        batch_discount_percent,
        issuers: table::new(ctx),
    };

    // Register in registry
    table::add(&mut registry.token_types, token_type.name, object::id(&token_type));
    registry.total_token_types = registry.total_token_types + 1;

    event::emit(TokenTypeCreated {
        token_type_id: object::id(&token_type),
        name: token_type.name,
        symbol: token_type.symbol,
        price_per_token,
        max_supply,
    });

    token_type
}

/// Add issuer (simplified)
public fun add_issuer(
    registry: &UtilityTokenRegistry,
    token_type: &mut TokenType,
    issuer: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == registry.authority, base::not_authorized_error());
    assert!(!table::contains(&token_type.issuers, issuer), base::minter_exists_error());

    table::add(&mut token_type.issuers, issuer, true);
}

// ===== Ultra-Efficient Batch Minting =====

/// Batch mint tokens - optimized for 10,000+ tokens with minimal gas
public fun batch_mint_tokens(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    recipient: address,
    amount: u64,
    payment: Coin<SUI>,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
): (TokenWallet, BatchMintReceipt) {
    let sender = tx_context::sender(ctx);

    // Authorization check
    assert!(
        sender == registry.authority || table::contains(&token_type.issuers, sender),
        base::not_authorized_error(),
    );

    // Validate batch size
    assert!(amount > 0 && amount <= MAX_BATCH_SIZE, base::invalid_amount_error());

    // Supply check
    if (token_type.max_supply > 0) {
        assert!(
            utils::safe_add(token_type.current_supply, amount) <= token_type.max_supply,
            base::supply_exceeded_error(),
        );
    };

    // Calculate cost with batch discount
    let (total_cost, discount_applied) = calculate_batch_cost(token_type, amount);

    // Validate payment
    let payment_amount = coin::value(&payment);
    assert!(payment_amount >= total_cost, base::insufficient_balance_error());

    // Transfer payment to registry authority
    transfer::public_transfer(payment, registry.authority);

    let current_time = utils::current_time_ms();

    // Create or update wallet (ultra-lightweight)
    let wallet = TokenWallet {
        id: object::new(ctx),
        token_type: object::id(token_type),
        owner: recipient,
        balance: amount,
        created_at: current_time,
    };

    // Create batch receipt
    let receipt = BatchMintReceipt {
        id: object::new(ctx),
        token_type: object::id(token_type),
        recipient,
        amount_minted: amount,
        total_cost,
        batch_discount_applied: discount_applied,
        minted_at: current_time,
        batch_id: utils::safe_utf8(batch_id),
    };

    // Update supply tracking
    token_type.current_supply = utils::safe_add(token_type.current_supply, amount);
    registry.total_supply_minted = utils::safe_add(registry.total_supply_minted, amount);

    event::emit(BatchTokensMinted {
        token_type_id: object::id(token_type),
        recipient,
        amount,
        total_cost,
        discount_applied,
        batch_id: utils::safe_utf8(batch_id),
    });

    (wallet, receipt)
}

/// Calculate batch cost with discounts
fun calculate_batch_cost(token_type: &TokenType, amount: u64): (u64, u8) {
    let base_cost = utils::safe_mul(amount, token_type.price_per_token);

    // Apply batch discount if threshold met
    if (amount >= token_type.batch_discount_threshold && token_type.batch_discount_percent > 0) {
        let discount_amount = (base_cost * (token_type.batch_discount_percent as u64)) / 100;
        let discounted_cost = base_cost - discount_amount;
        (discounted_cost, token_type.batch_discount_percent)
    } else {
        (base_cost, 0)
    }
}

/// Entry function for batch minting
public entry fun batch_mint_tokens_entry(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    recipient: address,
    amount: u64,
    payment: Coin<SUI>,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
) {
    let (wallet, receipt) = batch_mint_tokens(
        registry,
        token_type,
        recipient,
        amount,
        payment,
        batch_id,
        ctx,
    );

    transfer::public_transfer(wallet, recipient);
    transfer::public_transfer(receipt, tx_context::sender(ctx)); // Receipt to minter
}

/// Multi-recipient batch mint - mint to multiple addresses in one transaction
public entry fun multi_batch_mint_entry(
    registry: &mut UtilityTokenRegistry,
    token_type: &mut TokenType,
    recipients: vector<address>,
    amounts: vector<u64>,
    payment: Coin<SUI>,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(
        vector::length(&recipients) == vector::length(&amounts),
        base::invalid_metadata_error(),
    );
    assert!(vector::length(&recipients) <= 100, EBatchTooLarge); // Limit for gas efficiency

    let sender = tx_context::sender(ctx);
    assert!(
        sender == registry.authority || table::contains(&token_type.issuers, sender),
        base::not_authorized_error(),
    );

    // Calculate total amount and cost
    let mut total_amount = 0u64;
    let mut i = 0;
    while (i < vector::length(&amounts)) {
        total_amount = utils::safe_add(total_amount, *vector::borrow(&amounts, i));
        i = i + 1;
    };

    let (total_cost, discount_applied) = calculate_batch_cost(token_type, total_amount);

    // Validate payment
    assert!(coin::value(&payment) >= total_cost, base::insufficient_balance_error());

    // Supply check
    if (token_type.max_supply > 0) {
        assert!(
            utils::safe_add(token_type.current_supply, total_amount) <= token_type.max_supply,
            base::supply_exceeded_error(),
        );
    };

    // Transfer payment
    transfer::public_transfer(payment, registry.authority);

    let current_time = utils::current_time_ms();

    // Mint to each recipient
    i = 0;
    while (i < vector::length(&recipients)) {
        let recipient = *vector::borrow(&recipients, i);
        let amount = *vector::borrow(&amounts, i);

        if (amount > 0) {
            let wallet = TokenWallet {
                id: object::new(ctx),
                token_type: object::id(token_type),
                owner: recipient,
                balance: amount,
                created_at: current_time,
            };

            transfer::public_transfer(wallet, recipient);
        };

        i = i + 1;
    };

    // Update supply
    token_type.current_supply = utils::safe_add(token_type.current_supply, total_amount);
    registry.total_supply_minted = utils::safe_add(registry.total_supply_minted, total_amount);

    event::emit(BatchTokensMinted {
        token_type_id: object::id(token_type),
        recipient: sender, // Minter as recipient in event
        amount: total_amount,
        total_cost,
        discount_applied,
        batch_id: utils::safe_utf8(batch_id),
    });
}

// ===== Efficient Token Operations =====

/// Merge multiple wallets of same token type (gas-efficient consolidation)
public fun merge_wallets(
    primary_wallet: &mut TokenWallet,
    secondary_wallet: TokenWallet,
    ctx: &mut TxContext,
) {
    assert!(primary_wallet.owner == tx_context::sender(ctx), base::not_authorized_error());
    assert!(secondary_wallet.owner == tx_context::sender(ctx), base::not_authorized_error());
    assert!(
        primary_wallet.token_type == secondary_wallet.token_type,
        base::token_not_found_error(),
    );

    let TokenWallet { id, token_type: _, owner: _, balance, created_at: _ } = secondary_wallet;

    primary_wallet.balance = utils::safe_add(primary_wallet.balance, balance);

    // Destroy secondary wallet
    id.delete();
}

/// Split wallet into smaller amounts (for transfers/sales)
public fun split_wallet(
    wallet: &mut TokenWallet,
    split_amount: u64,
    ctx: &mut TxContext,
): TokenWallet {
    assert!(wallet.owner == tx_context::sender(ctx), base::not_authorized_error());
    assert!(split_amount > 0 && split_amount < wallet.balance, base::invalid_amount_error());

    wallet.balance = wallet.balance - split_amount;

    TokenWallet {
        id: object::new(ctx),
        token_type: wallet.token_type,
        owner: wallet.owner,
        balance: split_amount,
        created_at: utils::current_time_ms(),
    }
}

/// Transfer tokens between wallets (optimized)
public entry fun transfer_tokens(
    from_wallet: &mut TokenWallet,
    to: address,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(from_wallet.owner == tx_context::sender(ctx), base::not_authorized_error());
    assert!(amount > 0 && amount <= from_wallet.balance, base::invalid_amount_error());

    // Create new wallet for recipient
    let new_wallet = TokenWallet {
        id: object::new(ctx),
        token_type: from_wallet.token_type,
        owner: to,
        balance: amount,
        created_at: utils::current_time_ms(),
    };

    // Update sender's balance
    from_wallet.balance = from_wallet.balance - amount;

    // Transfer to recipient
    transfer::public_transfer(new_wallet, to);

    event::emit(TokensTransferred {
        token_type_id: from_wallet.token_type,
        from: tx_context::sender(ctx),
        to,
        amount,
    });
}

// ===== View Functions (Optimized) =====

/// Get token type info
public fun get_token_type_info(
    token_type: &TokenType,
): (String, String, u64, u64, u64, u8, u64, u8) {
    (
        token_type.name,
        token_type.symbol,
        token_type.price_per_token,
        token_type.max_supply,
        token_type.current_supply,
        token_type.decimals,
        token_type.batch_discount_threshold,
        token_type.batch_discount_percent,
    )
}

/// Get wallet info
public fun get_wallet_info(wallet: &TokenWallet): (ID, address, u64, u64) {
    (wallet.token_type, wallet.owner, wallet.balance, wallet.created_at)
}

/// Calculate batch cost preview
public fun preview_batch_cost(token_type: &TokenType, amount: u64): (u64, u8) {
    calculate_batch_cost(token_type, amount)
}

/// Check if address is authorized issuer
public fun is_authorized_issuer(token_type: &TokenType, issuer: address): bool {
    table::contains(&token_type.issuers, issuer)
}

/// Get configuration flags
public fun get_token_config(token_type: &TokenType): (bool, bool, bool) {
    let flags = token_type.config_flags;
    (
        (flags & 1) != 0, // is_transferable
        (flags & 2) != 0, // is_burnable
        (flags & 4) != 0, // is_price_adjustable
    )
}
