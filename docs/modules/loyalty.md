# 🏆 Loyalty Module

The **Loyalty Module** (`otl::loyalty`) provides a comprehensive loyalty program system with point management, tier progression, reward distribution, and customer engagement features. Perfect for businesses wanting to build customer retention and engagement.

## 📋 Overview

The Loyalty module enables businesses to create sophisticated loyalty programs with point accumulation, tier-based benefits, reward redemption, and customer analytics. It supports both token-based and point-based loyalty systems with flexible reward structures.

## 🎯 Key Features

- **🎯 Loyalty Programs** - Complete loyalty program management
- **⭐ Point Systems** - Flexible point accumulation and redemption
- **🏅 Tier Management** - Customer tier progression with benefits
- **🎁 Reward Distribution** - Automated and manual reward systems
- **📊 Customer Analytics** - Engagement tracking and insights
- **🔄 Multi-Program Support** - Multiple loyalty programs per business
- **💰 Token Integration** - Link with business tokens for rewards
- **📱 Mobile Ready** - QR codes and mobile integration

## 🏗️ Core Structures

### LoyaltyRegistry

Main registry for managing loyalty programs.

```move
public struct LoyaltyRegistry has key {
    id: UID,

    // Registry info
    name: String,
    description: String,
    authority: address,

    // Program management
    programs: Table<ID, LoyaltyProgramInfo>,
    total_programs: u64,

    // Customer management
    customers: Table<address, CustomerInfo>,
    total_customers: u64,

    // Statistics
    total_points_issued: u64,
    total_points_redeemed: u64,
    total_rewards_distributed: u64,

    // Configuration
    default_point_value: u64, // Value in MIST
    max_programs_per_business: u64,

    // Timestamps
    created_at: u64,
    last_updated: u64,
}
```

### LoyaltyProgram

Individual loyalty program configuration.

```move
public struct LoyaltyProgram has key {
    id: UID,

    // Program info
    name: String,
    description: String,
    business_name: String,
    logo_url: String,

    // Program configuration
    program_type: u8, // 0=points, 1=token, 2=hybrid
    point_earning_rate: u64, // Points per SUI spent
    point_value: u64, // Value of 1 point in MIST

    // Tier system
    tiers: vector<LoyaltyTier>,
    tier_benefits: Table<u8, TierBenefits>,

    // Token integration
    linked_token_type: Option<ID>,
    token_reward_rate: u64, // Tokens per point redeemed

    // Rewards catalog
    rewards: Table<ID, RewardItem>,
    total_rewards: u64,

    // Program settings
    is_active: bool,
    requires_membership: bool,
    auto_tier_upgrade: bool,
    point_expiry_days: Option<u64>,

    // Statistics
    total_members: u64,
    total_points_issued: u64,
    total_points_redeemed: u64,
    total_transactions: u64,

    // Authority
    program_authority: address,

    // Timestamps
    created_at: u64,
    last_updated: u64,
}
```

### CustomerLoyalty

Customer's loyalty status and points across programs.

```move
public struct CustomerLoyalty has key {
    id: UID,

    // Customer info
    customer_address: address,
    customer_name: String,
    email: Option<String>,
    phone: Option<String>,

    // Program memberships
    memberships: Table<ID, MembershipInfo>,
    total_programs: u64,

    // Overall statistics
    total_points_earned: u64,
    total_points_redeemed: u64,
    total_rewards_claimed: u64,
    lifetime_value: u64,

    // Preferences
    notification_preferences: u8, // Bitfield
    preferred_rewards: vector<String>,

    // Timestamps
    joined_at: u64,
    last_activity: u64,
}
```

### MembershipInfo

Customer's membership in a specific loyalty program.

