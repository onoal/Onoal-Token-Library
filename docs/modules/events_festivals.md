# 🎪 Events & Festivals Module

The **Events & Festivals Module** (`otl::events_festivals`) provides a comprehensive event management system with custom festival tokens, registration management, ticketing integration, and event analytics. Perfect for organizing concerts, conferences, festivals, and community events.

## 📋 Overview

The Events & Festivals module enables event organizers to create and manage events with custom tokens, handle registrations, integrate with ticketing systems, and track event analytics. It supports both free and paid events with flexible pricing models.

## 🎯 Key Features

- **🎪 Event Management** - Complete event lifecycle management
- **🪙 Custom Festival Tokens** - Event-specific tokens and rewards
- **🎫 Registration System** - Attendee registration and management
- **💰 Flexible Pricing** - Free, paid, and tiered pricing models
- **🎁 Reward Distribution** - Attendee rewards and commemorative tokens
- **📊 Event Analytics** - Comprehensive event metrics and insights
- **🔗 Integration Ready** - Works with ticket, social, and loyalty modules
- **📱 Mobile Support** - QR codes and mobile check-in

## 🏗️ Core Structures

### EventRegistry

Main registry for managing events and festivals.

```move
public struct EventRegistry has key {
    id: UID,

    // Registry info
    name: String,
    description: String,
    authority: address,

    // Event management
    events: Table<ID, EventInfo>,
    total_events: u64,
    active_events: u64,

    // Festival tokens
    festival_tokens: Table<ID, FestivalTokenInfo>,
    total_festival_tokens: u64,

    // Statistics
    total_registrations: u64,
    total_attendees: u64,
    total_revenue: u64,

    // Configuration
    max_events_per_organizer: u64,
    default_registration_fee: u64,

    // Timestamps
    created_at: u64,
    last_updated: u64,
}
```

### Event

Individual event configuration and management.

```move
public struct Event has key {
    id: UID,

    // Basic event info
    name: String,
    description: String,
    category: String, // concert, conference, festival, workshop, etc.

    // Visual identity
    logo_url: String,
    banner_url: String,
    gallery_urls: vector<String>,

    // Event details
    organizer: address,
    organizer_name: String,
    venue_name: String,
    venue_address: String,

    // Timing
    start_time: u64,
    end_time: u64,
    registration_start: u64,
    registration_end: u64,

    // Capacity and pricing
    max_attendees: Option<u64>,
    current_registrations: u64,
    registration_fee: u64, // 0 for free events

    // Festival token
    has_festival_token: bool,
    festival_token_id: Option<ID>,
    token_reward_amount: u64, // Tokens given to attendees

    // Event features
    requires_approval: bool,
    is_public: bool,
    allow_waitlist: bool,
    has_merchandise: bool,

    // Social features
    allow_social_sharing: bool,
    hashtags: vector<String>,
    social_links: VecMap<String, String>,

    // Status
    event_status: u8, // 0=draft, 1=published, 2=active, 3=completed, 4=cancelled

    // Statistics
    total_revenue: u64,
    total_attendees: u64,
    total_check_ins: u64,

    // Timestamps
    created_at: u64,
    last_updated: u64,
}
```

### FestivalToken

Custom token for specific events or festivals.

```move
public struct FestivalToken<phantom T> has key {
    id: UID,

    // Token metadata
    name: String,
    symbol: String,
    description: String,
    image_url: String,

    // Event association
    event_id: ID,
    event_name: String,

    // Treasury management
    treasury_cap: TreasuryCap<T>,

    // Supply and distribution
    max_supply: u64,
    current_supply: u64,
    attendee_allocation: u64, // Tokens reserved for attendees
    organizer_allocation: u64, // Tokens for organizer

    // Distribution settings
    tokens_per_attendee: u64,
    bonus_for_early_registration: u64,
    bonus_for_social_sharing: u64,

    // Token features
    is_transferable: bool,
    is_commemorative: bool, // Cannot be sold, only kept as memory
    expiry_date: Option<u64>,

    // Statistics
    total_distributed: u64,
    total_claimed: u64,

    // Authority
    token_authority: address,

    // Timestamps
    created_at: u64,
    distribution_started: Option<u64>,
}
```

### EventRegistration

Individual attendee registration record.

