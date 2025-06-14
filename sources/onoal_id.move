#[allow(unused_const, duplicate_alias, unused_field)]
module otl::onoal_id;

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
const ONOAL_ID_VERSION: u64 = 1;
const MAX_ONOAL_ID_LENGTH: u64 = 32;
const MIN_ONOAL_ID_LENGTH: u64 = 3;
const MAX_DISPLAY_NAME_LENGTH: u64 = 64;

// Official Onoal address - ONLY this address can create @onoal profiles
const OFFICIAL_ONOAL_ADDRESS: address =
    @0x3175c9d95270ede9da98f9b914ef78dc42fe1fec3cb2081cccbb08461c5c1bdf;

// Account types
const ACCOUNT_TYPE_USER: u8 = 0;
const ACCOUNT_TYPE_COMPANY: u8 = 1;
const ACCOUNT_TYPE_MERCHANT: u8 = 2;
const ACCOUNT_TYPE_PLATFORM: u8 = 3;
const ACCOUNT_TYPE_ADMIN: u8 = 4;
const ACCOUNT_TYPE_OFFICIAL: u8 = 5; // New: Official Onoal accounts

// Verification tiers
const VERIFICATION_NONE: u8 = 0;
const VERIFICATION_BASIC: u8 = 1;
const VERIFICATION_PREMIUM: u8 = 2;
const VERIFICATION_OFFICIAL: u8 = 3;
const VERIFICATION_ENTERPRISE: u8 = 4;

// Reserved prefixes for different account types (OPTIONAL - no longer required)
// User examples: alice123, john_doe, crypto_fan
// Company examples: tesla_corp, microsoft_biz, startup_inc
// Merchant examples: alice_shop, electronics_store, crypto_merchant
// Platform examples: onoal_official, admin_support, platform_team

// ===== Core Structs =====

/// Global registry for OnoalID system with restricted premium prefixes
public struct OnoalIDRegistry has key {
    id: UID,
    /// Registry authority
    authority: address,
    /// Official Onoal address (only one that can create @onoal profiles)
    official_onoal_address: address,
    /// Mapping: onoal_id -> OnoalIDRecord
    id_records: Table<String, OnoalIDRecord>,
    /// Reverse mapping: sui_address -> onoal_id
    address_to_id: Table<address, String>,
    /// Account type mappings
    user_ids: Table<String, bool>, // user IDs
    company_ids: Table<String, CompanyInfo>, // company IDs with extra info
    merchant_ids: Table<String, MerchantInfo>, // merchant IDs
    platform_ids: Table<String, bool>, // platform/admin IDs
    official_onoal_ids: Table<String, bool>, // official @onoal IDs
    /// Temporary official ID management
    temporary_assignments: Table<String, TemporaryOfficialAssignment>, // temp_id -> assignment
    employee_to_temp_id: Table<address, String>, // employee_address -> temp_id
    /// Registry statistics by type
    total_users: u64,
    total_companies: u64,
    total_merchants: u64,
    total_platforms: u64,
    total_official_onoal: u64,
    total_temporary_officials: u64,
    /// Fees by account type
    user_registration_fee: u64,
    company_registration_fee: u64,
    merchant_registration_fee: u64,
    premium_fee: u64,
}

/// Enhanced OnoalID record with account type support
public struct OnoalIDRecord has store {
    /// The human-readable ID (e.g., "alice123", "tesla_corp", "onoal_support")
    onoal_id: String,
    /// Associated Sui address
    sui_address: address,
    /// Account type classification
    account_type: u8, // 0=user, 1=company, 2=merchant, 3=platform, 4=admin, 5=official
    /// Display information
    display_name: String,
    avatar_url: String,
    bio: String,
    /// Verification status
    is_verified: bool,
    is_premium: bool,
    verification_tier: u8,
    /// Business information (for companies/merchants)
    business_name: Option<String>,
    business_category: Option<String>,
    business_website: Option<String>,
    /// Metadata
    created_at: u64,
    last_updated: u64,
    /// Social/contact links
    contact_info: Table<String, String>, // type -> value (email, phone, website, etc.)
    /// Temporary official ID tracking
    is_temporary_official: bool, // Is this a temporary @onoal ID?
    temporary_expires_at: Option<u64>, // When does temporary status expire?
    original_id_backup: Option<String>, // Backup of original non-official ID
}

/// Company-specific information
public struct CompanyInfo has store {
    company_name: String,
    business_category: String,
    registration_number: Option<String>,
    tax_id: Option<String>,
    website: String,
    employee_count: Option<u64>,
    founded_year: Option<u64>,
    is_verified_business: bool,
}

/// Merchant-specific information
public struct MerchantInfo has store {
    store_name: String,
    store_category: String,
    store_description: String,
    store_website: Option<String>,
    accepts_crypto: bool,
    kiosk_ids: vector<ID>, // Associated kiosks
    is_verified_merchant: bool,
}

/// OnoalID NFT - represents ownership of an ID
public struct OnoalIDNFT has key, store {
    id: UID,
    /// The OnoalID this NFT represents
    onoal_id: String,
    /// Owner's Sui address
    owner: address,
    /// NFT metadata
    name: String,
    description: String,
    image_url: String,
    /// Transferability settings
    is_transferable: bool,
    created_at: u64,
}

/// Temporary reservation for ID registration
public struct IDReservation has key, store {
    id: UID,
    reserved_id: String,
    reserver: address,
    expires_at: u64,
    reservation_fee_paid: u64,
}

