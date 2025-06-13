#[allow(unused_const, duplicate_alias)]
module otl::collectible;

use otl::base;
use otl::utils;
use std::string::{Self, String};
use sui::display;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::package;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};

// ===== Core Structs =====

/// Collection manager that controls NFT creation and metadata
public struct Collection has key {
    id: UID,
    /// Creator/admin of the collection
    authority: address,
    /// Collection metadata
    name: String,
    symbol: String,
    description: String,
    /// Collection image/banner
    image_url: String,
    external_url: String,
    /// Supply tracking
    max_supply: u64,
    current_supply: u64,
    /// NFT registry for tracking individual NFTs
    nfts: Table<u64, ID>, // maps token_id to NFT object ID
    /// Authorized minters
    minters: VecMap<address, bool>,
    /// Collection-wide attributes
    collection_attributes: VecMap<String, String>,
}

/// Individual NFT/Collectible object
public struct Collectible has key, store {
    id: UID,
    /// Reference to the collection
    collection: ID,
    /// Unique token ID within the collection
    token_id: u64,
    /// NFT metadata
    name: String,
    description: String,
    image_url: String,
    external_url: String,
    /// Individual attributes (traits, rarity, etc.)
    attributes: VecMap<String, String>,
    /// Creator/original minter
    creator: address,
}

/// One-time witness for creating Display
public struct COLLECTIBLE has drop {}

// ===== Events =====

public struct CollectionCreated has copy, drop {
    collection_id: ID,
    authority: address,
    name: String,
    symbol: String,
    max_supply: u64,
}

public struct CollectibleMinted has copy, drop {
    collection_id: ID,
    nft_id: ID,
    token_id: u64,
    recipient: address,
    name: String,
}

public struct CollectibleTransferred has copy, drop {
    nft_id: ID,
    from: address,
    to: address,
}

public struct CollectibleBurned has copy, drop {
    collection_id: ID,
    nft_id: ID,
    token_id: u64,
    owner: address,
}

// ===== Collection Management =====

/// Create a new NFT collection with Display setup
public fun create_collection(
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    external_url: vector<u8>,
    max_supply: u64,
    ctx: &mut TxContext,
): Collection {
    // Validate collection parameters
    let (is_valid, error_code) = utils::validate_collection_params(
        &name,
        &symbol,
        &description,
        &image_url,
        max_supply,
    );
    assert!(is_valid, error_code);

    let authority = tx_context::sender(ctx);
    assert!(utils::validate_address(authority), base::not_authorized_error());

    let collection = Collection {
        id: object::new(ctx),
        authority,
        name: utils::safe_utf8(name),
        symbol: utils::safe_utf8(symbol),
        description: utils::safe_utf8(description),
        image_url: utils::safe_utf8(image_url),
        external_url: utils::safe_utf8(external_url),
        max_supply,
        current_supply: 0,
        nfts: table::new(ctx),
        minters: vec_map::empty(),
        collection_attributes: vec_map::empty(),
    };

    event::emit(CollectionCreated {
        collection_id: object::id(&collection),
        authority,
        name: collection.name,
        symbol: collection.symbol,
        max_supply,
    });

    collection
}

/// Create a collection and share it as a shared object
public entry fun create_shared_collection(
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    external_url: vector<u8>,
    max_supply: u64,
    ctx: &mut TxContext,
) {
    let collection = create_collection(
        name,
        symbol,
        description,
        image_url,
        external_url,
        max_supply,
        ctx,
    );
    transfer::share_object(collection);
}

/// Initialize Display for Collectible NFTs - call this once after publishing
public fun init_display(otw: COLLECTIBLE, ctx: &mut TxContext) {
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"external_url"),
        string::utf8(b"attributes"),
        string::utf8(b"collection"),
        string::utf8(b"creator"),
    ];

    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"{description}"),
        string::utf8(b"{image_url}"),
        string::utf8(b"{external_url}"),
        string::utf8(b"{attributes}"),
        string::utf8(b"Onoal Collectibles"),
        string::utf8(b"{creator}"),
    ];

    let publisher = package::claim(otw, ctx);
    let mut display = display::new_with_fields<Collectible>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display::update_version(&mut display);
    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
}

/// Add authorized minter to collection
public fun add_minter(collection: &mut Collection, minter: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == collection.authority, base::not_authorized_error());
    assert!(utils::validate_address(minter), base::not_authorized_error());
    assert!(!vec_map::contains(&collection.minters, &minter), base::minter_exists_error());

    vec_map::insert(&mut collection.minters, minter, true);
}

/// Remove authorized minter from collection
public fun remove_minter(collection: &mut Collection, minter: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == collection.authority, base::not_authorized_error());
    assert!(vec_map::contains(&collection.minters, &minter), base::minter_not_found_error());

    vec_map::remove(&mut collection.minters, &minter);
}

// ===== NFT Operations =====

