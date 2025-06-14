#[allow(unused_const, duplicate_alias, unused_field)]
module otl::namespaces;

use otl::base;
use otl::utils;
use std::option::{Self, Option};
use std::string::{Self, String};
use std::vector;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

// ===== Constants =====
const NAMESPACE_VERSION: u64 = 1;
const MAX_USERNAME_LENGTH: u64 = 32;
const MIN_USERNAME_LENGTH: u64 = 2;
const MAX_DOMAIN_LENGTH: u64 = 16;

// Domain types
const DOMAIN_TYPE_FREE: u8 = 0; // Free public domains
const DOMAIN_TYPE_PREMIUM: u8 = 1; // Premium paid domains
const DOMAIN_TYPE_OFFICIAL: u8 = 2; // Official Onoal domains
const DOMAIN_TYPE_PRIVATE: u8 = 3; // Private company domains

// Official Onoal domains
const OFFICIAL_DOMAIN_ONO: vector<u8> = b"ono";
const OFFICIAL_DOMAIN_ONOAL: vector<u8> = b"onoal";

// ===== Core Structs =====

/// Global namespace registry for domain-based OnoalIDs
public struct NamespaceRegistry has key {
    id: UID,
    /// Registry authority
    authority: address,
    /// Available domains and their managers
    domains: Table<String, DomainInfo>, // domain -> domain info
    /// All registered namespaced IDs
    namespaced_ids: Table<String, NamespacedRecord>, // full_id -> record
    /// Reverse lookup: address -> list of namespaced IDs
    address_to_ids: Table<address, vector<String>>,
    /// Domain reservations
    domain_reservations: Table<String, DomainReservation>,
    /// Statistics
    total_domains: u64,
    total_namespaced_ids: u64,
    /// Fees
    domain_registration_fee: u64,
    premium_domain_fee: u64,
    id_registration_fee: u64,
}

/// Domain information and management
public struct DomainInfo has copy, drop, store {
    domain: String, // e.g., "ono", "onoal", "company"
    domain_type: u8, // 0=free, 1=premium, 2=official, 3=private
    manager: address, // Who can approve registrations
    is_open_registration: bool, // Anyone can register vs approval needed
    registration_fee: u64, // Fee to register username in this domain
    max_registrations: Option<u64>, // Max usernames allowed (None = unlimited)
    current_registrations: u64,
    /// Domain metadata
    description: String,
    website: Option<String>,
    created_at: u64,
    /// Domain settings
    allow_subdomains: bool, // e.g., alice.shop.ono
    min_username_length: u8,
    max_username_length: u8,
}

/// Namespaced ID record (e.g., alice.ono, tesla.onoal)
public struct NamespacedRecord has store {
    /// Full namespaced ID (e.g., "alice.ono", "tesla.onoal")
    full_id: String,
    /// Username part (e.g., "alice", "tesla")
    username: String,
    /// Domain part (e.g., "ono", "onoal")
    domain: String,
    /// Owner's Sui address
    sui_address: address,
    /// Account type (from onoal_id module)
    account_type: u8,
    /// Display information
    display_name: String,
    avatar_url: String,
    bio: String,
    /// Verification status
    is_verified: bool,
    verification_tier: u8,
    /// Metadata
    created_at: u64,
    last_updated: u64,
    /// Links to other systems
    linked_onoal_id: Option<String>, // Link to basic @username if exists
    contact_info: Table<String, String>,
}

/// Domain reservation for future registration
public struct DomainReservation has store {
    domain: String,
    reserver: address,
    domain_type: u8,
    registration_fee_paid: u64,
    expires_at: u64,
    justification: String, // Why they want this domain
}

/// NFT representing ownership of a namespaced ID
public struct NamespacedIDNFT has key, store {
    id: UID,
    /// The full namespaced ID
    full_id: String,
    username: String,
    domain: String,
    /// Owner
    owner: address,
    /// NFT metadata
    name: String,
    description: String,
    image_url: String,
    /// Settings
    is_transferable: bool,
    created_at: u64,
}