/// Simplified record data for queries
public struct OnoalIDInfo has drop {
    onoal_id: String,
    sui_address: address,
    display_name: String,
    avatar_url: String,
    bio: String,
    is_verified: bool,
    is_premium: bool,
    verification_tier: u8,
    created_at: u64,
    last_updated: u64,
}

/// Temporary official ID assignment record
public struct TemporaryOfficialAssignment has store {
    /// The temporary @onoal ID assigned
    temporary_onoal_id: String,
    /// The employee's address
    employee_address: address,
    /// Original ID before becoming temporary official (for restoration)
    original_id: Option<String>,
    /// Assignment details
    assigned_by: address, // Should be OFFICIAL_ONOAL_ADDRESS
    assigned_at: u64,
    expires_at: Option<u64>, // None = indefinite
    /// Employee info
    employee_name: String,
    department: String,
    role: String,
    /// Status
    is_active: bool,
}

// ===== Events =====

public struct OnoalIDRegistered has copy, drop {
    onoal_id: String,
    sui_address: address,
    owner: address,
    is_premium: bool,
    verification_tier: u8,
}

public struct OfficialOnoalIDCreated has copy, drop {
    onoal_id: String,
    sui_address: address,
    created_by: address,
    verification_tier: u8,
}

public struct TemporaryOfficialIDAssigned has copy, drop {
    temporary_onoal_id: String,
    employee_address: address,
    original_id: Option<String>,
    assigned_by: address,
    employee_name: String,
    department: String,
    role: String,
    expires_at: Option<u64>,
}

public struct TemporaryOfficialIDRevoked has copy, drop {
    temporary_onoal_id: String,
    employee_address: address,
    restored_id: Option<String>,
    revoked_by: address,
    revoked_at: u64,
}

public struct OnoalIDTransferred has copy, drop {
    onoal_id: String,
    from_address: address,
    to_address: address,
    transferred_by: address,
}

public struct OnoalIDUpdated has copy, drop {
    onoal_id: String,
    sui_address: address,
    updated_by: address,
}

// ===== Registry Management =====

/// Create the global OnoalID registry with restricted premium prefixes
public fun create_onoal_id_registry(
    registration_fee: u64,
    premium_fee: u64,
    ctx: &mut TxContext,
): OnoalIDRegistry {
    let registry = OnoalIDRegistry {
        id: object::new(ctx),
        authority: tx_context::sender(ctx),
        official_onoal_address: OFFICIAL_ONOAL_ADDRESS,
        id_records: table::new(ctx),
        address_to_id: table::new(ctx),
        user_ids: table::new(ctx),
        company_ids: table::new(ctx),
        merchant_ids: table::new(ctx),
        platform_ids: table::new(ctx),
        official_onoal_ids: table::new(ctx),
        temporary_assignments: table::new(ctx),
        employee_to_temp_id: table::new(ctx),
        total_users: 0,
        total_companies: 0,
        total_merchants: 0,
        total_platforms: 0,
        total_official_onoal: 0,
        total_temporary_officials: 0,
        user_registration_fee: 0,
        company_registration_fee: 0,
        merchant_registration_fee: 0,
        premium_fee,
    };

    // NOTE: No premium prefix managers - all restricted except @onoal for official address
    registry
}

/// Create and share the registry
public entry fun create_shared_onoal_id_registry(
    registration_fee: u64,
    premium_fee: u64,
    ctx: &mut TxContext,
) {
    let registry = create_onoal_id_registry(registration_fee, premium_fee, ctx);
    transfer::share_object(registry);
}

// ===== Official Onoal Registration (RESTRICTED) =====

/// Register official @onoal account - ONLY for official Onoal address
public fun register_official_onoal_id(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>, // Must start with "onoal"
    display_name: vector<u8>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    target_address: address, // Address that will own this official ID
    ctx: &mut TxContext,
): OnoalIDNFT {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // STRICT AUTHORIZATION: Only official Onoal address can create @onoal IDs
    assert!(sender == OFFICIAL_ONOAL_ADDRESS, base::not_authorized_error());

    // Validate that ID starts with "onoal"
    assert!(starts_with(&desired_id, &b"onoal"), base::invalid_metadata_error());
    assert!(validate_onoal_id(&desired_id), base::invalid_metadata_error());

    let onoal_id_str = utils::safe_utf8(desired_id);

    // Check availability
    assert!(!table::contains(&registry.id_records, onoal_id_str), base::token_exists_error());
    assert!(
        !table::contains(&registry.address_to_id, target_address),
        base::account_exists_error(),
    );

    // Create official record with highest verification
    let record = OnoalIDRecord {
        onoal_id: onoal_id_str,
        sui_address: target_address,
        account_type: ACCOUNT_TYPE_OFFICIAL,
        display_name: utils::safe_utf8(display_name),
        avatar_url: utils::safe_utf8(avatar_url),
        bio: utils::safe_utf8(bio),
        is_verified: true, // Official accounts are always verified
        is_premium: true, // Official accounts are premium
        verification_tier: VERIFICATION_OFFICIAL,
        business_name: option::some(string::utf8(b"Onoal Official")),
        business_category: option::some(string::utf8(b"Platform")),
        business_website: option::some(string::utf8(b"https://onoal.com")),
        created_at: current_time,
        last_updated: current_time,
        contact_info: table::new(ctx),
        is_temporary_official: false,
        temporary_expires_at: option::none(),
        original_id_backup: option::none(),
    };

    // Create NFT (non-transferable for official accounts)
    let nft = OnoalIDNFT {
        id: object::new(ctx),
        onoal_id: onoal_id_str,
        owner: target_address,
        name: generate_official_nft_name(&onoal_id_str),
        description: generate_official_nft_description(&onoal_id_str),
        image_url: generate_official_nft_image_url(&onoal_id_str),
        is_transferable: false, // Official IDs are non-transferable
        created_at: current_time,
    };

    // Register in tables
    table::add(&mut registry.id_records, onoal_id_str, record);
    table::add(&mut registry.address_to_id, target_address, onoal_id_str);
    table::add(&mut registry.official_onoal_ids, onoal_id_str, true);

    // Update stats
    registry.total_official_onoal = registry.total_official_onoal + 1;

    event::emit(OfficialOnoalIDCreated {
        onoal_id: onoal_id_str,
        sui_address: target_address,
        created_by: sender,
        verification_tier: VERIFICATION_OFFICIAL,
    });

    nft
}

