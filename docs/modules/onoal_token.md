# 🪙 ONOAL Token Module

The **ONOAL Token Module** (`otl::onoal_token`) implements the native platform token for the Onoal ecosystem. It provides a comprehensive token system with fixed pricing, supply management, and advanced authorization features.

## 📋 Overview

ONOAL is the native utility token of the Onoal platform, built on top of Sui's `Coin<T>` standard. It features fixed pricing (1 SUI = 1000 ONOAL), a maximum supply of 1 billion tokens, and sophisticated minter management with daily limits and expiration controls.

## 🎯 Key Features

- **🏦 Fixed Pricing** - 1 SUI = 1000 ONOAL tokens (stable exchange rate)
- **📊 Supply Management** - 1 billion max supply with 9 decimals
- **👥 Minter Categories** - 5 specialized minter types with allocations
- **⏰ Daily Limits** - Configurable daily minting limits per minter
- **🔒 Authorization System** - Advanced permission management
- **📈 Purchase System** - Direct SUI-to-ONOAL conversion
- **📊 Analytics** - Comprehensive tracking and reporting

## 💰 Token Economics

### Supply Distribution

| Category         | Allocation | Percentage | Purpose                         |
| ---------------- | ---------- | ---------- | ------------------------------- |
| **Ecosystem**    | 200M ONOAL | 20%        | Community rewards, partnerships |
| **Development**  | 150M ONOAL | 15%        | Development funding, team       |
| **Treasury**     | 300M ONOAL | 30%        | Platform reserves, stability    |
| **Partnerships** | 100M ONOAL | 10%        | Strategic partnerships          |
| **Marketing**    | 50M ONOAL  | 5%         | Marketing campaigns, growth     |
| **Public Sale**  | 200M ONOAL | 20%        | Public token sales              |

### Pricing Model

- **Exchange Rate**: 1 SUI = 1000 ONOAL (fixed)
- **Minimum Purchase**: 0.001 SUI (1 ONOAL)
- **Decimals**: 9 (same as SUI for easy conversion)

## 🏗️ Core Structures

### ONOAL_TOKEN (One Time Witness)

```move
public struct ONOAL_TOKEN has drop {}
```

The One Time Witness used to create the ONOAL coin type, ensuring uniqueness and proper Sui integration.

### OnoalTokenManager

Main management structure for the ONOAL token system.

```move
public struct OnoalTokenManager has key {
    id: UID,
    treasury_cap: TreasuryCap<ONOAL_TOKEN>,
    // Supply tracking
    total_supply: u64,
    circulating_supply: u64,
    max_supply: u64,
    // Pricing
    sui_to_onoal_rate: u64, // 1000 ONOAL per 1 SUI
    // Minter management
    minters: Table<address, MinterInfo>,
    minter_categories: Table<u8, MinterCategory>,
    // Statistics
    total_purchases: u64,
    total_sui_received: u64,
    // Configuration
    is_purchase_enabled: bool,
    emergency_pause: bool,
    authority: address,
}
```

### MinterInfo

Information about individual authorized minters.

```move
public struct MinterInfo has store {
    minter_address: address,
    category: u8,
    daily_limit: u64,
    total_minted: u64,
    daily_minted: u64,
    last_mint_day: u64,
    is_active: bool,
    expires_at: Option<u64>,
    authorized_by: address,
    authorized_at: u64,
}
```

### MinterCategory

Configuration for different minter categories.

```move
public struct MinterCategory has store {
    category_id: u8,
    name: String,
    description: String,
    total_allocation: u64,
    minted_amount: u64,
    max_daily_per_minter: u64,
    is_active: bool,
}
```

### PurchaseReceipt

Receipt for ONOAL token purchases.

```move
public struct PurchaseReceipt has key, store {
    id: UID,
    purchaser: address,
    sui_amount: u64,
    onoal_amount: u64,
    exchange_rate: u64,
    purchased_at: u64,
    transaction_hash: String,
}
```

## 🔧 Core Functions

### Token Management

```move
// Initialize the ONOAL token system
public fun init(otw: ONOAL_TOKEN, ctx: &mut TxContext)

// Create token manager
public fun create_onoal_token_manager(
    treasury_cap: TreasuryCap<ONOAL_TOKEN>,
    ctx: &mut TxContext
): OnoalTokenManager
```

### Minter Management

```move
// Add authorized minter
public fun add_minter(
    manager: &mut OnoalTokenManager,
    minter_address: address,
    category: u8,
    daily_limit: u64,
    expires_at: Option<u64>,
    ctx: &mut TxContext
)

// Remove minter authorization
public fun remove_minter(
    manager: &mut OnoalTokenManager,
    minter_address: address,
    ctx: &mut TxContext
)

// Update minter limits
public fun update_minter_daily_limit(
    manager: &mut OnoalTokenManager,
    minter_address: address,
    new_daily_limit: u64,
    ctx: &mut TxContext
)
```

### Token Operations

```move
// Mint tokens (authorized minters only)
public fun mint_onoal(
    manager: &mut OnoalTokenManager,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext
): Coin<ONOAL_TOKEN>

// Burn tokens
public fun burn_onoal(
    manager: &mut OnoalTokenManager,
    coin: Coin<ONOAL_TOKEN>,
    ctx: &mut TxContext
)

// Purchase ONOAL with SUI
public fun purchase_onoal_with_sui(
    manager: &mut OnoalTokenManager,
    payment: Coin<SUI>,
    ctx: &mut TxContext
): (Coin<ONOAL_TOKEN>, PurchaseReceipt)
```

### Batch Operations

