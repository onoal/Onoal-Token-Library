# 🪙 Coin Module

The **Coin Module** (`otl::coin`) provides a comprehensive system for creating and managing business tokens built on Sui's `Coin<T>` standard. It enables businesses to create custom fungible tokens with advanced features like dynamic pricing, batch operations, and sophisticated minting controls.

## 📋 Overview

The Coin module allows businesses to create their own branded tokens with customizable features including fixed or dynamic pricing, supply management, batch discounts, and authorized minter systems. Perfect for loyalty programs, utility tokens, and business-specific currencies.

## 🎯 Key Features

- **🏭 Business Token Creation** - Custom tokens for any business use case
- **💰 Flexible Pricing Models** - Fixed, dynamic, or tiered pricing
- **👥 Batch Operations** - Mint thousands of tokens efficiently
- **🎯 Batch Discounts** - Volume-based pricing incentives
- **🔒 Authorized Minters** - Controlled token minting system
- **📊 Supply Management** - Max supply caps and tracking
- **💳 Direct Purchases** - SUI-to-token conversion
- **📈 Analytics** - Comprehensive token metrics

## 🏗️ Core Structures

### UtilityTokenRegistry

Main registry for managing business token types.

```move
public struct UtilityTokenRegistry has key {
    id: UID,

    // Registry info
    name: String,
    description: String,
    authority: address,

    // Token management
    token_types: Table<ID, TokenTypeInfo>,
    total_token_types: u64,

    // Statistics
    total_tokens_minted: u64,
    total_revenue_generated: u64,
    total_purchases: u64,

    // Configuration
    default_decimals: u8,
    min_price_per_token: u64,
    max_batch_size: u64,

    // Timestamps
    created_at: u64,
    last_updated: u64,
}
```

### TokenType

Configuration and state for a specific business token.

```move
public struct TokenType<phantom T> has key {
    id: UID,

    // Token metadata
    name: String,
    symbol: String,
    description: String,
    image_url: String,
    external_url: String,

    // Treasury management
    treasury_cap: TreasuryCap<T>,

    // Supply tracking
    max_supply: u64,
    current_supply: u64,
    circulating_supply: u64,

    // Pricing
    price_per_token: u64, // in MIST (1 SUI = 1,000,000,000 MIST)
    is_price_adjustable: bool,

    // Batch discount system
    batch_discount_threshold: u64, // minimum tokens for discount
    batch_discount_percentage: u64, // discount percentage (basis points)

    // Features
    is_transferable: bool,
    is_burnable: bool,
    decimals: u8,

    // Authorized minters
    authorized_minters: Table<address, MinterInfo>,

    // Statistics
    total_purchases: u64,
    total_revenue: u64,
    total_minted: u64,
    total_burned: u64,

    // Authority
    authority: address,

    // Timestamps
    created_at: u64,
    last_price_update: u64,
}
```

### MinterInfo

Information about authorized token minters.

```move
public struct MinterInfo has store {
    minter_address: address,
    daily_mint_limit: u64,
    total_minted: u64,
    daily_minted: u64,
    last_mint_day: u64,
    is_active: bool,
    authorized_at: u64,
    authorized_by: address,
}
```

### PurchaseReceipt

Receipt for token purchases with detailed information.

```move
public struct PurchaseReceipt has key, store {
    id: UID,

    // Purchase details
    token_type_id: ID,
    purchaser: address,

    // Transaction info
    sui_amount_paid: u64,
    tokens_received: u64,
    price_per_token: u64,

    // Discount info
    original_price: u64,
    discount_applied: u64,
    discount_percentage: u64,

    // Metadata
    purchase_timestamp: u64,
    transaction_hash: String,

    // Token info
    token_name: String,
    token_symbol: String,
}
```

### BatchMintReceipt

Receipt for batch minting operations.

```move
public struct BatchMintReceipt has key, store {
    id: UID,

    // Batch info
    token_type_id: ID,
    batch_id: String,
    minter: address,

    // Recipients and amounts
    recipients: vector<address>,
    amounts: vector<u64>,
    total_minted: u64,

    // Timestamps
    minted_at: u64,

    // Token info
    token_name: String,
    token_symbol: String,
}
```

## 🔧 Core Functions

### Registry Management

```move
// Create utility token registry
public fun create_utility_token_registry(
    name: vector<u8>,
    ctx: &mut TxContext,
): UtilityTokenRegistry

// Create and share registry
public entry fun create_shared_utility_token_registry(
    name: vector<u8>,
    description: vector<u8>,
    ctx: &mut TxContext,
)
```

