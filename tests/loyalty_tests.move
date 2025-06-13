#[test_only, allow(unused_use, duplicate_alias)]
module otl::loyalty_tests;

use otl::loyalty::{Self, LoyaltyProgram, LoyaltyCard, LOYALTY};
use sui::clock;
use sui::test_scenario::{Self, Scenario};
use sui::transfer;

const ADMIN: address = @0x100;
const USER1: address = @0x200;
const USER2: address = @0x300;

#[test]
fun test_create_loyalty_program() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);

        loyalty::create_shared_loyalty_program(
            b"Onoal Coffee Rewards",
            b"Earn points with every purchase and unlock exclusive rewards",
            b"https://onoal.com/coffee/logo.png",
            b"https://onoal.com/coffee-rewards",
            10, // 10 points per dollar
            365, // points expire after 1 year
            0, // Bronze: 0+ points
            1000, // Silver: 1000+ points
            5000, // Gold: 5000+ points
            15000, // Platinum: 15000+ points
            50000, // Diamond: 50000+ points
            ctx,
        );
    };

    test_scenario::next_tx(scenario, USER1);
    {
        let program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let (
            name,
            description,
            points_per_dollar,
            total_cards,
            total_points_issued,
            total_points_redeemed,
            expiry_days,
        ) = loyalty::get_program_info(&program);

        assert!(name == std::string::utf8(b"Onoal Coffee Rewards"), 0);
        assert!(points_per_dollar == 10, 1);
        assert!(total_cards == 0, 2);
        assert!(total_points_issued == 0, 3);
        assert!(total_points_redeemed == 0, 4);
        assert!(expiry_days == 365, 5);

        // Check tier thresholds
        let (bronze, silver, gold, platinum, diamond) = loyalty::get_tier_thresholds(&program);
        assert!(bronze == 0, 6);
        assert!(silver == 1000, 7);
        assert!(gold == 5000, 8);
        assert!(platinum == 15000, 9);
        assert!(diamond == 50000, 10);

        test_scenario::return_shared(program);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_issue_loyalty_card() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create program
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        loyalty::create_shared_loyalty_program(
            b"Test Loyalty",
            b"Test program",
            b"https://test.com/logo.png",
            b"https://test.com",
            5, // 5 points per dollar
            0, // no expiry
            0,
            100,
            500,
            1500,
            5000,
            ctx,
        );
    };

    // Issue card
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        loyalty::issue_loyalty_card_to_recipient(
            &mut program,
            USER1,
            b"CARD001",
            &clock,
            ctx,
        );

        let (_, _, _, total_cards, _, _, _) = loyalty::get_program_info(&program);
        assert!(total_cards == 1, 0);

        test_scenario::return_shared(program);
        clock::destroy_for_testing(clock);
    };

    // Check USER1 received the card
    test_scenario::next_tx(scenario, USER1);
    {
        let card = test_scenario::take_from_sender<LoyaltyCard>(scenario);

        let (
            program_id,
            holder,
            card_number,
            tier,
            tier_name,
            total_points,
            lifetime_points,
            issued_at,
        ) = loyalty::get_card_info(&card);

        assert!(holder == USER1, 1);
        assert!(card_number == std::string::utf8(b"CARD001"), 2);
        assert!(tier == 0, 3); // Bronze tier
        assert!(tier_name == std::string::utf8(b"Bronze"), 4);
        assert!(total_points == 0, 5);
        assert!(lifetime_points == 0, 6);
        assert!(issued_at > 0, 7);

        test_scenario::return_to_sender(scenario, card);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_earn_points() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Setup program and card
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        loyalty::create_shared_loyalty_program(
            b"Points Test",
            b"Test earning points",
            b"https://test.com/logo.png",
            b"https://test.com",
            10,
            30, // 30 day expiry
            0,
            1000,
            5000,
            15000,
            50000,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        loyalty::issue_loyalty_card_to_recipient(
            &mut program,
            USER1,
            b"EARN001",
            &clock,
            ctx,
        );

        test_scenario::return_shared(program);
        clock::destroy_for_testing(clock);
    };

    // Earn points
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut card = test_scenario::take_from_address<LoyaltyCard>(scenario, USER1);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        // Earn 500 points for a purchase
        loyalty::earn_points_entry(
            &mut program,
            &mut card,
            500,
            b"Purchase at Store #123",
            b"TXN_001",
            &clock,
            ctx,
        );

        let (_, _, _, _, _, total_points, lifetime_points, _) = loyalty::get_card_info(&card);
        assert!(total_points == 500, 0);
        assert!(lifetime_points == 500, 1);

        let (_, _, _, total_cards, total_points_issued, _, _) = loyalty::get_program_info(&program);
        assert!(total_points_issued == 500, 2);

        test_scenario::return_shared(program);
        transfer::public_transfer(card, USER1);
        clock::destroy_for_testing(clock);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_spend_points() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Setup and earn points first
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        loyalty::create_shared_loyalty_program(
            b"Spend Test",
            b"Test spending points",
            b"https://test.com/logo.png",
            b"https://test.com",
            10,
            0, // no expiry
            0,
            1000,
            5000,
            15000,
            50000,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        loyalty::issue_loyalty_card_to_recipient(
            &mut program,
            USER1,
            b"SPEND001",
            &clock,
            ctx,
        );

        test_scenario::return_shared(program);
        clock::destroy_for_testing(clock);
    };

    // Earn some points first
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut card = test_scenario::take_from_address<LoyaltyCard>(scenario, USER1);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        loyalty::earn_points_entry(
            &mut program,
            &mut card,
            1000,
            b"Initial purchase",
            b"TXN_001",
            &clock,
            ctx,
        );

        test_scenario::return_shared(program);
        transfer::public_transfer(card, USER1);
        clock::destroy_for_testing(clock);
    };

    // Now spend points
    test_scenario::next_tx(scenario, USER1);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut card = test_scenario::take_from_sender<LoyaltyCard>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        // Spend 300 points for a reward
        loyalty::spend_points_entry(
            &mut program,
            &mut card,
            300,
            b"Redeemed for free coffee",
            b"REWARD_001",
            &clock,
            ctx,
        );

        let (_, _, _, _, _, total_points, lifetime_points, _) = loyalty::get_card_info(&card);
        assert!(total_points == 700, 0); // 1000 - 300
        assert!(lifetime_points == 1000, 1); // Lifetime doesn't decrease

        let (_, _, _, _, _, total_points_redeemed, _) = loyalty::get_program_info(&program);
        assert!(total_points_redeemed == 300, 2);

        test_scenario::return_shared(program);
        test_scenario::return_to_sender(scenario, card);
        clock::destroy_for_testing(clock);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_tier_upgrade() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Setup program
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        loyalty::create_shared_loyalty_program(
            b"Tier Test",
            b"Test tier upgrades",
            b"https://test.com/logo.png",
            b"https://test.com",
            10,
            0,
            0, // Bronze: 0+
            100, // Silver: 100+
            500, // Gold: 500+
            1500, // Platinum: 1500+
            5000, // Diamond: 5000+
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        loyalty::issue_loyalty_card_to_recipient(
            &mut program,
            USER1,
            b"TIER001",
            &clock,
            ctx,
        );

        test_scenario::return_shared(program);
        clock::destroy_for_testing(clock);
    };

    // Earn enough points to reach Silver (100+ points)
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut card = test_scenario::take_from_address<LoyaltyCard>(scenario, USER1);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        // Start at Bronze
        let (_, _, _, tier, tier_name, _, _, _) = loyalty::get_card_info(&card);
        assert!(tier == 0, 0); // Bronze
        assert!(tier_name == std::string::utf8(b"Bronze"), 1);

        // Earn 150 points -> should upgrade to Silver
        loyalty::earn_points_entry(
            &mut program,
            &mut card,
            150,
            b"Big purchase",
            b"TXN_002",
            &clock,
            ctx,
        );

        // Check tier upgrade
        let (_, _, _, tier, tier_name, _, _, _) = loyalty::get_card_info(&card);
        assert!(tier == 1, 2); // Silver
        assert!(tier_name == std::string::utf8(b"Silver"), 3);

        test_scenario::return_shared(program);
        transfer::public_transfer(card, USER1);
        clock::destroy_for_testing(clock);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_transfer_points() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Setup program
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        loyalty::create_shared_loyalty_program(
            b"Transfer Test",
            b"Test point transfers",
            b"https://test.com/logo.png",
            b"https://test.com",
            10,
            0,
            0,
            1000,
            5000,
            15000,
            50000,
            ctx,
        );
    };

    // Issue cards to both users
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        loyalty::issue_loyalty_card_to_recipient(
            &mut program,
            USER1,
            b"TRANSFER001",
            &clock,
            ctx,
        );

        loyalty::issue_loyalty_card_to_recipient(
            &mut program,
            USER2,
            b"TRANSFER002",
            &clock,
            ctx,
        );

        test_scenario::return_shared(program);
        clock::destroy_for_testing(clock);
    };

    // USER1 earns points
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut card1 = test_scenario::take_from_address<LoyaltyCard>(scenario, USER1);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        loyalty::earn_points_entry(
            &mut program,
            &mut card1,
            500,
            b"Purchase",
            b"TXN_003",
            &clock,
            ctx,
        );

        test_scenario::return_shared(program);
        transfer::public_transfer(card1, USER1);
        clock::destroy_for_testing(clock);
    };

    // USER1 transfers points to USER2
    test_scenario::next_tx(scenario, USER1);
    {
        let mut program = test_scenario::take_shared<LoyaltyProgram>(scenario);
        let mut card1 = test_scenario::take_from_sender<LoyaltyCard>(scenario);
        let mut card2 = test_scenario::take_from_address<LoyaltyCard>(scenario, USER2);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        // Transfer 200 points from USER1 to USER2
        loyalty::transfer_points_entry(
            &mut program,
            &mut card1,
            &mut card2,
            200,
            &clock,
            ctx,
        );

        // Check balances
        let (_, _, _, _, _, total_points1, _, _) = loyalty::get_card_info(&card1);
        let (_, _, _, _, _, total_points2, lifetime_points2, _) = loyalty::get_card_info(&card2);

        assert!(total_points1 == 300, 0); // 500 - 200
        assert!(total_points2 == 200, 1); // 0 + 200
        assert!(lifetime_points2 == 200, 2); // Lifetime increases for recipient

        test_scenario::return_shared(program);
        test_scenario::return_to_sender(scenario, card1);
        transfer::public_transfer(card2, USER2);
        clock::destroy_for_testing(clock);
    };

    test_scenario::end(scenario_val);
}
