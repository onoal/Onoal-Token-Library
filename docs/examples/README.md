# 💡 OTL Code Examples

Practical code examples demonstrating how to use the Onoal Token Library in real-world scenarios.

## 📚 Example Categories

### 🪙 Token Examples

- **[Simple Business Token](./simple-business-token.md)** - Create and manage a basic business token
- **[Loyalty Token System](./loyalty-token-system.md)** - Build a customer loyalty program
- **[Airdrop Campaign](./airdrop-campaign.md)** - Mass token distribution
- **[Token Vesting](./token-vesting.md)** - Time-locked token release

### 🎨 NFT Examples

- **[Art Collection](./art-collection.md)** - Create and mint an art NFT collection
- **[Gaming Assets](./gaming-assets.md)** - Game items and character NFTs
- **[Membership Cards](./membership-cards.md)** - Exclusive membership NFTs
- **[Dynamic NFTs](./dynamic-nfts.md)** - NFTs with changing attributes

### 🎫 Event & Ticketing

- **[Concert Tickets](./concert-tickets.md)** - Event ticketing system
- **[Festival Management](./festival-management.md)** - Multi-day festival with custom coins
- **[VIP Access System](./vip-access-system.md)** - Tiered access control
- **[Season Passes](./season-passes.md)** - Multi-event access passes

### 🏪 Marketplace Examples

- **[NFT Marketplace](./nft-marketplace.md)** - Complete marketplace integration
- **[Token Exchange](./token-exchange.md)** - Token trading platform
- **[Auction System](./auction-system.md)** - NFT auction functionality
- **[Merchant Store](./merchant-store.md)** - Digital goods store

### 👥 Social & Identity

- **[Social Platform](./social-platform.md)** - User profiles and social features
- **[Identity Verification](./identity-verification.md)** - KYC and verification system
- **[Community DAO](./community-dao.md)** - Governance and voting
- **[Creator Economy](./creator-economy.md)** - Content creator monetization

### 🔧 Integration Examples

- **[Frontend Integration](./frontend-integration.md)** - React/TypeScript integration
- **[Mobile App](./mobile-app.md)** - React Native implementation
- **[API Backend](./api-backend.md)** - Node.js backend integration
- **[Analytics Dashboard](./analytics-dashboard.md)** - Metrics and reporting

## 🚀 Quick Start Examples

### 1. Create Your First Token (5 minutes)

```move
// Complete example in simple-business-token.md
use otl::coin;

public entry fun create_coffee_shop_token(ctx: &mut TxContext) {
    // Create registry
    let registry = coin::create_utility_token_registry(b"Coffee Shop Tokens", ctx);

    // Create token type
    let token_type = coin::create_token_type(
        &mut registry,
        b"Coffee Coin",
        b"COFFEE",
        b"Loyalty token for our coffee shop",
        100, // 100 MIST per token
        1000000, // 1M max supply
        9, // decimals
        true, true, true, // transferable, burnable, price adjustable
        50, 10, // batch discount: 50+ tokens get 10% off
        ctx
    );

    transfer::share_object(registry);
    transfer::share_object(token_type);
}
```

### 2. Mint Your First NFT Collection (10 minutes)

```move
// Complete example in art-collection.md
use otl::collectible;

public entry fun create_digital_art_collection(ctx: &mut TxContext) {
    let collection = collectible::create_collection(
        b"Digital Dreams",
        b"DREAMS",
        b"A collection of AI-generated digital art",
        b"https://myart.com/collection.png",
        100, // limited to 100 pieces
        b"Dream #",
        b"A unique AI-generated artwork",
        b"https://api.myart.com/art/",
        b"https://myart.com/art/",
        true, true, // auto names, use token ID in URL
        true, false, false, // transferable, not burnable, immutable
        ctx
    );

    transfer::share_object(collection);
}
```

### 3. Set Up User Profiles (15 minutes)

```move
// Complete example in social-platform.md
use otl::social;
use otl::onoal_id;

public entry fun create_social_profile(
    username: vector<u8>,
    display_name: vector<u8>,
    bio: vector<u8>,
    ctx: &mut TxContext
) {
    // Create OnoalID
    let onoal_id = onoal_id::register_user_id(
        username,
        display_name,
        bio,
        b"", // avatar URL
        ctx
    );

    // Create social profile
    let profile = social::create_user_profile(
        username,
        display_name,
        bio,
        b"", // avatar URL
        b"", // banner URL
        0, // public privacy
        ctx
    );

    let sender = tx_context::sender(ctx);
    transfer::public_transfer(onoal_id, sender);
    transfer::public_transfer(profile, sender);
}
```

## 🎯 Use Case Examples

### E-Commerce Platform

```move
// Combine tokens, NFTs, and loyalty
module ecommerce::shop {
    use otl::coin;
    use otl::loyalty;
    use otl::collectible;

    // Store loyalty points as tokens
    // Product warranties as NFTs
    // Customer tiers via loyalty program
    // Bulk discounts via batch operations
}
```

