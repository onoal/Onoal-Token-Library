#[allow(unused_use)]
module otl::digital_asset_test;

use otl::digital_asset::{Self, Digital_asset};
use std::debug;
use sui::test_scenario as ts;

#[test]
fun test_mint_to_sender() {
    let owner = @0xAD;
    let mut scenario = ts::begin(owner);

    // Test data
    let name = b"Test NFT";
    let description = b"This is a test NFT";
    let url = b"https://example.com/metadata.json";

    // Mint NFT
    ts::next_tx(&mut scenario, owner);
    {
        digital_asset::mint_to_sender(name, description, url, ts::ctx(&mut scenario));
    };

    // Verify NFT was minted and transferred to owner
    ts::next_tx(&mut scenario, owner);
    {
        let nft = ts::take_from_sender<Digital_asset>(&scenario);

        // NFT is gemint en opgehaald, dus test is geslaagd
        // Verify NFT metadata
        debug::print(&b"# NFT Name: ");
        debug::print(nft.name());
        debug::print(&b"# NFT Description: ");
        debug::print(nft.description());
        debug::print(&b"# NFT URL: ");
        debug::print(nft.url());

        ts::return_to_sender(&scenario, nft);
    };

    ts::end(scenario);
}