/// Entry function for official Onoal registration
public entry fun register_official_onoal_id_entry(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>,
    display_name: vector<u8>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    target_address: address,
    ctx: &mut TxContext,
) {
    let nft = register_official_onoal_id(
        registry,
        desired_id,
        display_name,
        avatar_url,
        bio,
        target_address,
        ctx,
    );

    transfer::public_transfer(nft, target_address);
}

// ===== Temporary Official ID Management (RESTRICTED) =====

/// Assign temporary @onoal ID to employee - ONLY for official Onoal address
public fun assign_temporary_official_id(
    registry: &mut OnoalIDRegistry,
    employee_address: address,
    temporary_id: vector<u8>, // Must start with "onoal"
    employee_name: vector<u8>,
    department: vector<u8>,
    role: vector<u8>,
    expires_at: Option<u64>, // None = indefinite
    ctx: &mut TxContext,
): OnoalIDNFT {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // STRICT AUTHORIZATION: Only official Onoal address can assign temporary IDs
    assert!(sender == OFFICIAL_ONOAL_ADDRESS, base::not_authorized_error());

    // Validate that ID starts with "onoal"
    assert!(starts_with(&temporary_id, &b"onoal"), base::invalid_metadata_error());
    assert!(validate_onoal_id(&temporary_id), base::invalid_metadata_error());

    let temp_id_str = utils::safe_utf8(temporary_id);

    // Check if temporary ID is available
    assert!(!table::contains(&registry.id_records, temp_id_str), base::token_exists_error());

    // Check if employee already has a temporary assignment
    assert!(
        !table::contains(&registry.employee_to_temp_id, employee_address),
        base::account_exists_error(),
    );

    // Get employee's current ID (if any) for backup
    let original_id = if (table::contains(&registry.address_to_id, employee_address)) {
        let current_id = table::borrow(&registry.address_to_id, employee_address);
        option::some(*current_id)
    } else {
        option::none()
    };

    // If employee has existing ID, remove it temporarily
    if (option::is_some(&original_id)) {
        let existing_id = *option::borrow(&original_id);

        // Remove from address mapping temporarily
        table::remove(&mut registry.address_to_id, employee_address);

        // Update the existing record to mark it as temporarily suspended
        if (table::contains(&registry.id_records, existing_id)) {
            let existing_record = table::borrow_mut(&mut registry.id_records, existing_id);
            existing_record.last_updated = current_time;
        };
    };

    // Create temporary official record
    let temp_record = OnoalIDRecord {
        onoal_id: temp_id_str,
        sui_address: employee_address,
        account_type: ACCOUNT_TYPE_OFFICIAL,
        display_name: utils::safe_utf8(employee_name),
        avatar_url: string::utf8(b"https://api.onoal.com/temp/avatar.png"),
        bio: string::utf8(b"Temporary Onoal team member"),
        is_verified: true, // Temporary officials are verified
        is_premium: true, // Temporary officials get premium status
        verification_tier: VERIFICATION_OFFICIAL,
        business_name: option::some(string::utf8(b"Onoal Official")),
        business_category: option::some(utils::safe_utf8(department)),
        business_website: option::some(string::utf8(b"https://onoal.com")),
        created_at: current_time,
        last_updated: current_time,
        contact_info: table::new(ctx),
        is_temporary_official: true,
        temporary_expires_at: expires_at,
        original_id_backup: original_id,
    };

    // Create temporary assignment record
    let assignment = TemporaryOfficialAssignment {
        temporary_onoal_id: temp_id_str,
        employee_address,
        original_id,
        assigned_by: sender,
        assigned_at: current_time,
        expires_at,
        employee_name: utils::safe_utf8(employee_name),
        department: utils::safe_utf8(department),
        role: utils::safe_utf8(role),
        is_active: true,
    };

    // Create NFT for temporary official ID
    let nft = OnoalIDNFT {
        id: object::new(ctx),
        onoal_id: temp_id_str,
        owner: employee_address,
        name: generate_temporary_official_nft_name(&temp_id_str),
        description: generate_temporary_official_nft_description(&temp_id_str),
        image_url: generate_official_nft_image_url(&temp_id_str),
        is_transferable: false, // Temporary IDs are non-transferable
        created_at: current_time,
    };

    // Register in tables
    table::add(&mut registry.id_records, temp_id_str, temp_record);
    table::add(&mut registry.address_to_id, employee_address, temp_id_str);
    table::add(&mut registry.official_onoal_ids, temp_id_str, true);
    table::add(&mut registry.temporary_assignments, temp_id_str, assignment);
    table::add(&mut registry.employee_to_temp_id, employee_address, temp_id_str);

    // Update stats
    registry.total_official_onoal = registry.total_official_onoal + 1;
    registry.total_temporary_officials = registry.total_temporary_officials + 1;

    event::emit(TemporaryOfficialIDAssigned {
        temporary_onoal_id: temp_id_str,
        employee_address,
        original_id,
        assigned_by: sender,
        employee_name: utils::safe_utf8(employee_name),
        department: utils::safe_utf8(department),
        role: utils::safe_utf8(role),
        expires_at,
    });

    nft
}