```move
public struct MembershipInfo has store {
    program_id: ID,
    program_name: String,

    // Points and tier
    current_points: u64,
    lifetime_points: u64,
    current_tier: u8,
    tier_progress: u64, // Points toward next tier

    // Activity tracking
    total_transactions: u64,
    total_spent: u64,
    last_transaction: u64,

    // Rewards
    rewards_claimed: u64,
    pending_rewards: vector<ID>,

    // Status
    is_active: bool,
    membership_level: u8, // 0=basic, 1=premium, 2=vip

    // Timestamps
    joined_at: u64,
    last_tier_upgrade: u64,
}
```

### LoyaltyTier

Configuration for loyalty program tiers.

```move
public struct LoyaltyTier has store {
    tier_level: u8,
    tier_name: String,
    tier_description: String,

    // Requirements
    points_required: u64,
    spending_required: Option<u64>,
    transactions_required: Option<u64>,

    // Benefits
    point_multiplier: u64, // Basis points (10000 = 1x)
    discount_percentage: u64, // Basis points
    exclusive_rewards: bool,
    priority_support: bool,

    // Tier features
    tier_color: String,
    tier_icon_url: String,
    welcome_bonus: u64, // Points awarded on tier upgrade

    // Maintenance
    maintain_spending: Option<u64>, // Required spending to maintain tier
    maintain_period_days: Option<u64>,
}
```

### RewardItem

Individual reward in the loyalty program catalog.

```move
public struct RewardItem has store {
    reward_id: ID,

    // Basic info
    name: String,
    description: String,
    category: String,
    image_url: String,

    // Cost and availability
    point_cost: u64,
    token_cost: Option<u64>,
    cash_value: u64, // Value in MIST

    // Availability
    total_quantity: Option<u64>, // None = unlimited
    remaining_quantity: Option<u64>,
    min_tier_required: u8,

    // Reward type
    reward_type: u8, // 0=discount, 1=product, 2=service, 3=token, 4=experience
    reward_data: String, // JSON data for reward specifics

    // Validity
    valid_from: Option<u64>,
    valid_until: Option<u64>,
    usage_limit_per_customer: Option<u64>,

    // Status
    is_active: bool,
    is_featured: bool,

    // Statistics
    total_redeemed: u64,
    popularity_score: u64,
}
```

### RewardClaim

Record of a customer claiming a reward.

```move
public struct RewardClaim has key, store {
    id: UID,

    // Claim info
    program_id: ID,
    reward_id: ID,
    customer: address,

    // Claim details
    points_spent: u64,
    tokens_spent: Option<u64>,
    claim_code: String, // Unique redemption code

    // Status
    claim_status: u8, // 0=pending, 1=approved, 2=redeemed, 3=expired

    // Metadata
    reward_name: String,
    reward_description: String,

    // Timestamps
    claimed_at: u64,
    expires_at: Option<u64>,
    redeemed_at: Option<u64>,

    // Redemption info
    redemption_location: Option<String>,
    redemption_notes: Option<String>,
}
```

## 🔧 Core Functions

### Registry Management

```move
// Create loyalty registry
public fun create_loyalty_registry(
    name: vector<u8>,
    description: vector<u8>,
    default_point_value: u64,
    ctx: &mut TxContext,
): LoyaltyRegistry

// Create and share registry
public entry fun create_shared_loyalty_registry(
    name: vector<u8>,
    description: vector<u8>,
    default_point_value: u64,
    ctx: &mut TxContext,
)
```

### Loyalty Program Management

```move
// Create loyalty program
public fun create_loyalty_program(
    registry: &mut LoyaltyRegistry,
    name: vector<u8>,
    description: vector<u8>,
    business_name: vector<u8>,
    logo_url: vector<u8>,
    program_type: u8,
    point_earning_rate: u64,
    point_value: u64,
    ctx: &mut TxContext,
): LoyaltyProgram

// Add tier to program
public fun add_loyalty_tier(
    program: &mut LoyaltyProgram,
    tier_level: u8,
    tier_name: vector<u8>,
    tier_description: vector<u8>,
    points_required: u64,
    point_multiplier: u64,
    discount_percentage: u64,
    ctx: &mut TxContext,
)

// Add reward to program
public fun add_reward_item(
    program: &mut LoyaltyProgram,
    name: vector<u8>,
    description: vector<u8>,
    category: vector<u8>,
    point_cost: u64,
    cash_value: u64,
    reward_type: u8,
    min_tier_required: u8,
    ctx: &mut TxContext,
): ID
```