/// Domain info for queries
public struct DomainInfoSummary has drop {
    domain_type: u8,
    manager: address,
    is_open_registration: bool,
    registration_fee: u64,
    current_registrations: u64,
}

// ===== Events =====

public struct DomainRegistered has copy, drop {
    domain: String,
    domain_type: u8,
    manager: address,
    is_open_registration: bool,
}

public struct NamespacedIDRegistered has copy, drop {
    full_id: String,
    username: String,
    domain: String,
    sui_address: address,
    account_type: u8,
}

public struct DomainTransferred has copy, drop {
    domain: String,
    from_manager: address,
    to_manager: address,
}

// ===== Registry Management =====

/// Create the global namespace registry
public fun create_namespace_registry(
    domain_registration_fee: u64,
    premium_domain_fee: u64,
    id_registration_fee: u64,
    ctx: &mut TxContext,
): NamespaceRegistry {
    let authority = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    let mut registry = NamespaceRegistry {
        id: object::new(ctx),
        authority,
        domains: table::new(ctx),
        namespaced_ids: table::new(ctx),
        address_to_ids: table::new(ctx),
        domain_reservations: table::new(ctx),
        total_domains: 0,
        total_namespaced_ids: 0,
        domain_registration_fee,
        premium_domain_fee,
        id_registration_fee,
    };

    // Register official Onoal domains
    let ono_domain = DomainInfo {
        domain: string::utf8(OFFICIAL_DOMAIN_ONO),
        domain_type: DOMAIN_TYPE_OFFICIAL,
        manager: authority,
        is_open_registration: false, // Requires approval
        registration_fee: premium_domain_fee,
        max_registrations: option::none(),
        current_registrations: 0,
        description: string::utf8(b"Official Onoal premium domain"),
        website: option::some(string::utf8(b"https://onoal.com")),
        created_at: current_time,
        allow_subdomains: true,
        min_username_length: 2,
        max_username_length: 32,
    };

    let onoal_domain = DomainInfo {
        domain: string::utf8(OFFICIAL_DOMAIN_ONOAL),
        domain_type: DOMAIN_TYPE_OFFICIAL,
        manager: authority,
        is_open_registration: false, // Requires approval
        registration_fee: premium_domain_fee * 2, // Even more premium
        max_registrations: option::some(1000), // Limited official accounts
        current_registrations: 0,
        description: string::utf8(b"Official Onoal corporate domain"),
        website: option::some(string::utf8(b"https://onoal.com")),
        created_at: current_time,
        allow_subdomains: false, // No subdomains for official
        min_username_length: 3,
        max_username_length: 20,
    };

    table::add(&mut registry.domains, string::utf8(OFFICIAL_DOMAIN_ONO), ono_domain);
    table::add(&mut registry.domains, string::utf8(OFFICIAL_DOMAIN_ONOAL), onoal_domain);
    registry.total_domains = 2;

    event::emit(DomainRegistered {
        domain: string::utf8(OFFICIAL_DOMAIN_ONO),
        domain_type: DOMAIN_TYPE_OFFICIAL,
        manager: authority,
        is_open_registration: false,
    });

    event::emit(DomainRegistered {
        domain: string::utf8(OFFICIAL_DOMAIN_ONOAL),
        domain_type: DOMAIN_TYPE_OFFICIAL,
        manager: authority,
        is_open_registration: false,
    });

    registry
}

/// Create and share the registry
public entry fun create_shared_namespace_registry(
    domain_registration_fee: u64,
    premium_domain_fee: u64,
    id_registration_fee: u64,
    ctx: &mut TxContext,
) {
    let registry = create_namespace_registry(
        domain_registration_fee,
        premium_domain_fee,
        id_registration_fee,
        ctx,
    );
    transfer::share_object(registry);
}