### Token Type Creation

```move
// Create new token type
public fun create_token_type<T: drop>(
    registry: &mut UtilityTokenRegistry,
    witness: T,
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    price_per_token: u64,
    max_supply: u64,
    decimals: u8,
    is_transferable: bool,
    is_burnable: bool,
    is_price_adjustable: bool,
    batch_discount_threshold: u64,
    batch_discount_percentage: u64,
    ctx: &mut TxContext,
): TokenType<T>

// Create token type with metadata
public fun create_token_type_with_metadata<T: drop>(
    registry: &mut UtilityTokenRegistry,
    witness: T,
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    external_url: vector<u8>,
    price_per_token: u64,
    max_supply: u64,
    decimals: u8,
    is_transferable: bool,
    is_burnable: bool,
    is_price_adjustable: bool,
    batch_discount_threshold: u64,
    batch_discount_percentage: u64,
    ctx: &mut TxContext,
): TokenType<T>
```

### Token Operations

```move
// Purchase tokens with SUI
public fun purchase_tokens<T>(
    token_type: &mut TokenType<T>,
    payment: Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext,
): (Coin<T>, PurchaseReceipt, Coin<SUI>) // Returns tokens, receipt, and change

// Mint tokens (authorized minters only)
public fun mint_tokens<T>(
    token_type: &mut TokenType<T>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
): Coin<T>

// Burn tokens
public fun burn_tokens<T>(
    token_type: &mut TokenType<T>,
    tokens: Coin<T>,
    ctx: &mut TxContext,
)
```

### Batch Operations

```move
// Batch mint to multiple recipients
public fun batch_mint_tokens<T>(
    token_type: &mut TokenType<T>,
    recipients: vector<address>,
    amounts: vector<u64>,
    batch_id: vector<u8>,
    ctx: &mut TxContext,
): (vector<Coin<T>>, BatchMintReceipt)

// Batch airdrop (same amount to all recipients)
public fun batch_airdrop_tokens<T>(
    token_type: &mut TokenType<T>,
    recipients: vector<address>,
    amount_per_recipient: u64,
    ctx: &mut TxContext,
): vector<Coin<T>>

// Batch purchase for multiple recipients
public fun batch_purchase_tokens<T>(
    token_type: &mut TokenType<T>,
    payment: Coin<SUI>,
    recipients: vector<address>,
    amounts: vector<u64>,
    ctx: &mut TxContext,
): (vector<Coin<T>>, PurchaseReceipt, Coin<SUI>)
```

### Minter Management

```move
// Add authorized minter
public fun add_authorized_minter<T>(
    token_type: &mut TokenType<T>,
    minter_address: address,
    daily_mint_limit: u64,
    ctx: &mut TxContext,
)

// Remove authorized minter
public fun remove_authorized_minter<T>(
    token_type: &mut TokenType<T>,
    minter_address: address,
    ctx: &mut TxContext,
)

// Update minter daily limit
public fun update_minter_daily_limit<T>(
    token_type: &mut TokenType<T>,
    minter_address: address,
    new_daily_limit: u64,
    ctx: &mut TxContext,
)
```

### Pricing Management

```move
// Update token price
public fun update_token_price<T>(
    token_type: &mut TokenType<T>,
    new_price: u64,
    ctx: &mut TxContext,
)

// Update batch discount settings
public fun update_batch_discount<T>(
    token_type: &mut TokenType<T>,
    threshold: u64,
    discount_percentage: u64,
    ctx: &mut TxContext,
)

// Calculate purchase cost with discounts
public fun calculate_purchase_cost<T>(
    token_type: &TokenType<T>,
    amount: u64,
): (u64, u64, u64) // (total_cost, original_cost, discount_amount)
```

## 🎯 Usage Examples

### Create Business Token

```move
// Create a coffee shop loyalty token
public entry fun create_coffee_shop_token(ctx: &mut TxContext) {
    // Create registry
    let mut registry = coin::create_utility_token_registry(
        b"Coffee Shop Tokens",
        ctx
    );

    // Create token type
    let token_type = coin::create_token_type_with_metadata(
        &mut registry,
        COFFEE_TOKEN {}, // One-time witness
        b"Coffee Coin",
        b"COFFEE",
        b"Loyalty token for our coffee shop - earn rewards with every purchase!",
        b"https://coffeeshop.com/token-logo.png",
        b"https://coffeeshop.com/loyalty",
        100, // 100 MIST per token (0.0001 SUI)
        1000000, // 1M max supply
        9, // 9 decimals
        true, // transferable
        false, // not burnable
        true, // price adjustable
        50, // 50+ tokens for batch discount
        10, // 10% batch discount
        ctx
    );

    // Share objects
    transfer::share_object(registry);
    transfer::share_object(token_type);
}
```