```move
public struct EventRegistration has key, store {
    id: UID,

    // Registration info
    event_id: ID,
    attendee: address,

    // Attendee details
    attendee_name: String,
    attendee_email: String,
    attendee_phone: Option<String>,

    // Registration details
    registration_type: u8, // 0=general, 1=vip, 2=speaker, 3=sponsor
    ticket_tier: Option<String>,

    // Payment info
    amount_paid: u64,
    payment_method: String, // "SUI", "ONOAL", "FREE"
    payment_transaction: Option<String>,

    // Status
    registration_status: u8, // 0=pending, 1=confirmed, 2=checked_in, 3=cancelled
    approval_status: u8, // 0=pending, 1=approved, 2=rejected (for approval-required events)

    // Check-in info
    check_in_time: Option<u64>,
    check_in_location: Option<String>,
    qr_code: String, // Unique QR code for check-in

    // Rewards
    festival_tokens_claimed: bool,
    bonus_tokens_earned: u64,

    // Preferences
    dietary_restrictions: Option<String>,
    accessibility_needs: Option<String>,
    t_shirt_size: Option<String>,

    // Timestamps
    registered_at: u64,
    confirmed_at: Option<u64>,
}
```

### EventMerchandise

Merchandise items available for the event.

```move
public struct EventMerchandise has store {
    item_id: ID,

    // Item details
    name: String,
    description: String,
    category: String, // t-shirt, poster, sticker, etc.
    image_url: String,

    // Pricing and availability
    price_sui: u64,
    price_festival_tokens: Option<u64>,
    total_quantity: Option<u64>,
    remaining_quantity: Option<u64>,

    // Item specifications
    sizes_available: vector<String>,
    colors_available: vector<String>,

    // Availability
    available_from: Option<u64>,
    available_until: Option<u64>,
    is_limited_edition: bool,

    // Statistics
    total_sold: u64,
    revenue_generated: u64,
}
```

### EventAnalytics

Comprehensive analytics for event performance.

```move
public struct EventAnalytics has store {
    event_id: ID,

    // Registration metrics
    total_registrations: u64,
    confirmed_registrations: u64,
    cancelled_registrations: u64,
    waitlist_count: u64,

    // Attendance metrics
    total_check_ins: u64,
    check_in_rate: u64, // Percentage
    no_show_count: u64,

    // Revenue metrics
    total_revenue: u64,
    average_ticket_price: u64,
    merchandise_revenue: u64,

    // Engagement metrics
    social_shares: u64,
    festival_tokens_claimed: u64,
    merchandise_sales: u64,

    // Demographics
    registration_by_day: VecMap<u64, u64>,
    attendee_locations: VecMap<String, u64>,

    // Timestamps
    last_updated: u64,
}
```

## 🔧 Core Functions

### Registry Management

```move
// Create event registry
public fun create_event_registry(
    name: vector<u8>,
    description: vector<u8>,
    ctx: &mut TxContext,
): EventRegistry

// Create and share registry
public entry fun create_shared_event_registry(
    name: vector<u8>,
    description: vector<u8>,
    ctx: &mut TxContext,
)
```

### Event Management

```move
// Create event
public fun create_event(
    registry: &mut EventRegistry,
    name: vector<u8>,
    description: vector<u8>,
    category: vector<u8>,
    organizer_name: vector<u8>,
    venue_name: vector<u8>,
    venue_address: vector<u8>,
    start_time: u64,
    end_time: u64,
    registration_fee: u64,
    max_attendees: Option<u64>,
    ctx: &mut TxContext,
): Event

// Update event details
public fun update_event_details(
    event: &mut Event,
    name: Option<vector<u8>>,
    description: Option<vector<u8>>,
    venue_name: Option<vector<u8>>,
    venue_address: Option<vector<u8>>,
    ctx: &mut TxContext,
)

// Publish event (make it public)
public fun publish_event(
    event: &mut Event,
    ctx: &mut TxContext,
)
```

### Festival Token Management

