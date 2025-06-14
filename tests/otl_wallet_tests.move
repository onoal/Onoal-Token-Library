#[allow(duplicate_alias, unused_use, unused_const)]
#[test_only]
module otl::otl_wallet_tests;

use otl::otl_wallet::{Self, OTLWallet};
use std::string;
use sui::object;
use sui::test_scenario::{Self as test, next_tx};

// Test constants
const USER1: address = @0xA1;
const USER2: address = @0xA2;

#[test]
fun test_create_otl_wallet() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"My OTL Wallet",
            b"Personal wallet for all OTL assets",
            b"https://example.com/avatar.png",
            ctx,
        );
    };

    // Check wallet was created and transferred to user
    next_tx(&mut scenario, USER1);
    {
        let wallet = test::take_from_sender<OTLWallet>(&scenario);

        let (
            owner,
            name,
            description,
            avatar_url,
            is_active,
            privacy_level,
            total_transactions,
            total_value_transacted,
            created_at,
            last_activity,
        ) = otl_wallet::get_wallet_info(&wallet);

        assert!(owner == USER1, 0);
        assert!(name == string::utf8(b"My OTL Wallet"), 1);
        assert!(description == string::utf8(b"Personal wallet for all OTL assets"), 2);
        assert!(avatar_url == string::utf8(b"https://example.com/avatar.png"), 3);
        assert!(is_active == true, 4);
        assert!(privacy_level == 0, 5); // public by default
        assert!(total_transactions == 0, 6);
        assert!(total_value_transacted == 0, 7);
        assert!(created_at > 0, 8);
        assert!(last_activity == created_at, 9);

        // Check supported features
        let features = otl_wallet::get_supported_features(&wallet);
        assert!(vector::length(&features) == 6, 10);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"tokens")), 11);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"collectibles")), 12);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"tickets")), 13);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"loyalty")), 14);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"kiosks")), 15);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"permissions")), 16);

        // Check wallet version
        assert!(otl_wallet::get_wallet_version(&wallet) == 1, 17);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_update_wallet_metadata() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Original Name",
            b"Original Description",
            b"https://original.com/avatar.png",
            ctx,
        );
    };

    // Update wallet metadata - partial update
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        otl_wallet::update_wallet_metadata(
            &mut wallet,
            std::option::some(b"Updated Name"),
            std::option::none(), // don't update description
            std::option::some(b"https://updated.com/avatar.png"),
            ctx,
        );

        let (_, name, description, avatar_url, _, _, _, _, _, _) = otl_wallet::get_wallet_info(
            &wallet,
        );

        assert!(name == string::utf8(b"Updated Name"), 0);
        assert!(description == string::utf8(b"Original Description"), 1); // unchanged
        assert!(avatar_url == string::utf8(b"https://updated.com/avatar.png"), 2);

        test::return_to_sender(&scenario, wallet);
    };

    // Update wallet metadata - full update
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        otl_wallet::update_wallet_metadata(
            &mut wallet,
            std::option::some(b"Final Name"),
            std::option::some(b"Final Description"),
            std::option::some(b"https://final.com/avatar.png"),
            ctx,
        );

        let (_, name, description, avatar_url, _, _, _, _, _, _) = otl_wallet::get_wallet_info(
            &wallet,
        );

        assert!(name == string::utf8(b"Final Name"), 0);
        assert!(description == string::utf8(b"Final Description"), 1);
        assert!(avatar_url == string::utf8(b"https://final.com/avatar.png"), 2);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_update_wallet_settings() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Test Wallet",
            b"Test Description",
            b"https://test.com/avatar.png",
            ctx,
        );
    };

    // Update wallet settings - partial update
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Update only auto_accept_assets
        otl_wallet::update_wallet_settings(
            &mut wallet,
            std::option::some(false), // auto_accept_assets
            std::option::none(), // don't change privacy_level
            ctx,
        );

        let (_, _, _, _, _, privacy_level, _, _, _, _) = otl_wallet::get_wallet_info(&wallet);
        assert!(privacy_level == 0, 0); // should remain unchanged

        test::return_to_sender(&scenario, wallet);
    };

    // Update wallet settings - full update
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        otl_wallet::update_wallet_settings(
            &mut wallet,
            std::option::some(true), // auto_accept_assets back to true
            std::option::some(2), // privacy_level = private
            ctx,
        );

        let (_, _, _, _, _, privacy_level, _, _, _, _) = otl_wallet::get_wallet_info(&wallet);
        assert!(privacy_level == 2, 0);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_add_token_wallet() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Token Test Wallet",
            b"Wallet for testing token integration",
            b"https://test.com/avatar.png",
            ctx,
        );
    };

    // Add token wallet
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Create mock IDs
        let token_type_id = object::id_from_address(@0x123);
        let token_wallet_id = object::id_from_address(@0x456);

        otl_wallet::add_token_wallet(
            &mut wallet,
            token_type_id,
            token_wallet_id,
            ctx,
        );

        // Check asset summary
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            token_types,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            _,
            _,
        ) = otl_wallet::get_asset_summary_details(&summary);

        assert!(token_types == 1, 0);
        assert!(collectibles == 0, 1);
        assert!(tickets == 0, 2);
        assert!(loyalty_cards == 0, 3);

        // Check transaction count increased
        let (_, _, _, _, _, _, total_transactions, _, _, _) = otl_wallet::get_wallet_info(&wallet);
        assert!(total_transactions == 1, 4);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_add_collectible() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Collectible Test Wallet",
            b"Wallet for testing collectible integration",
            b"https://test.com/avatar.png",
            ctx,
        );
    };

    // Add collectible
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let collectible_id = object::id_from_address(@0x789);

        otl_wallet::add_collectible(&mut wallet, collectible_id, ctx);

        // Check asset summary
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            token_types,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            _,
            _,
        ) = otl_wallet::get_asset_summary_details(&summary);

        assert!(token_types == 0, 0);
        assert!(collectibles == 1, 1);
        assert!(tickets == 0, 2);
        assert!(loyalty_cards == 0, 3);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_add_ticket() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Ticket Test Wallet",
            b"Wallet for testing ticket integration",
            b"https://test.com/avatar.png",
            ctx,
        );
    };

    // Add ticket
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let ticket_id = object::id_from_address(@0xABC);

        otl_wallet::add_ticket(&mut wallet, ticket_id, ctx);

        // Check asset summary
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            token_types,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            _,
            _,
        ) = otl_wallet::get_asset_summary_details(&summary);

        assert!(token_types == 0, 0);
        assert!(collectibles == 0, 1);
        assert!(tickets == 1, 2);
        assert!(loyalty_cards == 0, 3);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_add_loyalty_card() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Loyalty Test Wallet",
            b"Wallet for testing loyalty integration",
            b"https://test.com/avatar.png",
            ctx,
        );
    };

    // Add loyalty card
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let loyalty_card_id = object::id_from_address(@0xDEF);

        otl_wallet::add_loyalty_card(&mut wallet, loyalty_card_id, ctx);

        // Check asset summary
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            token_types,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            _,
            _,
        ) = otl_wallet::get_asset_summary_details(&summary);

        assert!(token_types == 0, 0);
        assert!(collectibles == 0, 1);
        assert!(tickets == 0, 2);
        assert!(loyalty_cards == 1, 3);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_remove_asset() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet and add assets
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Remove Test Wallet",
            b"Wallet for testing asset removal",
            b"https://test.com/avatar.png",
            ctx,
        );
    };

    // Add multiple assets
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let collectible_id = object::id_from_address(@0x111);
        let ticket_id = object::id_from_address(@0x222);
        let loyalty_card_id = object::id_from_address(@0x333);

        otl_wallet::add_collectible(&mut wallet, collectible_id, ctx);
        otl_wallet::add_ticket(&mut wallet, ticket_id, ctx);
        otl_wallet::add_loyalty_card(&mut wallet, loyalty_card_id, ctx);

        // Verify all assets added
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            _,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            _,
            _,
        ) = otl_wallet::get_asset_summary_details(&summary);
        assert!(collectibles == 1, 0);
        assert!(tickets == 1, 1);
        assert!(loyalty_cards == 1, 2);

        test::return_to_sender(&scenario, wallet);
    };

    // Remove collectible
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let collectible_id = object::id_from_address(@0x111);

        otl_wallet::remove_asset(&mut wallet, b"collectible", collectible_id, ctx);

        // Verify collectible removed
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            _,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            _,
            _,
        ) = otl_wallet::get_asset_summary_details(&summary);
        assert!(collectibles == 0, 0);
        assert!(tickets == 1, 1);
        assert!(loyalty_cards == 1, 2);

        test::return_to_sender(&scenario, wallet);
    };

    // Remove ticket
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let ticket_id = object::id_from_address(@0x222);

        otl_wallet::remove_asset(&mut wallet, b"ticket", ticket_id, ctx);

        // Verify ticket removed
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            _,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            _,
            _,
        ) = otl_wallet::get_asset_summary_details(&summary);
        assert!(collectibles == 0, 0);
        assert!(tickets == 0, 1);
        assert!(loyalty_cards == 1, 2);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_permission_registry_integration() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Permission Test Wallet",
            b"Wallet for testing permission integration",
            b"https://test.com/permission-avatar.png",
            ctx,
        );
    };

    // Join permission registry
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let registry_id = object::id_from_address(@0x555);

        otl_wallet::join_permission_registry(
            &mut wallet,
            registry_id,
            b"token_type",
            ctx,
        );

        // Update permission info
        let roles = vector[string::utf8(b"minter"), string::utf8(b"admin")];
        let permissions = vector[string::utf8(b"mint"), string::utf8(b"burn")];

        otl_wallet::update_permission_registry_info(
            &mut wallet,
            registry_id,
            roles,
            permissions,
            true, // is_issuer
            false, // is_frozen
            ctx,
        );

        // Check role and issuer status
        assert!(otl_wallet::has_role_in_registry(&wallet, registry_id, string::utf8(b"minter")), 0);
        assert!(otl_wallet::has_role_in_registry(&wallet, registry_id, string::utf8(b"admin")), 1);
        assert!(otl_wallet::is_issuer_in_registry(&wallet, registry_id), 2);
        assert!(
            !otl_wallet::has_role_in_registry(&wallet, registry_id, string::utf8(b"viewer")),
            3,
        );

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_kiosk_integration() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Kiosk Test Wallet",
            b"Wallet for testing kiosk integration",
            b"https://test.com/kiosk-avatar.png",
            ctx,
        );
    };

    // Add merchant kiosk and platform listing
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        let kiosk_id = object::id_from_address(@0x666);
        let listing_id = object::id_from_address(@0x777);

        otl_wallet::add_merchant_kiosk(&mut wallet, kiosk_id, ctx);
        otl_wallet::add_platform_listing(&mut wallet, listing_id, ctx);

        // Check asset summary
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            _,
            _,
            _,
            _,
            _,
            merchant_kiosks,
            platform_listings,
        ) = otl_wallet::get_asset_summary_details(&summary);

        assert!(merchant_kiosks == 1, 0);
        assert!(platform_listings == 1, 1);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