/// Revoke temporary @onoal ID and restore original ID - ONLY for official Onoal address
public fun revoke_temporary_official_id(
    registry: &mut OnoalIDRegistry,
    employee_address: address,
    ctx: &mut TxContext,
): Option<OnoalIDNFT> {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // STRICT AUTHORIZATION: Only official Onoal address can revoke temporary IDs
    assert!(sender == OFFICIAL_ONOAL_ADDRESS, base::not_authorized_error());

    // Check if employee has a temporary assignment
    assert!(
        table::contains(&registry.employee_to_temp_id, employee_address),
        base::account_not_found_error(),
    );

    let temp_id = table::remove(&mut registry.employee_to_temp_id, employee_address);
    let assignment = table::remove(&mut registry.temporary_assignments, temp_id);

    // Remove temporary official record
    let OnoalIDRecord {
        onoal_id: _,
        sui_address: _,
        account_type: _,
        display_name: _,
        avatar_url: _,
        bio: _,
        is_verified: _,
        is_premium: _,
        verification_tier: _,
        business_name: _,
        business_category: _,
        business_website: _,
        created_at: _,
        last_updated: _,
        contact_info,
        is_temporary_official: _,
        temporary_expires_at: _,
        original_id_backup: _,
    } = table::remove(&mut registry.id_records, temp_id);

    // Destroy the contact_info table
    table::destroy_empty(contact_info);

    table::remove(&mut registry.address_to_id, employee_address);
    table::remove(&mut registry.official_onoal_ids, temp_id);

    // Update stats
    registry.total_official_onoal = registry.total_official_onoal - 1;
    registry.total_temporary_officials = registry.total_temporary_officials - 1;

    let restored_nft_opt = if (option::is_some(&assignment.original_id)) {
        let original_id = *option::borrow(&assignment.original_id);

        // Restore original ID
        table::add(&mut registry.address_to_id, employee_address, original_id);

        // Update original record
        if (table::contains(&registry.id_records, original_id)) {
            let original_record = table::borrow_mut(&mut registry.id_records, original_id);
            original_record.last_updated = current_time;
        };

        // Create NFT for restored ID
        let restored_nft = OnoalIDNFT {
            id: object::new(ctx),
            onoal_id: original_id,
            owner: employee_address,
            name: generate_nft_name(&original_id, ACCOUNT_TYPE_USER), // Assume user type for restored
            description: generate_nft_description(&original_id, ACCOUNT_TYPE_USER),
            image_url: generate_nft_image_url(&original_id),
            is_transferable: true, // Restored IDs are transferable
            created_at: current_time,
        };

        option::some(restored_nft)
    } else {
        // No original ID to restore
        option::none()
    };

    // Consume the assignment struct
    let TemporaryOfficialAssignment {
        temporary_onoal_id: _,
        employee_address: _,
        original_id,
        assigned_by: _,
        assigned_at: _,
        expires_at: _,
        employee_name: _,
        department: _,
        role: _,
        is_active: _,
    } = assignment;

    event::emit(TemporaryOfficialIDRevoked {
        temporary_onoal_id: temp_id,
        employee_address,
        restored_id: original_id,
        revoked_by: sender,
        revoked_at: current_time,
    });

    restored_nft_opt
}

/// Entry function for assigning temporary official ID
public entry fun assign_temporary_official_id_entry(
    registry: &mut OnoalIDRegistry,
    employee_address: address,
    temporary_id: vector<u8>,
    employee_name: vector<u8>,
    department: vector<u8>,
    role: vector<u8>,
    expires_at: Option<u64>,
    ctx: &mut TxContext,
) {
    let nft = assign_temporary_official_id(
        registry,
        employee_address,
        temporary_id,
        employee_name,
        department,
        role,
        expires_at,
        ctx,
    );

    transfer::public_transfer(nft, employee_address);
}

/// Entry function for revoking temporary official ID
public entry fun revoke_temporary_official_id_entry(
    registry: &mut OnoalIDRegistry,
    employee_address: address,
    ctx: &mut TxContext,
) {
    let mut restored_nft_opt = revoke_temporary_official_id(registry, employee_address, ctx);

    if (option::is_some(&restored_nft_opt)) {
        let restored_nft = option::extract(&mut restored_nft_opt);
        transfer::public_transfer(restored_nft, employee_address);
    };

    option::destroy_none(restored_nft_opt);
}

// ===== Standard Registration Functions (NO PREMIUM PREFIXES) =====

