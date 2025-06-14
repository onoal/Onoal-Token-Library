#[allow(unused_variable)]
#[test_only]
module otl::ticket_tests;

use otl::ticket::{Self, Event, Ticket, TICKET};
use sui::clock;
use sui::test_scenario::{Self, Scenario};
use sui::transfer;

const ADMIN: address = @0x100;
const USER1: address = @0x200;
const USER2: address = @0x300;

#[test]
fun test_create_event() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);

        // Event in the future (timestamps in milliseconds)
        let now = 1700000000000; // Nov 2023
        let sale_start = now + 100000; // sale starts later
        let sale_end = now + 200000; // sale ends after that
        let event_date = now + 300000; // event is after sales

        ticket::create_shared_event(
            b"Onoal Tech Conference 2024",
            b"The biggest blockchain tech conference of the year",
            b"Amsterdam Convention Center",
            event_date,
            sale_start,
            sale_end,
            b"https://onoal.com/events/tech2024/banner.png",
            b"https://onoal.com/events/tech2024/poster.png",
            b"https://onoal.com/events/tech2024",
            500, // max tickets
            ctx,
        );
    };

    test_scenario::next_tx(scenario, USER1);
    {
        let event = test_scenario::take_shared<Event>(scenario);
        let (
            name,
            description,
            venue,
            event_date,
            max_tickets,
            current_tickets,
            tickets_used,
        ) = ticket::get_event_info(&event);

        assert!(name == std::string::utf8(b"Onoal Tech Conference 2024"), 0);
        assert!(venue == std::string::utf8(b"Amsterdam Convention Center"), 1);
        assert!(max_tickets == 500, 2);
        assert!(current_tickets == 0, 3);
        assert!(tickets_used == 0, 4);

        test_scenario::return_shared(event);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_issue_ticket() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create event
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        let now = 1700000000000;

        ticket::create_shared_event(
            b"Test Event",
            b"Test event description",
            b"Test Venue",
            now + 300000, // event date
            now - 100000, // sale already started
            now + 200000, // sale not ended yet
            b"https://test.com/banner.png",
            b"https://test.com/poster.png",
            b"https://test.com/event",
            100,
            ctx,
        );
    };

    // Issue ticket
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000); // current time
        let ctx = test_scenario::ctx(scenario);

        ticket::issue_ticket_to_recipient(
            &mut event,
            USER1,
            b"VIP",
            b"Section A, Row 1, Seat 5",
            50000000, // 0.05 SUI in MIST
            &clock,
            ctx,
        );

        let (_, _, _, _, max_tickets, current_tickets, _) = ticket::get_event_info(&event);
        assert!(current_tickets == 1, 0);

        test_scenario::return_shared(event);
        clock::destroy_for_testing(clock);
    };

    // Check USER1 received the ticket
    test_scenario::next_tx(scenario, USER1);
    {
        let ticket = test_scenario::take_from_sender<Ticket>(scenario);

        let (
            event_id,
            ticket_id,
            holder,
            status,
            ticket_type,
            seat_info,
            issued_at,
            redeemed_at,
        ) = ticket::get_ticket_info(&ticket);

        assert!(ticket_id == 1, 1);
        assert!(holder == USER1, 2);
        assert!(status == 0, 3); // TICKET_STATUS_UNUSED
        assert!(ticket_type == std::string::utf8(b"VIP"), 4);
        assert!(seat_info == std::string::utf8(b"Section A, Row 1, Seat 5"), 5);
        assert!(redeemed_at == 0, 6); // not redeemed yet
        assert!(ticket::is_ticket_valid(&ticket), 7);

        test_scenario::return_to_sender(scenario, ticket);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_redeem_ticket() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create event and issue ticket
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        let now = 1700000000000;

        ticket::create_shared_event(
            b"Redeem Test Event",
            b"Event for testing ticket redemption",
            b"Test Venue",
            now + 100000, // event date soon
            now - 200000, // sale already started
            now + 50000, // sale not ended
            b"https://test.com/banner.png",
            b"https://test.com/poster.png",
            b"https://test.com/event",
            50,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        ticket::issue_ticket_to_recipient(
            &mut event,
            USER1,
            b"General",
            b"Section B, Row 5, Seat 12",
            25000000, // 0.025 SUI
            &clock,
            ctx,
        );

        test_scenario::return_shared(event);
        clock::destroy_for_testing(clock);
    };

    // Wait until event time and redeem ticket
    test_scenario::next_tx(scenario, USER1);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut ticket = test_scenario::take_from_sender<Ticket>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Set time to after event start
        clock::set_for_testing(&mut clock, 1700000100000); // event date passed
        let ctx = test_scenario::ctx(scenario);

        // Check ticket is valid before redemption
        assert!(ticket::is_ticket_valid(&ticket), 0);

        // Redeem ticket with commemorative info
        ticket::redeem_ticket_entry(
            &mut event,
            &mut ticket,
            b"Onoal Tech Conference 2024 - Commemorative NFT",
            b"Thank you for attending Onoal Tech Conference 2024! This NFT commemorates your participation in this historic event.",
            b"https://onoal.com/events/tech2024/commemorative.png",
            &clock,
            ctx,
        );

        // Check ticket status after redemption
        assert!(ticket::is_ticket_used(&ticket), 1);
        assert!(!ticket::is_ticket_valid(&ticket), 2);

        // Check commemorative info
        let (comm_title, comm_desc, comm_image) = ticket::get_commemorative_info(&ticket);
        assert!(
            comm_title == std::string::utf8(b"Onoal Tech Conference 2024 - Commemorative NFT"),
            3,
        );
        assert!(!std::string::is_empty(&comm_desc), 4);
        assert!(!std::string::is_empty(&comm_image), 5);

        // Check event stats
        let (max_tickets, current_tickets, tickets_used, remaining) = ticket::get_event_stats(
            &event,
        );
        assert!(tickets_used == 1, 6);
        assert!(remaining == 49, 7);

        test_scenario::return_shared(event);
        test_scenario::return_to_sender(scenario, ticket);
        clock::destroy_for_testing(clock);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_transfer_ticket() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create event and issue ticket
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        let now = 1700000000000;

        ticket::create_shared_event(
            b"Transfer Test",
            b"Event for testing ticket transfers",
            b"Test Venue",
            now + 300000,
            now - 100000,
            now + 200000,
            b"https://test.com/banner.png",
            b"https://test.com/poster.png",
            b"https://test.com/event",
            10,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        ticket::issue_ticket_to_recipient(
            &mut event,
            USER1,
            b"Transfer Ticket",
            b"Section C, Row 3, Seat 8",
            30000000,
            &clock,
            ctx,
        );

        test_scenario::return_shared(event);
        clock::destroy_for_testing(clock);
    };

    // Transfer ticket from USER1 to USER2
    test_scenario::next_tx(scenario, USER1);
    {
        let ticket = test_scenario::take_from_sender<Ticket>(scenario);
        let ctx = test_scenario::ctx(scenario);

        // Check ticket is valid for transfer
        assert!(ticket::is_ticket_valid(&ticket), 0);

        ticket::transfer_ticket(ticket, USER2, ctx);
    };

    // Check USER2 received the ticket
    test_scenario::next_tx(scenario, USER2);
    {
        let ticket_ids = test_scenario::ids_for_sender<Ticket>(scenario);
        assert!(vector::length(&ticket_ids) == 1, 1);

        let ticket = test_scenario::take_from_sender<Ticket>(scenario);
        let (_, ticket_id, holder, status, ticket_type, _, _, _) = ticket::get_ticket_info(&ticket);

        assert!(ticket_id == 1, 2);
        assert!(holder == USER1, 3); // Original holder info preserved
        assert!(status == 0, 4); // Still unused
        assert!(ticket_type == std::string::utf8(b"Transfer Ticket"), 5);

        test_scenario::return_to_sender(scenario, ticket);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_ticket_attributes() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create event and issue ticket
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        let now = 1700000000000;

        ticket::create_shared_event(
            b"Attribute Test",
            b"Event for testing attributes",
            b"Test Venue",
            now + 300000,
            now - 100000,
            now + 200000,
            b"https://test.com/banner.png",
            b"https://test.com/poster.png",
            b"https://test.com/event",
            10,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        ticket::issue_ticket_to_recipient(
            &mut event,
            USER1,
            b"Premium",
            b"Section VIP, Row 1, Seat 1",
            100000000, // 0.1 SUI
            &clock,
            ctx,
        );

        test_scenario::return_shared(event);
        clock::destroy_for_testing(clock);
    };

    // Add attributes to ticket
    test_scenario::next_tx(scenario, USER1);
    {
        let mut ticket = test_scenario::take_from_sender<Ticket>(scenario);
        let ctx = test_scenario::ctx(scenario);

        ticket::add_ticket_attribute(
            &mut ticket,
            b"access_level",
            b"premium_backstage",
            ctx,
        );

        ticket::add_ticket_attribute(
            &mut ticket,
            b"perks",
            b"meet_and_greet,vip_lounge,early_access",
            ctx,
        );

        // Check attributes
        let access_level = ticket::get_ticket_attribute(
            &ticket,
            &std::string::utf8(b"access_level"),
        );
        let perks = ticket::get_ticket_attribute(&ticket, &std::string::utf8(b"perks"));

        assert!(access_level == std::string::utf8(b"premium_backstage"), 0);
        assert!(perks == std::string::utf8(b"meet_and_greet,vip_lounge,early_access"), 1);

        test_scenario::return_to_sender(scenario, ticket);
    };

    test_scenario::end(scenario_val);
}
