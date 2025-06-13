#[test_only, allow(unused_use, duplicate_alias)]
module otl::collectible_tests;

use otl::collectible::{Self, Collection, Collectible, COLLECTIBLE};
use sui::test_scenario::{Self, Scenario};
use sui::transfer;

const ADMIN: address = @0x100;
const USER1: address = @0x200;
const USER2: address = @0x300;

#[test]
fun test_create_collection() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        collectible::create_shared_collection(
            b"Onoal NFT Collection",
            b"ONC",
            b"A collection of unique Onoal NFTs",
            b"https://onoal.com/collection.png",
            b"https://onoal.com/collection",
            1000, // max supply
            ctx,
        );
    };

    test_scenario::next_tx(scenario, USER1);
    {
        let collection = test_scenario::take_shared<Collection>(scenario);
        let (
            name,
            symbol,
            _description,
            max_supply,
            current_supply,
        ) = collectible::get_collection_info(&collection);

        assert!(name == std::string::utf8(b"Onoal NFT Collection"), 0);
        assert!(symbol == std::string::utf8(b"ONC"), 1);
        assert!(max_supply == 1000, 2);
        assert!(current_supply == 0, 3);

        test_scenario::return_shared(collection);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_mint_collectible() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create collection
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        collectible::create_shared_collection(
            b"Test NFTs",
            b"TNT",
            b"Test collection",
            b"https://test.com/collection.png",
            b"https://test.com",
            100,
            ctx,
        );
    };

    // Mint NFT to USER1
    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(scenario);
        let ctx = test_scenario::ctx(scenario);

        collectible::mint_collectible_to_recipient(
            &mut collection,
            b"Cool NFT #1",
            b"A very cool NFT",
            b"https://test.com/nft1.png",
            b"https://test.com/nft1",
            USER1,
            ctx,
        );

        let (_, _, _, _, current_supply) = collectible::get_collection_info(&collection);
        assert!(current_supply == 1, 0);

        test_scenario::return_shared(collection);
    };

    // Check USER1 received the NFT
    test_scenario::next_tx(scenario, USER1);
    {
        let nft = test_scenario::take_from_sender<Collectible>(scenario);

        let (
            collection_id,
            token_id,
            name,
            description,
            image_url,
            creator,
        ) = collectible::get_collectible_info(&nft);

        assert!(token_id == 1, 1);
        assert!(name == std::string::utf8(b"Cool NFT #1"), 2);
        assert!(description == std::string::utf8(b"A very cool NFT"), 3);
        assert!(creator == ADMIN, 4);

        test_scenario::return_to_sender(scenario, nft);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_transfer_collectible() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create and mint
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        collectible::create_shared_collection(
            b"Transfer Test",
            b"TT",
            b"For transfer testing",
            b"https://test.com/collection.png",
            b"https://test.com",
            10,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(scenario);
        let ctx = test_scenario::ctx(scenario);
        collectible::mint_collectible_to_recipient(
            &mut collection,
            b"Transfer NFT",
            b"NFT for transfer test",
            b"https://test.com/transfer.png",
            b"https://test.com/transfer",
            USER1,
            ctx,
        );
        test_scenario::return_shared(collection);
    };

    // Transfer from USER1 to USER2
    test_scenario::next_tx(scenario, USER1);
    {
        let nft = test_scenario::take_from_sender<Collectible>(scenario);
        let ctx = test_scenario::ctx(scenario);

        collectible::transfer_collectible(nft, USER2, ctx);
    };

    // Check USER2 received the NFT
    test_scenario::next_tx(scenario, USER2);
    {
        let nft_ids = test_scenario::ids_for_sender<Collectible>(scenario);
        assert!(vector::length(&nft_ids) == 1, 0);

        let nft = test_scenario::take_from_sender<Collectible>(scenario);
        let (_, token_id, name, _, _, _) = collectible::get_collectible_info(&nft);

        assert!(token_id == 1, 1);
        assert!(name == std::string::utf8(b"Transfer NFT"), 2);

        test_scenario::return_to_sender(scenario, nft);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_add_collectible_attributes() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create and mint
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        collectible::create_shared_collection(
            b"Attribute Test",
            b"AT",
            b"For attribute testing",
            b"https://test.com/collection.png",
            b"https://test.com",
            10,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(scenario);
        let ctx = test_scenario::ctx(scenario);
        collectible::mint_collectible_to_recipient(
            &mut collection,
            b"Attribute NFT",
            b"NFT with attributes",
            b"https://test.com/attr.png",
            b"https://test.com/attr",
            USER1,
            ctx,
        );
        test_scenario::return_shared(collection);
    };

    // Add attributes to NFT
    test_scenario::next_tx(scenario, USER1);
    {
        let mut nft = test_scenario::take_from_sender<Collectible>(scenario);
        let ctx = test_scenario::ctx(scenario);

        collectible::add_collectible_attribute(
            &mut nft,
            b"rarity",
            b"legendary",
            ctx,
        );

        collectible::add_collectible_attribute(
            &mut nft,
            b"power",
            b"100",
            ctx,
        );

        // Check attributes
        let rarity = collectible::get_collectible_attribute(&nft, &std::string::utf8(b"rarity"));
        let power = collectible::get_collectible_attribute(&nft, &std::string::utf8(b"power"));

        assert!(rarity == std::string::utf8(b"legendary"), 0);
        assert!(power == std::string::utf8(b"100"), 1);

        test_scenario::return_to_sender(scenario, nft);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_burn_collectible() {
    let mut scenario_val = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_val;

    // Create and mint
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        collectible::create_shared_collection(
            b"Burn Test",
            b"BT",
            b"For burn testing",
            b"https://test.com/collection.png",
            b"https://test.com",
            10,
            ctx,
        );
    };

    test_scenario::next_tx(scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(scenario);
        let ctx = test_scenario::ctx(scenario);
        collectible::mint_collectible_to_recipient(
            &mut collection,
            b"Burn NFT",
            b"NFT to be burned",
            b"https://test.com/burn.png",
            b"https://test.com/burn",
            USER1,
            ctx,
        );
        test_scenario::return_shared(collection);
    };

    // Burn the NFT
    test_scenario::next_tx(scenario, USER1);
    {
        let mut collection = test_scenario::take_shared<Collection>(scenario);
        let nft = test_scenario::take_from_sender<Collectible>(scenario);
        let ctx = test_scenario::ctx(scenario);

        let token_id = {
            let (_, id, _, _, _, _) = collectible::get_collectible_info(&nft);
            id
        };

        // Verify token exists before burn
        assert!(collectible::token_exists(&collection, token_id), 0);

        collectible::burn_collectible(&mut collection, nft, ctx);

        // Verify token no longer exists after burn
        assert!(!collectible::token_exists(&collection, token_id), 1);

        test_scenario::return_shared(collection);
    };

    // Verify USER1 no longer has any NFTs
    test_scenario::next_tx(scenario, USER1);
    {
        let nft_ids = test_scenario::ids_for_sender<Collectible>(scenario);
        assert!(vector::length(&nft_ids) == 0, 2);
    };

    test_scenario::end(scenario_val);
}