/// Register a user account (alice123, john_doe, crypto_fan) - NO premium prefixes allowed
public fun register_user_id(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>,
    display_name: vector<u8>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    ctx: &mut TxContext,
): OnoalIDNFT {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // Validate user ID format - NO premium prefixes allowed
    assert!(validate_user_id(&desired_id), base::invalid_metadata_error());

    let onoal_id_str = utils::safe_utf8(desired_id);

    // Check availability
    assert!(!table::contains(&registry.id_records, onoal_id_str), base::token_exists_error());
    assert!(!table::contains(&registry.address_to_id, sender), base::account_exists_error());

    // Create user record (no premium status for regular users)
    let record = OnoalIDRecord {
        onoal_id: onoal_id_str,
        sui_address: sender,
        account_type: ACCOUNT_TYPE_USER,
        display_name: utils::safe_utf8(display_name),
        avatar_url: utils::safe_utf8(avatar_url),
        bio: utils::safe_utf8(bio),
        is_verified: false,
        is_premium: false, // No premium for regular users
        verification_tier: VERIFICATION_NONE,
        business_name: option::none(),
        business_category: option::none(),
        business_website: option::none(),
        created_at: current_time,
        last_updated: current_time,
        contact_info: table::new(ctx),
        is_temporary_official: false,
        temporary_expires_at: option::none(),
        original_id_backup: option::none(),
    };

    // Create NFT
    let nft = OnoalIDNFT {
        id: object::new(ctx),
        onoal_id: onoal_id_str,
        owner: sender,
        name: generate_nft_name(&onoal_id_str, ACCOUNT_TYPE_USER),
        description: generate_nft_description(&onoal_id_str, ACCOUNT_TYPE_USER),
        image_url: generate_nft_image_url(&onoal_id_str),
        is_transferable: true,
        created_at: current_time,
    };

    // Register in tables
    table::add(&mut registry.id_records, onoal_id_str, record);
    table::add(&mut registry.address_to_id, sender, onoal_id_str);
    table::add(&mut registry.user_ids, onoal_id_str, true);

    // Update stats
    registry.total_users = registry.total_users + 1;

    event::emit(OnoalIDRegistered {
        onoal_id: onoal_id_str,
        sui_address: sender,
        owner: sender,
        is_premium: false,
        verification_tier: VERIFICATION_NONE,
    });

    nft
}

/// Register a company account (tesla_corp, microsoft_biz, startup_inc) - NO premium prefixes allowed
public fun register_company_id(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>,
    display_name: vector<u8>,
    company_name: vector<u8>,
    business_category: vector<u8>,
    website: vector<u8>,
    mut registration_number: Option<vector<u8>>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    ctx: &mut TxContext,
): OnoalIDNFT {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // Validate company ID format - NO premium prefixes allowed
    assert!(validate_company_id(&desired_id), base::invalid_metadata_error());
    assert!(!vector::is_empty(&company_name), base::invalid_metadata_error());

    let onoal_id_str = utils::safe_utf8(desired_id);

    // Check availability
    assert!(!table::contains(&registry.id_records, onoal_id_str), base::token_exists_error());
    assert!(!table::contains(&registry.address_to_id, sender), base::account_exists_error());

    // Create company info
    let company_info = CompanyInfo {
        company_name: utils::safe_utf8(company_name),
        business_category: utils::safe_utf8(business_category),
        registration_number: if (option::is_some(&registration_number)) {
            option::some(utils::safe_utf8(option::extract(&mut registration_number)))
        } else {
            option::none()
        },
        tax_id: option::none(),
        website: utils::safe_utf8(website),
        employee_count: option::none(),
        founded_year: option::none(),
        is_verified_business: false,
    };

    // Create company record (no premium status for regular companies)
    let record = OnoalIDRecord {
        onoal_id: onoal_id_str,
        sui_address: sender,
        account_type: ACCOUNT_TYPE_COMPANY,
        display_name: utils::safe_utf8(display_name),
        avatar_url: utils::safe_utf8(avatar_url),
        bio: utils::safe_utf8(bio),
        is_verified: false,
        is_premium: false, // No premium for regular companies
        verification_tier: VERIFICATION_BASIC,
        business_name: option::some(company_info.company_name),
        business_category: option::some(company_info.business_category),
        business_website: option::some(company_info.website),
        created_at: current_time,
        last_updated: current_time,
        contact_info: table::new(ctx),
        is_temporary_official: false,
        temporary_expires_at: option::none(),
        original_id_backup: option::none(),
    };

    // Create NFT
    let nft = OnoalIDNFT {
        id: object::new(ctx),
        onoal_id: onoal_id_str,
        owner: sender,
        name: generate_nft_name(&onoal_id_str, ACCOUNT_TYPE_COMPANY),
        description: generate_nft_description(&onoal_id_str, ACCOUNT_TYPE_COMPANY),
        image_url: generate_nft_image_url(&onoal_id_str),
        is_transferable: false, // Companies typically don't transfer IDs
        created_at: current_time,
    };

    // Register in tables
    table::add(&mut registry.id_records, onoal_id_str, record);
    table::add(&mut registry.address_to_id, sender, onoal_id_str);
    table::add(&mut registry.company_ids, onoal_id_str, company_info);

    // Update stats
    registry.total_companies = registry.total_companies + 1;

    option::destroy_none(registration_number);

    event::emit(OnoalIDRegistered {
        onoal_id: onoal_id_str,
        sui_address: sender,
        owner: sender,
        is_premium: false,
        verification_tier: VERIFICATION_BASIC,
    });

    nft
}

