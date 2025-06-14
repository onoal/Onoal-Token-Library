# 🎫 Ticket Module

The **Ticket Module** (`otl::ticket`) provides a comprehensive event ticketing system with time-based access control, QR code integration, and batch validation capabilities. Perfect for concerts, conferences, festivals, and any event requiring access management.

## 📋 Overview

The Ticket module enables creation and management of digital event tickets as NFTs with advanced features like access levels, time restrictions, QR code generation, and commemorative functionality. It's designed for both simple events and complex multi-day festivals.

## 🎯 Key Features

- **🎟️ Digital Tickets** - NFT-based tickets with unique identifiers
- **⏰ Time-Based Access** - Configurable validity periods and access windows
- **🔒 Access Levels** - VIP, General, Staff, and custom access tiers
- **📱 QR Code Integration** - Scannable QR codes for entry validation
- **🏆 Commemorative NFTs** - Tickets become collectible memories after events
- **👥 Batch Operations** - Mint and validate thousands of tickets efficiently
- **🎪 Multi-Event Support** - Season passes and festival-wide access
- **📊 Analytics** - Comprehensive attendance and usage tracking

## 🏗️ Core Structures

### TicketRegistry

Main registry for managing all ticket types and events.

```move
public struct TicketRegistry has key {
    id: UID,
    // Registry metadata
    name: String,
    description: String,
    authority: address,

    // Event management
    events: Table<ID, EventInfo>,
    ticket_types: Table<ID, TicketTypeInfo>,

    // Access control
    authorized_validators: Table<address, bool>,
    authorized_minters: Table<address, bool>,

    // Statistics
    total_events: u64,
    total_ticket_types: u64,
    total_tickets_minted: u64,
    total_tickets_validated: u64,

    // Configuration
    default_validity_hours: u64,
    allow_transfers: bool,
    require_qr_validation: bool,
}
```

### EventInfo

Information about a specific event.

```move
public struct EventInfo has store {
    event_id: ID,
    name: String,
    description: String,
    venue: String,

    // Timing
    start_time: u64,
    end_time: u64,
    doors_open_time: u64,

    // Capacity
    max_capacity: u64,
    current_attendance: u64,

    // Configuration
    is_active: bool,
    requires_qr_scan: bool,
    allow_early_entry: bool,

    // Metadata
    image_url: String,
    external_url: String,
    organizer: address,
    created_at: u64,
}
```

### TicketTypeInfo

Configuration for different ticket types within an event.

```move
public struct TicketTypeInfo has store {
    ticket_type_id: ID,
    event_id: ID,

    // Basic info
    name: String, // e.g., "VIP", "General Admission", "Early Bird"
    description: String,

    // Access control
    access_level: u8, // 0=General, 1=VIP, 2=Staff, 3=Artist, 4=Press
    allowed_areas: vector<String>,

    // Pricing and supply
    price: u64,
    max_supply: u64,
    current_supply: u64,

    // Timing
    sale_start_time: u64,
    sale_end_time: u64,
    valid_from: u64,
    valid_until: u64,

    // Features
    is_transferable: bool,
    is_refundable: bool,
    includes_commemorative: bool,

    // Metadata
    ticket_image_url: String,
    perks: vector<String>, // List of included perks
}
```

### Ticket

Individual ticket NFT structure.

```move
public struct Ticket has key, store {
    id: UID,

    // Event and type references
    event_id: ID,
    ticket_type_id: ID,

    // Ticket details
    ticket_number: u64,
    seat_info: Option<String>, // "Section A, Row 5, Seat 12"

    // Access control
    access_level: u8,
    allowed_areas: vector<String>,

    // Validation
    qr_code_data: String,
    is_validated: bool,
    validated_at: Option<u64>,
    validated_by: Option<address>,
    entry_count: u8, // For multi-entry tickets
    max_entries: u8,

    // Timing
    valid_from: u64,
    valid_until: u64,

    // Ownership
    original_purchaser: address,
    current_holder: address,

    // Commemorative features
    is_commemorative: bool,
    attendance_proof: Option<String>, // Proof of attendance data

    // Metadata
    name: String,
    description: String,
    image_url: String,
    attributes: VecMap<String, String>,
}
```