```move
// Create festival token for event
public fun create_festival_token<T: drop>(
    event: &mut Event,
    witness: T,
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    image_url: vector<u8>,
    max_supply: u64,
    tokens_per_attendee: u64,
    ctx: &mut TxContext,
): FestivalToken<T>

// Distribute tokens to attendees
public fun distribute_festival_tokens<T>(
    festival_token: &mut FestivalToken<T>,
    registrations: vector<address>,
    ctx: &mut TxContext,
): vector<Coin<T>>

// Claim festival tokens (for attendees)
public fun claim_festival_tokens<T>(
    festival_token: &mut FestivalToken<T>,
    registration: &EventRegistration,
    ctx: &mut TxContext,
): Coin<T>
```

### Registration Management

```move
// Register for event
public fun register_for_event(
    event: &mut Event,
    attendee_name: vector<u8>,
    attendee_email: vector<u8>,
    attendee_phone: Option<vector<u8>>,
    registration_type: u8,
    payment: Option<Coin<SUI>>,
    ctx: &mut TxContext,
): (EventRegistration, Option<Coin<SUI>>) // Returns registration and change

// Confirm registration (for approval-required events)
public fun confirm_registration(
    event: &mut Event,
    registration: &mut EventRegistration,
    ctx: &mut TxContext,
)

// Check in attendee
public fun check_in_attendee(
    event: &mut Event,
    registration: &mut EventRegistration,
    check_in_location: vector<u8>,
    ctx: &mut TxContext,
)
```

### Merchandise Management

```move
// Add merchandise to event
public fun add_event_merchandise(
    event: &mut Event,
    name: vector<u8>,
    description: vector<u8>,
    category: vector<u8>,
    price_sui: u64,
    price_festival_tokens: Option<u64>,
    total_quantity: Option<u64>,
    ctx: &mut TxContext,
): ID

// Purchase merchandise
public fun purchase_merchandise(
    event: &mut Event,
    merchandise_id: ID,
    payment: Coin<SUI>,
    size: Option<vector<u8>>,
    color: Option<vector<u8>>,
    ctx: &mut TxContext,
): (MerchandisePurchase, Coin<SUI>) // Returns purchase receipt and change
```

## 🎯 Usage Examples

### Create Music Festival

```move
// Create a comprehensive music festival
public entry fun create_summer_music_festival(ctx: &mut TxContext) {
    // Create event registry
    let mut registry = events_festivals::create_event_registry(
        b"Music Festival Registry",
        b"Registry for music festivals and concerts",
        ctx
    );

    // Create the festival event
    let mut festival = events_festivals::create_event(
        &mut registry,
        b"Summer Music Festival 2024",
        b"Three days of amazing music, food, and community in the heart of the city",
        b"Music Festival",
        b"City Events Co.",
        b"Central Park Amphitheater",
        b"123 Park Avenue, Music City",
        1719792000, // July 1, 2024 00:00 UTC
        1720051200, // July 4, 2024 00:00 UTC
        50_000_000_000, // 50 SUI registration fee
        option::some(10000), // Max 10,000 attendees
        ctx
    );

    // Create festival token
    let mut festival_token = events_festivals::create_festival_token(
        &mut festival,
        SUMMER_FEST_TOKEN {},
        b"Summer Fest Token",
        b"SUMMER24",
        b"Commemorative token for Summer Music Festival 2024 attendees",
        b"https://summerfest.com/token-logo.png",
        50000, // 50k max supply
        5, // 5 tokens per attendee
        ctx
    );

    // Add merchandise
    events_festivals::add_event_merchandise(
        &mut festival,
        b"Festival T-Shirt",
        b"Official Summer Music Festival 2024 t-shirt",
        b"Apparel",
        25_000_000_000, // 25 SUI
        option::some(100), // Or 100 festival tokens
        option::some(1000), // 1000 shirts available
        ctx
    );

    events_festivals::add_event_merchandise(
        &mut festival,
        b"Festival Poster",
        b"Limited edition festival poster signed by artists",
        b"Collectibles",
        15_000_000_000, // 15 SUI
        option::some(75), // Or 75 festival tokens
        option::some(500), // 500 posters available
        ctx
    );

    // Publish the event
    events_festivals::publish_event(&mut festival, ctx);

    // Share objects
    transfer::share_object(registry);
    transfer::share_object(festival);
    transfer::share_object(festival_token);
}
```

### Register for Event

