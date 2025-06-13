#[allow(unused_const, duplicate_alias)]
module otl::ticket;

use otl::base;
use otl::utils;
use std::string::{Self, String};
use sui::clock::{Self, Clock};
use sui::display;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::package;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};

// ===== Constants =====
const TICKET_STATUS_UNUSED: u8 = 0;
const TICKET_STATUS_USED: u8 = 1;
const TICKET_STATUS_EXPIRED: u8 = 2;

// ===== Core Structs =====

/// Event manager that controls ticket creation and metadata
public struct Event has key {
    id: UID,
    /// Event organizer/admin
    authority: address,
    /// Event metadata
    name: String,
    description: String,
    venue: String,
    /// Event timing
    event_date: u64, // timestamp in milliseconds
    sale_start: u64, // when ticket sales start
    sale_end: u64, // when ticket sales end
    /// Event images
    image_url: String,
    poster_url: String,
    external_url: String,
    /// Ticket supply
    max_tickets: u64,
    current_tickets: u64,
    tickets_used: u64,
    /// Ticket registry
    tickets: Table<u64, ID>, // maps ticket_id to Ticket object ID
    /// Authorized ticket issuers
    issuers: VecMap<address, bool>,
    /// Event-specific attributes
    event_attributes: VecMap<String, String>,
}

/// Digital ticket that can be redeemed once
public struct Ticket has key, store {
    id: UID,
    /// Reference to the event
    event: ID,
    /// Unique ticket ID within the event
    ticket_id: u64,
    /// Ticket holder info
    holder: address,
    /// Ticket status
    status: u8, // 0 = unused, 1 = used, 2 = expired
    /// Ticket metadata
    ticket_type: String, // VIP, General, Early Bird, etc.
    seat_info: String, // Section A, Row 5, Seat 12, etc.
    price_paid: u64, // Price paid in MIST
    /// Timing
    issued_at: u64,
    redeemed_at: u64, // 0 if not redeemed
    /// Ticket-specific attributes (access level, perks, etc.)
    ticket_attributes: VecMap<String, String>,
    /// Commemorative metadata (filled after use)
    commemorative_title: String,
    commemorative_description: String,
    commemorative_image: String,
}

/// One-time witness for creating Display
public struct TICKET has drop {}

// ===== Events =====

public struct EventCreated has copy, drop {
    event_id: ID,
    authority: address,
    name: String,
    event_date: u64,
    max_tickets: u64,
}

public struct TicketIssued has copy, drop {
    event_id: ID,
    ticket_id: ID,
    ticket_number: u64,
    holder: address,
    ticket_type: String,
}

public struct TicketRedeemed has copy, drop {
    event_id: ID,
    ticket_id: ID,
    ticket_number: u64,
    holder: address,
    redeemed_at: u64,
}

public struct TicketTransformed has copy, drop {
    ticket_id: ID,
    holder: address,
    commemorative_title: String,
}

// ===== Event Management =====

/// Create a new event for ticket issuance
public fun create_event(
    name: vector<u8>,
    description: vector<u8>,
    venue: vector<u8>,
    event_date: u64,
    sale_start: u64,
    sale_end: u64,
    image_url: vector<u8>,
    poster_url: vector<u8>,
    external_url: vector<u8>,
    max_tickets: u64,
    ctx: &mut TxContext,
): Event {
    // Validate event parameters
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());
    assert!(!vector::is_empty(&venue), base::invalid_metadata_error());
    assert!(event_date > sale_end, base::invalid_metadata_error());
    assert!(sale_start < sale_end, base::invalid_metadata_error());
    assert!(max_tickets > 0, base::invalid_supply_error());

    let authority = tx_context::sender(ctx);
    assert!(utils::validate_address(authority), base::not_authorized_error());

    let event = Event {
        id: object::new(ctx),
        authority,
        name: utils::safe_utf8(name),
        description: utils::safe_utf8(description),
        venue: utils::safe_utf8(venue),
        event_date,
        sale_start,
        sale_end,
        image_url: utils::safe_utf8(image_url),
        poster_url: utils::safe_utf8(poster_url),
        external_url: utils::safe_utf8(external_url),
        max_tickets,
        current_tickets: 0,
        tickets_used: 0,
        tickets: table::new(ctx),
        issuers: vec_map::empty(),
        event_attributes: vec_map::empty(),
    };

    event::emit(EventCreated {
        event_id: object::id(&event),
        authority,
        name: event.name,
        event_date,
        max_tickets,
    });

    event
}