### Customer Management

```move
// Register customer
public fun register_customer(
    registry: &mut LoyaltyRegistry,
    customer_name: vector<u8>,
    email: Option<vector<u8>>,
    phone: Option<vector<u8>>,
    ctx: &mut TxContext,
): CustomerLoyalty

// Join loyalty program
public fun join_loyalty_program(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    ctx: &mut TxContext,
)

// Award points to customer
public fun award_points(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    points: u64,
    transaction_amount: u64,
    ctx: &mut TxContext,
)
```

### Point Operations

```move
// Earn points from purchase
public fun earn_points_from_purchase(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    purchase_amount: u64,
    ctx: &mut TxContext,
): u64 // Returns points earned

// Redeem points for reward
public fun redeem_points_for_reward(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    reward_id: ID,
    ctx: &mut TxContext,
): RewardClaim

// Transfer points between customers
public fun transfer_points(
    program: &mut LoyaltyProgram,
    from_customer: &mut CustomerLoyalty,
    to_customer: &mut CustomerLoyalty,
    points: u64,
    ctx: &mut TxContext,
)
```

### Tier Management

```move
// Check and upgrade customer tier
public fun check_tier_upgrade(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    ctx: &mut TxContext,
): bool // Returns true if upgraded

// Manually upgrade customer tier
public fun upgrade_customer_tier(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    new_tier: u8,
    ctx: &mut TxContext,
)

// Get tier benefits
public fun get_tier_benefits(
    program: &LoyaltyProgram,
    tier_level: u8,
): (u64, u64, bool) // (point_multiplier, discount_percentage, exclusive_rewards)
```

## 🎯 Usage Examples

### Create Coffee Shop Loyalty Program

```move
// Create a comprehensive loyalty program for a coffee shop
public entry fun create_coffee_loyalty_program(ctx: &mut TxContext) {
    // Create loyalty registry
    let mut registry = loyalty::create_loyalty_registry(
        b"Coffee Shop Loyalty Programs",
        b"Loyalty programs for coffee shops and cafes",
        1000, // 1000 MIST per point
        ctx
    );

    // Create loyalty program
    let mut program = loyalty::create_loyalty_program(
        &mut registry,
        b"Bean There Loyalty",
        b"Earn points with every coffee purchase and unlock exclusive rewards",
        b"Bean There Coffee",
        b"https://beanthere.com/logo.png",
        0, // Points-based program
        100, // 100 points per 1 SUI spent
        1000, // 1 point = 1000 MIST value
        ctx
    );

    // Add loyalty tiers
    loyalty::add_loyalty_tier(
        &mut program,
        0, // Bronze tier
        b"Coffee Lover",
        b"Welcome to our loyalty program!",
        0, // No points required
        10000, // 1x point multiplier
        0, // No discount
        ctx
    );

    loyalty::add_loyalty_tier(
        &mut program,
        1, // Silver tier
        b"Coffee Enthusiast",
        b"Enjoy 5% discount on all purchases",
        1000, // 1000 points required
        11000, // 1.1x point multiplier
        500, // 5% discount
        ctx
    );

    loyalty::add_loyalty_tier(
        &mut program,
        2, // Gold tier
        b"Coffee Connoisseur",
        b"Enjoy 10% discount and exclusive rewards",
        5000, // 5000 points required
        12000, // 1.2x point multiplier
        1000, // 10% discount
        ctx
    );

    // Add rewards to catalog
    loyalty::add_reward_item(
        &mut program,
        b"Free Coffee",
        b"Redeem for any regular coffee drink",
        b"Beverages",
        500, // 500 points
        5_000_000_000, // 5 SUI value
        1, // Product reward
        0, // Available to all tiers
        ctx
    );

    loyalty::add_reward_item(
        &mut program,
        b"Free Pastry",
        b"Choose any pastry from our selection",
        b"Food",
        300, // 300 points
        3_000_000_000, // 3 SUI value
        1, // Product reward
        0, // Available to all tiers
        ctx
    );

    loyalty::add_reward_item(
        &mut program,
        b"Coffee Tasting Session",
        b"Exclusive coffee tasting with our master roaster",
        b"Experiences",
        2000, // 2000 points
        20_000_000_000, // 20 SUI value
        4, // Experience reward
        2, // Gold tier only
        ctx
    );

    // Share objects
    transfer::share_object(registry);
    transfer::share_object(program);
}
```