```move
// Customer registers for the festival
public entry fun register_for_summer_fest(
    event: &mut Event,
    payment: Coin<SUI>,
    attendee_name: vector<u8>,
    attendee_email: vector<u8>,
    attendee_phone: vector<u8>,
    ctx: &mut TxContext,
) {
    let (registration, change) = events_festivals::register_for_event(
        event,
        attendee_name,
        attendee_email,
        option::some(attendee_phone),
        0, // General registration
        option::some(payment),
        ctx
    );

    let attendee = tx_context::sender(ctx);
    transfer::public_transfer(registration, attendee);

    // Return change if any
    if (coin::value(&change) > 0) {
        transfer::public_transfer(change, attendee);
    } else {
        coin::destroy_zero(change);
    };
}
```

### Event Check-in and Token Distribution

```move
// Check in attendee and distribute festival tokens
public entry fun check_in_and_distribute_tokens(
    event: &mut Event,
    festival_token: &mut FestivalToken<SUMMER_FEST_TOKEN>,
    registration: &mut EventRegistration,
    ctx: &mut TxContext,
) {
    // Check in the attendee
    events_festivals::check_in_attendee(
        event,
        registration,
        b"Main Entrance",
        ctx
    );

    // Claim festival tokens
    let tokens = events_festivals::claim_festival_tokens(
        festival_token,
        registration,
        ctx
    );

    // Transfer tokens to attendee
    transfer::public_transfer(tokens, registration.attendee);
}
```

### Batch Registration Processing

```move
// Process multiple registrations efficiently
public entry fun batch_process_registrations(
    event: &mut Event,
    registrations: vector<ID>,
    ctx: &mut TxContext,
) {
    let mut i = 0;
    while (i < vector::length(&registrations)) {
        let registration_id = *vector::borrow(&registrations, i);

        // In real implementation, you'd get the registration object
        // and process it (confirm, check-in, etc.)

        i = i + 1;
    };
}
```

### Purchase Event Merchandise

```move
// Purchase festival merchandise
public entry fun buy_festival_merch(
    event: &mut Event,
    merchandise_id: ID,
    payment: Coin<SUI>,
    size: vector<u8>,
    color: vector<u8>,
    ctx: &mut TxContext,
) {
    let (purchase, change) = events_festivals::purchase_merchandise(
        event,
        merchandise_id,
        payment,
        option::some(size),
        option::some(color),
        ctx
    );

    let buyer = tx_context::sender(ctx);
    transfer::public_transfer(purchase, buyer);

    // Return change
    if (coin::value(&change) > 0) {
        transfer::public_transfer(change, buyer);
    } else {
        coin::destroy_zero(change);
    };
}
```

## 🎪 Event Categories

### Event Types

| Category       | Description             | Typical Features                           |
| -------------- | ----------------------- | ------------------------------------------ |
| **Concert**    | Music performances      | Artist lineup, venue seating, merchandise  |
| **Conference** | Professional gatherings | Speaker sessions, networking, certificates |
| **Festival**   | Multi-day celebrations  | Multiple stages, camping, food vendors     |
| **Workshop**   | Educational sessions    | Limited capacity, materials, certificates  |
| **Sports**     | Athletic competitions   | Team rosters, scoring, season passes       |
| **Exhibition** | Art and trade shows     | Booth spaces, catalogs, networking         |

### Registration Types

| Type        | Value | Description        | Benefits                                       |
| ----------- | ----- | ------------------ | ---------------------------------------------- |
| **General** | `0`   | Standard attendee  | Basic access, festival tokens                  |
| **VIP**     | `1`   | Premium experience | Priority access, bonus tokens, exclusive areas |
| **Speaker** | `2`   | Event presenter    | Complimentary access, speaker tokens           |
| **Sponsor** | `3`   | Event sponsor      | Branding opportunities, sponsor benefits       |
| **Staff**   | `4`   | Event staff        | Work access, staff tokens                      |
| **Media**   | `5`   | Press and media    | Media access, press kit                        |

## 🪙 Festival Token Economics

### Token Distribution Model

```move
// Example token allocation for a 10,000 attendee festival
let total_supply = 50000; // 50k tokens
let attendee_allocation = 35000; // 70% for attendees (3.5 per person average)
let organizer_allocation = 10000; // 20% for organizer
let bonus_pool = 5000; // 10% for bonuses and rewards
```

### Bonus Token System