/// Create event and share it
public entry fun create_shared_event(
    name: vector<u8>,
    description: vector<u8>,
    venue: vector<u8>,
    event_date: u64,
    sale_start: u64,
    sale_end: u64,
    image_url: vector<u8>,
    poster_url: vector<u8>,
    external_url: vector<u8>,
    max_tickets: u64,
    ctx: &mut TxContext,
) {
    let event = create_event(
        name,
        description,
        venue,
        event_date,
        sale_start,
        sale_end,
        image_url,
        poster_url,
        external_url,
        max_tickets,
        ctx,
    );
    transfer::share_object(event);
}

/// Initialize Display for Tickets
public fun init_display(otw: TICKET, ctx: &mut TxContext) {
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"ticket_type"),
        string::utf8(b"seat_info"),
        string::utf8(b"status"),
        string::utf8(b"venue"),
        string::utf8(b"event_date"),
    ];

    let values = vector[
        string::utf8(b"Ticket #{ticket_id}"),
        string::utf8(b"{commemorative_description}"),
        string::utf8(b"{commemorative_image}"),
        string::utf8(b"{ticket_type}"),
        string::utf8(b"{seat_info}"),
        string::utf8(b"{status}"),
        string::utf8(b"Digital Event Ticket"),
        string::utf8(b"{event_date}"),
    ];

    let publisher = package::claim(otw, ctx);
    let mut display = display::new_with_fields<Ticket>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display::update_version(&mut display);
    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
}

/// Add authorized ticket issuer
public fun add_issuer(event: &mut Event, issuer: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == event.authority, base::not_authorized_error());
    assert!(utils::validate_address(issuer), base::not_authorized_error());
    assert!(!vec_map::contains(&event.issuers, &issuer), base::minter_exists_error());

    vec_map::insert(&mut event.issuers, issuer, true);
}

// ===== Ticket Operations =====

/// Issue a new ticket for an event
public fun issue_ticket(
    event: &mut Event,
    recipient: address,
    ticket_type: vector<u8>,
    seat_info: vector<u8>,
    price_paid: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): Ticket {
    let sender = tx_context::sender(ctx);
    assert!(
        sender == event.authority || vec_map::contains(&event.issuers, &sender),
        base::not_authorized_error(),
    );
    assert!(utils::validate_address(recipient), base::not_authorized_error());
    assert!(event.current_tickets < event.max_tickets, base::supply_exceeded_error());

    let current_time = clock::timestamp_ms(clock);
    assert!(current_time >= event.sale_start, base::invalid_metadata_error());
    assert!(current_time <= event.sale_end, base::invalid_metadata_error());

    let ticket_number = event.current_tickets + 1;
    event.current_tickets = ticket_number;

    let ticket = Ticket {
        id: object::new(ctx),
        event: object::id(event),
        ticket_id: ticket_number,
        holder: recipient,
        status: TICKET_STATUS_UNUSED,
        ticket_type: utils::safe_utf8(ticket_type),
        seat_info: utils::safe_utf8(seat_info),
        price_paid,
        issued_at: current_time,
        redeemed_at: 0,
        ticket_attributes: vec_map::empty(),
        commemorative_title: string::utf8(b""),
        commemorative_description: string::utf8(b""),
        commemorative_image: string::utf8(b""),
    };

    // Register ticket in event
    table::add(&mut event.tickets, ticket_number, object::id(&ticket));

    event::emit(TicketIssued {
        event_id: object::id(event),
        ticket_id: object::id(&ticket),
        ticket_number,
        holder: recipient,
        ticket_type: ticket.ticket_type,
    });

    ticket
}

/// Issue ticket and transfer to recipient
public entry fun issue_ticket_to_recipient(
    event: &mut Event,
    recipient: address,
    ticket_type: vector<u8>,
    seat_info: vector<u8>,
    price_paid: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let ticket = issue_ticket(event, recipient, ticket_type, seat_info, price_paid, clock, ctx);
    transfer::public_transfer(ticket, recipient);
}

/// Redeem a ticket (use it once)
public fun redeem_ticket(
    event: &mut Event,
    ticket: &mut Ticket,
    commemorative_title: vector<u8>,
    commemorative_description: vector<u8>,
    commemorative_image: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(ticket.event == object::id(event), base::token_not_found_error());
    assert!(ticket.status == TICKET_STATUS_UNUSED, base::invalid_metadata_error());

    let current_time = clock::timestamp_ms(clock);

    // Check if event has started (can only redeem on or after event date)
    assert!(current_time >= event.event_date, base::invalid_metadata_error());

    // Update ticket status
    ticket.status = TICKET_STATUS_USED;
    ticket.redeemed_at = current_time;
    event.tickets_used = event.tickets_used + 1;

    // Transform into commemorative collectible
    ticket.commemorative_title = utils::safe_utf8(commemorative_title);
    ticket.commemorative_description = utils::safe_utf8(commemorative_description);
    ticket.commemorative_image = utils::safe_utf8(commemorative_image);

    event::emit(TicketRedeemed {
        event_id: object::id(event),
        ticket_id: object::id(ticket),
        ticket_number: ticket.ticket_id,
        holder: ticket.holder,
        redeemed_at: current_time,
    });

    event::emit(TicketTransformed {
        ticket_id: object::id(ticket),
        holder: ticket.holder,
        commemorative_title: ticket.commemorative_title,
    });
}