fun test_comprehensive_wallet_functionality() {
    let mut scenario = test::begin(USER1);

    // Create comprehensive OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Comprehensive Wallet",
            b"Full-featured wallet with all asset types",
            b"https://test.com/comprehensive-avatar.png",
            ctx,
        );
    };

    // Add all types of assets and integrations
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Add various assets
        let token_type_id = object::id_from_address(@0x123);
        let token_wallet_id = object::id_from_address(@0x456);
        let collectible_id = object::id_from_address(@0x789);
        let ticket_id = object::id_from_address(@0xABC);
        let loyalty_card_id = object::id_from_address(@0xDEF);
        let kiosk_id = object::id_from_address(@0x111);
        let listing_id = object::id_from_address(@0x222);
        let registry_id = object::id_from_address(@0x333);

        // Add all assets
        otl_wallet::add_token_wallet(&mut wallet, token_type_id, token_wallet_id, ctx);
        otl_wallet::add_collectible(&mut wallet, collectible_id, ctx);
        otl_wallet::add_ticket(&mut wallet, ticket_id, ctx);
        otl_wallet::add_loyalty_card(&mut wallet, loyalty_card_id, ctx);
        otl_wallet::add_merchant_kiosk(&mut wallet, kiosk_id, ctx);
        otl_wallet::add_platform_listing(&mut wallet, listing_id, ctx);

        // Join permission registry
        otl_wallet::join_permission_registry(&mut wallet, registry_id, b"comprehensive", ctx);

        // Update settings
        otl_wallet::update_wallet_settings(
            &mut wallet,
            std::option::some(false), // auto_accept_assets
            std::option::some(1), // privacy_level = friends
            ctx,
        );

        // Verify comprehensive asset summary
        let summary = otl_wallet::get_asset_summary(&wallet);
        let (
            token_types,
            _,
            collectibles,
            tickets,
            loyalty_cards,
            merchant_kiosks,
            platform_listings,
        ) = otl_wallet::get_asset_summary_details(&summary);

        assert!(token_types == 1, 0);
        assert!(collectibles == 1, 1);
        assert!(tickets == 1, 2);
        assert!(loyalty_cards == 1, 3);
        assert!(merchant_kiosks == 1, 4);
        assert!(platform_listings == 1, 5);

        // Check wallet info shows increased activity
        let (
            _,
            _,
            _,
            _,
            _,
            privacy_level,
            total_transactions,
            _,
            _,
            _,
        ) = otl_wallet::get_wallet_info(&wallet);

        assert!(privacy_level == 1, 6); // friends level
        // Fix: 4 transactions = only asset additions increment transaction count
        // add_token_wallet, add_collectible, add_ticket, add_loyalty_card = 4 transactions
        assert!(total_transactions == 4, 7);

        // Check all features are supported
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"tokens")), 8);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"collectibles")), 9);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"tickets")), 10);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"loyalty")), 11);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"kiosks")), 12);
        assert!(otl_wallet::is_feature_supported(&wallet, string::utf8(b"permissions")), 13);

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 2)]
fun test_unauthorized_wallet_access() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet as USER1
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"User1 Wallet",
            b"This wallet belongs to USER1",
            b"https://user1.com/avatar.png",
            ctx,
        );
    };

    // Try to modify wallet as USER2 (should fail)
    next_tx(&mut scenario, USER2);
    {
        // This should fail because USER2 doesn't have the wallet
        // The test framework will abort when trying to take from USER2's inventory
        // We need to take from USER1 but use USER2's context
        let mut wallet = test::take_from_address<OTLWallet>(&scenario, USER1);
        let ctx = test::ctx(&mut scenario);

        // This should abort with not_authorized_error
        otl_wallet::update_wallet_metadata(
            &mut wallet,
            std::option::some(b"Hacked Name"),
            std::option::none(),
            std::option::none(),
            ctx,
        );

        test::return_to_address(USER1, wallet);
    };

    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 4)]
fun test_empty_wallet_name() {
    let mut scenario = test::begin(USER1);

    // Try to create wallet with empty name (should fail)
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"", // empty name should cause failure
            b"Valid description",
            b"https://valid.com/avatar.png",
            ctx,
        );
    };

    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1)]
fun test_invalid_privacy_level() {
    let mut scenario = test::begin(USER1);

    // Create OTL wallet
    {
        let ctx = test::ctx(&mut scenario);
        otl_wallet::create_otl_wallet_entry(
            b"Test Wallet",
            b"Test Description",
            b"https://test.com/avatar.png",
            ctx,
        );
    };

    // Try to set invalid privacy level (should fail)
    next_tx(&mut scenario, USER1);
    {
        let mut wallet = test::take_from_sender<OTLWallet>(&scenario);
        let ctx = test::ctx(&mut scenario);

        // Privacy level > 2 should cause failure
        otl_wallet::update_wallet_settings(
            &mut wallet,
            std::option::none(),
            std::option::some(5), // invalid privacy level
            ctx,
        );

        test::return_to_sender(&scenario, wallet);
    };

    test::end(scenario);
}