// ===== Domain Management =====

/// Register a new domain (e.g., "company", "shop", "crypto")
public fun register_domain(
    registry: &mut NamespaceRegistry,
    domain: vector<u8>,
    domain_type: u8,
    is_open_registration: bool,
    registration_fee: u64,
    max_registrations: Option<u64>,
    description: vector<u8>,
    mut website: Option<vector<u8>>,
    ctx: &mut TxContext,
): DomainInfo {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // Validate domain
    assert!(validate_domain(&domain), base::invalid_metadata_error());
    let domain_str = utils::safe_utf8(domain);

    // Check if domain already exists
    assert!(!table::contains(&registry.domains, domain_str), base::token_exists_error());

    // Only authority can register official domains
    if (domain_type == DOMAIN_TYPE_OFFICIAL) {
        assert!(sender == registry.authority, base::not_authorized_error());
    };

    let domain_info = DomainInfo {
        domain: domain_str,
        domain_type,
        manager: sender,
        is_open_registration,
        registration_fee,
        max_registrations,
        current_registrations: 0,
        description: utils::safe_utf8(description),
        website: if (option::is_some(&website)) {
            option::some(utils::safe_utf8(option::extract(&mut website)))
        } else {
            option::none()
        },
        created_at: current_time,
        allow_subdomains: true,
        min_username_length: 2,
        max_username_length: 32,
    };

    table::add(&mut registry.domains, domain_str, domain_info);
    registry.total_domains = registry.total_domains + 1;

    option::destroy_none(website);

    event::emit(DomainRegistered {
        domain: domain_str,
        domain_type,
        manager: sender,
        is_open_registration,
    });

    // Return a copy of the domain info
    *table::borrow(&registry.domains, domain_str)
}

// ===== Namespaced ID Registration =====

/// Register a namespaced ID (e.g., alice.ono, tesla.onoal)
public fun register_namespaced_id(
    registry: &mut NamespaceRegistry,
    username: vector<u8>,
    domain: vector<u8>,
    account_type: u8,
    display_name: vector<u8>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    linked_onoal_id: Option<String>,
    ctx: &mut TxContext,
): NamespacedIDNFT {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // Validate inputs
    assert!(validate_username(&username), base::invalid_metadata_error());
    assert!(validate_domain(&domain), base::invalid_metadata_error());

    let username_str = utils::safe_utf8(username);
    let domain_str = utils::safe_utf8(domain);
    let full_id = create_full_id(&username_str, &domain_str);

    // Check if domain exists
    assert!(table::contains(&registry.domains, domain_str), base::token_not_found_error());
    let domain_info = table::borrow_mut(&mut registry.domains, domain_str);

    // Check if full ID is available
    assert!(!table::contains(&registry.namespaced_ids, full_id), base::token_exists_error());

    // Check domain registration permissions
    if (!domain_info.is_open_registration) {
        assert!(
            sender == domain_info.manager || sender == registry.authority,
            base::not_authorized_error(),
        );
    };

    // Check domain limits
    if (option::is_some(&domain_info.max_registrations)) {
        let max_regs = *option::borrow(&domain_info.max_registrations);
        assert!(domain_info.current_registrations < max_regs, base::supply_exceeded_error());
    };

    // Check username length for this domain
    let username_len = vector::length(&username);
    assert!(
        username_len >= (domain_info.min_username_length as u64) &&
        username_len <= (domain_info.max_username_length as u64),
        base::invalid_metadata_error(),
    );

    // Store domain type for NFT creation
    let domain_type = domain_info.domain_type;
    let is_official_domain = domain_type == DOMAIN_TYPE_OFFICIAL;

    // Create namespaced record
    let record = NamespacedRecord {
        full_id,
        username: username_str,
        domain: domain_str,
        sui_address: sender,
        account_type,
        display_name: utils::safe_utf8(display_name),
        avatar_url: utils::safe_utf8(avatar_url),
        bio: utils::safe_utf8(bio),
        is_verified: false,
        verification_tier: if (is_official_domain) 3 else 1,
        created_at: current_time,
        last_updated: current_time,
        linked_onoal_id,
        contact_info: table::new(ctx),
    };

    // Create NFT
    let nft = NamespacedIDNFT {
        id: object::new(ctx),
        full_id,
        username: username_str,
        domain: domain_str,
        owner: sender,
        name: generate_namespaced_nft_name(&username_str, &domain_str),
        description: generate_namespaced_nft_description(&domain_str, domain_type),
        image_url: generate_namespaced_nft_image(&username_str, &domain_str),
        is_transferable: !is_official_domain, // Official IDs non-transferable
        created_at: current_time,
    };

    // Update registry
    table::add(&mut registry.namespaced_ids, full_id, record);

    // Update address mapping
    if (table::contains(&registry.address_to_ids, sender)) {
        let ids = table::borrow_mut(&mut registry.address_to_ids, sender);
        vector::push_back(ids, full_id);
    } else {
        let mut new_ids = vector::empty<String>();
        vector::push_back(&mut new_ids, full_id);
        table::add(&mut registry.address_to_ids, sender, new_ids);
    };

    // Update domain stats
    domain_info.current_registrations = domain_info.current_registrations + 1;
    registry.total_namespaced_ids = registry.total_namespaced_ids + 1;

    event::emit(NamespacedIDRegistered {
        full_id,
        username: username_str,
        domain: domain_str,
        sui_address: sender,
        account_type,
    });

    nft
}