/// Redeem ticket entry function
public entry fun redeem_ticket_entry(
    event: &mut Event,
    ticket: &mut Ticket,
    commemorative_title: vector<u8>,
    commemorative_description: vector<u8>,
    commemorative_image: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    redeem_ticket(
        event,
        ticket,
        commemorative_title,
        commemorative_description,
        commemorative_image,
        clock,
        ctx,
    );
}

/// Transfer ticket to new holder
public entry fun transfer_ticket(ticket: Ticket, recipient: address, ctx: &mut TxContext) {
    assert!(utils::validate_address(recipient), base::not_authorized_error());
    assert!(ticket.status == TICKET_STATUS_UNUSED, base::invalid_metadata_error());

    transfer::public_transfer(ticket, recipient);
}

/// Mark expired tickets (only authority)
public fun mark_ticket_expired(
    event: &mut Event,
    ticket: &mut Ticket,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == event.authority, base::not_authorized_error());
    assert!(ticket.event == object::id(event), base::token_not_found_error());
    assert!(ticket.status == TICKET_STATUS_UNUSED, base::invalid_metadata_error());

    let current_time = clock::timestamp_ms(clock);
    // Tickets expire 24 hours after event end (example logic)
    let expiry_time = event.event_date + (24 * 60 * 60 * 1000); // 24 hours in ms
    assert!(current_time > expiry_time, base::invalid_metadata_error());

    ticket.status = TICKET_STATUS_EXPIRED;
}

// ===== Attribute Management =====

/// Add attribute to ticket
public fun add_ticket_attribute(
    ticket: &mut Ticket,
    key: vector<u8>,
    value: vector<u8>,
    ctx: &mut TxContext,
) {
    vec_map::insert(&mut ticket.ticket_attributes, utils::safe_utf8(key), utils::safe_utf8(value));
}

/// Add attribute to event
public fun add_event_attribute(
    event: &mut Event,
    key: vector<u8>,
    value: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == event.authority, base::not_authorized_error());
    vec_map::insert(&mut event.event_attributes, utils::safe_utf8(key), utils::safe_utf8(value));
}

// ===== View Functions =====

/// Get event info
public fun get_event_info(event: &Event): (String, String, String, u64, u64, u64, u64) {
    (
        event.name,
        event.description,
        event.venue,
        event.event_date,
        event.max_tickets,
        event.current_tickets,
        event.tickets_used,
    )
}

/// Get ticket info
public fun get_ticket_info(ticket: &Ticket): (ID, u64, address, u8, String, String, u64, u64) {
    (
        ticket.event,
        ticket.ticket_id,
        ticket.holder,
        ticket.status,
        ticket.ticket_type,
        ticket.seat_info,
        ticket.issued_at,
        ticket.redeemed_at,
    )
}

/// Get commemorative info (for collectible display)
public fun get_commemorative_info(ticket: &Ticket): (String, String, String) {
    (ticket.commemorative_title, ticket.commemorative_description, ticket.commemorative_image)
}

/// Check if ticket is used/redeemed
public fun is_ticket_used(ticket: &Ticket): bool {
    ticket.status == TICKET_STATUS_USED
}

/// Check if ticket is expired
public fun is_ticket_expired(ticket: &Ticket): bool {
    ticket.status == TICKET_STATUS_EXPIRED
}

/// Check if ticket is valid (unused and not expired)
public fun is_ticket_valid(ticket: &Ticket): bool {
    ticket.status == TICKET_STATUS_UNUSED
}

/// Get ticket attribute
public fun get_ticket_attribute(ticket: &Ticket, key: &String): String {
    if (vec_map::contains(&ticket.ticket_attributes, key)) {
        *vec_map::get(&ticket.ticket_attributes, key)
    } else {
        string::utf8(b"")
    }
}

/// Get event attribute
public fun get_event_attribute(event: &Event, key: &String): String {
    if (vec_map::contains(&event.event_attributes, key)) {
        *vec_map::get(&event.event_attributes, key)
    } else {
        string::utf8(b"")
    }
}

/// Check if address is authorized issuer
public fun is_authorized_issuer(event: &Event, issuer: address): bool {
    issuer == event.authority || vec_map::contains(&event.issuers, &issuer)
}

/// Get event statistics
public fun get_event_stats(event: &Event): (u64, u64, u64, u64) {
    let remaining = event.max_tickets - event.current_tickets;
    (event.max_tickets, event.current_tickets, event.tickets_used, remaining)
}
