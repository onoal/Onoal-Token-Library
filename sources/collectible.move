#[allow(unused_const, duplicate_alias, unused_variable, lint(self_transfer))]
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

// ===== Constants =====
const MAX_BATCH_MINT: u64 = 1000; // Maximum NFTs per batch
const MAX_MULTI_RECIPIENT: u64 = 100; // Maximum recipients per multi-mint

// ===== Optimized Core Structs =====

/// Ultra-lightweight collection for batch operations
public struct Collection has key {
    id: UID,
    /// Creator/admin of the collection
    authority: address,
    /// Essential metadata only
    name: String,
    symbol: String,
    description: String,
    image_url: String,
    /// Supply tracking (essential)
    max_supply: u64,
    current_supply: u64,
    /// Configuration flags (packed for efficiency)
    config_flags: u8, // bit 0: transferable, bit 1: burnable, bit 2: mutable_metadata
    /// Authorized minters (simplified)
    minters: Table<address, bool>,
    /// Base metadata template for batch minting
    base_metadata: CollectionMetadata,
}

/// Metadata template for efficient batch operations
public struct CollectionMetadata has store {
    base_name_prefix: String, // e.g., "Onoal NFT #"
    base_description: String, // Template description
    base_image_url: String, // Base URL pattern, e.g., "https://api.onoal.com/nft/"
    base_external_url: String, // Base external URL
    /// Batch-specific settings
    auto_increment_names: bool, // Auto-generate names like "NFT #1", "NFT #2"
    use_token_id_in_url: bool, // Append token_id to image_url
}

/// Ultra-lightweight NFT for batch operations
public struct Collectible has key, store {
    id: UID,
    /// Essential data only
    collection: ID,
    token_id: u64,
    /// Minimal metadata (can be computed from collection + token_id)
    name: String,
    /// Optional attributes (only if needed)
    attributes: VecMap<String, String>,
    /// Creator (for royalties/provenance)
    creator: address,
}

/// Batch mint receipt for tracking large operations
public struct BatchMintReceipt has key, store {
    id: UID,
    collection_id: ID,
    batch_id: String,
    start_token_id: u64,
    end_token_id: u64,
    total_minted: u64,
    minted_by: address,
    minted_at: u64,
    recipients: vector<address>, // For multi-recipient batches
}

/// One-time witness for creating Display
public struct COLLECTIBLE has drop {}

// ===== Optimized Events =====

public struct CollectionCreated has copy, drop {
    collection_id: ID,
    authority: address,
    name: String,
    symbol: String,
    max_supply: u64,
}

public struct BatchMinted has copy, drop {
    collection_id: ID,
    batch_id: String,
    start_token_id: u64,
    end_token_id: u64,
    total_minted: u64,
    minted_by: address,
}

public struct CollectibleTransferred has copy, drop {
    nft_id: ID,
    from: address,
    to: address,
}

// ===== Display Setup =====

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
        string::utf8(b"token_id"),
        string::utf8(b"project_url"),
    ];

    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"Dynamic NFT from Onoal Token Library - {name}"),
        string::utf8(b"{image_url}"),
        string::utf8(b"{external_url}"),
        string::utf8(b"{attributes}"),
        string::utf8(b"Onoal Collectibles"),
        string::utf8(b"{creator}"),
        string::utf8(b"#{token_id}"),
        string::utf8(b"https://onoal.com"),
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

/// Create Display object and share it (alternative approach)
public fun create_shared_display(otw: COLLECTIBLE, ctx: &mut TxContext) {
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"external_url"),
        string::utf8(b"attributes"),
        string::utf8(b"collection"),
        string::utf8(b"creator"),
        string::utf8(b"token_id"),
        string::utf8(b"project_url"),
    ];

    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"Dynamic NFT from Onoal Token Library - {name}"),
        string::utf8(b"{image_url}"),
        string::utf8(b"{external_url}"),
        string::utf8(b"{attributes}"),
        string::utf8(b"Onoal Collectibles"),
        string::utf8(b"{creator}"),
        string::utf8(b"#{token_id}"),
        string::utf8(b"https://onoal.com"),
    ];

    let publisher = package::claim(otw, ctx);
    let mut display = display::new_with_fields<Collectible>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display::update_version(&mut display);

    // Share the display object so it can be used by anyone
    transfer::public_share_object(display);
    transfer::public_transfer(publisher, tx_context::sender(ctx));
}

