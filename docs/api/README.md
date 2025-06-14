# 📖 OTL API Reference

Complete API documentation for all Onoal Token Library modules, functions, and structures.

## 📚 Module APIs

### 🔧 Core Foundation

- **[Base API](./base.md)** - Error codes, versioning, feature flags
- **[Utils API](./utils.md)** - Validation, string, math utilities
- **[Upgrade API](./upgrade.md)** - Package upgrade management

### 🏛️ Registry System

- **[OTL Registry API](./otl_registry.md)** - Module registration and management
- **[OTL Interfaces API](./otl_interfaces.md)** - Interface compliance system
- **[OTL Adapters API](./otl_adapters.md)** - Backward compatibility
- **[OTL Init API](./otl_init.md)** - System initialization

### 🪙 Token Ecosystem

- **[ONOAL Token API](./onoal_token.md)** - Native platform token
- **[Coin API](./coin.md)** - Business token creation
- **[Collectible API](./collectible.md)** - NFT system
- **[Loyalty API](./loyalty.md)** - Loyalty programs
- **[Ticket API](./ticket.md)** - Event tickets

### 🔧 Infrastructure

- **[Batch Utils API](./batch_utils.md)** - Gas-optimized operations
- **[Permissions API](./permissions.md)** - Access control
- **[Payment Transfer API](./payment_transfer.md)** - Payment processing
- **[Claim Escrow API](./claim_escrow.md)** - Fiat-to-crypto escrow
- **[OTL Wallet API](./otl_wallet.md)** - Multi-asset wallet
- **[Kiosk Integration API](./kiosk_integration.md)** - Marketplace integration

### 🚀 Advanced Features

- **[Social API](./social.md)** - Social profiles and features
- **[OnoalID API](./onoal_id.md)** - Identity system
- **[Namespaces API](./namespaces.md)** - Domain naming
- **[Events & Festivals API](./events_festivals.md)** - Event management

## 🔍 Quick Reference

### Common Patterns

#### Error Handling

```move
use otl::base;

// Standard error checking
assert!(condition, base::not_authorized_error());
assert!(amount > 0, base::invalid_amount_error());
```

#### Feature Flags

```move
// Check if feature is enabled
let has_staking = base::is_feature_enabled(&registry, base::feature_staking());

// Combine features
let features = base::feature_staking() | base::feature_governance();
```

#### Module Registration

```move
// Register module with registry
otl_registry::register_module(
    &mut registry,
    module_name,
    module_type,
    version,
    api_version,
    dependencies,
    provides,
    requires,
    features,
    ctx,
);
```

### Function Categories

| Category       | Description                  | Examples                         |
| -------------- | ---------------------------- | -------------------------------- |
| **Creation**   | Create new objects/resources | `create_*`, `new_*`, `init_*`    |
| **Management** | Manage existing resources    | `add_*`, `remove_*`, `update_*`  |
| **Operations** | Perform actions              | `mint_*`, `burn_*`, `transfer_*` |
| **Queries**    | Read information             | `get_*`, `is_*`, `check_*`       |
| **Batch**      | Bulk operations              | `batch_*`, `bulk_*`, `multi_*`   |

### Return Types

| Pattern     | Description      | Example                                  |
| ----------- | ---------------- | ---------------------------------------- |
| `T`         | Single object    | `create_wallet() -> Wallet`              |
| `(T, U)`    | Multiple returns | `mint_with_receipt() -> (Coin, Receipt)` |
| `vector<T>` | Collection       | `batch_mint() -> vector<NFT>`            |
| `Option<T>` | Optional value   | `get_user() -> Option<User>`             |
| `bool`      | Success/failure  | `is_authorized() -> bool`                |

## 🎯 Usage Patterns

### Initialization Pattern

```move
// 1. Create registry
let registry = otl_registry::create_otl_registry(ctx);

// 2. Register modules
otl_init::setup_full_otl_system(&mut registry, ctx);

// 3. Share registry
transfer::share_object(registry);
```

### Token Creation Pattern

```move
// 1. Create token type
let token_type = coin::create_token_type(/* params */);

// 2. Add authorized minters
coin::add_minter(&mut token_type, minter_address, ctx);

// 3. Mint tokens
let tokens = coin::mint_tokens(&mut token_type, amount, ctx);
```

### NFT Collection Pattern

```move
// 1. Create collection
let collection = collectible::create_collection(/* params */);

// 2. Batch mint NFTs
let (nfts, receipt) = collectible::batch_mint_nfts(
    &mut collection, count, recipient, ctx
);

// 3. Transfer NFTs
// Handle distribution...
```

## 🔗 Cross-Module Integration

### Registry + Modules

```move
// Check if module is available
if (otl_registry::is_module_registered(&registry, "social")) {
    // Use social features
};
```

### Wallet + Assets

```move
// Add different asset types to wallet
otl_wallet::add_token_balance(&mut wallet, tokens, ctx);
otl_wallet::add_collectible(&mut wallet, nft_id, ctx);
```

### Kiosk + Marketplace

```move
// List assets on marketplace
kiosk_integration::list_collectible(&mut kiosk, nft, price, ctx);
kiosk_integration::list_tokens(&mut kiosk, tokens, price, ctx);
```

## 📊 Event Reference

### Common Events

```move
// Module registration
ModuleRegistered { module_id, module_type, version }

// Token operations
TokenMinted { token_type, amount, recipient }
TokenTransferred { from, to, amount }

// NFT operations
CollectionCreated { collection_id, name, max_supply }
BatchMinted { collection_id, start_id, end_id, count }

// Social events
ProfileCreated { profile_id, owner, username }
ShowcaseCreated { showcase_id, name, item_count }
```

## 🚨 Error Reference

### Common Error Codes

| Code | Constant               | When Used                 |
| ---- | ---------------------- | ------------------------- |
| 1001 | `INSUFFICIENT_BALANCE` | Not enough tokens/balance |
| 1002 | `INVALID_AMOUNT`       | Amount is zero or invalid |
| 1003 | `NOT_AUTHORIZED`       | Caller lacks permission   |
| 1004 | `SUPPLY_EXCEEDED`      | Would exceed max supply   |
| 1005 | `INVALID_METADATA`     | Metadata format invalid   |

## 🔧 Development Tools

### Testing Utilities

```move
// Test helpers (in test modules)
use otl::test_utils;

let test_ctx = test_utils::create_test_context();
let test_registry = test_utils::setup_test_registry(&mut test_ctx);
```

### Debug Functions

```move
// Debug information
let info = otl_registry::get_registry_info(&registry);
debug::print(&info);
```

## 📚 Related Documentation

- **[Module Documentation](../modules/)** - Detailed module guides
- **[Developer Guides](../guides/)** - Step-by-step tutorials
- **[Code Examples](../examples/)** - Practical implementations