### Customer Registration and Program Joining

```move
// Customer registers and joins loyalty program
public entry fun join_coffee_loyalty(
    registry: &mut LoyaltyRegistry,
    program: &mut LoyaltyProgram,
    customer_name: vector<u8>,
    email: vector<u8>,
    ctx: &mut TxContext,
) {
    // Register customer
    let mut customer = loyalty::register_customer(
        registry,
        customer_name,
        option::some(email),
        option::none(), // No phone
        ctx
    );

    // Join loyalty program
    loyalty::join_loyalty_program(
        program,
        &mut customer,
        ctx
    );

    // Transfer customer loyalty object
    transfer::public_transfer(customer, tx_context::sender(ctx));
}
```

### Earning Points from Purchases

```move
// Customer makes purchase and earns points
public entry fun make_purchase_and_earn_points(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    purchase_amount: u64, // Amount in MIST
    ctx: &mut TxContext,
) {
    // Award points based on purchase
    let points_earned = loyalty::earn_points_from_purchase(
        program,
        customer,
        purchase_amount,
        ctx
    );

    // Check for tier upgrade
    let upgraded = loyalty::check_tier_upgrade(
        program,
        customer,
        ctx
    );

    if (upgraded) {
        // Customer was upgraded - could emit event or send notification
    };
}
```

### Redeeming Rewards

```move
// Customer redeems points for a reward
public entry fun redeem_free_coffee(
    program: &mut LoyaltyProgram,
    customer: &mut CustomerLoyalty,
    reward_id: ID,
    ctx: &mut TxContext,
) {
    // Redeem points for reward
    let claim = loyalty::redeem_points_for_reward(
        program,
        customer,
        reward_id,
        ctx
    );

    // Transfer claim to customer
    transfer::public_transfer(claim, tx_context::sender(ctx));
}
```

### Batch Point Awards

```move
// Award points to multiple customers (e.g., for special promotion)
public entry fun special_promotion_points(
    program: &mut LoyaltyProgram,
    customers: vector<address>,
    bonus_points: u64,
    ctx: &mut TxContext,
) {
    let mut i = 0;
    while (i < vector::length(&customers)) {
        let customer_addr = *vector::borrow(&customers, i);

        // In real implementation, you'd need to get customer objects
        // This is simplified for example purposes

        i = i + 1;
    };
}
```

## 🏅 Tier System

### Standard Tier Structure

| Tier  | Name         | Points Required | Benefits                                     |
| ----- | ------------ | --------------- | -------------------------------------------- |
| **0** | Bronze/Basic | 0               | Standard point earning                       |
| **1** | Silver       | 1,000           | 1.1x points, 5% discount                     |
| **2** | Gold         | 5,000           | 1.2x points, 10% discount, exclusive rewards |
| **3** | Platinum     | 15,000          | 1.5x points, 15% discount, priority support  |
| **4** | Diamond      | 50,000          | 2x points, 20% discount, VIP experiences     |

### Tier Benefits Configuration

```move
// Configure tier benefits
public fun configure_tier_benefits(
    program: &mut LoyaltyProgram,
    tier_level: u8,
    point_multiplier: u64, // Basis points (10000 = 1x)
    discount_percentage: u64, // Basis points (1000 = 10%)
    exclusive_rewards: bool,
    priority_support: bool,
    ctx: &mut TxContext,
)
```

## 🎁 Reward Categories