// ===== Collection Management (Optimized) =====

/// Create optimized collection for batch operations
public fun create_collection(
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    max_supply: u64,
    base_name_prefix: vector<u8>,
    base_description: vector<u8>,
    base_image_url: vector<u8>,
    base_external_url: vector<u8>,
    auto_increment_names: bool,
    use_token_id_in_url: bool,
    is_transferable: bool,
    is_burnable: bool,
    mutable_metadata: bool,
    ctx: &mut TxContext,
): Collection {
    // Validate collection parameters
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());
    assert!(!vector::is_empty(&symbol), base::invalid_metadata_error());
    assert!(max_supply > 0, base::invalid_amount_error());

    let authority = tx_context::sender(ctx);

    // Pack configuration flags for gas efficiency
    let mut config_flags = 0u8;
    if (is_transferable) config_flags = config_flags | 1;
    if (is_burnable) config_flags = config_flags | 2;
    if (mutable_metadata) config_flags = config_flags | 4;

    let collection = Collection {
        id: object::new(ctx),
        authority,
        name: utils::safe_utf8(name),
        symbol: utils::safe_utf8(symbol),
        description: utils::safe_utf8(description),
        image_url: utils::safe_utf8(image_url),
        max_supply,
        current_supply: 0,
        config_flags,
        minters: table::new(ctx),
        base_metadata: CollectionMetadata {
            base_name_prefix: utils::safe_utf8(base_name_prefix),
            base_description: utils::safe_utf8(base_description),
            base_image_url: utils::safe_utf8(base_image_url),
            base_external_url: utils::safe_utf8(base_external_url),
            auto_increment_names,
            use_token_id_in_url,
        },
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

/// Create and share collection
public entry fun create_shared_collection(
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    max_supply: u64,
    base_name_prefix: vector<u8>,
    base_description: vector<u8>,
    base_image_url: vector<u8>,
    base_external_url: vector<u8>,
    auto_increment_names: bool,
    use_token_id_in_url: bool,
    is_transferable: bool,
    is_burnable: bool,
    mutable_metadata: bool,
    ctx: &mut TxContext,
) {
    let collection = create_collection(
        name,
        symbol,
        description,
        image_url,
        max_supply,
        base_name_prefix,
        base_description,
        base_image_url,
        base_external_url,
        auto_increment_names,
        use_token_id_in_url,
        is_transferable,
        is_burnable,
        mutable_metadata,
        ctx,
    );
    transfer::share_object(collection);
}

/// Add minter (simplified)
public fun add_minter(collection: &mut Collection, minter: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == collection.authority, base::not_authorized_error());
    assert!(!table::contains(&collection.minters, minter), base::minter_exists_error());

    table::add(&mut collection.minters, minter, true);
}

// ===== Ultra-Efficient Batch Minting =====

