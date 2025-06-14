#[test_only]
module otl::events_festivals_tests;

use otl::base;
use otl::events_festivals::{
    Self,
    EventRegistry,
    FestivalCoinTreasury,
    EventTicket,
    LoyaltyBadge,
    EventProfile,
    FESTIVAL_COIN
};
use std::string::{Self, String};
use std::vector;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
use sui::vec_map;

// Test addresses
const ORGANIZER: address = @0x1;
const USER1: address = @0x2;
const USER2: address = @0x3;
const USER3: address = @0x4;

// Test constants
const FESTIVAL_START: u64 = 1700000000000; // Future timestamp
const FESTIVAL_END: u64 = 1700086400000; // 24 hours later
const REGISTRATION_DEADLINE: u64 = 1699999000000; // 1 hour before start

#[test]
fun test_create_festival_event() {
    let mut scenario = test::begin(ORGANIZER);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create festival event
    {
        let ctx = test::ctx(&mut scenario);
        events_festivals::create_event_entry(
            b"Onoal Music Festival 2024",
            b"The biggest electronic music festival in Europe",
            b"Amsterdam Arena",
            b"https://onoal.com/festival2024.jpg",
            b"https://festival.onoal.com",
            FESTIVAL_START,
            FESTIVAL_END,
            REGISTRATION_DEADLINE,
            b"Onoal Festival Coins",
            b"OFC",
            100, // 1 EUR = 100 festival coins
            &clock,
            ctx,
        );
    };

    // Verify event creation
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let treasury = test::take_shared<FestivalCoinTreasury>(&scenario);

        let (
            name,
            description,
            venue,
            start_date,
            end_date,
            tickets_sold,
            is_active,
        ) = events_festivals::get_event_info(&event);

        assert!(name == string::utf8(b"Onoal Music Festival 2024"), 0);
        assert!(venue == string::utf8(b"Amsterdam Arena"), 1);
        assert!(start_date == FESTIVAL_START, 2);
        assert!(end_date == FESTIVAL_END, 3);
        assert!(tickets_sold == 0, 4);
        assert!(is_active == true, 5);

        let (
            treasury_name,
            symbol,
            total_supply,
            circulating_supply,
            fiat_rate,
            sui_rate,
        ) = events_festivals::get_treasury_info(&treasury);

        assert!(treasury_name == string::utf8(b"Onoal Festival Coins"), 6);
        assert!(symbol == string::utf8(b"OFC"), 7);
        assert!(total_supply == 0, 8);
        assert!(fiat_rate == 100, 9);

        test::return_shared(event);
        test::return_shared(treasury);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_add_ticket_types_and_gates() {
    let mut scenario = test::begin(ORGANIZER);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create event first
    {
        let ctx = test::ctx(&mut scenario);
        events_festivals::create_event_entry(
            b"Test Festival",
            b"Test Description",
            b"Test Venue",
            b"https://test.com/image.jpg",
            b"https://test.com",
            FESTIVAL_START,
            FESTIVAL_END,
            REGISTRATION_DEADLINE,
            b"Test Coins",
            b"TC",
            100,
            &clock,
            ctx,
        );
    };

    // Add ticket types
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Add General Admission tickets
        events_festivals::add_ticket_type(
            &mut event,
            b"General Admission",
            b"Access to main festival area",
            50000000, // 0.05 SUI
            5000, // 50 festival coins
            1000, // max supply
            0, // ACCESS_GENERAL
            FESTIVAL_START,
            FESTIVAL_END,
            true, // transferable
            ctx,
        );

        // Add VIP tickets
        events_festivals::add_ticket_type(
            &mut event,
            b"VIP",
            b"VIP area access with premium amenities",
            200000000, // 0.2 SUI
            20000, // 200 festival coins
            100, // max supply
            1, // ACCESS_VIP
            FESTIVAL_START,
            FESTIVAL_END,
            true,
            ctx,
        );

        // Add Backstage Pass
        events_festivals::add_ticket_type(
            &mut event,
            b"Backstage Pass",
            b"Exclusive backstage access",
            500000000, // 0.5 SUI
            50000, // 500 festival coins
            20, // max supply
            2, // ACCESS_BACKSTAGE
            FESTIVAL_START,
            FESTIVAL_END,
            false, // not transferable
            ctx,
        );

        test::return_shared(event);
    };

    // Add access gates
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Main entrance
        events_festivals::add_access_gate(
            &mut event,
            b"Main Entrance",
            b"Festival Main Gate",
            0, // ACCESS_GENERAL
            vector[
                string::utf8(b"General Admission"),
                string::utf8(b"VIP"),
                string::utf8(b"Backstage Pass"),
            ],
            ctx,
        );

        // VIP entrance
        events_festivals::add_access_gate(
            &mut event,
            b"VIP Entrance",
            b"VIP Area Gate",
            1, // ACCESS_VIP
            vector[string::utf8(b"VIP"), string::utf8(b"Backstage Pass")],
            ctx,
        );

        // Backstage entrance
        events_festivals::add_access_gate(
            &mut event,
            b"Backstage Entrance",
            b"Artist Area Gate",
            2, // ACCESS_BACKSTAGE
            vector[string::utf8(b"Backstage Pass")],
            ctx,
        );

        test::return_shared(event);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_load_festival_coins() {
    let mut scenario = test::begin(ORGANIZER);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Create event
    {
        let ctx = test::ctx(&mut scenario);
        events_festivals::create_event_entry(
            b"Coin Test Festival",
            b"Testing festival coins",
            b"Test Venue",
            b"https://test.com/image.jpg",
            b"https://test.com",
            FESTIVAL_START,
            FESTIVAL_END,
            REGISTRATION_DEADLINE,
            b"Test Festival Coins",
            b"TFC",
            100, // 1 EUR = 100 coins
            &clock,
            ctx,
        );
    };

    // User loads festival coins with SUI
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Create SUI coin for payment (0.1 SUI)
        let sui_coin = coin::mint_for_testing<sui::sui::SUI>(100000000, ctx);

        // Load festival coins
        events_festivals::load_festival_coins_sui_entry(
            &event,
            &mut treasury,
            sui_coin,
            &clock,
            ctx,
        );

        test::return_shared(event);
        test::return_shared(treasury);
    };

    // Verify festival coins received
    next_tx(&mut scenario, USER1);
    {
        let treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let festival_coins = test::take_from_sender<Coin<FESTIVAL_COIN>>(&scenario);

        // Should receive 100,000,000 * 1000 = 100,000,000,000 festival coins
        assert!(coin::value(&festival_coins) == 100000000000, 0);

        let (_, _, total_supply, circulating_supply, _, _) = events_festivals::get_treasury_info(
            &treasury,
        );
        assert!(total_supply == 100000000000, 1);
        assert!(circulating_supply == 100000000000, 2);

        test::return_to_sender(&scenario, festival_coins);
        test::return_shared(treasury);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_purchase_tickets_with_sui() {
    let mut scenario = test::begin(ORGANIZER);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup event with ticket types
    setup_complete_festival(&mut scenario, &clock);

    // User1 purchases General Admission ticket
    next_tx(&mut scenario, USER1);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_payment = coin::mint_for_testing<sui::sui::SUI>(50000000, ctx); // 0.05 SUI

        events_festivals::purchase_ticket_sui_entry(
            &mut event,
            string::utf8(b"General Admission"),
            b"General Area",
            sui_payment,
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    // Verify ticket received
    next_tx(&mut scenario, USER1);
    {
        let ticket = test::take_from_sender<EventTicket>(&scenario);

        let (
            event_id,
            ticket_type,
            ticket_number,
            qr_code,
            access_level,
            status,
            purchased_at,
        ) = events_festivals::get_ticket_info(&ticket);

        assert!(ticket_type == string::utf8(b"General Admission"), 0);
        assert!(ticket_number == 1, 1);
        assert!(access_level == 0, 2); // ACCESS_GENERAL
        assert!(status == 0, 3); // TICKET_STATUS_VALID

        test::return_to_sender(&scenario, ticket);
    };

    // User2 purchases VIP ticket
    next_tx(&mut scenario, USER2);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_payment = coin::mint_for_testing<sui::sui::SUI>(200000000, ctx); // 0.2 SUI

        events_festivals::purchase_ticket_sui_entry(
            &mut event,
            string::utf8(b"VIP"),
            b"VIP Section A",
            sui_payment,
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_purchase_tickets_with_festival_coins() {
    let mut scenario = test::begin(ORGANIZER);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup event
    setup_complete_festival(&mut scenario, &clock);

    // User loads festival coins first
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_coin = coin::mint_for_testing<sui::sui::SUI>(100000000, ctx); // 0.1 SUI
        events_festivals::load_festival_coins_sui_entry(
            &event,
            &mut treasury,
            sui_coin,
            &clock,
            ctx,
        );

        test::return_shared(event);
        test::return_shared(treasury);
    };

    // User purchases ticket with festival coins
    next_tx(&mut scenario, USER1);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let mut festival_coins = test::take_from_sender<Coin<FESTIVAL_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Split coins for ticket purchase (5000 coins for General Admission)
        let payment_coins = coin::split(&mut festival_coins, 5000, ctx);

        let ticket = events_festivals::purchase_ticket_festival_coins(
            &mut event,
            &mut treasury,
            string::utf8(b"General Admission"),
            b"Festival Ground",
            payment_coins,
            &clock,
            ctx,
        );

        transfer::public_transfer(ticket, USER1);
        test::return_to_sender(&scenario, festival_coins);
        test::return_shared(event);
        test::return_shared(treasury);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_access_control_system() {
    let mut scenario = test::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup event
    setup_complete_festival(&mut scenario, &clock);

    // User purchases VIP ticket
    next_tx(&mut scenario, USER1);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_payment = coin::mint_for_testing<sui::sui::SUI>(200000000, ctx);
        events_festivals::purchase_ticket_sui_entry(
            &mut event,
            string::utf8(b"VIP"),
            b"VIP Section",
            sui_payment,
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    // Fast forward to festival start time
    let current_time = clock::timestamp_ms(&clock);
    clock::increment_for_testing(&mut clock, FESTIVAL_START - current_time);

    // User enters through main entrance
    next_tx(&mut scenario, USER1);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let mut ticket = test::take_from_sender<EventTicket>(&scenario);
        let ctx = test::ctx(&mut scenario);

        events_festivals::use_ticket_at_gate(
            &mut event,
            &mut ticket,
            string::utf8(b"Main Entrance"),
            &clock,
            ctx,
        );

        // Verify ticket is now used
        let (_, _, _, _, _, status, _) = events_festivals::get_ticket_info(&ticket);
        assert!(status == 1, 0); // TICKET_STATUS_USED

        test::return_to_sender(&scenario, ticket);
        test::return_shared(event);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_loyalty_system() {
    let mut scenario = test::begin(ORGANIZER);
    let clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup event
    setup_complete_festival(&mut scenario, &clock);

    // Add loyalty tiers
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        events_festivals::add_loyalty_tier(
            &mut event,
            1, // tier level
            b"Silver",
            2, // required events
            100000000, // required spending (0.1 SUI)
            10, // 10% discount
            2, // 2 hours early access
            ctx,
        );

        events_festivals::add_loyalty_tier(
            &mut event,
            2,
            b"Gold",
            5,
            500000000, // 0.5 SUI
            20, // 20% discount
            6, // 6 hours early access
            ctx,
        );

        test::return_shared(event);
    };

    // Add badge templates
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        events_festivals::add_badge_template(
            &mut event,
            b"Early Bird",
            b"Purchased ticket in first 24 hours",
            b"https://badges.onoal.com/early-bird.png",
            0, // BADGE_EARLY_BIRD
            ctx,
        );

        events_festivals::add_badge_template(
            &mut event,
            b"Repeat Visitor",
            b"Attended 3+ Onoal events",
            b"https://badges.onoal.com/repeat-visitor.png",
            1, // BADGE_REPEAT_VISITOR
            ctx,
        );

        test::return_shared(event);
    };

    // Create user profile
    next_tx(&mut scenario, USER1);
    {
        let ctx = test::ctx(&mut scenario);
        events_festivals::create_event_profile_entry(
            b"Festival Fan",
            b"https://avatar.onoal.com/user1.png",
            &clock,
            ctx,
        );
    };

    // Award badge to user
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let mut profile = test::take_from_address<EventProfile>(&scenario, USER1);
        let ctx = test::ctx(&mut scenario);

        let mut achievement_data = vec_map::empty<String, String>();
        vec_map::insert(
            &mut achievement_data,
            string::utf8(b"purchase_time"),
            string::utf8(b"2024-01-01T00:00:00Z"),
        );

        let badge = events_festivals::award_loyalty_badge(
            &mut event,
            &mut profile,
            string::utf8(b"Early Bird"),
            achievement_data,
            &clock,
            ctx,
        );

        transfer::public_transfer(badge, USER1);
        test::return_to_address(USER1, profile);
        test::return_shared(event);
    };

    // Verify badge received
    next_tx(&mut scenario, USER1);
    {
        let badge = test::take_from_sender<LoyaltyBadge>(&scenario);

        let (
            event_id,
            badge_name,
            badge_type,
            holder,
            earned_at,
            tier_level,
        ) = events_festivals::get_badge_info(&badge);

        assert!(badge_name == string::utf8(b"Early Bird"), 0);
        assert!(badge_type == 0, 1); // BADGE_EARLY_BIRD
        assert!(holder == USER1, 2);

        test::return_to_sender(&scenario, badge);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_complete_festival_workflow() {
    let mut scenario = test::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));

    // 1. Create festival
    setup_complete_festival(&mut scenario, &clock);

    // 2. Users create profiles
    next_tx(&mut scenario, USER1);
    {
        let ctx = test::ctx(&mut scenario);
        events_festivals::create_event_profile_entry(
            b"Music Lover",
            b"https://avatar.com/user1.png",
            &clock,
            ctx,
        );
    };

    // 3. User loads festival coins
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_coin = coin::mint_for_testing<sui::sui::SUI>(500000000, ctx); // 0.5 SUI
        events_festivals::load_festival_coins_sui_entry(
            &event,
            &mut treasury,
            sui_coin,
            &clock,
            ctx,
        );

        test::return_shared(event);
        test::return_shared(treasury);
    };

    // 4. User purchases VIP ticket with festival coins
    next_tx(&mut scenario, USER1);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let mut festival_coins = test::take_from_sender<Coin<FESTIVAL_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let payment_coins = coin::split(&mut festival_coins, 20000, ctx); // VIP ticket costs 20000 coins

        let ticket = events_festivals::purchase_ticket_festival_coins(
            &mut event,
            &mut treasury,
            string::utf8(b"VIP"),
            b"VIP Section Premium",
            payment_coins,
            &clock,
            ctx,
        );

        transfer::public_transfer(ticket, USER1);
        test::return_to_sender(&scenario, festival_coins);
        test::return_shared(event);
        test::return_shared(treasury);
    };

    // 5. Fast forward to festival day
    let current_time = clock::timestamp_ms(&clock);
    clock::increment_for_testing(&mut clock, FESTIVAL_START - current_time);

    // 6. User enters festival
    next_tx(&mut scenario, USER1);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let mut ticket = test::take_from_sender<EventTicket>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Enter through VIP entrance
        events_festivals::use_ticket_at_gate(
            &mut event,
            &mut ticket,
            string::utf8(b"VIP Entrance"),
            &clock,
            ctx,
        );

        test::return_to_sender(&scenario, ticket);
        test::return_shared(event);
    };

    // 7. Award loyalty badge
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let mut profile = test::take_from_address<EventProfile>(&scenario, USER1);
        let ctx = test::ctx(&mut scenario);

        // Add badge template first
        events_festivals::add_badge_template(
            &mut event,
            b"VIP Experience",
            b"Enjoyed VIP access at festival",
            b"https://badges.onoal.com/vip.png",
            2, // BADGE_VIP_MEMBER
            ctx,
        );

        let achievement_data = vec_map::empty<String, String>();
        let badge = events_festivals::award_loyalty_badge(
            &mut event,
            &mut profile,
            string::utf8(b"VIP Experience"),
            achievement_data,
            &clock,
            ctx,
        );

        transfer::public_transfer(badge, USER1);
        test::return_to_address(USER1, profile);
        test::return_shared(event);
    };

    // 8. Update user profile after event
    next_tx(&mut scenario, USER1);
    {
        let mut profile = test::take_from_address<EventProfile>(&scenario, USER1);
        let event = test::take_shared<EventRegistry>(&scenario);

        events_festivals::update_profile_after_event(
            &mut profile,
            object::id(&event),
            200000000, // spending amount
            &clock,
        );

        let (
            user,
            total_events,
            total_spending,
            current_tier,
            tier_name,
            badges_count,
        ) = events_festivals::get_profile_summary(&profile);

        assert!(total_events == 1, 0);
        assert!(total_spending == 200000000, 1);
        assert!(badges_count == 1, 2);

        test::return_to_address(USER1, profile);
        test::return_shared(event);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_festival_commerce_system() {
    let mut scenario = test::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup complete festival
    setup_complete_festival(&mut scenario, &clock);

    // Register food vendor
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        events_festivals::register_vendor_entry(
            &mut event,
            b"Onoal Food Truck",
            b"FOOD",
            b"Main Festival Area - Section A",
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    // Add food menu to vendor
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut vendor = test::take_shared<events_festivals::FestivalVendor>(&scenario);
        let ctx = test::ctx(&mut scenario);

        events_festivals::add_festival_food_menu(&mut vendor, ctx);

        test::return_shared(vendor);
    };

    // Register drinks vendor
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        events_festivals::register_vendor_entry(
            &mut event,
            b"Festival Bar",
            b"DRINKS",
            b"Main Stage Area",
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    // User loads festival coins
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_coin = coin::mint_for_testing<sui::sui::SUI>(100000000, ctx); // 0.1 SUI
        events_festivals::load_festival_coins_sui_entry(
            &event,
            &mut treasury,
            sui_coin,
            &clock,
            ctx,
        );

        test::return_shared(event);
        test::return_shared(treasury);
    };

    // User purchases food with festival coins
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut vendor = test::take_shared<events_festivals::FestivalVendor>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let mut festival_coins = test::take_from_sender<Coin<FESTIVAL_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Purchase burger (1200 coins) + fries (600 coins) = 1800 coins total
        let payment_coins = coin::split(&mut festival_coins, 1800, ctx);

        events_festivals::purchase_with_festival_coins_entry(
            &event,
            &mut vendor,
            &mut treasury,
            string::utf8(b"burger_classic"),
            1, // quantity
            b"No onions please",
            payment_coins,
            &clock,
            ctx,
        );

        test::return_to_sender(&scenario, festival_coins);
        test::return_shared(event);
        test::return_shared(vendor);
        test::return_shared(treasury);
    };

    // Verify purchase receipt
    next_tx(&mut scenario, USER1);
    {
        let receipt = test::take_from_sender<events_festivals::PurchaseReceipt>(&scenario);

        let (
            event_id,
            vendor_id,
            customer,
            total_amount,
            payment_method,
            order_status,
            purchase_time,
        ) = events_festivals::get_receipt_info(&receipt);

        assert!(customer == USER1, 0);
        assert!(total_amount == 1200, 1); // Burger price
        assert!(payment_method == string::utf8(b"FESTIVAL_COINS"), 2);
        assert!(order_status == string::utf8(b"PENDING"), 3);

        test::return_to_sender(&scenario, receipt);
    };

    // Vendor marks order as ready
    next_tx(&mut scenario, ORGANIZER);
    {
        let vendor = test::take_shared<events_festivals::FestivalVendor>(&scenario);
        let mut receipt = test::take_from_address<events_festivals::PurchaseReceipt>(
            &scenario,
            USER1,
        );
        let ctx = test::ctx(&mut scenario);

        events_festivals::update_order_status(
            &vendor,
            &mut receipt,
            b"READY",
            &clock,
            ctx,
        );

        test::return_to_address(USER1, receipt);
        test::return_shared(vendor);
    };

    // Verify order status updated
    next_tx(&mut scenario, USER1);
    {
        let receipt = test::take_from_sender<events_festivals::PurchaseReceipt>(&scenario);

        let (_, _, _, _, _, order_status, _) = events_festivals::get_receipt_info(&receipt);
        assert!(order_status == string::utf8(b"READY"), 0);

        test::return_to_sender(&scenario, receipt);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_multiple_vendor_purchases() {
    let mut scenario = test::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup festival
    setup_complete_festival(&mut scenario, &clock);

    // Register multiple vendors
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Food vendor
        events_festivals::register_vendor_entry(
            &mut event,
            b"Food Corner",
            b"FOOD",
            b"Food Court",
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Merchandise vendor
        events_festivals::register_vendor_entry(
            &mut event,
            b"Festival Merch",
            b"MERCHANDISE",
            b"Entrance Plaza",
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    // User loads plenty of festival coins
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_coin = coin::mint_for_testing<sui::sui::SUI>(500000000, ctx); // 0.5 SUI
        events_festivals::load_festival_coins_sui_entry(
            &event,
            &mut treasury,
            sui_coin,
            &clock,
            ctx,
        );

        test::return_shared(event);
        test::return_shared(treasury);
    };

    // Verify user has festival coins
    next_tx(&mut scenario, USER1);
    {
        let festival_coins = test::take_from_sender<Coin<FESTIVAL_COIN>>(&scenario);

        // Should have 500,000,000,000 festival coins (0.5 SUI * 1000 rate)
        assert!(coin::value(&festival_coins) == 500000000000, 0);

        test::return_to_sender(&scenario, festival_coins);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_gas_efficient_commerce() {
    let mut scenario = test::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));

    // Setup festival
    setup_complete_festival(&mut scenario, &clock);

    // Register vendor (minimal on-chain data)
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(&scenario);
        let ctx = test::ctx(&mut scenario);

        events_festivals::register_vendor_entry(
            &mut event,
            b"Gas Efficient Food Truck",
            b"FOOD",
            b"Main Area",
            &clock,
            ctx,
        );

        test::return_shared(event);
    };

    // User loads festival coins
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let sui_coin = coin::mint_for_testing<sui::sui::SUI>(100000000, ctx); // 0.1 SUI
        events_festivals::load_festival_coins_sui_entry(
            &event,
            &mut treasury,
            sui_coin,
            &clock,
            ctx,
        );

        test::return_shared(event);
        test::return_shared(treasury);
    };

    // User makes simple payment (product details off-chain)
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut vendor = test::take_shared<events_festivals::FestivalVendor>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let mut festival_coins = test::take_from_sender<Coin<FESTIVAL_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Simple payment: amount + hash reference to off-chain order
        let payment_coins = coin::split(&mut festival_coins, 1800, ctx); // 18 festival coins

        events_festivals::make_payment_entry(
            &event,
            &mut vendor,
            &mut treasury,
            1800, // Total amount
            b"order_hash_abc123", // Reference to off-chain order details
            payment_coins,
            &clock,
            ctx,
        );

        test::return_to_sender(&scenario, festival_coins);
        test::return_shared(event);
        test::return_shared(vendor);
        test::return_shared(treasury);
    };

    // Verify vendor stats updated
    next_tx(&mut scenario, USER1);
    {
        let vendor = test::take_shared<events_festivals::FestivalVendor>(&scenario);

        let (
            event_id,
            vendor_name,
            vendor_type,
            location,
            owner,
            is_active,
            total_sales,
            total_transactions,
        ) = events_festivals::get_vendor_info(&vendor);

        assert!(vendor_name == string::utf8(b"Gas Efficient Food Truck"), 0);
        assert!(total_sales == 1800, 1);
        assert!(total_transactions == 1, 2);
        assert!(is_active == true, 3);

        test::return_shared(vendor);
    };

    // User makes bulk payment (multiple items in one transaction)
    next_tx(&mut scenario, USER1);
    {
        let event = test::take_shared<EventRegistry>(&scenario);
        let mut vendor = test::take_shared<events_festivals::FestivalVendor>(&scenario);
        let mut treasury = test::take_shared<FestivalCoinTreasury>(&scenario);
        let mut festival_coins = test::take_from_sender<Coin<FESTIVAL_COIN>>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Bulk payment: multiple amounts + hash references
        let payment_coins = coin::split(&mut festival_coins, 3200, ctx); // 32 festival coins total

        events_festivals::bulk_payment_entry(
            &event,
            &mut vendor,
            &mut treasury,
            vector[1200, 800, 1200], // burger, beer, fries
            vector[
                string::utf8(b"order_hash_def456"),
                string::utf8(b"order_hash_ghi789"),
                string::utf8(b"order_hash_jkl012"),
            ],
            payment_coins,
            &clock,
            ctx,
        );

        test::return_to_sender(&scenario, festival_coins);
        test::return_shared(event);
        test::return_shared(vendor);
        test::return_shared(treasury);
    };

    // Verify bulk payment stats
    next_tx(&mut scenario, USER1);
    {
        let vendor = test::take_shared<events_festivals::FestivalVendor>(&scenario);

        let (_, _, _, _, _, _, total_sales, total_transactions) = events_festivals::get_vendor_info(
            &vendor,
        );

        assert!(total_sales == 5000, 0); // 1800 + 3200
        assert!(total_transactions == 4, 1); // 1 + 3

        test::return_shared(vendor);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

// Helper function to setup a complete festival with all ticket types and gates
fun setup_complete_festival(scenario: &mut Scenario, clock: &Clock) {
    // Create event
    {
        let ctx = test::ctx(scenario);
        events_festivals::create_event_entry(
            b"Complete Festival Test",
            b"Full featured festival for testing",
            b"Test Arena",
            b"https://test.com/festival.jpg",
            b"https://festival-test.com",
            FESTIVAL_START,
            FESTIVAL_END,
            REGISTRATION_DEADLINE,
            b"Festival Test Coins",
            b"FTC",
            100,
            clock,
            ctx,
        );
    };

    // Add ticket types
    next_tx(scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(scenario);
        let ctx = test::ctx(scenario);

        events_festivals::add_ticket_type(
            &mut event,
            b"General Admission",
            b"General access",
            50000000,
            5000,
            1000,
            0,
            FESTIVAL_START,
            FESTIVAL_END,
            true,
            ctx,
        );

        events_festivals::add_ticket_type(
            &mut event,
            b"VIP",
            b"VIP access",
            200000000,
            20000,
            100,
            1,
            FESTIVAL_START,
            FESTIVAL_END,
            true,
            ctx,
        );

        events_festivals::add_ticket_type(
            &mut event,
            b"Backstage Pass",
            b"Backstage access",
            500000000,
            50000,
            20,
            2,
            FESTIVAL_START,
            FESTIVAL_END,
            false,
            ctx,
        );

        test::return_shared(event);
    };

    // Add access gates
    next_tx(scenario, ORGANIZER);
    {
        let mut event = test::take_shared<EventRegistry>(scenario);
        let ctx = test::ctx(scenario);

        events_festivals::add_access_gate(
            &mut event,
            b"Main Entrance",
            b"Main Gate",
            0,
            vector[
                string::utf8(b"General Admission"),
                string::utf8(b"VIP"),
                string::utf8(b"Backstage Pass"),
            ],
            ctx,
        );

        events_festivals::add_access_gate(
            &mut event,
            b"VIP Entrance",
            b"VIP Gate",
            1,
            vector[string::utf8(b"VIP"), string::utf8(b"Backstage Pass")],
            ctx,
        );

        events_festivals::add_access_gate(
            &mut event,
            b"Backstage Entrance",
            b"Artist Gate",
            2,
            vector[string::utf8(b"Backstage Pass")],
            ctx,
        );

        test::return_shared(event);
    };
}
