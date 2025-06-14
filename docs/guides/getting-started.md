# 🚀 Getting Started with OTL

Welcome to the Onoal Token Library! This guide will help you get up and running with OTL, from installation to creating your first tokens and NFTs.

## 📋 Prerequisites

Before you begin, ensure you have:

- **Sui CLI** installed and configured
- **Move development environment** set up
- **Basic understanding** of Move programming language
- **Sui wallet** for testing (optional but recommended)

### Install Sui CLI

```bash
# Install Sui CLI
curl -fLJO https://github.com/MystenLabs/sui/releases/latest/download/sui-macos-x86_64.tgz
tar -xf sui-macos-x86_64.tgz
sudo mv sui /usr/local/bin/

# Verify installation
sui --version
```

## 🔧 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/onoal/Onoal-Token-Library.git
cd Onoal-Token-Library
```

### 2. Build the Project

```bash
# Build all modules
sui move build

# Run tests (optional)
sui move test
```

### 3. Deploy to Local Network

```bash
# Start local Sui network
sui start

# Deploy OTL package
sui client publish --gas-budget 100000000
```

## 🏗️ Basic Setup

### 1. Initialize the OTL System

First, you need to initialize the OTL registry and core modules:

```move
// In your deployment script or init function
public entry fun setup_otl_system(ctx: &mut TxContext) {
    // Initialize the complete OTL system
    otl::otl_init::initialize_complete_otl_system(ctx);
}
```

### 2. Verify System Health

Check that all modules are properly registered:

```move
public fun check_system_status(registry: &OTLRegistry): bool {
    otl::otl_init::check_system_health(registry)
}
```

## 🪙 Creating Your First Token

Let's create a simple business token using the coin module:

### 1. Create Token Registry

```move
use otl::coin;

public entry fun create_my_token_registry(ctx: &mut TxContext) {
    let registry = coin::create_utility_token_registry(
        b"My Business Tokens",
        ctx
    );
    transfer::share_object(registry);
}
```

### 2. Create Token Type

```move
public entry fun create_my_token(
    registry: &mut UtilityTokenRegistry,
    ctx: &mut TxContext
) {
    let token_type = coin::create_token_type(
        registry,
        b"My Token",           // name
        b"MTK",               // symbol
        b"A sample business token for my app", // description
        1000,                 // price per token (1000 MIST = 0.001 SUI)
        1000000,              // max supply (1M tokens)
        9,                    // decimals
        true,                 // transferable
        false,                // not burnable
        true,                 // price adjustable
        100,                  // batch discount threshold
        10,                   // 10% batch discount
        ctx
    );

    transfer::share_object(token_type);
}
```

### 3. Purchase Tokens

```move
public entry fun buy_tokens(
    token_type: &mut TokenType,
    payment: Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext
) {
    let (tokens, receipt) = coin::purchase_tokens(
        token_type,
        payment,
        amount,
        ctx
    );

    let buyer = tx_context::sender(ctx);
    transfer::public_transfer(tokens, buyer);
    transfer::public_transfer(receipt, buyer);
}
```

## 🎨 Creating Your First NFT Collection

Now let's create an NFT collection:

### 1. Create Collection

```move
use otl::collectible;

public entry fun create_my_nft_collection(ctx: &mut TxContext) {
    let collection = collectible::create_collection(
        b"My NFT Collection",     // name
        b"MYNFT",                // symbol
        b"A collection of unique digital art", // description
        b"https://mysite.com/collection.png", // collection image
        1000,                    // max supply
        b"My NFT #",            // name prefix for auto-generation
        b"A unique NFT from my collection", // base description
        b"https://api.mysite.com/nft/", // base image URL
        b"https://mysite.com/nft/", // base external URL
        true,                    // auto increment names
        true,                    // use token ID in URL
        true,                    // transferable
        false,                   // not burnable
        false,                   // immutable metadata
        ctx
    );

    transfer::share_object(collection);
}
```

### 2. Mint NFTs

```move
public entry fun mint_my_nfts(
    collection: &mut Collection,
    recipient: address,
    count: u64,
    ctx: &mut TxContext
) {
    let (nfts, receipt) = collectible::batch_mint_nfts(
        collection,
        count,
        recipient,
        b"batch_001",
        ctx
    );

    // Transfer NFTs to recipient
    let mut i = 0;
    while (i < vector::length(&nfts)) {
        let nft = vector::pop_back(&mut nfts);
        transfer::public_transfer(nft, recipient);
        i = i + 1;
    };

    transfer::public_transfer(receipt, tx_context::sender(ctx));
    vector::destroy_empty(nfts);
}
```

## 👤 Setting Up User Profiles

Create social profiles for your users:

### 1. Create User Profile

```move
use otl::social;

public entry fun create_user_profile(
    username: vector<u8>,
    display_name: vector<u8>,
    bio: vector<u8>,
    avatar_url: vector<u8>,
    ctx: &mut TxContext
) {
    let profile = social::create_user_profile(
        username,
        display_name,
        bio,
        avatar_url,
        b"", // banner URL
        0,   // public privacy
        ctx
    );

    transfer::public_transfer(profile, tx_context::sender(ctx));
}
```

### 2. Create NFT Showcase

```move
public entry fun create_nft_showcase(
    profile: &mut UserProfile,
    name: vector<u8>,
    description: vector<u8>,
    ctx: &mut TxContext
) {
    let showcase = social::create_showcase(
        profile,
        name,
        description,
        b"", // cover image
        true, // public
        ctx
    );

    transfer::public_transfer(showcase, tx_context::sender(ctx));
}
```

## 💳 Creating User Wallets

Set up OTL wallets for asset management:

### 1. Create Wallet

```move
use otl::otl_wallet;