### ValidationRecord

Record of ticket validation for audit trails.

```move
public struct ValidationRecord has store {
    ticket_id: ID,
    event_id: ID,
    validated_at: u64,
    validated_by: address,
    validation_location: String,
    entry_number: u8,
    is_valid_entry: bool,
    notes: String,
}
```

## 🔧 Core Functions

### Registry Management

```move
// Create ticket registry
public fun create_ticket_registry(
    name: vector<u8>,
    description: vector<u8>,
    default_validity_hours: u64,
    allow_transfers: bool,
    require_qr_validation: bool,
    ctx: &mut TxContext,
): TicketRegistry

// Add event to registry
public fun add_event(
    registry: &mut TicketRegistry,
    name: vector<u8>,
    description: vector<u8>,
    venue: vector<u8>,
    start_time: u64,
    end_time: u64,
    doors_open_time: u64,
    max_capacity: u64,
    image_url: vector<u8>,
    external_url: vector<u8>,
    ctx: &mut TxContext,
): ID
```

### Ticket Type Management

```move
// Create ticket type
public fun create_ticket_type(
    registry: &mut TicketRegistry,
    event_id: ID,
    name: vector<u8>,
    description: vector<u8>,
    access_level: u8,
    allowed_areas: vector<String>,
    price: u64,
    max_supply: u64,
    sale_start_time: u64,
    sale_end_time: u64,
    valid_from: u64,
    valid_until: u64,
    is_transferable: bool,
    is_refundable: bool,
    includes_commemorative: bool,
    ticket_image_url: vector<u8>,
    perks: vector<String>,
    ctx: &mut TxContext,
): ID

// Update ticket type
public fun update_ticket_type_pricing(
    registry: &mut TicketRegistry,
    ticket_type_id: ID,
    new_price: u64,
    ctx: &mut TxContext,
)
```

### Ticket Minting

```move
// Mint single ticket
public fun mint_ticket(
    registry: &mut TicketRegistry,
    event_id: ID,
    ticket_type_id: ID,
    recipient: address,
    seat_info: Option<String>,
    ctx: &mut TxContext,
): Ticket

// Batch mint tickets
public fun batch_mint_tickets(
    registry: &mut TicketRegistry,
    event_id: ID,
    ticket_type_id: ID,
    recipients: vector<address>,
    seat_infos: vector<Option<String>>,
    ctx: &mut TxContext,
): vector<Ticket>

// Mint tickets with payment
public fun purchase_tickets(
    registry: &mut TicketRegistry,
    event_id: ID,
    ticket_type_id: ID,
    quantity: u64,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): (vector<Ticket>, Coin<SUI>) // Returns tickets and change
```

### Ticket Validation

```move
// Validate single ticket
public fun validate_ticket(
    registry: &mut TicketRegistry,
    ticket: &mut Ticket,
    validation_location: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): bool

// Batch validate tickets
public fun batch_validate_tickets(
    registry: &mut TicketRegistry,
    tickets: &mut vector<Ticket>,
    validation_location: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): vector<bool>

// Validate by QR code
public fun validate_ticket_by_qr(
    registry: &mut TicketRegistry,
    qr_code_data: String,
    validation_location: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
): bool
```

## 🎯 Usage Examples

### Create Event and Ticket Types

