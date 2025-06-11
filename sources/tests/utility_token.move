#[allow(unused_use, duplicate_alias, unused_function)]
module otl::utility_token_test;

use otl::utility_token::{
    Self,
    UtilityToken,
    TokenManager,
    create_Utility_Token,
    create_Token_Manager,
    get_supply_info,
    share_token,
    share_manager,
    mint,
    burn
};
use std::debug;
use sui::test_scenario as ts;
use sui::transfer;
use sui::tx_context::{Self, TxContext};

#[test]
fun test_create_token_and_manager(ctx: &mut TxContext) {
    // Simuleer de test-user
    let test_addr = tx_context::sender(ctx);

    debug::print(&b"Test user address: ");
    debug::print(&test_addr);

    // Maak UtilityToken aan
    let token = create_Utility_Token(ctx, test_addr);
    debug::print(&b"UtilityToken aangemaakt door: ");

    // Maak TokenManager aan
    let name = b"Example Token";
    let symbol = b"EXM";
    let metadata = b"https://example.com/metadata.json";
    let decimals = 6;
    let total_supply = 1000000;

    let manager = create_Token_Manager(
        ctx,
        name,
        symbol,
        metadata,
        decimals,
        test_addr,
        total_supply,
    );

    debug::print(&b"TokenManager aangemaakt door: ");
    debug::print(&b"Totale supply: ");

    // Extra check: minted_supply moet 0 zijn
    let (_, minted) = get_supply_info(&manager);
    assert!(minted == 0, 999);

    // Share the objects
    share_token(token);
    share_manager(manager);
}

#[test]
fun test_mint_tokens(ctx: &mut TxContext) {
    // Simuleer de test-user
    let test_addr = tx_context::sender(ctx);

    debug::print(&b"Test user address: ");
    debug::print(&test_addr);

    // Maak TokenManager aan
    let name = b"Example Token";
    let symbol = b"EXM";
    let metadata = b"https://example.com/metadata.json";
    let decimals = 6;
    let total_supply = 1000000;

    let mut manager = create_Token_Manager(
        ctx,
        name,
        symbol,
        metadata,
        decimals,
        test_addr,
        total_supply,
    );

    // Mint 1000 tokens
    let mint_amount = 1000;
    mint(&mut manager, mint_amount, ctx);

    // Verifieer de geminte supply
    let (_, minted) = get_supply_info(&manager);
    assert!(minted == mint_amount, 1);

    // Share the manager
    share_manager(manager);
}

#[test]
fun test_burn_tokens(ctx: &mut TxContext) {
    // Simuleer de test-user
    let test_addr = tx_context::sender(ctx);

    // Maak TokenManager aan
    let name = b"Example Token";
    let symbol = b"EXM";
    let metadata = b"https://example.com/metadata.json";
    let decimals = 6;
    let total_supply = 1000000;

    let mut manager = create_Token_Manager(
        ctx,
        name,
        symbol,
        metadata,
        decimals,
        test_addr,
        total_supply,
    );

    // Mint eerst 1000 tokens
    let mint_amount = 1000;
    mint(&mut manager, mint_amount, ctx);

    // Verifieer de geminte supply
    let (_, minted) = get_supply_info(&manager);
    assert!(minted == mint_amount, 1);

    // Burn 500 tokens
    let burn_amount = 500;
    burn(&mut manager, burn_amount, ctx);

    // Verifieer de nieuwe supply na burning
    let (_, minted) = get_supply_info(&manager);
    assert!(minted == mint_amount - burn_amount, 2);
    // Share the manager
    share_manager(manager);
}