// ===== Validation Functions =====

/// Validate username format (alphanumeric + underscore)
fun validate_username(username: &vector<u8>): bool {
    let len = vector::length(username);
    if (len < MIN_USERNAME_LENGTH || len > MAX_USERNAME_LENGTH) return false;

    let mut i = 0;
    while (i < len) {
        let char = *vector::borrow(username, i);
        if (
            !(
                (char >= 48 && char <= 57) || // 0-9
            (char >= 65 && char <= 90) || // A-Z
            (char >= 97 && char <= 122) || // a-z
            char == 95, // underscore
            )
        ) {
            return false
        };
        i = i + 1;
    };

    true
}

/// Validate domain format (alphanumeric only, no underscore)
fun validate_domain(domain: &vector<u8>): bool {
    let len = vector::length(domain);
    if (len < 2 || len > MAX_DOMAIN_LENGTH) return false;

    let mut i = 0;
    while (i < len) {
        let char = *vector::borrow(domain, i);
        if (
            !(
                (char >= 48 && char <= 57) || // 0-9
            (char >= 97 && char <= 122), // a-z only (lowercase)
            )
        ) {
            return false
        };
        i = i + 1;
    };

    true
}

// ===== Utility Functions =====

/// Create full ID from username and domain
fun create_full_id(username: &String, domain: &String): String {
    let username_bytes = string::as_bytes(username);
    let domain_bytes = string::as_bytes(domain);
    let dot = b".";

    let mut full_id_bytes = *username_bytes;
    vector::append(&mut full_id_bytes, dot);
    vector::append(&mut full_id_bytes, *domain_bytes);

    string::utf8(full_id_bytes)
}

/// Generate NFT name for namespaced ID
fun generate_namespaced_nft_name(username: &String, domain: &String): String {
    let prefix = b"OnoalID: ";
    let username_bytes = string::as_bytes(username);
    let domain_bytes = string::as_bytes(domain);
    let dot = b".";

    let mut name_bytes = prefix;
    vector::append(&mut name_bytes, *username_bytes);
    vector::append(&mut name_bytes, dot);
    vector::append(&mut name_bytes, *domain_bytes);

    string::utf8(name_bytes)
}