```move
// Create ticket registry
let registry = ticket::create_ticket_registry(
    b"Concert Tickets",
    b"Digital tickets for concerts and events",
    24, // 24 hour default validity
    true, // allow transfers
    true, // require QR validation
    ctx,
);

// Add event
let event_id = ticket::add_event(
    &mut registry,
    b"Summer Music Festival 2024",
    b"Three days of amazing music and entertainment",
    b"Central Park, New York",
    1719792000000, // July 1, 2024 00:00 UTC
    1720051200000, // July 3, 2024 24:00 UTC
    1719788400000, // Doors open 1 hour before
    50000, // max capacity
    b"https://festival.com/poster.jpg",
    b"https://festival.com/event/summer2024",
    ctx,
);

// Create VIP ticket type
let vip_type_id = ticket::create_ticket_type(
    &mut registry,
    event_id,
    b"VIP Pass",
    b"Full festival access with VIP amenities",
    1, // VIP access level
    vector[
        string::utf8(b"main_stage"),
        string::utf8(b"vip_lounge"),
        string::utf8(b"backstage"),
        string::utf8(b"parking")
    ],
    500_000_000_000, // 500 SUI
    1000, // max supply
    1719705600000, // sale start
    1719792000000, // sale end (event start)
    1719792000000, // valid from (event start)
    1720051200000, // valid until (event end)
    true, // transferable
    true, // refundable
    true, // includes commemorative NFT
    b"https://festival.com/vip-ticket.jpg",
    vector[
        string::utf8(b"VIP Lounge Access"),
        string::utf8(b"Complimentary Drinks"),
        string::utf8(b"Meet & Greet"),
        string::utf8(b"Premium Parking")
    ],
    ctx,
);

transfer::share_object(registry);
```

### Purchase Tickets

```move
// Purchase VIP tickets
let sui_payment = coin::split(&mut sui_coin, 1_000_000_000_000, ctx); // 1000 SUI for 2 tickets
let (tickets, change) = ticket::purchase_tickets(
    &mut registry,
    event_id,
    vip_type_id,
    2, // quantity
    sui_payment,
    ctx,
);

// Transfer tickets to buyers
let ticket1 = vector::pop_back(&mut tickets);
let ticket2 = vector::pop_back(&mut tickets);
transfer::public_transfer(ticket1, @buyer1);
transfer::public_transfer(ticket2, @buyer2);
transfer::public_transfer(change, tx_context::sender(ctx));
vector::destroy_empty(tickets);
```

### Batch Mint for Giveaway

```move
// Batch mint general admission tickets for giveaway
let recipients = vector[
    @winner1, @winner2, @winner3, @winner4, @winner5
];

let seat_infos = vector[
    option::some(string::utf8(b"Section B, Row 10, Seat 1")),
    option::some(string::utf8(b"Section B, Row 10, Seat 2")),
    option::some(string::utf8(b"Section B, Row 10, Seat 3")),
    option::some(string::utf8(b"Section B, Row 10, Seat 4")),
    option::some(string::utf8(b"Section B, Row 10, Seat 5")),
];

let giveaway_tickets = ticket::batch_mint_tickets(
    &mut registry,
    event_id,
    general_type_id,
    recipients,
    seat_infos,
    ctx,
);

// Tickets are automatically transferred to recipients
```

### Validate Tickets at Event

```move
// Validate ticket at entrance
let is_valid = ticket::validate_ticket(
    &mut registry,
    &mut ticket,
    b"Main Entrance",
    &clock,
    ctx,
);

if (is_valid) {
    // Allow entry
    event::emit(TicketValidated {
        ticket_id: object::id(&ticket),
        event_id,
        validated_at: clock::timestamp_ms(&clock),
    });
} else {
    // Deny entry - ticket may be expired, already used, or invalid
};
```

### Batch Validation for Groups

```move
// Validate multiple tickets for a group
let validation_results = ticket::batch_validate_tickets(
    &mut registry,
    &mut group_tickets,
    b"VIP Entrance",
    &clock,
    ctx,
);

let mut i = 0;
while (i < vector::length(&validation_results)) {
    let is_valid = *vector::borrow(&validation_results, i);
    if (is_valid) {
        // Process valid ticket
    } else {
        // Handle invalid ticket
    };
    i = i + 1;
};
```

## 🎫 Access Levels

### Standard Access Levels