### Reward Types

| Type           | Value | Description                  | Examples                        |
| -------------- | ----- | ---------------------------- | ------------------------------- |
| **Discount**   | `0`   | Percentage or fixed discount | 10% off, $5 off                 |
| **Product**    | `1`   | Free or discounted products  | Free coffee, pastry             |
| **Service**    | `2`   | Service-based rewards        | Free delivery, priority service |
| **Token**      | `3`   | Business token rewards       | Bonus tokens, token multipliers |
| **Experience** | `4`   | Special experiences          | Tasting sessions, events        |

### Reward Configuration

```move
// Add experience reward
loyalty::add_reward_item(
    &mut program,
    b"VIP Coffee Cupping",
    b"Private coffee cupping session with our head roaster",
    b"Experiences",
    5000, // 5000 points
    50_000_000_000, // 50 SUI value
    4, // Experience type
    3, // Platinum tier required
    ctx
);
```

## 📊 Analytics & Insights

### Customer Analytics

```move
// Get customer loyalty statistics
public fun get_customer_analytics(
    customer: &CustomerLoyalty,
): (u64, u64, u64, u64, u64) {
    (
        customer.total_points_earned,
        customer.total_points_redeemed,
        customer.total_rewards_claimed,
        customer.lifetime_value,
        customer.total_programs,
    )
}
```

### Program Performance

```move
// Get program performance metrics
public fun get_program_analytics(
    program: &LoyaltyProgram,
): (u64, u64, u64, u64) {
    (
        program.total_members,
        program.total_points_issued,
        program.total_points_redeemed,
        program.total_transactions,
    )
}
```

### Tier Distribution

```move
// Analyze tier distribution
public fun get_tier_distribution(
    program: &LoyaltyProgram,
): vector<u64> {
    // Returns count of customers in each tier
    vector[0, 0, 0, 0, 0] // Placeholder
}
```

## 🔗 Integration Examples

### With Business Tokens

```move
// Link loyalty program to business token
loyalty::link_token_to_program(
    &mut program,
    token_type_id,
    100, // 100 tokens per 1000 points
    ctx
);

// Redeem points for tokens
loyalty::redeem_points_for_tokens(
    &mut program,
    &mut customer,
    1000, // points to redeem
    ctx
);
```

### With Social Module

```move
// Add loyalty achievements to social profile
social::add_loyalty_achievement(
    &mut profile,
    program_id,
    b"Coffee Connoisseur",
    b"Reached Gold tier in Bean There Loyalty",
    ctx
);
```

### With Events

```move
// Create event-specific loyalty bonuses
loyalty::create_event_bonus(
    &mut program,
    event_id,
    200, // 2x points during event
    ctx
);
```

## 🚨 Security Features

### Point Security

- **Audit Trail** - All point transactions are recorded
- **Fraud Detection** - Unusual point earning patterns flagged
- **Expiration** - Points can expire to prevent hoarding
- **Transfer Limits** - Limits on point transfers between customers

### Reward Security

- **Unique Codes** - Each reward claim has unique redemption code
- **Expiration** - Reward claims expire after set period
- **Usage Limits** - Limits on reward redemptions per customer
- **Verification** - Business can verify reward claims before fulfillment

## 📱 Mobile Integration

### QR Code Support

```move
// Generate QR code for reward claim
public fun generate_claim_qr_code(
    claim: &RewardClaim,
): String {
    // Returns QR code data for mobile scanning
    claim.claim_code
}
```

### Mobile Notifications

- **Point Earnings** - Notify when points are earned
- **Tier Upgrades** - Celebrate tier progressions
- **Reward Availability** - Alert about new rewards
- **Expiration Warnings** - Remind about expiring points/rewards

## 📚 Related Documentation

- [Coin Module](./coin.md) - Business token integration
- [Social Module](./social.md) - Social features and achievements
- [Events & Festivals](./events_festivals.md) - Event-based loyalty bonuses
- [OTL Wallet](./otl_wallet.md) - Loyalty point management