### Purchase Tokens

```move
// Customer purchases coffee tokens
public entry fun buy_coffee_tokens(
    token_type: &mut TokenType<COFFEE_TOKEN>,
    payment: Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext,
) {
    let (tokens, receipt, change) = coin::purchase_tokens(
        token_type,
        payment,
        amount,
        ctx
    );

    let buyer = tx_context::sender(ctx);
    transfer::public_transfer(tokens, buyer);
    transfer::public_transfer(receipt, buyer);

    // Return change if any
    if (coin::value(&change) > 0) {
        transfer::public_transfer(change, buyer);
    } else {
        coin::destroy_zero(change);
    };
}
```

### Batch Airdrop Campaign

```move
// Airdrop tokens to loyal customers
public entry fun loyalty_airdrop(
    token_type: &mut TokenType<COFFEE_TOKEN>,
    ctx: &mut TxContext,
) {
    // List of loyal customers
    let loyal_customers = vector[
        @customer1,
        @customer2,
        @customer3,
        @customer4,
        @customer5,
    ];

    // Airdrop 100 tokens to each customer
    let tokens = coin::batch_airdrop_tokens(
        token_type,
        loyal_customers,
        100_000_000_000, // 100 tokens (with 9 decimals)
        ctx
    );

    // Tokens are automatically transferred to recipients
    vector::destroy_empty(tokens);
}
```

### Batch Mint for Business Partners

```move
// Mint different amounts for business partners
public entry fun partner_token_distribution(
    token_type: &mut TokenType<COFFEE_TOKEN>,
    ctx: &mut TxContext,
) {
    let partners = vector[
        @partner_cafe_a,
        @partner_cafe_b,
        @partner_roastery,
        @partner_supplier,
    ];

    let amounts = vector[
        50000_000_000_000, // 50,000 tokens for Cafe A
        30000_000_000_000, // 30,000 tokens for Cafe B
        75000_000_000_000, // 75,000 tokens for Roastery
        25000_000_000_000, // 25,000 tokens for Supplier
    ];

    let (tokens, receipt) = coin::batch_mint_tokens(
        token_type,
        partners,
        amounts,
        b"partner_distribution_q1_2024",
        ctx
    );

    // Tokens are automatically transferred to partners
    transfer::public_transfer(receipt, tx_context::sender(ctx));
    vector::destroy_empty(tokens);
}
```

### Set Up Authorized Minters

```move
// Add authorized minters for different business functions
public entry fun setup_minters(
    token_type: &mut TokenType<COFFEE_TOKEN>,
    ctx: &mut TxContext,
) {
    // Add POS system as minter (for customer rewards)
    coin::add_authorized_minter(
        token_type,
        @pos_system,
        10000_000_000_000, // 10,000 tokens daily limit
        ctx
    );

    // Add marketing wallet as minter (for campaigns)
    coin::add_authorized_minter(
        token_type,
        @marketing_wallet,
        5000_000_000_000, // 5,000 tokens daily limit
        ctx
    );

    // Add partnership manager as minter
    coin::add_authorized_minter(
        token_type,
        @partnership_manager,
        20000_000_000_000, // 20,000 tokens daily limit
        ctx
    );
}
```

### Dynamic Pricing Updates

```move
// Update token price based on demand
public entry fun update_pricing(
    token_type: &mut TokenType<COFFEE_TOKEN>,
    new_price: u64,
    new_batch_threshold: u64,
    new_batch_discount: u64,
    ctx: &mut TxContext,
) {
    // Update base price
    coin::update_token_price(
        token_type,
        new_price,
        ctx
    );

    // Update batch discount settings
    coin::update_batch_discount(
        token_type,
        new_batch_threshold,
        new_batch_discount,
        ctx
    );
}
```

## 💰 Pricing Models

### Fixed Pricing

```move
// Simple fixed price per token
let token_type = coin::create_token_type(
    registry,
    witness,
    b"Fixed Price Token",
    b"FPT",
    b"Token with fixed pricing",
    1000, // 1000 MIST per token
    1000000, // max supply
    9, // decimals
    true, false, false, // transferable, not burnable, price not adjustable
    0, 0, // no batch discount
    ctx
);
```

### Dynamic Pricing