- **Early Bird Bonus** - Extra tokens for early registration
- **Social Sharing Bonus** - Tokens for promoting the event
- **Check-in Bonus** - Tokens for actually attending
- **Engagement Bonus** - Tokens for participating in activities
- **Loyalty Bonus** - Extra tokens for repeat attendees

### Token Utility

```move
// Festival tokens can be used for:
// 1. Merchandise purchases
// 2. Food and beverage discounts
// 3. VIP area access
// 4. Future event discounts
// 5. Commemorative collectibles
```

## 📊 Event Analytics

### Registration Analytics

```move
// Get registration statistics
public fun get_registration_analytics(
    event: &Event,
): (u64, u64, u64, u64) {
    (
        event.current_registrations,
        event.total_attendees,
        event.total_check_ins,
        event.total_revenue,
    )
}
```

### Revenue Breakdown

```move
// Analyze revenue sources
public fun get_revenue_breakdown(
    event: &Event,
): (u64, u64, u64) { // (registration_revenue, merchandise_revenue, total_revenue)
    // Implementation would calculate these metrics
    (0, 0, 0)
}
```

### Attendance Patterns

```move
// Track check-in patterns
public fun get_attendance_patterns(
    event: &Event,
): VecMap<u64, u64> { // timestamp -> check-in count
    // Returns check-in patterns by hour/day
    vec_map::empty()
}
```

## 🔗 Integration Examples

### With Ticket Module

```move
// Create event tickets linked to festival
ticket::create_event_tickets(
    &mut ticket_registry,
    event_id,
    b"Summer Fest VIP Pass",
    1000, // 1000 VIP tickets
    ctx
);
```

### With Social Module

```move
// Create event community
social::create_event_community(
    &mut social_registry,
    event_id,
    b"Summer Music Festival 2024 Attendees",
    ctx
);
```

### With Loyalty Module

```move
// Award loyalty points for event attendance
loyalty::award_event_attendance_points(
    &mut loyalty_program,
    &customer,
    event_id,
    500, // 500 loyalty points
    ctx
);
```

## 📱 Mobile Integration

### QR Code System

```move
// Generate QR code for registration
public fun generate_registration_qr(
    registration: &EventRegistration,
): String {
    registration.qr_code
}

// Validate QR code at check-in
public fun validate_check_in_qr(
    event: &Event,
    qr_code: String,
): bool {
    // Validate QR code and return true if valid
    true
}
```

### Mobile Check-in Flow

1. **Attendee arrives** at event venue
2. **Staff scans** QR code from attendee's mobile device
3. **System validates** registration and updates status
4. **Festival tokens** are automatically distributed
5. **Welcome message** is sent to attendee

## 🎁 Reward Distribution

### Automated Distribution

```move
// Automatically distribute tokens on check-in
public fun auto_distribute_on_checkin<T>(
    festival_token: &mut FestivalToken<T>,
    registration: &mut EventRegistration,
    ctx: &mut TxContext,
): Coin<T> {
    // Calculate tokens based on registration type and bonuses
    let base_tokens = festival_token.tokens_per_attendee;
    let bonus_tokens = calculate_bonus_tokens(registration);
    let total_tokens = base_tokens + bonus_tokens;

    // Mint and return tokens
    coin::mint(&mut festival_token.treasury_cap, total_tokens, ctx)
}
```

### Manual Rewards

```move
// Manually award special tokens
public fun award_special_tokens<T>(
    festival_token: &mut FestivalToken<T>,
    recipient: address,
    amount: u64,
    reason: vector<u8>,
    ctx: &mut TxContext,
): Coin<T>
```

## 🚨 Security Features

### Registration Security

- **Unique QR Codes** - Each registration has unique identifier
- **Payment Verification** - All payments are verified on-chain
- **Capacity Limits** - Cannot exceed maximum attendee limits
- **Fraud Prevention** - Duplicate registration detection

### Token Security

- **Supply Limits** - Cannot mint beyond max supply
- **Distribution Tracking** - All token distributions are recorded
- **Authority Control** - Only event organizer can manage tokens
- **Expiration Dates** - Tokens can have expiration dates

## 📚 Related Documentation

- [Ticket Module](./ticket.md) - Event ticketing integration
- [Social Module](./social.md) - Event communities and social features
- [Loyalty Module](./loyalty.md) - Event-based loyalty rewards
- [Coin Module](./coin.md) - Custom festival token creation