/// Mint a new collectible NFT
public fun mint_collectible(
    collection: &mut Collection,
    name: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    external_url: vector<u8>,
    recipient: address,
    ctx: &mut TxContext,
): Collectible {
    let sender = tx_context::sender(ctx);
    assert!(
        sender == collection.authority || vec_map::contains(&collection.minters, &sender),
        base::not_authorized_error(),
    );
    assert!(utils::validate_address(recipient), base::not_authorized_error());
    assert!(collection.current_supply < collection.max_supply, base::supply_exceeded_error());

    // Validate NFT parameters
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());
    assert!(!vector::is_empty(&image_url), base::invalid_metadata_error());

    let token_id = collection.current_supply + 1;
    collection.current_supply = token_id;

    let nft = Collectible {
        id: object::new(ctx),
        collection: object::id(collection),
        token_id,
        name: utils::safe_utf8(name),
        description: utils::safe_utf8(description),
        image_url: utils::safe_utf8(image_url),
        external_url: utils::safe_utf8(external_url),
        attributes: vec_map::empty(),
        creator: sender,
    };

    // Register NFT in collection
    table::add(&mut collection.nfts, token_id, object::id(&nft));

    event::emit(CollectibleMinted {
        collection_id: object::id(collection),
        nft_id: object::id(&nft),
        token_id,
        recipient,
        name: nft.name,
    });

    nft
}

/// Mint collectible and transfer to recipient
public entry fun mint_collectible_to_recipient(
    collection: &mut Collection,
    name: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    external_url: vector<u8>,
    recipient: address,
    ctx: &mut TxContext,
) {
    let nft = mint_collectible(
        collection,
        name,
        description,
        image_url,
        external_url,
        recipient,
        ctx,
    );
    transfer::public_transfer(nft, recipient);
}

/// Transfer collectible to new owner
public entry fun transfer_collectible(nft: Collectible, recipient: address, ctx: &mut TxContext) {
    assert!(utils::validate_address(recipient), base::not_authorized_error());

    event::emit(CollectibleTransferred {
        nft_id: object::id(&nft),
        from: tx_context::sender(ctx),
        to: recipient,
    });

    transfer::public_transfer(nft, recipient);
}

/// Burn a collectible (only owner can burn)
public fun burn_collectible(collection: &mut Collection, nft: Collectible, ctx: &mut TxContext) {
    assert!(nft.collection == object::id(collection), base::token_not_found_error());

    let token_id = nft.token_id;
    let nft_id = object::id(&nft);

    // Remove from collection registry
    table::remove(&mut collection.nfts, token_id);

    event::emit(CollectibleBurned {
        collection_id: object::id(collection),
        nft_id,
        token_id,
        owner: tx_context::sender(ctx),
    });

    // Destroy the NFT
    let Collectible {
        id,
        collection: _,
        token_id: _,
        name: _,
        description: _,
        image_url: _,
        external_url: _,
        attributes: _,
        creator: _,
    } = nft;
    object::delete(id);
}

/// Burn collectible entry function
public entry fun burn_collectible_entry(
    collection: &mut Collection,
    nft: Collectible,
    ctx: &mut TxContext,
) {
    burn_collectible(collection, nft, ctx);
}

// ===== Attribute Management =====

/// Add attribute to collectible (only owner can modify)
public fun add_collectible_attribute(
    nft: &mut Collectible,
    key: vector<u8>,
    value: vector<u8>,
    ctx: &mut TxContext,
) {
    // In a real implementation, you might want to check ownership
    // For now, anyone can add attributes
    vec_map::insert(&mut nft.attributes, utils::safe_utf8(key), utils::safe_utf8(value));
}

/// Add attribute to collection (only authority can modify)
public fun add_collection_attribute(
    collection: &mut Collection,
    key: vector<u8>,
    value: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == collection.authority, base::not_authorized_error());
    vec_map::insert(
        &mut collection.collection_attributes,
        utils::safe_utf8(key),
        utils::safe_utf8(value),
    );
}

// ===== View Functions =====

/// Get collection info
public fun get_collection_info(collection: &Collection): (String, String, String, u64, u64) {
    (
        collection.name,
        collection.symbol,
        collection.description,
        collection.max_supply,
        collection.current_supply,
    )
}

/// Get collectible info
public fun get_collectible_info(nft: &Collectible): (ID, u64, String, String, String, address) {
    (nft.collection, nft.token_id, nft.name, nft.description, nft.image_url, nft.creator)
}

/// Get collectible attribute
public fun get_collectible_attribute(nft: &Collectible, key: &String): String {
    if (vec_map::contains(&nft.attributes, key)) {
        *vec_map::get(&nft.attributes, key)
    } else {
        string::utf8(b"")
    }
}

/// Get collection attribute
public fun get_collection_attribute(collection: &Collection, key: &String): String {
    if (vec_map::contains(&collection.collection_attributes, key)) {
        *vec_map::get(&collection.collection_attributes, key)
    } else {
        string::utf8(b"")
    }
}

/// Check if address is authorized minter
public fun is_authorized_minter(collection: &Collection, minter: address): bool {
    minter == collection.authority || vec_map::contains(&collection.minters, &minter)
}

/// Check if token exists in collection
public fun token_exists(collection: &Collection, token_id: u64): bool {
    table::contains(&collection.nfts, token_id)
}

/// Get total supply of collection
public fun get_total_supply(collection: &Collection): u64 {
    collection.current_supply
}

/// Get max supply of collection
public fun get_max_supply(collection: &Collection): u64 {
    collection.max_supply
}

/// Check if collection is sold out
public fun is_sold_out(collection: &Collection): bool {
    collection.current_supply >= collection.max_supply
}