public entry fun create_user_wallet(
    name: vector<u8>,
    ctx: &mut TxContext
) {
    let (wallet, registry_opt) = otl_wallet::create_otl_wallet_with_registry(
        name,
        true, // create asset registry
        ctx
    );

    let sender = tx_context::sender(ctx);
    transfer::public_transfer(wallet, sender);

    if (option::is_some(&registry_opt)) {
        let registry = option::extract(&mut registry_opt);
        transfer::public_transfer(registry, sender);
    };

    option::destroy_none(registry_opt);
}
```

## 🏪 Setting Up Marketplace

Integrate with Sui Kiosk for marketplace functionality:

### 1. Create Kiosk Registry

```move
use otl::kiosk_integration;

public entry fun setup_marketplace(ctx: &mut TxContext) {
    let registry = kiosk_integration::create_kiosk_registry(ctx);
    transfer::share_object(registry);
}
```

### 2. Register as Merchant

```move
public entry fun register_merchant(
    registry: &mut KioskRegistry,
    merchant_name: vector<u8>,
    merchant_description: vector<u8>,
    ctx: &mut TxContext
) {
    kiosk_integration::register_merchant_kiosk(
        registry,
        merchant_name,
        merchant_description,
        ctx
    );
}
```

## 🔧 Advanced Features

### 1. Batch Operations

```move
// Batch mint tokens to multiple recipients
public entry fun airdrop_tokens(
    token_type: &mut TokenType,
    recipients: vector<address>,
    amount_per_recipient: u64,
    ctx: &mut TxContext
) {
    coin::batch_airdrop_tokens(
        token_type,
        recipients,
        amount_per_recipient,
        ctx
    );
}
```

### 2. Event Management

```move
use otl::events_festivals;

public entry fun create_event(
    name: vector<u8>,
    description: vector<u8>,
    venue: vector<u8>,
    start_date: u64,
    end_date: u64,
    ctx: &mut TxContext
) {
    let event_registry = events_festivals::create_event_registry(
        name,
        description,
        venue,
        b"https://myevent.com/image.png",
        b"https://myevent.com",
        start_date,
        end_date,
        start_date - 86400000, // registration deadline (1 day before)
        b"Event Coin",
        b"EVNT",
        1000, // 1 EUR = 1000 event coins
        ctx
    );

    transfer::share_object(event_registry);
}
```

## 🧪 Testing Your Implementation

### 1. Unit Tests

```move
#[test_only]
module my_app::tests {
    use otl::coin;
    use sui::test_scenario;

    #[test]
    fun test_token_creation() {
        let mut scenario = test_scenario::begin(@admin);

        // Test token creation
        test_scenario::next_tx(&mut scenario, @admin);
        {
            let registry = coin::create_utility_token_registry(b"Test", test_scenario::ctx(&mut scenario));
            transfer::share_object(registry);
        };

        // Test token type creation
        test_scenario::next_tx(&mut scenario, @admin);
        {
            let mut registry = test_scenario::take_shared<UtilityTokenRegistry>(&scenario);
            let token_type = coin::create_token_type(
                &mut registry,
                b"Test Token",
                b"TEST",
                b"Test description",
                1000,
                1000000,
                9,
                true, false, true,
                100, 10,
                test_scenario::ctx(&mut scenario)
            );
            transfer::share_object(token_type);
            test_scenario::return_shared(registry);
        };

        test_scenario::end(scenario);
    }
}
```

### 2. Integration Tests

```bash
# Run all tests
sui move test

# Run specific test
sui move test --filter test_token_creation
```

## 📊 Monitoring and Analytics

### 1. Check System Health

```move
public fun get_system_status(registry: &OTLRegistry) {
    let (total_modules, total_plugins, batch_enabled, analytics_enabled) =
        otl::otl_init::get_system_info(registry);

    // Log or emit events with status
}
```

### 2. Track Token Metrics

```move
public fun get_token_stats(token_type: &TokenType) {
    let (current_supply, total_purchases, total_revenue) =
        coin::get_token_statistics(token_type);

    // Process metrics
}
```

## 🚨 Best Practices

### 1. Error Handling

```move
// Always use OTL error codes
assert!(amount > 0, base::invalid_amount_error());
assert!(sender == authority, base::not_authorized_error());
```

### 2. Gas Optimization

```move
// Use batch operations for multiple items
let (nfts, receipt) = collectible::batch_mint_nfts(collection, 100, recipient, b"batch", ctx);

// Instead of individual mints
// for (i in 0..100) { collectible::mint_nft(...) } // DON'T DO THIS
```

### 3. Security

```move
// Validate inputs
assert!(!vector::is_empty(&name), base::invalid_metadata_error());
assert!(utils::validate_address(recipient), base::invalid_address_error());

// Check permissions
assert!(permissions::has_permission(&registry, sender, "mint"), base::not_authorized_error());
```

## 🔗 Next Steps

Now that you have the basics working:

1. **Explore Advanced Features** - Check out loyalty programs, event tickets, and social features
2. **Integrate with Frontend** - Build a web interface using Sui TypeScript SDK
3. **Deploy to Testnet** - Test your application on Sui testnet
4. **Join the Community** - Connect with other OTL developers

## 📚 Additional Resources

- **[Module Documentation](../modules/)** - Detailed module guides
- **[API Reference](../api/)** - Complete function documentation
- **[Code Examples](../examples/)** - More implementation examples
- **[Migration Guide](./migration.md)** - Upgrading between versions

## 🆘 Getting Help

- **GitHub Issues**: [Report bugs or request features](https://github.com/onoal/Onoal-Token-Library/issues)
- **Discord**: [Join our community](https://discord.gg/onoal)
- **Documentation**: [Browse all docs](../README.md)

Happy building with OTL! 🎉
