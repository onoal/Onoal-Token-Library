#[test_only]
module otl::onoal_token_tests;

use otl::onoal_token::{Self, OnoalTokenRegistry, ONOAL_TOKEN};
use std::string;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
use sui::test_utils;

// Test addresses
const ADMIN: address = @0x1;
const USER1: address = @0x2;
const USER2: address = @0x3;
const MINTER1: address = @0x4;
const TREASURY: address = @0x5;

// Test constants
const INITIAL_SUI_BALANCE: u64 = 10_000_000_000; // 10 SUI
const TEST_MINT_AMOUNT: u64 = 1_000_000_000_000; // 1000 tokens with 9 decimals

#[test]
fun test_token_creation() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Test token creation happens automatically in init
    // Let's verify by creating test registry instead
    next_tx(&mut scenario, ADMIN);
    {
        let (registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

        // Verify token info
        let (
            name,
            symbol,
            description,
            icon_url,
            total_supply,
            max_supply,
            circulating_supply,
            burned_supply,
            locked_supply,
            fixed_price_sui,
        ) = onoal_token::get_token_info(&registry);

        assert!(name == string::utf8(b"Onoal Token"), 0);
        assert!(symbol == string::utf8(b"ONOAL"), 1);
        assert!(total_supply == 0, 2);
        assert!(max_supply == 1_000_000_000_000_000_000, 3); // 1 billion with 9 decimals
        assert!(circulating_supply == 0, 4);
        assert!(burned_supply == 0, 5);
        assert!(locked_supply == 0, 6);
        assert!(fixed_price_sui == 1_000_000_000, 7); // 1 SUI = 1000 ONOAL

        // Verify config
        let (
            is_mintable,
            is_burnable,
            is_transferable,
            is_stakeable,
            governance_enabled,
            voting_power_enabled,
            price_enabled,
        ) = onoal_token::get_token_config(&registry);

        assert!(is_mintable == true, 8);
        assert!(is_burnable == true, 9);
        assert!(is_transferable == true, 10);
        assert!(is_stakeable == false, 11);
        assert!(governance_enabled == false, 12);
        assert!(voting_power_enabled == false, 13);
        assert!(price_enabled == true, 14);

        // Clean up without share_object
        test_utils::destroy(registry);
        transfer::public_transfer(treasury_cap, ADMIN);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_initial_supply_mint() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    // Mint initial supply
    next_tx(&mut scenario, ADMIN);
    {
        let initial_tokens = onoal_token::mint_initial_supply(
            &mut registry,
            ADMIN,
            &clock,
            ctx(&mut scenario),
        );

        assert!(coin::value(&initial_tokens) == 100_000_000_000_000_000, 0); // 100M tokens

        // Verify supply updated
        let (
            _,
            _,
            _,
            _,
            total_supply,
            _,
            circulating_supply,
            _,
            _,
            _,
        ) = onoal_token::get_token_info(&registry);

        assert!(total_supply == 100_000_000_000_000_000, 1);
        assert!(circulating_supply == 100_000_000_000_000_000, 2);

        transfer::public_transfer(initial_tokens, ADMIN);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_token_purchase_with_sui() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    // User purchases tokens with SUI
    next_tx(&mut scenario, USER1);
    {
        let sui_payment = coin::mint_for_testing<sui::sui::SUI>(
            INITIAL_SUI_BALANCE,
            ctx(&mut scenario),
        );

        let purchased_tokens = onoal_token::purchase_tokens_with_sui(
            &mut registry,
            sui_payment,
            &clock,
            ctx(&mut scenario),
        );

        // With fixed price of 1 SUI = 1000 ONOAL tokens
        // 10 SUI should give 10,000 tokens
        let expected_tokens = (INITIAL_SUI_BALANCE * 1_000_000_000) / 1_000_000_000; // Same as SUI amount * 1000
        assert!(coin::value(&purchased_tokens) == expected_tokens, 0);

        // Verify supply updated
        let (
            _,
            _,
            _,
            _,
            total_supply,
            _,
            circulating_supply,
            _,
            _,
            _,
        ) = onoal_token::get_token_info(&registry);

        assert!(total_supply == expected_tokens, 1);
        assert!(circulating_supply == expected_tokens, 2);

        transfer::public_transfer(purchased_tokens, USER1);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_minter_authorization() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    // Authorize minter
    next_tx(&mut scenario, ADMIN);
    {
        onoal_token::authorize_minter(
            &mut registry,
            MINTER1,
            0, // MINTER_ECOSYSTEM_REWARDS category
            TEST_MINT_AMOUNT,
            TEST_MINT_AMOUNT / 10, // Daily limit
            0, // Never expires
            b"Test ecosystem rewards",
            &clock,
            ctx(&mut scenario),
        );

        // Verify minter is authorized
        assert!(onoal_token::is_authorized_minter(&registry, MINTER1), 0);

        // Get minter info
        let (
            category,
            max_mint_amount,
            minted_amount,
            daily_limit,
            daily_minted,
            is_active,
            expires_at,
            purpose,
        ) = onoal_token::get_minter_info(&registry, MINTER1);

        assert!(category == 0, 1);
        assert!(max_mint_amount == TEST_MINT_AMOUNT, 2);
        assert!(minted_amount == 0, 3);
        assert!(daily_limit == TEST_MINT_AMOUNT / 10, 4);
        assert!(daily_minted == 0, 5);
        assert!(is_active == true, 6);
        assert!(expires_at == 0, 7);
        assert!(purpose == string::utf8(b"Test ecosystem rewards"), 8);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_authorized_minting() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry and authorize minter
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    next_tx(&mut scenario, ADMIN);
    {
        onoal_token::authorize_minter(
            &mut registry,
            MINTER1,
            0, // MINTER_ECOSYSTEM_REWARDS
            TEST_MINT_AMOUNT,
            TEST_MINT_AMOUNT / 10,
            0,
            b"Test minting",
            &clock,
            ctx(&mut scenario),
        );
    };

    // Minter mints tokens
    next_tx(&mut scenario, MINTER1);
    {
        let minted_tokens = onoal_token::mint_tokens(
            &mut registry,
            USER1,
            TEST_MINT_AMOUNT / 100, // Small amount within limits
            b"Test mint purpose",
            &clock,
            ctx(&mut scenario),
        );

        assert!(coin::value(&minted_tokens) == TEST_MINT_AMOUNT / 100, 0);

        // Verify minter stats updated
        let (_, _, minted_amount, _, daily_minted, _, _, _) = onoal_token::get_minter_info(
            &registry,
            MINTER1,
        );

        assert!(minted_amount == TEST_MINT_AMOUNT / 100, 1);
        assert!(daily_minted == TEST_MINT_AMOUNT / 100, 2);

        transfer::public_transfer(minted_tokens, USER1);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_token_burning() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry and mint some tokens
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    next_tx(&mut scenario, ADMIN);
    {
        let initial_tokens = onoal_token::mint_initial_supply(
            &mut registry,
            ADMIN,
            &clock,
            ctx(&mut scenario),
        );
        transfer::public_transfer(initial_tokens, ADMIN);
    };

    // Burn some tokens
    next_tx(&mut scenario, ADMIN);
    {
        let tokens_to_burn = test::take_from_sender<Coin<ONOAL_TOKEN>>(&scenario);
        let burn_amount = coin::value(&tokens_to_burn) / 10; // Burn 10%

        let remaining_tokens = onoal_token::split_coin(
            &mut tokens_to_burn,
            coin::value(&tokens_to_burn) - burn_amount,
            ctx(&mut scenario),
        );

        let burned_amount = onoal_token::burn_tokens_with_reason(
            &mut registry,
            tokens_to_burn,
            b"Test burn",
            &clock,
            ctx(&mut scenario),
        );

        assert!(burned_amount == burn_amount, 0);

        // Verify supply stats
        let (total_supply, circulating_supply, burned_supply, _, _) = onoal_token::get_supply_stats(
            &registry,
        );

        assert!(burned_supply == burn_amount, 1);
        assert!(circulating_supply == total_supply - burn_amount, 2);

        transfer::public_transfer(remaining_tokens, ADMIN);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_price_management() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    // Update price
    next_tx(&mut scenario, ADMIN);
    {
        let new_price = 2_000_000_000; // 2 SUI = 1000 ONOAL tokens
        onoal_token::update_fixed_price(
            &mut registry,
            new_price,
            &clock,
            ctx(&mut scenario),
        );

        // Verify price updated
        let (fixed_price_sui, price_enabled, _, _) = onoal_token::get_pricing_info(&registry);

        assert!(fixed_price_sui == new_price, 0);
        assert!(price_enabled == true, 1);

        // Test disabling price
        onoal_token::set_price_enabled(&mut registry, false, ctx(&mut scenario));

        let (_, price_enabled_2, _, _) = onoal_token::get_pricing_info(&registry);
        assert!(price_enabled_2 == false, 2);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_token_utilities() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry and mint tokens
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    next_tx(&mut scenario, ADMIN);
    {
        let tokens = onoal_token::mint_initial_supply(
            &mut registry,
            ADMIN,
            &clock,
            ctx(&mut scenario),
        );
        transfer::public_transfer(tokens, ADMIN);
    };

    // Test utility functions
    next_tx(&mut scenario, ADMIN);
    {
        let mut tokens = test::take_from_sender<Coin<ONOAL_TOKEN>>(&scenario);
        let total_value = coin::value(&tokens);

        // Split coins
        let split_amount = total_value / 3;
        let split_tokens = onoal_token::split_coin(&mut tokens, split_amount, ctx(&mut scenario));
        assert!(coin::value(&split_tokens) == split_amount, 0);

        // Join coins back
        onoal_token::join_coins(&mut tokens, split_tokens);
        assert!(coin::value(&tokens) == total_value, 1);

        // Test display conversion
        let display_amount = onoal_token::to_display_amount(total_value);
        let back_to_base = onoal_token::from_display_amount(display_amount);
        assert!(back_to_base == total_value, 2);

        // Test price calculations
        let sui_cost = onoal_token::calculate_sui_cost(&registry, 1000_000_000_000); // 1000 tokens
        let token_amount = onoal_token::calculate_token_amount(&registry, sui_cost);
        assert!(token_amount == 1000_000_000_000, 3);

        transfer::public_transfer(tokens, ADMIN);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_token_attributes() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    // Add attributes
    next_tx(&mut scenario, ADMIN);
    {
        onoal_token::add_token_attribute(
            &mut registry,
            b"launch_date",
            b"2024-01-01",
            ctx(&mut scenario),
        );

        onoal_token::add_token_attribute(
            &mut registry,
            b"network",
            b"Sui Mainnet",
            ctx(&mut scenario),
        );

        // Verify attributes
        let launch_date = onoal_token::get_token_attribute(
            &registry,
            &string::utf8(b"launch_date"),
        );
        let network = onoal_token::get_token_attribute(&registry, &string::utf8(b"network"));
        let missing = onoal_token::get_token_attribute(&registry, &string::utf8(b"missing"));

        assert!(launch_date == string::utf8(b"2024-01-01"), 0);
        assert!(network == string::utf8(b"Sui Mainnet"), 1);
        assert!(missing == string::utf8(b""), 2);

        // Update existing attribute
        onoal_token::add_token_attribute(
            &mut registry,
            b"network",
            b"Sui Network",
            ctx(&mut scenario),
        );

        let updated_network = onoal_token::get_token_attribute(
            &registry,
            &string::utf8(b"network"),
        );
        assert!(updated_network == string::utf8(b"Sui Network"), 3);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_upgrade_functionality() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    // Test upgrade
    next_tx(&mut scenario, ADMIN);
    {
        let (old_version, _, _, _, _) = onoal_token::get_version_info(&registry);
        assert!(old_version == 1, 0);

        onoal_token::execute_token_upgrade(
            &mut registry,
            2,
            false, // no migration required
            &clock,
            ctx(&mut scenario),
        );

        let (new_version, _, _, migration_required, _) = onoal_token::get_version_info(&registry);
        assert!(new_version == 2, 1);
        assert!(migration_required == false, 2);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_authority_transfer() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create registry
    next_tx(&mut scenario, ADMIN);
    let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

    // Transfer authority
    next_tx(&mut scenario, ADMIN);
    {
        onoal_token::transfer_authority(&mut registry, USER1, ctx(&mut scenario));
    };

    // Verify new authority can perform admin functions
    next_tx(&mut scenario, USER1);
    {
        onoal_token::set_price_enabled(&mut registry, false, ctx(&mut scenario));

        let (_, price_enabled, _, _) = onoal_token::get_pricing_info(&registry);
        assert!(price_enabled == false, 0);
    };

    // Clean up
    test_utils::destroy(registry);
    transfer::public_transfer(treasury_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}

// Simplified tests without share_object calls
#[test]
fun test_basic_functionality() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    next_tx(&mut scenario, ADMIN);
    {
        let (mut registry, treasury_cap) = onoal_token::create_test_registry(ctx(&mut scenario));

        // Test minting
        let tokens = onoal_token::mint_initial_supply(
            &mut registry,
            ADMIN,
            &clock,
            ctx(&mut scenario),
        );

        // Test splitting
        let split_tokens = onoal_token::split_coin(&mut tokens, 1000, ctx(&mut scenario));
        assert!(coin::value(&split_tokens) == 1000, 0);

        // Test joining
        onoal_token::join_coins(&mut tokens, split_tokens);

        // Test display conversion
        let display_amount = onoal_token::to_display_amount(1_000_000_000);
        assert!(display_amount == 1, 1);

        let base_amount = onoal_token::from_display_amount(1);
        assert!(base_amount == 1_000_000_000, 2);

        // Clean up
        transfer::public_transfer(tokens, ADMIN);
        transfer::public_transfer(treasury_cap, ADMIN);
        test_utils::destroy(registry);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}
