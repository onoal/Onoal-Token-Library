#[allow(unused_const, unused_variable)]
#[test_only]
module otl::kiosk_integration_tests;

use otl::coin::{Self, UtilityTokenRegistry, TokenType, TokenWallet};
use otl::collectible::{Self, Collection, Collectible};
use otl::kiosk_integration::{Self, KioskRegistry, MerchantKioskInfo, PlatformListing};
use otl::ticket::{Self, Event, Ticket};
use sui::clock;
use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
use sui::test_scenario::{Self, Scenario};
use sui::transfer;

const PLATFORM_ADMIN: address = @0x100;
const MERCHANT1: address = @0x200;
const MERCHANT2: address = @0x300;
const USER1: address = @0x400;
const USER2: address = @0x500;

// Helper function to create SUI coins for testing
fun mint_sui_for_testing(
    amount: u64,
    ctx: &mut sui::tx_context::TxContext,
): sui::coin::Coin<sui::sui::SUI> {
    sui::coin::mint_for_testing<sui::sui::SUI>(amount, ctx)
}

#[test]
fun test_create_kiosk_registry() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    test_scenario::next_tx(scenario, USER1);
    {
        let registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let (
            platform_authority,
            platform_kiosk_id,
            total_merchants,
            total_sales_volume,
            total_platform_fees,
            platform_fee_bps,
            merchant_fee_bps,
        ) = kiosk_integration::get_registry_info(&registry);

        assert!(platform_authority == PLATFORM_ADMIN, 0);
        assert!(total_merchants == 0, 1);
        assert!(total_sales_volume == 0, 2);
        assert!(total_platform_fees == 0, 3);
        assert!(platform_fee_bps == 250, 4); // 2.5%
        assert!(merchant_fee_bps == 500, 5); // 5%

        test_scenario::return_shared(registry);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_create_merchant_kiosk() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Create registry
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    // MERCHANT1 creates their kiosk
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Onoal Coffee Shop",
            b"Premium coffee and pastries with loyalty rewards",
            ctx,
        );

        let (_, _, total_merchants, _, _, _, _) = kiosk_integration::get_registry_info(&registry);
        assert!(total_merchants == 1, 0);

        // Check merchant info
        let (
            merchant_name,
            merchant_description,
            kiosk_id,
            total_sales,
            total_items_sold,
            is_verified,
        ) = kiosk_integration::get_merchant_info(&registry, MERCHANT1);

        assert!(merchant_name == std::string::utf8(b"Onoal Coffee Shop"), 1);
        assert!(total_sales == 0, 2);
        assert!(total_items_sold == 0, 3);
        assert!(is_verified == false, 4); // Not verified yet

        test_scenario::return_shared(registry);
    };

    // Check MERCHANT1 received kiosk and cap
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        // Merchant should have received a kiosk cap (kiosk is transferred to them)
        let kiosk_cap = test_scenario::take_from_sender<KioskOwnerCap>(scenario);
        test_scenario::return_to_sender(scenario, kiosk_cap);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_verify_merchant() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Setup registry and merchant kiosk
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Verified Merchant",
            b"A trustworthy merchant",
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    // Platform admin verifies the merchant
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::verify_merchant(&mut registry, MERCHANT1, ctx);

        // Check merchant is now verified
        assert!(kiosk_integration::is_merchant_verified(&registry, MERCHANT1), 0);

        test_scenario::return_shared(registry);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_list_collectible_on_merchant_kiosk() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Setup registry and merchant kiosk
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"NFT Gallery",
            b"Exclusive digital art collection",
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    // Create a collectible collection
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let ctx = test_scenario::ctx(scenario);
        collectible::create_shared_collection(
            b"Gallery Collection",
            b"GALLERY",
            b"Exclusive art pieces",
            b"https://gallery.com/collection.png",
            b"https://gallery.com",
            100,
            ctx,
        );
    };

    // Mint a collectible
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut collection = test_scenario::take_shared<Collection>(scenario);
        let ctx = test_scenario::ctx(scenario);

        collectible::mint_collectible_to_recipient(
            &mut collection,
            b"Digital Masterpiece #1",
            b"A stunning digital artwork",
            b"https://gallery.com/art1.png",
            b"https://gallery.com/art1",
            MERCHANT1,
            ctx,
        );

        test_scenario::return_shared(collection);
    };

    // List collectible on merchant's own kiosk
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut merchant_kiosk = test_scenario::take_from_address<Kiosk>(scenario, MERCHANT1);
        let merchant_cap = test_scenario::take_from_sender<KioskOwnerCap>(scenario);
        let collectible = test_scenario::take_from_sender<Collectible>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::list_collectible_on_merchant_kiosk(
            &mut merchant_kiosk,
            &merchant_cap,
            collectible,
            5000000000, // 5 SUI
            ctx,
        );

        transfer::public_transfer(merchant_kiosk, MERCHANT1);
        test_scenario::return_to_sender(scenario, merchant_cap);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_list_collectible_on_platform_kiosk() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Setup registry and merchant kiosk
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Platform Seller",
            b"Selling on the main marketplace",
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    // Create and mint collectible
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let ctx = test_scenario::ctx(scenario);
        collectible::create_shared_collection(
            b"Platform Collection",
            b"PLATFORM",
            b"Items for the main marketplace",
            b"https://platform.com/collection.png",
            b"https://platform.com",
            50,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut collection = test_scenario::take_shared<Collection>(scenario);
        let ctx = test_scenario::ctx(scenario);

        collectible::mint_collectible_to_recipient(
            &mut collection,
            b"Platform NFT #1",
            b"An NFT for the main marketplace",
            b"https://platform.com/nft1.png",
            b"https://platform.com/nft1",
            MERCHANT1,
            ctx,
        );

        test_scenario::return_shared(collection);
    };

    // List collectible on platform kiosk
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let mut platform_kiosk = test_scenario::take_from_address<Kiosk>(scenario, PLATFORM_ADMIN);
        let collectible = test_scenario::take_from_sender<Collectible>(scenario);
        let ctx = test_scenario::ctx(scenario);

        let listing = kiosk_integration::list_collectible_on_platform_kiosk(
            &mut registry,
            &mut platform_kiosk,
            collectible,
            3000000000, // 3 SUI
            b"Exclusive Platform NFT",
            b"A rare digital collectible available on the main marketplace",
            b"https://platform.com/nft1.png",
            ctx,
        );

        // Check listing info
        let (
            item_id,
            item_type,
            merchant,
            price,
            title,
            description,
            is_active,
            merchant_fee_amount,
            platform_fee_amount,
        ) = kiosk_integration::get_listing_info(&listing);

        assert!(item_type == std::string::utf8(b"collectible"), 0);
        assert!(merchant == MERCHANT1, 1);
        assert!(price == 3000000000, 2); // 3 SUI
        assert!(title == std::string::utf8(b"Exclusive Platform NFT"), 3);
        assert!(is_active == true, 4);
        assert!(merchant_fee_amount == 150000000, 5); // 5% of 3 SUI = 0.15 SUI
        assert!(platform_fee_amount == 75000000, 6); // 2.5% of 3 SUI = 0.075 SUI

        test_scenario::return_shared(registry);
        transfer::public_transfer(platform_kiosk, PLATFORM_ADMIN);
        transfer::public_transfer(listing, MERCHANT1);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_list_ticket_on_platform_kiosk() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Setup registry
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    // Create event and issue ticket
    test_scenario::next_tx(scenario, USER1);
    {
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        ticket::create_shared_event(
            b"Onoal Festival 2024",
            b"The biggest blockchain festival of the year",
            b"Convention Center",
            1700000000000 + (7 * 24 * 60 * 60 * 1000), // Event in 7 days
            1700000000000, // Sale starts now
            1700000000000 + (6 * 24 * 60 * 60 * 1000), // Sale ends in 6 days
            b"https://festival.com/poster.png",
            b"https://festival.com/poster_large.png",
            b"https://festival.com",
            1000,
            ctx,
        );

        clock::destroy_for_testing(clock);
    };

    test_scenario::next_tx(scenario, USER1);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1700000000000);
        let ctx = test_scenario::ctx(scenario);

        ticket::issue_ticket_to_recipient(
            &mut event,
            USER1,
            b"VIP",
            b"Section A, Row 1, Seat 5",
            2000000000, // Paid 2 SUI
            &clock,
            ctx,
        );

        test_scenario::return_shared(event);
        clock::destroy_for_testing(clock);
    };

    // List ticket for resale on platform kiosk
    test_scenario::next_tx(scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let mut platform_kiosk = test_scenario::take_from_address<Kiosk>(scenario, PLATFORM_ADMIN);
        let ticket = test_scenario::take_from_sender<Ticket>(scenario);
        let ctx = test_scenario::ctx(scenario);

        let listing = kiosk_integration::list_ticket_on_platform_kiosk(
            &mut registry,
            &mut platform_kiosk,
            ticket,
            2500000000, // Reselling for 2.5 SUI
            3000000000, // Max resale price 3 SUI (anti-scalping)
            b"VIP Festival Ticket",
            b"Premium VIP access to Onoal Festival 2024",
            ctx,
        );

        // Check listing
        let (
            item_id,
            item_type,
            merchant,
            price,
            title,
            description,
            is_active,
            merchant_fee_amount,
            platform_fee_amount,
        ) = kiosk_integration::get_listing_info(&listing);

        assert!(item_type == std::string::utf8(b"ticket"), 0);
        assert!(merchant == USER1, 1);
        assert!(price == 2500000000, 2); // 2.5 SUI
        assert!(title == std::string::utf8(b"VIP Festival Ticket"), 3);
        assert!(is_active == true, 4);

        test_scenario::return_shared(registry);
        transfer::public_transfer(platform_kiosk, PLATFORM_ADMIN);
        transfer::public_transfer(listing, USER1);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_list_token_wallet_on_platform_kiosk() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Setup registry
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    // Create utility token system
    test_scenario::next_tx(scenario, USER1);
    {
        let ctx = test_scenario::ctx(scenario);
        coin::create_shared_utility_token_registry(
            b"Token Trading Registry",
            b"For trading utility tokens",
            ctx,
        );
    };

    test_scenario::next_tx(scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<UtilityTokenRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        coin::create_shared_token_type(
            &mut registry,
            b"Gaming Credits",
            b"GAME",
            b"Credits for gaming ecosystem",
            b"https://game.com/icon.png",
            b"https://game.com",
            100000000, // 0.1 SUI per token
            false,
            1000000,
            8,
            true,
            true,
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    // User purchases tokens
    test_scenario::next_tx(scenario, USER1);
    {
        let mut token_registry = test_scenario::take_shared<UtilityTokenRegistry>(scenario);
        let mut token_type = test_scenario::take_shared<TokenType>(scenario);
        let ctx = test_scenario::ctx(scenario);

        let payment = mint_sui_for_testing(5000000000, ctx); // 5 SUI for 50 tokens
        coin::smart_purchase_tokens_entry(
            &mut token_registry,
            &mut token_type,
            50,
            payment,
            ctx,
        );

        test_scenario::return_shared(token_registry);
        test_scenario::return_shared(token_type);
    };

    // List token wallet on platform kiosk
    test_scenario::next_tx(scenario, USER1);
    {
        let mut kiosk_registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let mut platform_kiosk = test_scenario::take_from_address<Kiosk>(scenario, PLATFORM_ADMIN);
        let token_wallet = test_scenario::take_from_sender<TokenWallet>(scenario);
        let ctx = test_scenario::ctx(scenario);

        let listing = kiosk_integration::list_token_wallet_on_platform_kiosk(
            &mut kiosk_registry,
            &mut platform_kiosk,
            token_wallet,
            120000000, // Selling for 0.12 SUI per token (20% markup)
            b"Gaming Credits Wallet",
            b"50 gaming credits ready for immediate use",
            ctx,
        );

        // Check listing
        let (
            item_id,
            item_type,
            merchant,
            price,
            title,
            description,
            is_active,
            merchant_fee_amount,
            platform_fee_amount,
        ) = kiosk_integration::get_listing_info(&listing);

        assert!(item_type == std::string::utf8(b"token_wallet"), 0);
        assert!(merchant == USER1, 1);
        assert!(price == 6000000000, 2); // 50 tokens * 0.12 SUI = 6 SUI
        assert!(title == std::string::utf8(b"Gaming Credits Wallet"), 3);
        assert!(is_active == true, 4);
        assert!(merchant_fee_amount == 300000000, 5); // 5% of 6 SUI = 0.3 SUI
        assert!(platform_fee_amount == 150000000, 6); // 2.5% of 6 SUI = 0.15 SUI

        test_scenario::return_shared(kiosk_registry);
        transfer::public_transfer(platform_kiosk, PLATFORM_ADMIN);
        transfer::public_transfer(listing, USER1);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_dual_kiosk_ecosystem() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Setup the complete dual kiosk ecosystem
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    // Two merchants create their kiosks
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Coffee & NFTs",
            b"Where coffee meets digital art",
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    test_scenario::next_tx(scenario, MERCHANT2);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Festival Organizer",
            b"Premium events and experiences",
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    // Platform admin verifies both merchants
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::verify_merchant(&mut registry, MERCHANT1, ctx);
        kiosk_integration::verify_merchant(&mut registry, MERCHANT2, ctx);

        // Check final registry state
        let (
            platform_authority,
            platform_kiosk_id,
            total_merchants,
            total_sales_volume,
            total_platform_fees,
            platform_fee_bps,
            merchant_fee_bps,
        ) = kiosk_integration::get_registry_info(&registry);

        assert!(platform_authority == PLATFORM_ADMIN, 0);
        assert!(total_merchants == 2, 1);
        assert!(total_sales_volume == 0, 2); // No sales yet
        assert!(total_platform_fees == 0, 3); // No fees yet
        assert!(platform_fee_bps == 250, 4); // 2.5%
        assert!(merchant_fee_bps == 500, 5); // 5%

        // Check both merchants are verified
        assert!(kiosk_integration::is_merchant_verified(&registry, MERCHANT1), 6);
        assert!(kiosk_integration::is_merchant_verified(&registry, MERCHANT2), 7);
        assert!(kiosk_integration::has_merchant_kiosk(&registry, MERCHANT1), 8);
        assert!(kiosk_integration::has_merchant_kiosk(&registry, MERCHANT2), 9);

        test_scenario::return_shared(registry);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_create_master_kiosk() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Create registry
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    // Create master kiosk
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_master_kiosk_entry(&mut registry, ctx);

        // Check master kiosk is enabled
        assert!(kiosk_integration::is_master_kiosk_enabled(&registry), 0);

        // Check extended registry info
        let (
            platform_authority,
            platform_kiosk_id,
            master_kiosk_opt,
            master_kiosk_enabled,
            total_merchants,
            total_sales_volume,
            total_platform_fees,
            platform_fee_bps,
            merchant_fee_bps,
        ) = kiosk_integration::get_extended_registry_info(&registry);

        assert!(platform_authority == PLATFORM_ADMIN, 1);
        assert!(master_kiosk_enabled == true, 2);
        assert!(std::option::is_some(&master_kiosk_opt), 3);
        assert!(total_merchants == 1, 4); // Onoal is now a merchant

        // Check Onoal is in verified list
        assert!(kiosk_integration::is_in_onoal_verified_list(&registry, PLATFORM_ADMIN), 5);
        assert!(kiosk_integration::is_merchant_onoal_verified(&registry, PLATFORM_ADMIN), 6);

        // Check verification level
        let (none, basic, onoal, master) = kiosk_integration::get_verification_levels();
        assert!(
            kiosk_integration::get_merchant_verification_level(&registry, PLATFORM_ADMIN) == master,
            7,
        );

        test_scenario::return_shared(registry);
    };

    // Check PLATFORM_ADMIN received master kiosk and cap
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let master_kiosk_cap = test_scenario::take_from_sender<KioskOwnerCap>(scenario);
        test_scenario::return_to_sender(scenario, master_kiosk_cap);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_onoal_verification_system() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Setup registry and master kiosk
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_master_kiosk_entry(&mut registry, ctx);
        test_scenario::return_shared(registry);
    };

    // Create merchant kiosk
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Premium Coffee Shop",
            b"High-quality coffee with blockchain loyalty",
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    // Basic verification first
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::verify_merchant(&mut registry, MERCHANT1, ctx);

        // Check basic verification
        assert!(kiosk_integration::is_merchant_verified(&registry, MERCHANT1), 0);
        assert!(!kiosk_integration::is_merchant_onoal_verified(&registry, MERCHANT1), 1);

        let (_, basic, _, _) = kiosk_integration::get_verification_levels();
        assert!(
            kiosk_integration::get_merchant_verification_level(&registry, MERCHANT1) == basic,
            2,
        );

        test_scenario::return_shared(registry);
    };

    // Grant Onoal verification
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::grant_onoal_verification(
            &mut registry,
            MERCHANT1,
            b"business_license",
            b"NL-12345-COFFEE-2024",
            ctx,
        );

        // Check Onoal verification
        assert!(kiosk_integration::is_merchant_verified(&registry, MERCHANT1), 3);
        assert!(kiosk_integration::is_merchant_onoal_verified(&registry, MERCHANT1), 4);
        assert!(kiosk_integration::is_in_onoal_verified_list(&registry, MERCHANT1), 5);

        let (_, _, onoal, _) = kiosk_integration::get_verification_levels();
        assert!(
            kiosk_integration::get_merchant_verification_level(&registry, MERCHANT1) == onoal,
            6,
        );

        // Check extended merchant info
        let (
            merchant_name,
            merchant_description,
            kiosk_id,
            total_sales,
            total_items_sold,
            is_verified,
            is_onoal_verified,
            verification_level,
            verified_at,
            verified_by,
        ) = kiosk_integration::get_extended_merchant_info(&registry, MERCHANT1);

        assert!(merchant_name == std::string::utf8(b"Premium Coffee Shop"), 7);
        assert!(is_verified == true, 8);
        assert!(is_onoal_verified == true, 9);
        assert!(verification_level == onoal, 10);
        assert!(verified_by == PLATFORM_ADMIN, 11);
        assert!(verified_at > 0, 12);

        test_scenario::return_shared(registry);
    };

    // Test revoke Onoal verification
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        kiosk_integration::revoke_onoal_verification(&mut registry, MERCHANT1, ctx);

        // Check verification downgrade
        assert!(kiosk_integration::is_merchant_verified(&registry, MERCHANT1), 13); // Still basic verified
        assert!(!kiosk_integration::is_merchant_onoal_verified(&registry, MERCHANT1), 14); // No longer Onoal verified
        assert!(!kiosk_integration::is_in_onoal_verified_list(&registry, MERCHANT1), 15);

        let (_, basic, _, _) = kiosk_integration::get_verification_levels();
        assert!(
            kiosk_integration::get_merchant_verification_level(&registry, MERCHANT1) == basic,
            16,
        );

        test_scenario::return_shared(registry);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_master_kiosk_complete_ecosystem() {
    let mut scenario_val = test_scenario::begin(PLATFORM_ADMIN);
    let scenario = &mut scenario_val;

    // Complete ecosystem test with master kiosk
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_shared_kiosk_registry(ctx);
    };

    // Create master kiosk
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_master_kiosk_entry(&mut registry, ctx);
        test_scenario::return_shared(registry);
    };

    // Create multiple merchants with different verification levels
    test_scenario::next_tx(scenario, MERCHANT1);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Basic Merchant",
            b"Basic verified merchant",
            ctx,
        );
        test_scenario::return_shared(registry);
    };

    test_scenario::next_tx(scenario, MERCHANT2);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);
        kiosk_integration::create_merchant_kiosk_entry(
            &mut registry,
            b"Premium Partner",
            b"Onoal verified premium partner",
            ctx,
        );
        test_scenario::return_shared(registry);
    };

    // Apply different verification levels
    test_scenario::next_tx(scenario, PLATFORM_ADMIN);
    {
        let mut registry = test_scenario::take_shared<KioskRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        // Basic verification for MERCHANT1
        kiosk_integration::verify_merchant(&mut registry, MERCHANT1, ctx);

        // Onoal verification for MERCHANT2
        kiosk_integration::verify_merchant(&mut registry, MERCHANT2, ctx);
        kiosk_integration::grant_onoal_verification(
            &mut registry,
            MERCHANT2,
            b"premium_partner_agreement",
            b"ONOAL-PARTNER-2024-001",
            ctx,
        );

        test_scenario::return_shared(registry);
    };

    // Final verification check
    test_scenario::next_tx(scenario, USER1);
    {
        let registry = test_scenario::take_shared<KioskRegistry>(scenario);

        let (none, basic, onoal, master) = kiosk_integration::get_verification_levels();

        // Check all verification levels
        assert!(
            kiosk_integration::get_merchant_verification_level(&registry, PLATFORM_ADMIN) == master,
            0,
        );
        assert!(
            kiosk_integration::get_merchant_verification_level(&registry, MERCHANT1) == basic,
            1,
        );
        assert!(
            kiosk_integration::get_merchant_verification_level(&registry, MERCHANT2) == onoal,
            2,
        );
        assert!(kiosk_integration::get_merchant_verification_level(&registry, USER1) == none, 3);

        // Check Onoal verified list
        assert!(kiosk_integration::is_in_onoal_verified_list(&registry, PLATFORM_ADMIN), 4);
        assert!(!kiosk_integration::is_in_onoal_verified_list(&registry, MERCHANT1), 5);
        assert!(kiosk_integration::is_in_onoal_verified_list(&registry, MERCHANT2), 6);

        // Check extended registry info
        let (
            platform_authority,
            platform_kiosk_id,
            master_kiosk_opt,
            master_kiosk_enabled,
            total_merchants,
            total_sales_volume,
            total_platform_fees,
            platform_fee_bps,
            merchant_fee_bps,
        ) = kiosk_integration::get_extended_registry_info(&registry);

        assert!(platform_authority == PLATFORM_ADMIN, 7);
        assert!(master_kiosk_enabled == true, 8);
        assert!(std::option::is_some(&master_kiosk_opt), 9);
        assert!(total_merchants == 3, 10); // Onoal + 2 merchants

        test_scenario::return_shared(registry);
    };

    test_scenario::end(scenario_val);
}
