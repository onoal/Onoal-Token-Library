#[allow(unused_variable)]
#[test_only]
module otl::collectible_tests;

use otl::collectible::{Self, Collection, Collectible};
use sui::test_scenario;
use sui::test_utils;

const ADMIN: address = @0xAD;
const USER: address = @0xB0B;

#[test]
fun test_create_collection() {
    let mut scenario = test_scenario::begin(ADMIN);
    {
        collectible::create_shared_collection(
            b"Onoal NFT Collection",
            b"ONC",
            b"A collection of unique Onoal NFTs",
            b"https://onoal.com/collection.png",
            1000, // max supply
            b"Onoal NFT #", // base_name_prefix
            b"A unique Onoal NFT", // base_description
            b"https://onoal.com/nft/", // base_image_url
            b"https://onoal.com/nft/", // base_external_url
            true, // auto_increment_names
            true, // use_token_id_in_url
            true, // is_transferable
            true, // is_burnable
            false, // mutable_metadata
            test_scenario::ctx(&mut scenario),
        );
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let collection = test_scenario::take_shared<Collection>(&scenario);

        // Verify collection properties
        let (name, symbol, max_supply, current_supply) = collectible::get_collection_info(
            &collection,
        );
        assert!(name == std::string::utf8(b"Onoal NFT Collection"), 0);
        assert!(symbol == std::string::utf8(b"ONC"), 1);
        assert!(max_supply == 1000, 2);
        assert!(current_supply == 0, 3);

        test_scenario::return_shared(collection);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_mint_collectible() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create collection
    {
        collectible::create_shared_collection(
            b"Test NFTs",
            b"TNT",
            b"Test collection",
            b"https://test.com/collection.png",
            100,
            b"Test NFT #", // base_name_prefix
            b"A test NFT", // base_description
            b"https://test.com/nft/", // base_image_url
            b"https://test.com/nft/", // base_external_url
            true, // auto_increment_names
            true, // use_token_id_in_url
            true, // is_transferable
            true, // is_burnable
            false, // mutable_metadata
            test_scenario::ctx(&mut scenario),
        );
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(&scenario);

        // Mint NFT using batch_mint_to_recipient
        collectible::batch_mint_to_recipient(
            &mut collection,
            USER,
            1, // amount
            b"test_batch_1", // batch_id
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(collection);
    };

    test_scenario::next_tx(&mut scenario, USER);
    {
        let collection = test_scenario::take_shared<Collection>(&scenario);
        let nft = test_scenario::take_from_sender<Collectible>(&scenario);

        // Verify NFT properties
        let (token_id, name, collection_id) = collectible::get_collectible_info(&nft);
        assert!(token_id == 1, 0);
        assert!(collection_id == sui::object::id(&collection), 1);

        test_scenario::return_from_sender(nft);
        test_scenario::return_shared(collection);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_transfer_collectible() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create collection and mint NFT
    {
        collectible::create_shared_collection(
            b"Transfer Test",
            b"TT",
            b"For transfer testing",
            b"https://test.com/collection.png",
            10,
            b"Transfer NFT #", // base_name_prefix
            b"A transfer test NFT", // base_description
            b"https://test.com/nft/", // base_image_url
            b"https://test.com/nft/", // base_external_url
            true, // auto_increment_names
            true, // use_token_id_in_url
            true, // is_transferable
            true, // is_burnable
            false, // mutable_metadata
            test_scenario::ctx(&mut scenario),
        );
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(&scenario);

        collectible::batch_mint_to_recipient(
            &mut collection,
            ADMIN,
            1, // amount
            b"transfer_test", // batch_id
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(collection);
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let nft = test_scenario::take_from_sender<Collectible>(&scenario);

        // Transfer NFT to USER
        sui::transfer::public_transfer(nft, USER);
    };

    test_scenario::next_tx(&mut scenario, USER);
    {
        // Verify USER received the NFT
        let nft = test_scenario::take_from_sender<Collectible>(&scenario);
        let (token_id, _, _) = collectible::get_collectible_info(&nft);
        assert!(token_id == 1, 0);

        test_scenario::return_from_sender(nft);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_add_attributes() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create collection and mint NFT
    {
        collectible::create_shared_collection(
            b"Attribute Test",
            b"AT",
            b"For attribute testing",
            b"https://test.com/collection.png",
            10,
            b"Attribute NFT #", // base_name_prefix
            b"An attribute test NFT", // base_description
            b"https://test.com/nft/", // base_image_url
            b"https://test.com/nft/", // base_external_url
            true, // auto_increment_names
            true, // use_token_id_in_url
            true, // is_transferable
            true, // is_burnable
            true, // mutable_metadata (allow attribute changes)
            test_scenario::ctx(&mut scenario),
        );
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(&scenario);

        collectible::batch_mint_to_recipient(
            &mut collection,
            ADMIN,
            1, // amount
            b"attribute_test", // batch_id
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(collection);
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut nft = test_scenario::take_from_sender<Collectible>(&scenario);

        // Add attributes
        collectible::add_attribute(
            &mut nft,
            std::string::utf8(b"rarity"),
            std::string::utf8(b"legendary"),
        );
        collectible::add_attribute(
            &mut nft,
            std::string::utf8(b"power"),
            std::string::utf8(b"100"),
        );

        // Verify attributes
        let rarity = collectible::get_attribute(&nft, &std::string::utf8(b"rarity"));
        assert!(std::option::is_some(&rarity), 0);
        assert!(*std::option::borrow(&rarity) == std::string::utf8(b"legendary"), 1);

        test_scenario::return_from_sender(nft);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_burn_collectible() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Create collection and mint NFT
    {
        collectible::create_shared_collection(
            b"Burn Test",
            b"BT",
            b"For burn testing",
            b"https://test.com/collection.png",
            10,
            b"Burn NFT #", // base_name_prefix
            b"A burn test NFT", // base_description
            b"https://test.com/nft/", // base_image_url
            b"https://test.com/nft/", // base_external_url
            true, // auto_increment_names
            true, // use_token_id_in_url
            true, // is_transferable
            true, // is_burnable
            false, // mutable_metadata
            test_scenario::ctx(&mut scenario),
        );
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut collection = test_scenario::take_shared<Collection>(&scenario);

        collectible::batch_mint_to_recipient(
            &mut collection,
            ADMIN,
            1, // amount
            b"burn_test", // batch_id
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(collection);
    };

    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let collection = test_scenario::take_shared<Collection>(&scenario);
        let nft = test_scenario::take_from_sender<Collectible>(&scenario);

        let (token_id, _, _) = collectible::get_collectible_info(&nft);

        // Burn the NFT (correct signature: just nft and ctx)
        collectible::burn_collectible(nft, test_scenario::ctx(&mut scenario));

        test_scenario::return_shared(collection);
    };

    test_scenario::end(scenario);
}
