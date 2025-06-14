# 🎨 Collectible Module

The **Collectible Module** (`otl::collectible`) provides a comprehensive NFT system with batch operations, collection management, and Sui Display integration. It's optimized for gas efficiency while maintaining full feature richness.

## 📋 Overview

The Collectible module enables creation and management of NFT collections with advanced features like batch minting, metadata templates, and seamless integration with Sui's Display standard and Kiosk framework.

## 🎯 Key Features

- **🏭 Batch Operations** - Mint up to 1000 NFTs in a single transaction
- **📦 Collection Management** - Organized NFT collections with metadata templates
- **🎨 Sui Display Integration** - Native display support for wallets and marketplaces
- **⚡ Gas Optimization** - Ultra-lightweight structures for minimal costs
- **🔧 Configurable Metadata** - Flexible metadata system with templates
- **👥 Multi-Recipient Minting** - Distribute NFTs to multiple addresses efficiently
- **🔒 Access Control** - Authorized minter system with permissions

## 🏗️ Core Structures

### Collection

Main collection structure for organizing NFTs.

```move
public struct Collection has key {
    id: UID,
    // Creator/admin of the collection
    authority: address,
    // Essential metadata
    name: String,
    symbol: String,
    description: String,
    image_url: String,
    // Supply tracking
    max_supply: u64,
    current_supply: u64,
    // Configuration flags (packed for efficiency)
    config_flags: u8, // bit 0: transferable, bit 1: burnable, bit 2: mutable_metadata
    // Authorized minters
    minters: Table<address, bool>,
    // Base metadata template
    base_metadata: CollectionMetadata,
}
```

### CollectionMetadata

Template for efficient batch NFT creation.

```move
public struct CollectionMetadata has store {
    base_name_prefix: String, // e.g., "Onoal NFT #"
    base_description: String, // Template description
    base_image_url: String, // Base URL pattern
    base_external_url: String, // Base external URL
    // Batch-specific settings
    auto_increment_names: bool, // Auto-generate names
    use_token_id_in_url: bool, // Append token_id to image_url
}
```

### Collectible

Individual NFT structure (ultra-lightweight).

```move
public struct Collectible has key, store {
    id: UID,
    // Essential data only
    collection: ID,
    token_id: u64,
    // Minimal metadata
    name: String,
    // Optional attributes (only if needed)
    attributes: VecMap<String, String>,
    // Creator (for royalties/provenance)
    creator: address,
}
```

### BatchMintReceipt

Receipt for tracking batch operations.

```move
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
```

## 🔧 Core Functions

### Collection Management

```move
// Create optimized collection
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
    is_mutable_metadata: bool,
    ctx: &mut TxContext,
): Collection

// Create and share collection
public entry fun create_shared_collection(
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    max_supply: u64,
    // ... other parameters
    ctx: &mut TxContext,
)
```

### Minter Management

```move
// Add authorized minter
public fun add_minter(
    collection: &mut Collection,
    minter: address,
    ctx: &mut TxContext,
)

// Remove minter
public fun remove_minter(
    collection: &mut Collection,
    minter: address,
    ctx: &mut TxContext,
)

// Check if address is authorized minter
public fun is_authorized_minter(
    collection: &Collection,
    minter: address,
): bool
```

### NFT Minting

```move
// Mint single NFT
public fun mint_nft(
    collection: &mut Collection,
    recipient: address,
    name: vector<u8>,
    attributes: VecMap<String, String>,
    ctx: &mut TxContext,
): Collectible

// Batch mint NFTs (gas optimized)
public fun batch_mint_nfts(
    collection: &mut Collection,
    count: u64,
    recipient: address,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
): (vector<Collectible>, BatchMintReceipt)

// Multi-recipient batch mint
public fun batch_mint_to_recipients(
    collection: &mut Collection,
    recipients: vector<address>,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
): (vector<Collectible>, BatchMintReceipt)
```

### Advanced Minting

```move
// Mint with custom attributes
public fun mint_nft_with_attributes(
    collection: &mut Collection,
    recipient: address,
    name: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    external_url: vector<u8>,
    attributes: VecMap<String, String>,
    ctx: &mut TxContext,
): Collectible

// Batch mint with incremental attributes
public fun batch_mint_with_incremental_attributes(
    collection: &mut Collection,
    count: u64,
    recipient: address,
    base_attributes: VecMap<String, String>,
    incremental_attributes: vector<String>, // Keys to increment
    ctx: &mut TxContext,
): vector<Collectible>
```

### Display Integration

```move
// Initialize Display for Collectible NFTs
public fun init_display(otw: COLLECTIBLE, ctx: &mut TxContext)

// Create shared display object
public fun create_shared_display(otw: COLLECTIBLE, ctx: &mut TxContext)
```

## 🎯 Usage Examples

### Create NFT Collection

```move
// Create a new NFT collection
let collection = collectible::create_collection(
    b"Onoal Genesis",
    b"ONOGEN",
    b"Genesis collection of Onoal NFTs",
    b"https://onoal.com/collections/genesis.png",
    10000, // max supply
    b"Onoal Genesis #", // name prefix
    b"A unique Genesis NFT from the Onoal ecosystem", // base description
    b"https://api.onoal.com/nft/genesis/", // base image URL
    b"https://onoal.com/nft/", // base external URL
    true, // auto increment names
    true, // use token ID in URL
    true, // transferable
    false, // not burnable
    false, // immutable metadata
    ctx,
);

// Share the collection
transfer::share_object(collection);
```

### Batch Mint NFTs