/// Register a merchant account (alice_shop, electronics_store, crypto_merchant) - NO premium prefixes allowed
public fun register_merchant_id(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>,
    display_name: vector<u8>,
    store_name: vector<u8>,
    store_category: vector<u8>,
    store_description: vector<u8>,
    mut store_website: Option<vector<u8>>,
    avatar_url: vector<u8>,
    ctx: &mut TxContext,
): OnoalIDNFT {
    let sender = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    // Validate merchant ID format - NO premium prefixes allowed
    assert!(validate_merchant_id(&desired_id), base::invalid_metadata_error());
    assert!(!vector::is_empty(&store_name), base::invalid_metadata_error());

    let onoal_id_str = utils::safe_utf8(desired_id);

    // Check availability
    assert!(!table::contains(&registry.id_records, onoal_id_str), base::token_exists_error());
    assert!(!table::contains(&registry.address_to_id, sender), base::account_exists_error());

    // Create merchant info
    let merchant_info = MerchantInfo {
        store_name: utils::safe_utf8(store_name),
        store_category: utils::safe_utf8(store_category),
        store_description: utils::safe_utf8(store_description),
        store_website: if (option::is_some(&store_website)) {
            option::some(utils::safe_utf8(option::extract(&mut store_website)))
        } else {
            option::none()
        },
        accepts_crypto: true, // Default for Sui-based merchants
        kiosk_ids: vector::empty(),
        is_verified_merchant: false,
    };

    // Create merchant record (no premium status for regular merchants)
    let record = OnoalIDRecord {
        onoal_id: onoal_id_str,
        sui_address: sender,
        account_type: ACCOUNT_TYPE_MERCHANT,
        display_name: utils::safe_utf8(display_name),
        avatar_url: utils::safe_utf8(avatar_url),
        bio: merchant_info.store_description,
        is_verified: false,
        is_premium: false, // No premium for regular merchants
        verification_tier: VERIFICATION_BASIC,
        business_name: option::some(merchant_info.store_name),
        business_category: option::some(merchant_info.store_category),
        business_website: merchant_info.store_website,
        created_at: current_time,
        last_updated: current_time,
        contact_info: table::new(ctx),
        is_temporary_official: false,
        temporary_expires_at: option::none(),
        original_id_backup: option::none(),
    };

    // Create NFT
    let nft = OnoalIDNFT {
        id: object::new(ctx),
        onoal_id: onoal_id_str,
        owner: sender,
        name: generate_nft_name(&onoal_id_str, ACCOUNT_TYPE_MERCHANT),
        description: generate_nft_description(&onoal_id_str, ACCOUNT_TYPE_MERCHANT),
        image_url: generate_nft_image_url(&onoal_id_str),
        is_transferable: false, // Merchants typically don't transfer IDs
        created_at: current_time,
    };

    // Register in tables
    table::add(&mut registry.id_records, onoal_id_str, record);
    table::add(&mut registry.address_to_id, sender, onoal_id_str);
    table::add(&mut registry.merchant_ids, onoal_id_str, merchant_info);

    // Update stats
    registry.total_merchants = registry.total_merchants + 1;

    option::destroy_none(store_website);

    event::emit(OnoalIDRegistered {
        onoal_id: onoal_id_str,
        sui_address: sender,
        owner: sender,
        is_premium: false,
        verification_tier: VERIFICATION_BASIC,
    });

    nft
}

// ===== STRICT Validation Functions (NO PREMIUM PREFIXES) =====

/// Validate user ID format - BLOCKS all premium prefixes including "onoal"
fun validate_user_id(id: &vector<u8>): bool {
    if (!validate_onoal_id(id)) return false;

    // STRICT: Block ALL premium/reserved prefixes
    if (starts_with(id, &b"onoal")) return false; // BLOCKED
    if (starts_with(id, &b"ono")) return false; // BLOCKED
    if (starts_with(id, &b"admin")) return false;
    if (starts_with(id, &b"official")) return false;
    if (starts_with(id, &b"platform")) return false;
    if (starts_with(id, &b"verified")) return false;

    true
}

/// Validate company ID format - BLOCKS all premium prefixes including "onoal"
fun validate_company_id(id: &vector<u8>): bool {
    if (!validate_onoal_id(id)) return false;

    // STRICT: Block ALL premium/reserved prefixes
    if (starts_with(id, &b"onoal")) return false; // BLOCKED
    if (starts_with(id, &b"ono")) return false; // BLOCKED
    if (starts_with(id, &b"admin")) return false;
    if (starts_with(id, &b"official")) return false;
    if (starts_with(id, &b"platform")) return false;
    if (starts_with(id, &b"verified")) return false;

    true
}

/// Validate merchant ID format - BLOCKS all premium prefixes including "onoal"
fun validate_merchant_id(id: &vector<u8>): bool {
    if (!validate_onoal_id(id)) return false;

    // STRICT: Block ALL premium/reserved prefixes
    if (starts_with(id, &b"onoal")) return false; // BLOCKED
    if (starts_with(id, &b"ono")) return false; // BLOCKED
    if (starts_with(id, &b"admin")) return false;
    if (starts_with(id, &b"official")) return false;
    if (starts_with(id, &b"platform")) return false;
    if (starts_with(id, &b"verified")) return false;

    true
}

// ===== NFT Generation Functions =====