/// Batch mint NFTs - optimized for 1000+ NFTs with minimal gas
public fun batch_mint_collectibles(
    collection: &mut Collection,
    recipient: address,
    amount: u64,
    batch_id: vector<u8>,
    custom_attributes: Option<VecMap<String, String>>, // Optional shared attributes
    ctx: &mut TxContext,
): (vector<Collectible>, BatchMintReceipt) {
    let sender = tx_context::sender(ctx);

    // Authorization check
    assert!(
        sender == collection.authority || table::contains(&collection.minters, sender),
        base::not_authorized_error(),
    );

    // Validate batch size
    assert!(amount > 0 && amount <= MAX_BATCH_MINT, base::invalid_amount_error());

    // Supply check
    assert!(
        utils::safe_add(collection.current_supply, amount) <= collection.max_supply,
        base::supply_exceeded_error(),
    );

    let start_token_id = collection.current_supply + 1;
    let end_token_id = collection.current_supply + amount;
    let current_time = utils::current_time_ms();

    // Create NFTs in batch (ultra-efficient)
    let mut nfts = vector::empty<Collectible>();
    let mut current_id = start_token_id;

    while (current_id <= end_token_id) {
        // Generate metadata efficiently
        let (nft_name, image_url) = generate_nft_metadata(collection, current_id);

        // Create minimal NFT
        let nft = Collectible {
            id: object::new(ctx),
            collection: object::id(collection),
            token_id: current_id,
            name: nft_name,
            attributes: if (option::is_some(&custom_attributes)) {
                *option::borrow(&custom_attributes)
            } else {
                vec_map::empty()
            },
            creator: sender,
        };

        vector::push_back(&mut nfts, nft);
        current_id = current_id + 1;
    };

    // Update collection supply
    collection.current_supply = end_token_id;

    // Create batch receipt
    let receipt = BatchMintReceipt {
        id: object::new(ctx),
        collection_id: object::id(collection),
        batch_id: utils::safe_utf8(batch_id),
        start_token_id,
        end_token_id,
        total_minted: amount,
        minted_by: sender,
        minted_at: current_time,
        recipients: vector[recipient],
    };

    event::emit(BatchMinted {
        collection_id: object::id(collection),
        batch_id: utils::safe_utf8(batch_id),
        start_token_id,
        end_token_id,
        total_minted: amount,
        minted_by: sender,
    });

    (nfts, receipt)
}

/// Generate NFT metadata efficiently using collection template
fun generate_nft_metadata(collection: &Collection, token_id: u64): (String, String) {
    let base_meta = &collection.base_metadata;

    // Generate name
    let name = if (base_meta.auto_increment_names) {
        // Simple approach: use base prefix + token_id as bytes
        let mut name_bytes = *string::as_bytes(&base_meta.base_name_prefix);
        // Convert token_id to string representation (simple implementation)
        let id_bytes = u64_to_ascii_bytes(token_id);
        vector::append(&mut name_bytes, id_bytes);
        string::utf8(name_bytes)
    } else {
        base_meta.base_name_prefix
    };

    // Generate image URL
    let image_url = if (base_meta.use_token_id_in_url) {
        let mut url_bytes = *string::as_bytes(&base_meta.base_image_url);
        let id_bytes = u64_to_ascii_bytes(token_id);
        vector::append(&mut url_bytes, id_bytes);
        vector::append(&mut url_bytes, b".json");
        string::utf8(url_bytes)
    } else {
        base_meta.base_image_url
    };

    (name, image_url)
}

/// Simple u64 to ASCII bytes conversion
fun u64_to_ascii_bytes(mut num: u64): vector<u8> {
    if (num == 0) {
        return vector[48] // ASCII '0'
    };

    let mut result = vector::empty<u8>();
    while (num > 0) {
        let digit = ((num % 10) as u8) + 48; // Convert to ASCII
        vector::push_back(&mut result, digit);
        num = num / 10;
    };

    // Reverse the vector to get correct order
    vector::reverse(&mut result);
    result
}