| Level | Name        | Description        | Typical Areas               |
| ----- | ----------- | ------------------ | --------------------------- |
| `0`   | **General** | Standard admission | Main areas, general seating |
| `1`   | **VIP**     | Premium experience | VIP lounge, premium seating |
| `2`   | **Staff**   | Event staff access | Backstage, staff areas      |
| `3`   | **Artist**  | Performer access   | Green room, stage access    |
| `4`   | **Press**   | Media access       | Press area, photo pit       |

### Custom Access Areas

```move
// Define custom areas for your event
let allowed_areas = vector[
    string::utf8(b"main_stage"),
    string::utf8(b"food_court"),
    string::utf8(b"merchandise"),
    string::utf8(b"vip_lounge"),
    string::utf8(b"backstage"),
    string::utf8(b"parking_premium"),
];
```

## 📱 QR Code Integration

### QR Code Data Format

```move
// QR code contains JSON data:
{
    "ticket_id": "0x1234...abcd",
    "event_id": "0x5678...efgh",
    "ticket_type": "VIP",
    "valid_from": 1719792000000,
    "valid_until": 1720051200000,
    "access_level": 1,
    "checksum": "abc123"
}
```

### Validation Process

1. **Scan QR Code** - Extract ticket data
2. **Verify Checksum** - Ensure data integrity
3. **Check Timing** - Validate current time is within valid window
4. **Validate Ticket** - Call `validate_ticket_by_qr`
5. **Grant/Deny Access** - Based on validation result

## 🏆 Commemorative Features

### Post-Event NFT Conversion

```move
// Convert ticket to commemorative NFT after event
public fun convert_to_commemorative(
    registry: &mut TicketRegistry,
    ticket: &mut Ticket,
    attendance_proof: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
)
```

### Attendance Proof

- **Photo Verification** - Selfie at event location
- **Location Data** - GPS coordinates during event
- **Time Stamps** - Entry and exit times
- **Social Proof** - Social media check-ins

## 📊 Analytics & Reporting

### Event Metrics

```move
// Get comprehensive event statistics
public fun get_event_analytics(
    registry: &TicketRegistry,
    event_id: ID,
): (u64, u64, u64, u64, u64) // (total_tickets, validated_tickets, current_attendance, revenue, refunds)
```

### Ticket Type Performance

```move
// Analyze ticket type sales
public fun get_ticket_type_stats(
    registry: &TicketRegistry,
    ticket_type_id: ID,
): (u64, u64, u64, u64) // (sold, validated, transferred, refunded)
```

## 🚨 Security Features

### Anti-Fraud Measures

- **Unique QR Codes** - Each ticket has unique, non-reproducible QR code
- **Time-Based Validation** - Tickets only valid during specified windows
- **Single-Use Validation** - Prevents ticket reuse (configurable for multi-entry)
- **Checksum Verification** - Cryptographic integrity checks

### Access Control

- **Authorized Validators** - Only approved addresses can validate tickets
- **Minter Permissions** - Controlled ticket minting
- **Transfer Restrictions** - Configurable transfer policies
- **Refund Controls** - Secure refund processing

## 🔗 Integration Examples

### With Events & Festivals Module

```move
// Create festival with multiple events
let festival_registry = events_festivals::create_event_registry(/* params */);
let ticket_registry = ticket::create_ticket_registry(/* params */);

// Link ticket types to festival events
ticket::link_to_festival_event(&mut ticket_registry, &festival_registry, event_id, ctx);
```

### With Social Module

```move
// Add ticket to user showcase
social::add_ticket_to_showcase(
    &mut showcase,
    ticket_id,
    string::utf8(b"My VIP experience at Summer Festival!"),
    ctx,
);
```

### With OTL Wallet

```move
// Add ticket to wallet
otl_wallet::add_ticket(
    &mut wallet,
    ticket,
    ctx,
);
```

## 📚 Related Documentation

- [Events & Festivals](./events_festivals.md) - Complete event management
- [Social Module](./social.md) - User profiles and showcases
- [OTL Wallet](./otl_wallet.md) - Multi-asset wallet management
- [Collectible Module](./collectible.md) - NFT functionality