/// Generate NFT name based on account type
fun generate_nft_name(onoal_id: &String, account_type: u8): String {
    if (account_type == ACCOUNT_TYPE_USER) {
        string::utf8(b"OnoalID User: ")
    } else if (account_type == ACCOUNT_TYPE_COMPANY) {
        string::utf8(b"OnoalID Company: ")
    } else if (account_type == ACCOUNT_TYPE_MERCHANT) {
        string::utf8(b"OnoalID Merchant: ")
    } else if (account_type == ACCOUNT_TYPE_PLATFORM) {
        string::utf8(b"OnoalID Platform: ")
    } else if (account_type == ACCOUNT_TYPE_OFFICIAL) {
        string::utf8(b"OnoalID Official: ")
    } else {
        string::utf8(b"OnoalID: ")
    }
    // Note: In a real implementation, you'd concatenate the ID here
}

/// Generate NFT description based on account type
fun generate_nft_description(onoal_id: &String, account_type: u8): String {
    if (account_type == ACCOUNT_TYPE_USER) {
        string::utf8(b"Personal OnoalID for user identification and social interaction")
    } else if (account_type == ACCOUNT_TYPE_COMPANY) {
        string::utf8(b"Corporate OnoalID for business identification and commerce")
    } else if (account_type == ACCOUNT_TYPE_MERCHANT) {
        string::utf8(b"Merchant OnoalID for store identification and marketplace integration")
    } else if (account_type == ACCOUNT_TYPE_PLATFORM) {
        string::utf8(b"Platform OnoalID for official platform services")
    } else if (account_type == ACCOUNT_TYPE_OFFICIAL) {
        string::utf8(b"Official Onoal account with verified status and premium features")
    } else {
        string::utf8(b"Official OnoalID for blockchain identity")
    }
}

/// Generate official NFT name for @onoal accounts
fun generate_official_nft_name(onoal_id: &String): String {
    string::utf8(b"Official Onoal: ")
    // Note: In a real implementation, you'd concatenate the ID here
}

/// Generate official NFT description for @onoal accounts
fun generate_official_nft_description(onoal_id: &String): String {
    string::utf8(
        b"Official Onoal account with verified status, premium features, and platform authority",
    )
}

/// Generate official NFT image URL for @onoal accounts
fun generate_official_nft_image_url(onoal_id: &String): String {
    let base_url = b"https://api.onoal.com/official/";
    let suffix = b"/image.png";
    let id_bytes = string::as_bytes(onoal_id);

    let mut url_bytes = base_url;
    vector::append(&mut url_bytes, *id_bytes);
    vector::append(&mut url_bytes, suffix);

    string::utf8(url_bytes)
}

/// Generate temporary official NFT name for @onoal accounts
fun generate_temporary_official_nft_name(onoal_id: &String): String {
    string::utf8(b"Temporary Onoal Staff: ")
    // Note: In a real implementation, you'd concatenate the ID here
}

/// Generate temporary official NFT description for @onoal accounts
fun generate_temporary_official_nft_description(onoal_id: &String): String {
    string::utf8(
        b"Temporary Onoal staff account with official status and premium features. This ID can be revoked by Onoal management.",
    )
}

// ===== ID Resolution =====

/// Resolve OnoalID to Sui address
public fun resolve_onoal_id(registry: &OnoalIDRegistry, onoal_id: String): Option<address> {
    if (table::contains(&registry.id_records, onoal_id)) {
        let record = table::borrow(&registry.id_records, onoal_id);
        option::some(record.sui_address)
    } else {
        option::none()
    }
}

/// Reverse resolve: Sui address to OnoalID
public fun resolve_sui_address(registry: &OnoalIDRegistry, sui_address: address): Option<String> {
    if (table::contains(&registry.address_to_id, sui_address)) {
        let onoal_id = table::borrow(&registry.address_to_id, sui_address);
        option::some(*onoal_id)
    } else {
        option::none()
    }
}

/// Get full record by OnoalID
public fun get_onoal_id_info(registry: &OnoalIDRegistry, onoal_id: String): Option<OnoalIDInfo> {
    if (table::contains(&registry.id_records, onoal_id)) {
        let record = table::borrow(&registry.id_records, onoal_id);
        option::some(OnoalIDInfo {
            onoal_id: record.onoal_id,
            sui_address: record.sui_address,
            display_name: record.display_name,
            avatar_url: record.avatar_url,
            bio: record.bio,
            is_verified: record.is_verified,
            is_premium: record.is_premium,
            verification_tier: record.verification_tier,
            created_at: record.created_at,
            last_updated: record.last_updated,
        })
    } else {
        option::none()
    }
}

// ===== Validation Functions =====