### Gaming Platform

```move
// Game assets and currencies
module gaming::platform {
    use otl::collectible; // Game items, characters
    use otl::coin;        // In-game currency
    use otl::social;      // Player profiles
    use otl::ticket;      // Tournament entries
}
```

### Event Management

```move
// Complete event ecosystem
module events::manager {
    use otl::ticket;           // Event tickets
    use otl::events_festivals; // Festival management
    use otl::loyalty;          // Repeat visitor rewards
    use otl::social;           // Attendee networking
}
```

## 🔧 Development Patterns

### 1. Module Initialization Pattern

```move
// Standard pattern for setting up OTL modules
public entry fun initialize_app(ctx: &mut TxContext) {
    // 1. Initialize OTL system
    otl::otl_init::initialize_complete_otl_system(ctx);

    // 2. Create app-specific registries
    let token_registry = coin::create_utility_token_registry(b"App Tokens", ctx);
    let kiosk_registry = kiosk_integration::create_kiosk_registry(ctx);

    // 3. Share objects
    transfer::share_object(token_registry);
    transfer::share_object(kiosk_registry);
}
```

### 2. Batch Operations Pattern

```move
// Efficient batch processing
public entry fun batch_setup(
    recipients: vector<address>,
    amounts: vector<u64>,
    ctx: &mut TxContext
) {
    // Validate inputs
    assert!(vector::length(&recipients) == vector::length(&amounts), 0);
    assert!(vector::length(&recipients) <= 1000, 1); // Max batch size

    // Process in batches
    let mut i = 0;
    while (i < vector::length(&recipients)) {
        // Batch operations here
        i = i + 1;
    };
}
```

### 3. Error Handling Pattern

```move
// Consistent error handling
public fun safe_operation(
    amount: u64,
    recipient: address,
    ctx: &mut TxContext
) {
    // Validate inputs
    assert!(amount > 0, base::invalid_amount_error());
    assert!(utils::validate_address(recipient), base::invalid_address_error());

    // Check permissions
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender), base::not_authorized_error());

    // Perform operation
    // ...
}
```

## 📊 Testing Examples

### Unit Test Pattern

```move
#[test_only]
module app::tests {
    use sui::test_scenario;
    use otl::coin;

    #[test]
    fun test_complete_flow() {
        let mut scenario = test_scenario::begin(@admin);

        // Setup phase
        test_scenario::next_tx(&mut scenario, @admin);
        {
            // Initialize system
        };

        // Test phase
        test_scenario::next_tx(&mut scenario, @user);
        {
            // Test user operations
        };

        // Cleanup
        test_scenario::end(scenario);
    }
}
```

## 🔗 Integration Guides

### Frontend Integration

```typescript
// TypeScript/React example
import { SuiClient } from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";

// Create token purchase transaction
const txb = new TransactionBlock();
txb.moveCall({
  target: `${PACKAGE_ID}::coin::purchase_tokens`,
  arguments: [
    txb.object(TOKEN_TYPE_ID),
    txb.object(SUI_COIN_ID),
    txb.pure(amount),
  ],
});
```

### Backend API

```javascript
// Node.js backend example
const express = require("express");
const { SuiClient } = require("@mysten/sui.js/client");

app.post("/api/mint-nft", async (req, res) => {
  const { collectionId, recipient, metadata } = req.body;

  // Create transaction
  const txb = new TransactionBlock();
  txb.moveCall({
    target: `${PACKAGE_ID}::collectible::mint_nft`,
    arguments: [
      txb.object(collectionId),
      txb.pure(recipient),
      txb.pure(metadata.name),
      // ... other arguments
    ],
  });

  // Execute and return result
  const result = await client.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    signer: keypair,
  });

  res.json({ success: true, digest: result.digest });
});
```

## 📚 Learning Path

### Beginner (Week 1)

1. [Simple Business Token](./simple-business-token.md)
2. [Art Collection](./art-collection.md)
3. [Social Platform](./social-platform.md)

### Intermediate (Week 2-3)

1. [Loyalty Token System](./loyalty-token-system.md)
2. [NFT Marketplace](./nft-marketplace.md)
3. [Concert Tickets](./concert-tickets.md)

### Advanced (Week 4+)

1. [Festival Management](./festival-management.md)
2. [Community DAO](./community-dao.md)
3. [Creator Economy](./creator-economy.md)

## 🆘 Getting Help

- **Questions about examples**: [GitHub Discussions](https://github.com/onoal/Onoal-Token-Library/discussions)
- **Bug reports**: [GitHub Issues](https://github.com/onoal/Onoal-Token-Library/issues)
- **Community support**: [Discord](https://discord.gg/onoal)

## 🤝 Contributing Examples

We welcome community contributions! To add your own example:

1. Fork the repository
2. Create your example in `docs/examples/`
3. Follow the existing format and style
4. Submit a pull request

---

_Happy coding with OTL! 🚀_
