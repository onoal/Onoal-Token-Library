#[test_only]
module otl::payment_transfer_tests;

use otl::payment_transfer::{
    Self,
    PaymentProcessor,
    AirdropCampaign,
    BulkTransferBatch,
    PaymentCard,
    VendorSettlement
};
use std::string::{Self, String};
use std::vector;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
use sui::vec_map;

// Test addresses
const ADMIN: address = @0x1;
const USER1: address = @0x2;
const USER2: address = @0x3;
const USER3: address = @0x4;
const VENDOR: address = @0x5;

// Test coin type
public struct TEST_COIN has drop {}

#[test]
fun test_create_payment_processor() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create treasury cap for testing
    {
        let ctx = test::ctx(&mut scenario);
        let (treasury_cap, coin_metadata) = coin::create_currency<TEST_COIN>(
            TEST_COIN {},
            9,
            b"TEST",
            b"Test Coin",
            b"Test coin for payment processor",
            option::none(),
            ctx,
        );

        let processor = payment_transfer::create_payment_processor(
            treasury_cap,
            1000, // base fee
            20, // 20% bulk discount
            ctx,
        );

        transfer::public_transfer(coin_metadata, ADMIN);
        transfer::share_object(processor);
    };

    // Verify processor creation
    next_tx(&mut scenario, ADMIN);
    {
        let processor = test::take_shared<PaymentProcessor<TEST_COIN>>(&scenario);

        let (
            total_payments,
            total_volume,
            total_gas_saved,
            base_fee,
            is_active,
        ) = payment_transfer::get_processor_stats(&processor);

        assert!(total_payments == 0, 0);
        assert!(total_volume == 0, 1);
        assert!(total_gas_saved == 0, 2);
        assert!(base_fee == 1000, 3);
        assert!(is_active == true, 4);

        test::return_shared(processor);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_airdrop_campaign() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup payment processor
    setup_payment_processor(&mut scenario, &clock);

    // Create airdrop campaign
    next_tx(&mut scenario, ADMIN);
    {
        let ctx = test::ctx(&mut scenario);
        let campaign = payment_transfer::create_airdrop_campaign<TEST_COIN>(
            b"Test Airdrop",
            b"Test airdrop campaign for early adopters",
            1000000, // total amount
            1000, // amount per recipient
            1000, // max recipients
            clock::timestamp_ms(&clock) + 1000, // start time
            clock::timestamp_ms(&clock) + 86400000, // end time (24 hours)
            false, // not whitelist only
            &clock,
            ctx,
        );

        transfer::share_object(campaign);
    };

    // Verify campaign creation
    next_tx(&mut scenario, ADMIN);
    {
        let campaign = test::take_shared<AirdropCampaign<TEST_COIN>>(&scenario);

        let (
            name,
            total_amount,
            amount_per_recipient,
            current_recipients,
            max_recipients,
            is_active,
        ) = payment_transfer::get_campaign_info(&campaign);

        assert!(name == string::utf8(b"Test Airdrop"), 0);
        assert!(total_amount == 1000000, 1);
        assert!(amount_per_recipient == 1000, 2);
        assert!(current_recipients == 0, 3);
        assert!(max_recipients == 1000, 4);
        assert!(is_active == true, 5);

        test::return_shared(campaign);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_airdrop_claim() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup
    setup_payment_processor(&mut scenario, &clock);
    setup_airdrop_campaign(&mut scenario, &clock);

    // Fast forward to campaign start
    clock::increment_for_testing(&mut clock, 2000);

    // User claims airdrop
    next_tx(&mut scenario, USER1);
    {
        let mut campaign = test::take_shared<AirdropCampaign<TEST_COIN>>(&scenario);
        let mut processor = test::take_shared<PaymentProcessor<TEST_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Check if user can claim
        assert!(payment_transfer::can_claim_airdrop(&campaign, USER1), 0);

        payment_transfer::claim_airdrop_entry(
            &mut campaign,
            &mut processor,
            &clock,
            ctx,
        );

        test::return_shared(campaign);
        test::return_shared(processor);
    };

    // Verify tokens received
    next_tx(&mut scenario, USER1);
    {
        let tokens = test::take_from_sender<Coin<TEST_COIN>>(&scenario);
        assert!(coin::value(&tokens) == 1000, 0);

        let campaign = test::take_shared<AirdropCampaign<TEST_COIN>>(&scenario);
        let (_, _, _, current_recipients, _, _) = payment_transfer::get_campaign_info(&campaign);
        assert!(current_recipients == 1, 1);

        // User cannot claim again
        assert!(!payment_transfer::can_claim_airdrop(&campaign, USER1), 2);

        test::return_to_sender(&scenario, tokens);
        test::return_shared(campaign);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_bulk_transfer() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup payment processor
    setup_payment_processor(&mut scenario, &clock);

    // Create bulk transfer batch
    next_tx(&mut scenario, USER1);
    {
        let ctx = test::ctx(&mut scenario);
        let mut transfers = vec_map::empty<address, u64>();
        vec_map::insert(&mut transfers, USER2, 1000);
        vec_map::insert(&mut transfers, USER3, 2000);

        let batch = payment_transfer::create_bulk_transfer_batch<TEST_COIN>(
            transfers,
            ctx,
        );

        transfer::share_object(batch);
    };

    // Execute bulk transfer
    next_tx(&mut scenario, USER1);
    {
        let mut batch = test::take_shared<BulkTransferBatch<TEST_COIN>>(&scenario);
        let mut processor = test::take_shared<PaymentProcessor<TEST_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Create payment coins (3000 + fees)
        let payment_coins = coin::mint_for_testing<TEST_COIN>(5000, ctx);

        payment_transfer::execute_bulk_transfer_entry(
            &mut batch,
            &mut processor,
            payment_coins,
            &clock,
            ctx,
        );

        test::return_shared(batch);
        test::return_shared(processor);
    };

    // Verify transfers completed
    next_tx(&mut scenario, USER2);
    {
        let tokens = test::take_from_sender<Coin<TEST_COIN>>(&scenario);
        assert!(coin::value(&tokens) == 1000, 0);
        test::return_to_sender(&scenario, tokens);
    };

    next_tx(&mut scenario, USER3);
    {
        let tokens = test::take_from_sender<Coin<TEST_COIN>>(&scenario);
        assert!(coin::value(&tokens) == 2000, 0);
        test::return_to_sender(&scenario, tokens);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_payment_card() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create payment card
    next_tx(&mut scenario, USER1);
    {
        let ctx = test::ctx(&mut scenario);
        let initial_coins = coin::mint_for_testing<TEST_COIN>(10000, ctx);

        let card = payment_transfer::create_payment_card(
            initial_coins,
            1000, // daily limit
            5000, // monthly limit
            30, // duration days
            true, // transferable
            &clock,
            ctx,
        );

        transfer::public_transfer(card, USER1);
    };

    // Use payment card
    next_tx(&mut scenario, USER1);
    {
        let mut card = test::take_from_sender<PaymentCard<TEST_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let (
            card_number,
            holder,
            balance,
            daily_limit,
            monthly_limit,
            is_active,
        ) = payment_transfer::get_card_info(&card);

        assert!(holder == USER1, 0);
        assert!(balance == 10000, 1);
        assert!(daily_limit == 1000, 2);
        assert!(monthly_limit == 5000, 3);
        assert!(is_active == true, 4);

        // Use card for payment
        payment_transfer::use_payment_card_entry(
            &mut card,
            500, // amount
            VENDOR,
            &clock,
            ctx,
        );

        let (_, _, new_balance, _, _, _) = payment_transfer::get_card_info(&card);
        assert!(new_balance == 9500, 5);

        test::return_to_sender(&scenario, card);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_vendor_settlement() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));

    // Create vendor settlement
    next_tx(&mut scenario, ADMIN);
    {
        let ctx = test::ctx(&mut scenario);
        let event_id = object::id_from_address(@0x123);
        let current_time = clock::timestamp_ms(&clock);

        let transaction_hashes = vector[
            string::utf8(b"tx_hash_1"),
            string::utf8(b"tx_hash_2"),
            string::utf8(b"tx_hash_3"),
        ];

        let settlement = payment_transfer::create_vendor_settlement(
            event_id,
            VENDOR,
            86400000, // daily settlement
            current_time,
            current_time + 86400000,
            transaction_hashes,
            ctx,
        );

        transfer::share_object(settlement);
    };

    // Finalize settlement
    next_tx(&mut scenario, ADMIN);
    {
        let mut settlement = test::take_shared<VendorSettlement>(&scenario);
        let ctx = test::ctx(&mut scenario);

        payment_transfer::finalize_vendor_settlement(
            &mut settlement,
            15000, // total volume
            300, // total fees
            &clock,
            ctx,
        );

        test::return_shared(settlement);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_gas_optimization_comparison() {
    let mut scenario = test::begin(ADMIN);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup
    setup_payment_processor(&mut scenario, &clock);

    // Test individual transfers (high gas)
    next_tx(&mut scenario, USER1);
    {
        let ctx = test::ctx(&mut scenario);

        // Individual transfer 1
        let coins1 = coin::mint_for_testing<TEST_COIN>(1000, ctx);
        transfer::public_transfer(coins1, USER2);

        // Individual transfer 2
        let coins2 = coin::mint_for_testing<TEST_COIN>(2000, ctx);
        transfer::public_transfer(coins2, USER3);
    };

    // Test bulk transfer (low gas)
    next_tx(&mut scenario, USER1);
    {
        let ctx = test::ctx(&mut scenario);
        let mut transfers = vec_map::empty<address, u64>();
        vec_map::insert(&mut transfers, USER2, 1000);
        vec_map::insert(&mut transfers, USER3, 2000);

        let batch = payment_transfer::create_bulk_transfer_batch<TEST_COIN>(
            transfers,
            ctx,
        );

        let (
            transfer_count,
            total_amount,
            estimated_gas,
            is_executed,
            created_by,
        ) = payment_transfer::get_batch_info(&batch);

        assert!(transfer_count == 2, 0);
        assert!(total_amount == 3000, 1);
        assert!(estimated_gas == 100000, 2); // 2 * 50000
        assert!(is_executed == false, 3);
        assert!(created_by == USER1, 4);

        transfer::share_object(batch);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

// Helper functions
fun setup_payment_processor(scenario: &mut Scenario, clock: &Clock) {
    next_tx(scenario, ADMIN);
    {
        let ctx = test::ctx(scenario);
        let (treasury_cap, coin_metadata) = coin::create_currency<TEST_COIN>(
            TEST_COIN {},
            9,
            b"TEST",
            b"Test Coin",
            b"Test coin for payment processor",
            option::none(),
            ctx,
        );

        let processor = payment_transfer::create_payment_processor(
            treasury_cap,
            1000,
            20,
            ctx,
        );

        transfer::public_transfer(coin_metadata, ADMIN);
        transfer::share_object(processor);
    };
}

fun setup_airdrop_campaign(scenario: &mut Scenario, clock: &Clock) {
    next_tx(scenario, ADMIN);
    {
        let ctx = test::ctx(scenario);
        let campaign = payment_transfer::create_airdrop_campaign<TEST_COIN>(
            b"Test Airdrop",
            b"Test airdrop campaign",
            1000000,
            1000,
            1000,
            clock::timestamp_ms(clock) + 1000,
            clock::timestamp_ms(clock) + 86400000,
            false,
            clock,
            ctx,
        );

        transfer::share_object(campaign);
    };
}