/// Validate OnoalID format
public fun validate_onoal_id(id: &vector<u8>): bool {
    let len = vector::length(id);
    if (len < MIN_ONOAL_ID_LENGTH || len > MAX_ONOAL_ID_LENGTH) {
        return false
    };

    // Check characters: only alphanumeric and underscore
    let mut i = 0;
    while (i < len) {
        let char = *vector::borrow(id, i);
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

/// Check if ID uses premium prefix - UPDATED: Only "onoal" is premium (and restricted)
public fun is_premium_id(id: &vector<u8>): bool {
    // Only "onoal" prefix is considered premium (and restricted to official address)
    starts_with(id, &b"onoal")
}

/// Helper function to check if vector starts with prefix
fun starts_with(haystack: &vector<u8>, needle: &vector<u8>): bool {
    let needle_len = vector::length(needle);
    let haystack_len = vector::length(haystack);

    if (needle_len > haystack_len) return false;

    let mut i = 0;
    while (i < needle_len) {
        if (*vector::borrow(haystack, i) != *vector::borrow(needle, i)) {
            return false
        };
        i = i + 1;
    };

    true
}

// ===== Utility Functions =====

/// Generate NFT image URL for OnoalID
fun generate_nft_image_url(onoal_id: &String): String {
    let base_url = b"https://api.onoal.com/id/";
    let suffix = b"/image.png";
    let id_bytes = string::as_bytes(onoal_id);

    let mut url_bytes = base_url;
    vector::append(&mut url_bytes, *id_bytes);
    vector::append(&mut url_bytes, suffix);

    string::utf8(url_bytes)
}

/// Format OnoalID for display (with @ prefix)
public fun format_onoal_id(onoal_id: &String): String {
    let prefix = b"@";
    let id_bytes = string::as_bytes(onoal_id);

    let mut formatted_bytes = prefix;
    vector::append(&mut formatted_bytes, *id_bytes);

    string::utf8(formatted_bytes)
}

/// Check if OnoalID exists
public fun onoal_id_exists(registry: &OnoalIDRegistry, onoal_id: String): bool {
    table::contains(&registry.id_records, onoal_id)
}

/// Get registry statistics
public fun get_registry_stats(registry: &OnoalIDRegistry): (u64, u64, u64, u64, u64) {
    (
        registry.total_users,
        registry.total_companies,
        registry.total_merchants,
        registry.total_platforms,
        registry.total_official_onoal,
    )
}

/// Check if address is the official Onoal address
public fun is_official_onoal_address(registry: &OnoalIDRegistry, address: address): bool {
    address == registry.official_onoal_address
}

/// Check if address has a temporary official assignment
public fun has_temporary_official_assignment(
    registry: &OnoalIDRegistry,
    employee_address: address,
): bool {
    table::contains(&registry.employee_to_temp_id, employee_address)
}

/// Get temporary assignment info
public fun get_temporary_assignment_info(
    registry: &OnoalIDRegistry,
    employee_address: address,
): Option<String> {
    if (table::contains(&registry.employee_to_temp_id, employee_address)) {
        let temp_id = table::borrow(&registry.employee_to_temp_id, employee_address);
        option::some(*temp_id)
    } else {
        option::none()
    }
}

/// Get temporary assignment details by temp ID
public fun get_assignment_details(registry: &OnoalIDRegistry, temp_id: String): Option<String> {
    if (table::contains(&registry.temporary_assignments, temp_id)) {
        let assignment = table::borrow(&registry.temporary_assignments, temp_id);
        option::some(assignment.employee_name)
    } else {
        option::none()
    }
}

/// Get all temporary assignments count
public fun get_temporary_assignments_count(registry: &OnoalIDRegistry): u64 {
    registry.total_temporary_officials
}

// ===== Integration with OTL Wallet =====

/// Link OnoalID with OTL Wallet (to be called from otl_wallet module)
public fun link_with_otl_wallet(registry: &OnoalIDRegistry, onoal_id: String, wallet_id: ID): bool {
    // This function can be expanded to create links between OnoalID and OTL wallets
    table::contains(&registry.id_records, onoal_id)
}

/// Get user-friendly address format
public fun get_display_address(registry: &OnoalIDRegistry, sui_address: address): String {
    if (table::contains(&registry.address_to_id, sui_address)) {
        let onoal_id = table::borrow(&registry.address_to_id, sui_address);
        format_onoal_id(onoal_id)
    } else {
        // Fallback to shortened Sui address (simplified)
        string::utf8(b"0x...")
    }
}

// ===== Entry Functions =====

/// Entry function for user registration
public entry fun register_user_id_entry(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>,
    display_name: vector<u8>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    ctx: &mut TxContext,
) {
    let nft = register_user_id(
        registry,
        desired_id,
        display_name,
        avatar_url,
        bio,
        ctx,
    );

    transfer::public_transfer(nft, tx_context::sender(ctx));
}

/// Entry function for company registration
public entry fun register_company_id_entry(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>,
    display_name: vector<u8>,
    company_name: vector<u8>,
    business_category: vector<u8>,
    website: vector<u8>,
    registration_number: Option<vector<u8>>,
    avatar_url: vector<u8>,
    bio: vector<u8>,
    ctx: &mut TxContext,
) {
    let nft = register_company_id(
        registry,
        desired_id,
        display_name,
        company_name,
        business_category,
        website,
        registration_number,
        avatar_url,
        bio,
        ctx,
    );

    transfer::public_transfer(nft, tx_context::sender(ctx));
}

/// Entry function for merchant registration
public entry fun register_merchant_id_entry(
    registry: &mut OnoalIDRegistry,
    desired_id: vector<u8>,
    display_name: vector<u8>,
    store_name: vector<u8>,
    store_category: vector<u8>,
    store_description: vector<u8>,
    store_website: Option<vector<u8>>,
    avatar_url: vector<u8>,
    ctx: &mut TxContext,
) {
    let nft = register_merchant_id(
        registry,
        desired_id,
        display_name,
        store_name,
        store_category,
        store_description,
        store_website,
        avatar_url,
        ctx,
    );

    transfer::public_transfer(nft, tx_context::sender(ctx));
}
