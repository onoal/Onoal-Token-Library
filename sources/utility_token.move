#[allow(unused_use, duplicate_alias, unused_field)]
module otl::utility_token;

use sui::address;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::object::{Self, UID};
use sui::sui;
use sui::transfer;
use sui::tx_context::{Self, TxContext};

public struct Signer has drop { a: address }

public struct UtilityToken has key {
    id: UID,
    creator: address,
}
public struct TokenManager has key {
    id: UID,
    creator: address,
    name: vector<u8>,
    symbol: vector<u8>,
    metadata: vector<u8>,
    decimals: u8,
    admin: address,
    minters: vector<address>,
    total_supply: u64,
    minted_supply: u64,
}

public fun create_Utility_Token(ctx: &mut TxContext, seller: address): UtilityToken {
    UtilityToken {
        id: object::new(ctx),
        creator: seller,
    }
}

public fun create_Token_Manager(
    ctx: &mut TxContext,
    name: vector<u8>,
    symbol: vector<u8>,
    metadata: vector<u8>,
    decimals: u8,
    admin: address,
    total_supply: u64,
): TokenManager {
    TokenManager {
        id: object::new(ctx),
        creator: tx_context::sender(ctx),
        name,
        symbol,
        metadata,
        decimals,
        admin,
        minters: vector::empty(),
        total_supply,
        minted_supply: 0,
    }
}

/// Mint new tokens. Only admin or minters can call this.
public fun mint(manager: &mut TokenManager, amount: u64, ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(sender == manager.admin || vector::contains(&manager.minters, &sender), 0);
    assert!(manager.minted_supply + amount <= manager.total_supply, 1);
    manager.minted_supply = manager.minted_supply + amount;
}

/// Burn tokens. Only admin can call this.
public fun burn(manager: &mut TokenManager, amount: u64, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == manager.admin, 0);
    assert!(amount <= manager.minted_supply, 1);
    manager.minted_supply = manager.minted_supply - amount;
}

/// Get current supply information
public fun get_supply_info(manager: &TokenManager): (u64, u64) {
    (manager.total_supply, manager.minted_supply)
}

/// Update token metadata. Only admin can call this.
public fun update_metadata(
    manager: &mut TokenManager,
    new_name: vector<u8>,
    new_symbol: vector<u8>,
    new_metadata: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == manager.admin, 0);
    manager.name = new_name;
    manager.symbol = new_symbol;
    manager.metadata = new_metadata;
}

/// Update token decimals. Only admin can call this.
public fun update_decimals(manager: &mut TokenManager, new_decimals: u8, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == manager.admin, 0);
    manager.decimals = new_decimals;
}

/// Share the token object
public fun share_token(token: UtilityToken) {
    transfer::share_object(token);
}

/// Share the manager object
public fun share_manager(manager: TokenManager) {
    transfer::share_object(manager);
}