```move
// Batch mint to multiple recipients
public fun batch_mint_onoal(
    manager: &mut OnoalTokenManager,
    recipients: vector<address>,
    amounts: vector<u64>,
    ctx: &mut TxContext
): vector<Coin<ONOAL_TOKEN>>

// Batch airdrop
public fun batch_airdrop(
    manager: &mut OnoalTokenManager,
    recipients: vector<address>,
    amount_per_recipient: u64,
    ctx: &mut TxContext
)
```

## 🎯 Usage Examples

### Initialize ONOAL Token System

```move
// In module init function
fun init(otw: ONOAL_TOKEN, ctx: &mut TxContext) {
    // Create coin metadata
    let (treasury_cap, metadata) = coin::create_currency(
        otw,
        9, // decimals
        b"ONOAL",
        b"Onoal Token",
        b"Native utility token of the Onoal ecosystem",
        option::some(url::new_unsafe_from_bytes(b"https://onoal.com/token-icon.png")),
        ctx
    );

    // Create token manager
    let manager = create_onoal_token_manager(treasury_cap, ctx);

    // Share objects
    transfer::public_share_object(manager);
    transfer::public_freeze_object(metadata);
}
```

### Add Authorized Minter

```move
// Add ecosystem minter with daily limit
onoal_token::add_minter(
    &mut manager,
    @ecosystem_wallet,
    MINTER_CATEGORY_ECOSYSTEM, // category 1
    50_000_000_000, // 50,000 ONOAL daily limit (with 9 decimals)
    option::none(), // no expiration
    ctx
);
```

### Purchase ONOAL Tokens

```move
// Purchase 1000 ONOAL with 1 SUI
let sui_payment = coin::split(&mut sui_coin, 1_000_000_000, ctx); // 1 SUI
let (onoal_tokens, receipt) = onoal_token::purchase_onoal_with_sui(
    &mut manager,
    sui_payment,
    ctx
);

// Transfer tokens to buyer
transfer::public_transfer(onoal_tokens, buyer_address);
transfer::public_transfer(receipt, buyer_address);
```

### Mint Tokens (Authorized Minter)

```move
// Mint 10,000 ONOAL tokens
let minted_tokens = onoal_token::mint_onoal(
    &mut manager,
    10_000_000_000_000, // 10,000 ONOAL (with 9 decimals)
    recipient_address,
    ctx
);

transfer::public_transfer(minted_tokens, recipient_address);
```

### Batch Airdrop

```move
// Airdrop 100 ONOAL to multiple users
let recipients = vector[
    @user1,
    @user2,
    @user3,
];

onoal_token::batch_airdrop(
    &mut manager,
    recipients,
    100_000_000_000, // 100 ONOAL per recipient
    ctx
);
```

## 📊 Minter Categories

### Category 1: Ecosystem (200M allocation)

- **Purpose**: Community rewards, ecosystem growth
- **Daily Limit**: 50,000 ONOAL per minter
- **Use Cases**: Staking rewards, community incentives

### Category 2: Partnerships (100M allocation)

- **Purpose**: Strategic partnerships, integrations
- **Daily Limit**: 25,000 ONOAL per minter
- **Use Cases**: Partner rewards, collaboration incentives

### Category 3: Development (150M allocation)

- **Purpose**: Development funding, team compensation
- **Daily Limit**: 30,000 ONOAL per minter
- **Use Cases**: Developer grants, team payments

### Category 4: Marketing (50M allocation)

- **Purpose**: Marketing campaigns, user acquisition
- **Daily Limit**: 15,000 ONOAL per minter
- **Use Cases**: Campaign rewards, referral bonuses

### Category 5: Treasury (300M allocation)

- **Purpose**: Platform reserves, emergency funds
- **Daily Limit**: 100,000 ONOAL per minter
- **Use Cases**: Platform operations, stability fund

## 🔒 Security Features

### Authorization Checks

- Only authorized minters can mint tokens
- Daily limits prevent excessive minting
- Category allocations ensure proper distribution
- Emergency pause functionality

### Supply Controls

- Hard cap of 1 billion tokens
- Category-based allocation tracking
- Circulating supply monitoring
- Burn functionality for deflationary pressure

## 📈 Analytics & Monitoring

### Key Metrics

- Total supply and circulating supply
- Purchase volume and SUI received
- Minter activity and daily limits
- Category allocation usage

### Events Emitted

- `OnoalTokenMinted` - Token minting events
- `OnoalTokenPurchased` - Purchase transactions
- `MinterAdded/Removed` - Minter management
- `EmergencyPauseActivated` - Security events

## 🚨 Important Notes

1. **Fixed Exchange Rate** - 1 SUI = 1000 ONOAL is hardcoded
2. **Daily Limits Reset** - Limits reset at midnight UTC
3. **Category Allocations** - Cannot exceed predefined allocations
4. **Emergency Controls** - Authority can pause all operations
5. **Sui Integration** - Full compatibility with Sui Coin standard

## 🔗 Integration Examples

### With OTL Wallet

```move
// Add ONOAL tokens to OTL wallet
otl_wallet::add_token_balance(
    &mut wallet,
    onoal_tokens,
    ctx
);
```

### With Kiosk Integration

```move
// List ONOAL tokens on marketplace
kiosk_integration::list_tokens_for_sale(
    &mut kiosk,
    onoal_tokens,
    price_in_sui,
    ctx
);
```

## 📚 Related Documentation

- [Coin Module](./coin.md) - Business token creation
- [Payment Transfer](./payment_transfer.md) - Payment processing
- [OTL Wallet](./otl_wallet.md) - Multi-asset wallet
- [Kiosk Integration](./kiosk_integration.md) - Marketplace features