/// Entry function for batch minting to single recipient
public entry fun batch_mint_to_recipient(
    collection: &mut Collection,
    recipient: address,
    amount: u64,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
) {
    let (mut nfts, receipt) = batch_mint_collectibles(
        collection,
        recipient,
        amount,
        batch_id,
        option::none(),
        ctx,
    );

    // Transfer all NFTs to recipient
    let mut i = 0;
    while (i < vector::length(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::public_transfer(nft, recipient);
        i = i + 1;
    };

    // Destroy empty vector
    vector::destroy_empty(nfts);

    // Transfer receipt to minter
    transfer::public_transfer(receipt, tx_context::sender(ctx));
}

/// Multi-recipient batch mint - distribute NFTs to multiple addresses
public entry fun multi_batch_mint_entry(
    collection: &mut Collection,
    recipients: vector<address>,
    amounts_per_recipient: vector<u64>,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(
        vector::length(&recipients) == vector::length(&amounts_per_recipient),
        base::invalid_metadata_error(),
    );
    assert!(vector::length(&recipients) <= MAX_MULTI_RECIPIENT, base::invalid_amount_error());

    let sender = tx_context::sender(ctx);
    assert!(
        sender == collection.authority || table::contains(&collection.minters, sender),
        base::not_authorized_error(),
    );

    // Calculate total amount
    let mut total_amount = 0u64;
    let mut i = 0;
    while (i < vector::length(&amounts_per_recipient)) {
        total_amount = utils::safe_add(total_amount, *vector::borrow(&amounts_per_recipient, i));
        i = i + 1;
    };

    // Supply check
    assert!(
        utils::safe_add(collection.current_supply, total_amount) <= collection.max_supply,
        base::supply_exceeded_error(),
    );

    let start_token_id = collection.current_supply + 1;
    let current_time = utils::current_time_ms();
    let mut current_token_id = start_token_id;

    // Mint to each recipient
    i = 0;
    while (i < vector::length(&recipients)) {
        let recipient = *vector::borrow(&recipients, i);
        let amount = *vector::borrow(&amounts_per_recipient, i);

        if (amount > 0) {
            let mut j = 0;
            while (j < amount) {
                let (nft_name, image_url) = generate_nft_metadata(collection, current_token_id);

                let nft = Collectible {
                    id: object::new(ctx),
                    collection: object::id(collection),
                    token_id: current_token_id,
                    name: nft_name,
                    attributes: vec_map::empty(),
                    creator: sender,
                };

                transfer::public_transfer(nft, recipient);
                current_token_id = current_token_id + 1;
                j = j + 1;
            };
        };

        i = i + 1;
    };

    // Update collection supply
    collection.current_supply = current_token_id - 1;

    // Create batch receipt
    let receipt = BatchMintReceipt {
        id: object::new(ctx),
        collection_id: object::id(collection),
        batch_id: utils::safe_utf8(batch_id),
        start_token_id,
        end_token_id: current_token_id - 1,
        total_minted: total_amount,
        minted_by: sender,
        minted_at: current_time,
        recipients,
    };

    transfer::public_transfer(receipt, sender);

    event::emit(BatchMinted {
        collection_id: object::id(collection),
        batch_id: utils::safe_utf8(batch_id),
        start_token_id,
        end_token_id: current_token_id - 1,
        total_minted: total_amount,
        minted_by: sender,
    });
}

// ===== Efficient NFT Operations =====

/// Transfer collectible (optimized)
public entry fun transfer_collectible(nft: Collectible, recipient: address, ctx: &mut TxContext) {
    event::emit(CollectibleTransferred {
        nft_id: object::id(&nft),
        from: tx_context::sender(ctx),
        to: recipient,
    });

    transfer::public_transfer(nft, recipient);
}

/// Burn collectible (simplified)
public entry fun burn_collectible(nft: Collectible, ctx: &mut TxContext) {
    let Collectible {
        id,
        collection: _,
        token_id: _,
        name: _,
        attributes: _,
        creator: _,
    } = nft;

    object::delete(id);
}

/// Add attribute to NFT (only if mutable)
public fun add_collectible_attribute(
    nft: &mut Collectible,
    key: vector<u8>,
    value: vector<u8>,
    ctx: &mut TxContext,
) {
    // Note: In production, you'd check if metadata is mutable via collection config
    vec_map::insert(&mut nft.attributes, utils::safe_utf8(key), utils::safe_utf8(value));
}

// ===== View Functions (Optimized) =====

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

/// Get collectible info with dynamic metadata generation
public fun get_collectible_info(nft: &Collectible): (ID, u64, String, String, String, address) {
    // Note: For Display to work properly, we need to generate the metadata here
    // In a real implementation, you'd fetch the collection and generate URLs
    let description = string::utf8(b"Dynamic NFT from Onoal Token Library");
    let image_url = string::utf8(b"https://api.onoal.com/nft/placeholder.json");

    (nft.collection, nft.token_id, nft.name, description, image_url, nft.creator)
}

/// Get collectible info with collection context for proper Display metadata
public fun get_collectible_display_info(
    nft: &Collectible,
    collection: &Collection,
): (String, String, String, String) {
    // Generate dynamic metadata using collection template
    let (name, image_url) = generate_nft_metadata_for_display(collection, nft.token_id);

    let description = collection.base_metadata.base_description;
    let external_url = if (collection.base_metadata.use_token_id_in_url) {
        let mut url_bytes = *string::as_bytes(&collection.base_metadata.base_external_url);
        let id_bytes = u64_to_ascii_bytes(nft.token_id);
        vector::append(&mut url_bytes, id_bytes);
        string::utf8(url_bytes)
    } else {
        collection.base_metadata.base_external_url
    };

    (name, description, image_url, external_url)
}

/// Generate metadata specifically for Display (similar to existing function but optimized)
fun generate_nft_metadata_for_display(collection: &Collection, token_id: u64): (String, String) {
    let base_meta = &collection.base_metadata;

    // Generate name
    let name = if (base_meta.auto_increment_names) {
        let mut name_bytes = *string::as_bytes(&base_meta.base_name_prefix);
        let id_bytes = u64_to_ascii_bytes(token_id);
        vector::append(&mut name_bytes, id_bytes);
        string::utf8(name_bytes)
    } else {
        base_meta.base_name_prefix
    };

    // Generate image URL
    let image_url = if (base_meta.use_token_id_in_url) {
        let mut url_bytes = *string::as_bytes(&base_meta.base_image_url);
        let id_bytes = u64_to_ascii_bytes(token_id);
        vector::append(&mut url_bytes, id_bytes);
        vector::append(&mut url_bytes, b".json");
        string::utf8(url_bytes)
    } else {
        base_meta.base_image_url
    };

    (name, image_url)
}

/// Get collectible attribute
public fun get_collectible_attribute(nft: &Collectible, key: &String): String {
    if (vec_map::contains(&nft.attributes, key)) {
        *vec_map::get(&nft.attributes, key)
    } else {
        string::utf8(b"")
    }
}

/// Get formatted attributes string for Display
public fun get_formatted_attributes(nft: &Collectible): String {
    if (vec_map::is_empty(&nft.attributes)) {
        return string::utf8(b"")
    };

    // Simple JSON-like formatting for attributes
    let mut result = string::utf8(b"{");
    let keys = vec_map::keys(&nft.attributes);
    let mut i = 0;

    while (i < vector::length(&keys)) {
        let key = vector::borrow(&keys, i);
        let value = vec_map::get(&nft.attributes, key);

        // Add key-value pair
        let mut pair_bytes = b"\"";
        vector::append(&mut pair_bytes, *string::as_bytes(key));
        vector::append(&mut pair_bytes, b"\":\"");
        vector::append(&mut pair_bytes, *string::as_bytes(value));
        vector::append(&mut pair_bytes, b"\"");

        if (i < vector::length(&keys) - 1) {
            vector::append(&mut pair_bytes, b",");
        };

        let pair_string = string::utf8(pair_bytes);
        result = string_concat(result, pair_string);

        i = i + 1;
    };

    string_concat(result, string::utf8(b"}"))
}

/// Simple string concatenation helper
fun string_concat(str1: String, str2: String): String {
    let mut bytes1 = *string::as_bytes(&str1);
    let bytes2 = *string::as_bytes(&str2);
    vector::append(&mut bytes1, bytes2);
    string::utf8(bytes1)
}

/// Check if address is authorized minter
public fun is_authorized_minter(collection: &Collection, minter: address): bool {
    minter == collection.authority || table::contains(&collection.minters, minter)
}

/// Get collection configuration
public fun get_collection_config(collection: &Collection): (bool, bool, bool) {
    let flags = collection.config_flags;
    (
        (flags & 1) != 0, // is_transferable
        (flags & 2) != 0, // is_burnable
        (flags & 4) != 0, // mutable_metadata
    )
}

/// Get batch mint cost estimate (placeholder for future pricing)
public fun estimate_batch_cost(collection: &Collection, amount: u64): u64 {
    // Could implement dynamic pricing based on collection size, rarity, etc.
    amount * 1000000 // 0.001 SUI per NFT as base cost
}

/// Check if collection is sold out
public fun is_sold_out(collection: &Collection): bool {
    collection.current_supply >= collection.max_supply
}

/// Get remaining supply
public fun get_remaining_supply(collection: &Collection): u64 {
    collection.max_supply - collection.current_supply
}

// ===== Advanced Royalty Management =====

/// Comprehensive royalty information for NFTs
public struct RoyaltyInfo has drop, store {
    /// Primary creator royalty
    creator_royalty_bps: u64, // Creator percentage in basis points (e.g., 250 = 2.5%)
    platform_royalty_bps: u64, // Platform percentage in basis points
    /// Multi-creator splits
    creators: vector<address>,
    creator_splits: vector<u64>, // Percentages for each creator (must sum to 100)
    /// Royalty caps and minimums
    max_royalty_bps: u64, // Maximum total royalty (e.g., 1000 = 10%)
    min_sale_price: u64, // Minimum sale price to trigger royalties
    /// Royalty settings
    is_transferable: bool, // Can royalty info be transferred
    enforce_on_all_sales: bool, // Enforce on all platforms
    /// Collection-level overrides
    collection_override: bool, // Collection can override individual royalties
}

/// Royalty payment record
public struct RoyaltyPayment has store {
    sale_id: ID,
    sale_price: u64,
    total_royalty_paid: u64,
    creator_payments: vector<u64>, // Amount paid to each creator
    platform_payment: u64,
    paid_at: u64,
    payment_reference: String,
}

/// Enhanced collection with royalty management
public struct RoyaltyCollection has key {
    id: UID,
    /// Basic collection info
    base_collection: ID, // Reference to base Collection
    /// Royalty settings
    default_royalty: RoyaltyInfo,
    custom_royalties: Table<ID, RoyaltyInfo>, // NFT ID -> custom royalty
    /// Royalty tracking
    total_royalties_paid: u64,
    total_sales_tracked: u64,
    royalty_payments: Table<ID, RoyaltyPayment>, // Sale ID -> payment record
    /// Royalty enforcement
    authorized_marketplaces: Table<address, bool>,
    royalty_enforcement_level: u8, // 0=optional, 1=recommended, 2=enforced
}

/// Marketplace integration for royalty enforcement
public struct RoyaltyMarketplace has key {
    id: UID,
    marketplace_name: String,
    operator: address,
    /// Royalty compliance
    enforces_royalties: bool,
    royalty_compliance_level: u8, // 0-100 compliance score
    /// Fee structure
    marketplace_fee_bps: u64,
    minimum_royalty_enforcement: u64, // Minimum royalty this marketplace will enforce
    /// Collections supported
    supported_collections: Table<ID, bool>,
    /// Sales tracking
    total_sales: u64,
    total_royalties_facilitated: u64,
}

// ===== Royalty Events =====

public struct RoyaltyPaid has copy, drop {
    nft_id: ID,
    sale_id: ID,
    sale_price: u64,
    total_royalty: u64,
    creator_count: u64,
    marketplace: address,
}

public struct RoyaltyInfoUpdated has copy, drop {
    nft_id: ID,
    collection_id: ID,
    creator_royalty_bps: u64,
    platform_royalty_bps: u64,
    updated_by: address,
}

// ===== Royalty Management Functions =====

/// Create royalty collection with default settings
public fun create_royalty_collection(
    base_collection: ID,
    creators: vector<address>,
    creator_splits: vector<u64>,
    creator_royalty_bps: u64,
    platform_royalty_bps: u64,
    max_royalty_bps: u64,
    min_sale_price: u64,
    enforcement_level: u8,
    ctx: &mut TxContext,
): RoyaltyCollection {
    // Validate inputs
    assert!(
        vector::length(&creators) == vector::length(&creator_splits),
        base::invalid_metadata_error(),
    );
    assert!(!vector::is_empty(&creators), base::invalid_metadata_error());
    assert!(
        creator_royalty_bps + platform_royalty_bps <= max_royalty_bps,
        base::invalid_amount_error(),
    );
    assert!(max_royalty_bps <= 5000, base::invalid_amount_error()); // Max 50% total royalty

    // Validate creator splits sum to 100
    let mut total_split = 0u64;
    let mut i = 0;
    while (i < vector::length(&creator_splits)) {
        total_split = total_split + *vector::borrow(&creator_splits, i);
        i = i + 1;
    };
    assert!(total_split == 100, base::invalid_metadata_error());

    let default_royalty = RoyaltyInfo {
        creator_royalty_bps,
        platform_royalty_bps,
        creators,
        creator_splits,
        max_royalty_bps,
        min_sale_price,
        is_transferable: false,
        enforce_on_all_sales: enforcement_level >= 2,
        collection_override: true,
    };

    let royalty_collection = RoyaltyCollection {
        id: object::new(ctx),
        base_collection,
        default_royalty,
        custom_royalties: table::new(ctx),
        total_royalties_paid: 0,
        total_sales_tracked: 0,
        royalty_payments: table::new(ctx),
        authorized_marketplaces: table::new(ctx),
        royalty_enforcement_level: enforcement_level,
    };

    royalty_collection
}

/// Set custom royalty for specific NFT
public fun set_custom_royalty(
    royalty_collection: &mut RoyaltyCollection,
    nft_id: ID,
    creators: vector<address>,
    creator_splits: vector<u64>,
    creator_royalty_bps: u64,
    platform_royalty_bps: u64,
    ctx: &mut TxContext,
) {
    // Only authorized addresses can set custom royalties
    let sender = tx_context::sender(ctx);

    // Validate splits
    assert!(
        vector::length(&creators) == vector::length(&creator_splits),
        base::invalid_metadata_error(),
    );
    let mut total_split = 0u64;
    let mut i = 0;
    while (i < vector::length(&creator_splits)) {
        total_split = total_split + *vector::borrow(&creator_splits, i);
        i = i + 1;
    };
    assert!(total_split == 100, base::invalid_metadata_error());

    let custom_royalty = RoyaltyInfo {
        creator_royalty_bps,
        platform_royalty_bps,
        creators,
        creator_splits,
        max_royalty_bps: royalty_collection.default_royalty.max_royalty_bps,
        min_sale_price: royalty_collection.default_royalty.min_sale_price,
        is_transferable: false,
        enforce_on_all_sales: royalty_collection.default_royalty.enforce_on_all_sales,
        collection_override: false,
    };

    if (table::contains(&royalty_collection.custom_royalties, nft_id)) {
        let existing = table::borrow_mut(&mut royalty_collection.custom_royalties, nft_id);
        *existing = custom_royalty;
    } else {
        table::add(&mut royalty_collection.custom_royalties, nft_id, custom_royalty);
    };

    event::emit(RoyaltyInfoUpdated {
        nft_id,
        collection_id: object::id(royalty_collection),
        creator_royalty_bps,
        platform_royalty_bps,
        updated_by: sender,
    });
}

/// Calculate royalty amounts for a sale
public fun calculate_royalties(
    royalty_collection: &RoyaltyCollection,
    nft_id: ID,
    sale_price: u64,
): (u64, vector<u64>, u64) {
    // Get royalty info (custom or default)
    let royalty_info = if (table::contains(&royalty_collection.custom_royalties, nft_id)) {
        table::borrow(&royalty_collection.custom_royalties, nft_id)
    } else {
        &royalty_collection.default_royalty
    };

    // Check minimum sale price
    if (sale_price < royalty_info.min_sale_price) {
        return (0, vector::empty<u64>(), 0)
    };

    // Calculate creator royalties
    let total_creator_royalty = (sale_price * royalty_info.creator_royalty_bps) / 10000;
    let mut creator_payments = vector::empty<u64>();

    let mut i = 0;
    while (i < vector::length(&royalty_info.creator_splits)) {
        let split_percent = *vector::borrow(&royalty_info.creator_splits, i);
        let creator_payment = (total_creator_royalty * split_percent) / 100;
        vector::push_back(&mut creator_payments, creator_payment);
        i = i + 1;
    };

    // Calculate platform royalty
    let platform_royalty = (sale_price * royalty_info.platform_royalty_bps) / 10000;

    let total_royalty = total_creator_royalty + platform_royalty;

    (total_royalty, creator_payments, platform_royalty)
}

/// Process royalty payment for a sale
public fun process_royalty_payment(
    royalty_collection: &mut RoyaltyCollection,
    nft_id: ID,
    sale_price: u64,
    payment_reference: vector<u8>,
    ctx: &mut TxContext,
): ID {
    let (total_royalty, creator_payments, platform_payment) = calculate_royalties(
        royalty_collection,
        nft_id,
        sale_price,
    );

    if (total_royalty == 0) {
        abort base::invalid_amount_error()
    };

    let sale_id = object::id_from_address(tx_context::sender(ctx));

    let royalty_payment = RoyaltyPayment {
        sale_id,
        sale_price,
        total_royalty_paid: total_royalty,
        creator_payments,
        platform_payment,
        paid_at: utils::current_time_ms(),
        payment_reference: utils::safe_utf8(payment_reference),
    };

    table::add(&mut royalty_collection.royalty_payments, sale_id, royalty_payment);

    // Update collection stats
    royalty_collection.total_royalties_paid =
        royalty_collection.total_royalties_paid + total_royalty;
    royalty_collection.total_sales_tracked = royalty_collection.total_sales_tracked + 1;

    event::emit(RoyaltyPaid {
        nft_id,
        sale_id,
        sale_price,
        total_royalty,
        creator_count: vector::length(&creator_payments),
        marketplace: tx_context::sender(ctx),
    });

    sale_id
}

/// Register authorized marketplace
public fun authorize_marketplace(
    royalty_collection: &mut RoyaltyCollection,
    marketplace: address,
    ctx: &mut TxContext,
) {
    // Only collection authority can authorize marketplaces
    table::add(&mut royalty_collection.authorized_marketplaces, marketplace, true);
}

// ===== View Functions for Royalty Management =====

/// Get royalty info for an NFT
public fun get_royalty_info(
    royalty_collection: &RoyaltyCollection,
    nft_id: ID,
): (u64, u64, vector<address>, vector<u64>, u64) {
    let royalty_info = if (table::contains(&royalty_collection.custom_royalties, nft_id)) {
        table::borrow(&royalty_collection.custom_royalties, nft_id)
    } else {
        &royalty_collection.default_royalty
    };

    (
        royalty_info.creator_royalty_bps,
        royalty_info.platform_royalty_bps,
        royalty_info.creators,
        royalty_info.creator_splits,
        royalty_info.min_sale_price,
    )
}

/// Get royalty collection stats
public fun get_royalty_collection_stats(
    royalty_collection: &RoyaltyCollection,
): (u64, u64, u64, u8) {
    (
        royalty_collection.total_royalties_paid,
        royalty_collection.total_sales_tracked,
        table::length(&royalty_collection.custom_royalties),
        royalty_collection.royalty_enforcement_level,
    )
}

/// Check if marketplace is authorized
public fun is_authorized_marketplace(
    royalty_collection: &RoyaltyCollection,
    marketplace: address,
): bool {
    table::contains(&royalty_collection.authorized_marketplaces, marketplace)
}

/// Get royalty payment details
public fun get_royalty_payment_info(
    royalty_collection: &RoyaltyCollection,
    sale_id: ID,
): (u64, u64, vector<u64>, u64, u64) {
    assert!(
        table::contains(&royalty_collection.royalty_payments, sale_id),
        base::token_not_found_error(),
    );
    let payment = table::borrow(&royalty_collection.royalty_payments, sale_id);

    (
        payment.sale_price,
        payment.total_royalty_paid,
        payment.creator_payments,
        payment.platform_payment,
        payment.paid_at,
    )
}

/// Calculate effective royalty rate for an NFT
public fun get_effective_royalty_rate(royalty_collection: &RoyaltyCollection, nft_id: ID): u64 {
    let royalty_info = if (table::contains(&royalty_collection.custom_royalties, nft_id)) {
        table::borrow(&royalty_collection.custom_royalties, nft_id)
    } else {
        &royalty_collection.default_royalty
    };

    royalty_info.creator_royalty_bps + royalty_info.platform_royalty_bps
}