```move
// Price adjustable by authority
let token_type = coin::create_token_type(
    registry,
    witness,
    b"Dynamic Price Token",
    b"DPT",
    b"Token with adjustable pricing",
    1000, // initial price
    1000000, // max supply
    9, // decimals
    true, false, true, // transferable, not burnable, price adjustable
    0, 0, // no batch discount initially
    ctx
);
```

### Batch Discount Pricing

```move
// Volume-based pricing with discounts
let token_type = coin::create_token_type(
    registry,
    witness,
    b"Bulk Discount Token",
    b"BDT",
    b"Token with volume discounts",
    1000, // base price
    1000000, // max supply
    9, // decimals
    true, false, true, // transferable, not burnable, price adjustable
    100, // 100+ tokens for discount
    15, // 15% discount
    ctx
);
```

## 📊 Pricing Calculations

### Cost Calculation with Discounts

```move
// Calculate total cost including discounts
let (total_cost, original_cost, discount_amount) = coin::calculate_purchase_cost(
    &token_type,
    150 // buying 150 tokens
);

// If batch threshold is 100 tokens with 15% discount:
// original_cost = 150 * 1000 = 150,000 MIST
// discount_amount = 150,000 * 15% = 22,500 MIST
// total_cost = 150,000 - 22,500 = 127,500 MIST
```

### Tiered Pricing Example

```move
// Implement tiered pricing logic
public fun calculate_tiered_price(amount: u64): u64 {
    if (amount >= 1000) {
        // 1000+ tokens: 20% discount
        utils::calculate_percentage(amount * 1000, 80)
    } else if (amount >= 500) {
        // 500-999 tokens: 15% discount
        utils::calculate_percentage(amount * 1000, 85)
    } else if (amount >= 100) {
        // 100-499 tokens: 10% discount
        utils::calculate_percentage(amount * 1000, 90)
    } else {
        // Less than 100 tokens: full price
        amount * 1000
    }
}
```

## 🔒 Security Features

### Minter Authorization

- **Daily Limits** - Prevent excessive minting
- **Address Whitelisting** - Only authorized addresses can mint
- **Activity Tracking** - Monitor minter behavior
- **Revocation** - Remove minter permissions instantly

### Supply Controls

- **Hard Caps** - Cannot exceed max supply
- **Supply Tracking** - Monitor circulating vs total supply
- **Burn Functionality** - Reduce supply if needed
- **Overflow Protection** - Safe arithmetic operations

### Price Protection

- **Authority Control** - Only token authority can adjust prices
- **Minimum Price** - Prevent price manipulation
- **Price History** - Track price changes
- **Discount Limits** - Reasonable discount percentages

## 📈 Analytics & Metrics

### Token Statistics

```move
// Get comprehensive token statistics
public fun get_token_statistics<T>(
    token_type: &TokenType<T>,
): (u64, u64, u64, u64, u64, u64) {
    (
        token_type.current_supply,
        token_type.circulating_supply,
        token_type.total_purchases,
        token_type.total_revenue,
        token_type.total_minted,
        token_type.total_burned,
    )
}
```

### Purchase Analytics

```move
// Track purchase patterns
public fun get_purchase_analytics<T>(
    token_type: &TokenType<T>,
): (u64, u64, u64) { // (avg_purchase_size, total_discounts_given, revenue_per_day)
    // Implementation would calculate these metrics
    (0, 0, 0)
}
```

## 🔗 Integration Examples

### With OTL Wallet

```move
// Add tokens to OTL wallet
otl_wallet::add_token_balance(
    &mut wallet,
    tokens,
    ctx
);
```

### With Loyalty Module

```move
// Use business tokens in loyalty program
loyalty::create_loyalty_program_with_token(
    &mut loyalty_registry,
    token_type_id,
    b"Coffee Shop Loyalty",
    ctx
);
```

### With Social Module

```move
// Showcase token achievements
social::add_token_achievement(
    &mut profile,
    token_type_id,
    b"Coffee Connoisseur",
    b"Earned 1000+ Coffee Coins",
    ctx
);
```

## 🚨 Important Notes

1. **One-Time Witness** - Each token type needs a unique witness type
2. **Supply Limits** - Cannot mint beyond max supply
3. **Daily Limits** - Minter daily limits reset at midnight UTC
4. **Price Adjustments** - Only possible if `is_price_adjustable` is true
5. **Batch Discounts** - Applied automatically when threshold is met

## 📚 Related Documentation

- [ONOAL Token](./onoal_token.md) - Native platform token
- [Loyalty Module](./loyalty.md) - Loyalty program integration
- [OTL Wallet](./otl_wallet.md) - Multi-asset wallet management
- [Base Module](./base.md) - Error codes and validation