/// Generate NFT description based on domain type
fun generate_namespaced_nft_description(domain: &String, domain_type: u8): String {
    if (domain_type == DOMAIN_TYPE_OFFICIAL) {
        string::utf8(b"Official Onoal namespaced identity with verified status")
    } else if (domain_type == DOMAIN_TYPE_PREMIUM) {
        string::utf8(b"Premium namespaced identity in the Onoal ecosystem")
    } else if (domain_type == DOMAIN_TYPE_PRIVATE) {
        string::utf8(b"Private company namespaced identity")
    } else {
        string::utf8(b"Namespaced identity in the Onoal ecosystem")
    }
}

/// Generate NFT image URL
fun generate_namespaced_nft_image(username: &String, domain: &String): String {
    let base_url = b"https://api.onoal.com/namespace/";
    let username_bytes = string::as_bytes(username);
    let domain_bytes = string::as_bytes(domain);
    let dot = b".";
    let suffix = b"/image.png";

    let mut url_bytes = base_url;
    vector::append(&mut url_bytes, *username_bytes);
    vector::append(&mut url_bytes, dot);
    vector::append(&mut url_bytes, *domain_bytes);
    vector::append(&mut url_bytes, suffix);

    string::utf8(url_bytes)
}

// ===== Query Functions =====

/// Resolve namespaced ID to Sui address
public fun resolve_namespaced_id(registry: &NamespaceRegistry, full_id: String): Option<address> {
    if (table::contains(&registry.namespaced_ids, full_id)) {
        let record = table::borrow(&registry.namespaced_ids, full_id);
        option::some(record.sui_address)
    } else {
        option::none()
    }
}

/// Get all namespaced IDs for an address
public fun get_address_namespaced_ids(
    registry: &NamespaceRegistry,
    sui_address: address,
): vector<String> {
    if (table::contains(&registry.address_to_ids, sui_address)) {
        *table::borrow(&registry.address_to_ids, sui_address)
    } else {
        vector::empty()
    }
}

/// Check if namespaced ID exists
public fun namespaced_id_exists(registry: &NamespaceRegistry, full_id: String): bool {
    table::contains(&registry.namespaced_ids, full_id)
}

/// Check if domain exists
public fun domain_exists(registry: &NamespaceRegistry, domain: String): bool {
    table::contains(&registry.domains, domain)
}

/// Get domain info
public fun get_domain_info(
    registry: &NamespaceRegistry,
    domain: String,
): Option<DomainInfoSummary> {
    if (table::contains(&registry.domains, domain)) {
        let domain_info = table::borrow(&registry.domains, domain);
        option::some(DomainInfoSummary {
            domain_type: domain_info.domain_type,
            manager: domain_info.manager,
            is_open_registration: domain_info.is_open_registration,
            registration_fee: domain_info.registration_fee,
            current_registrations: domain_info.current_registrations,
        })
    } else {
        option::none()
    }
}

// ===== Entry Functions =====

/// Entry function for registering namespaced ID
public entry fun register_namespaced_id_entry(
    registry: &mut NamespaceRegistry,
    username: vector<u8>,
    domain: vector<u8>,
    account_type: u8,
    display_name: vector<u8>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    ctx: &mut TxContext,
) {
    let nft = register_namespaced_id(
        registry,
        username,
        domain,
        account_type,
        display_name,
        avatar_url,
        bio,
        option::none(), // No linked basic ID
        ctx,
    );

    transfer::public_transfer(nft, tx_context::sender(ctx));
}

/// Entry function for domain registration
public entry fun register_domain_entry(
    registry: &mut NamespaceRegistry,
    domain: vector<u8>,
    domain_type: u8,
    is_open_registration: bool,
    registration_fee: u64,
    description: vector<u8>,
    ctx: &mut TxContext,
) {
    // Don't store the return value since we don't need it in entry function
    register_domain(
        registry,
        domain,
        domain_type,
        is_open_registration,
        registration_fee,
        option::none(), // No max registrations
        description,
        option::none(), // No website
        ctx,
    );
}