```move
// Batch mint 100 NFTs to a single recipient
let (nfts, receipt) = collectible::batch_mint_nfts(
    &mut collection,
    100, // count
    @recipient_address,
    b"batch_001", // batch ID
    ctx,
);

// Transfer NFTs to recipient
let mut i = 0;
while (i < vector::length(&nfts)) {
    let nft = vector::pop_back(&mut nfts);
    transfer::public_transfer(nft, @recipient_address);
    i = i + 1;
};

// Transfer receipt
transfer::public_transfer(receipt, tx_context::sender(ctx));
vector::destroy_empty(nfts);
```

### Multi-Recipient Batch Mint

```move
// Mint NFTs to multiple recipients
let recipients = vector[
    @user1,
    @user2,
    @user3,
    @user4,
    @user5,
];

let (nfts, receipt) = collectible::batch_mint_to_recipients(
    &mut collection,
    recipients,
    b"airdrop_001",
    ctx,
);

// NFTs are automatically distributed to recipients
transfer::public_transfer(receipt, tx_context::sender(ctx));
```

### Mint with Custom Attributes

```move
// Create custom attributes
let mut attributes = vec_map::empty<String, String>();
vec_map::insert(&mut attributes, string::utf8(b"rarity"), string::utf8(b"legendary"));
vec_map::insert(&mut attributes, string::utf8(b"power"), string::utf8(b"9000"));
vec_map::insert(&mut attributes, string::utf8(b"element"), string::utf8(b"fire"));

// Mint NFT with custom attributes
let nft = collectible::mint_nft_with_attributes(
    &mut collection,
    @recipient,
    b"Fire Dragon #1",
    b"A legendary fire dragon with immense power",
    b"https://api.onoal.com/nft/dragons/fire_001.png",
    b"https://onoal.com/nft/dragons/fire_001",
    attributes,
    ctx,
);

transfer::public_transfer(nft, @recipient);
```

### Initialize Display System

```move
// In module init function
fun init(otw: COLLECTIBLE, ctx: &mut TxContext) {
    // Initialize display for NFTs
    collectible::init_display(otw, ctx);
}

// Or create shared display
public entry fun setup_display(otw: COLLECTIBLE, ctx: &mut TxContext) {
    collectible::create_shared_display(otw, ctx);
}
```

## 📊 Batch Operations

### Gas Optimization Strategies

#### Single Recipient Batch

```move
// Most gas-efficient for single recipient
let (nfts, receipt) = collectible::batch_mint_nfts(
    &mut collection,
    1000, // maximum batch size
    @recipient,
    b"mega_batch",
    ctx,
);
```

#### Multi-Recipient Batch

```move
// Efficient for airdrops
let recipients = vector[/* up to 100 recipients */];
let (nfts, receipt) = collectible::batch_mint_to_recipients(
    &mut collection,
    recipients,
    b"airdrop_batch",
    ctx,
);
```

#### Incremental Attributes

```move
// For collections with sequential attributes
let base_attrs = vec_map::empty<String, String>();
vec_map::insert(&mut base_attrs, string::utf8(b"series"), string::utf8(b"genesis"));

let incremental_keys = vector[string::utf8(b"serial_number")];

let nfts = collectible::batch_mint_with_incremental_attributes(
    &mut collection,
    50, // count
    @recipient,
    base_attrs,
    incremental_keys,
    ctx,
);
```

## 🎨 Display Configuration

The Display system automatically generates metadata for NFTs:

### Default Display Fields

```move
{
    "name": "{name}",
    "description": "Dynamic NFT from Onoal Token Library - {name}",
    "image_url": "{image_url}",
    "external_url": "{external_url}",
    "attributes": "{attributes}",
    "collection": "Onoal Collectibles",
    "creator": "{creator}",
    "token_id": "#{token_id}",
    "project_url": "https://onoal.com"
}
```

### Dynamic URL Generation

For collections with `use_token_id_in_url = true`:

- Image URL: `{base_image_url}{token_id}.png`
- External URL: `{base_external_url}{token_id}`

## 🔒 Security Features

### Access Control

- Only collection authority can add/remove minters
- Only authorized minters can mint NFTs
- Supply limits enforced automatically

### Configuration Flags

```move
// Packed into single byte for gas efficiency
config_flags: u8
// bit 0: transferable (can be transferred)
// bit 1: burnable (can be burned)
// bit 2: mutable_metadata (metadata can be updated)
```

### Supply Management

- Hard cap enforcement via `max_supply`
- Current supply tracking
- Automatic token ID assignment

## 📈 Analytics & Events

### Events Emitted

```move
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
```

## 🔗 Integration Examples

### With Kiosk Integration

```move
// List NFT on marketplace
kiosk_integration::list_collectible(
    &mut kiosk,
    nft,
    price_in_sui,
    ctx,
);
```

### With OTL Wallet

```move
// Add NFT to wallet
otl_wallet::add_collectible(
    &mut wallet,
    nft_id,
    ctx,
);
```

### With Social Module

```move
// Add NFT to showcase
social::add_nft_to_showcase(
    &mut showcase,
    nft_id,
    string::utf8(b"My favorite NFT"),
    ctx,
);
```

## 🚨 Important Notes

1. **Batch Size Limits** - Maximum 1000 NFTs per batch for gas efficiency
2. **Token ID Assignment** - Automatically incremented starting from 1
3. **Metadata Templates** - Use templates for consistent batch minting
4. **Display Integration** - Initialize display for proper wallet/marketplace support
5. **Supply Limits** - Cannot exceed `max_supply` set during collection creation

## 📚 Related Documentation

- [Kiosk Integration](./kiosk_integration.md) - Marketplace functionality
- [Social Module](./social.md) - NFT showcases and profiles
- [OTL Wallet](./otl_wallet.md) - Multi-asset wallet management
- [Batch Utils](./batch_utils.md) - Gas optimization techniques
