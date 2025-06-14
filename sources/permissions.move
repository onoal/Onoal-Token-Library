module otl::permissions;

use otl::base;
use otl::utils;
use std::string::{Self, String};
use sui::event;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

// ===== Permission Constants =====
// Core permissions for different OTL modules
const PERMISSION_ADMIN: vector<u8> = b"admin";
const PERMISSION_TOKEN_ISSUER: vector<u8> = b"token_issuer";
const PERMISSION_COLLECTIBLE_MINTER: vector<u8> = b"collectible_minter";
const PERMISSION_TICKET_ISSUER: vector<u8> = b"ticket_issuer";
const PERMISSION_LOYALTY_MANAGER: vector<u8> = b"loyalty_manager";
const PERMISSION_KIOSK_MANAGER: vector<u8> = b"kiosk_manager";
const PERMISSION_CLAIM_MANAGER: vector<u8> = b"claim_manager";
const PERMISSION_PLATFORM_MODERATOR: vector<u8> = b"platform_moderator";
const PERMISSION_MERCHANT_VERIFIER: vector<u8> = b"merchant_verifier";
const PERMISSION_FINANCIAL_OPERATOR: vector<u8> = b"financial_operator";

// Role hierarchies - higher roles inherit lower role permissions
const ROLE_SUPER_ADMIN: vector<u8> = b"super_admin";
const ROLE_PLATFORM_ADMIN: vector<u8> = b"platform_admin";
const ROLE_RESOURCE_ADMIN: vector<u8> = b"resource_admin";
const ROLE_MERCHANT: vector<u8> = b"merchant";
const ROLE_PARTNER: vector<u8> = b"partner";
const ROLE_OPERATOR: vector<u8> = b"operator";
const ROLE_USER: vector<u8> = b"user";

// Resource types for granular permissions
const RESOURCE_UTILITY_TOKEN: vector<u8> = b"utility_token";
const RESOURCE_COLLECTIBLE: vector<u8> = b"collectible";
const RESOURCE_TICKET: vector<u8> = b"ticket";
const RESOURCE_LOYALTY: vector<u8> = b"loyalty";
const RESOURCE_KIOSK: vector<u8> = b"kiosk";
const RESOURCE_CLAIM_ESCROW: vector<u8> = b"claim_escrow";

// ===== Core Structs =====

/// Central permission registry for the entire OTL ecosystem
public struct PermissionRegistry has key {
    id: UID,
    /// Registry authority (typically platform deployer)
    super_admin: address,
    /// Global role definitions and their permissions
    role_definitions: Table<String, RoleDefinition>,
    /// Address-to-roles mapping
    user_roles: Table<address, UserPermissions>,
    /// Resource-specific permissions (for granular control)
    resource_permissions: Table<ID, ResourcePermissions>, // resource_id -> permissions
    /// Registry metadata
    registry_name: String,
    registry_version: u64,
    /// Statistics
    total_users: u64,
    total_resources: u64,
    /// Configuration
    is_registration_open: bool,
    require_admin_approval: bool,
}

/// Definition of a role and its permissions
public struct RoleDefinition has store {
    role_name: String,
    role_description: String,
    permissions: VecSet<String>, // Set of permission strings
    inherits_from: Option<String>, // Parent role for inheritance
    is_system_role: bool, // Cannot be deleted if true
    created_at: u64,
    created_by: address,
}

/// User's permissions and roles
public struct UserPermissions has store {
    user_address: address,
    /// Global roles
    global_roles: VecSet<String>,
    /// Resource-specific roles
    resource_roles: VecMap<ID, VecSet<String>>, // resource_id -> roles for that resource
    /// Direct permissions (override system)
    direct_permissions: VecSet<String>,
    /// Restrictions/revoked permissions
    revoked_permissions: VecSet<String>,
    /// Metadata
    assigned_by: address,
    assigned_at: u64,
    last_updated: u64,
    is_active: bool,
}

/// Permissions for a specific resource (token type, collection, etc.)
public struct ResourcePermissions has store {
    resource_id: ID,
    resource_type: String, // "utility_token", "collectible", etc.
    resource_name: String,
    /// Who can manage this resource
    admins: VecSet<address>,
    /// Who can issue/mint from this resource
    issuers: VecSet<address>,
    /// Who can moderate/verify for this resource
    moderators: VecSet<address>,
    /// Custom permissions for this resource
    custom_permissions: VecMap<String, VecSet<address>>,
    /// Resource settings
    is_public: bool, // Anyone can interact
    requires_approval: bool, // Actions need approval
    created_by: address,
    created_at: u64,
}

/// Temporary permission request for approval workflows
public struct PermissionRequest has key, store {
    id: UID,
    requester: address,
    request_type: String, // "role", "resource_access", "permission"
    target_resource: Option<ID>,
    requested_role: Option<String>,
    requested_permissions: VecSet<String>,
    justification: String,
    status: u8, // 0=pending, 1=approved, 2=denied
    requested_at: u64,
    reviewed_by: Option<address>,
    reviewed_at: u64,
}

// ===== Events =====

public struct PermissionRegistryCreated has copy, drop {
    registry_id: ID,
    super_admin: address,
    registry_name: String,
}

public struct RoleCreated has copy, drop {
    role_name: String,
    created_by: address,
    permissions_count: u64,
}

public struct RoleAssigned has copy, drop {
    user: address,
    role_name: String,
    assigned_by: address,
    is_global: bool,
    resource_id: Option<ID>,
}

public struct PermissionGranted has copy, drop {
    user: address,
    permission: String,
    granted_by: address,
    resource_id: Option<ID>,
}

public struct PermissionRevoked has copy, drop {
    user: address,
    permission: String,
    revoked_by: address,
    resource_id: Option<ID>,
}

public struct ResourceRegistered has copy, drop {
    resource_id: ID,
    resource_type: String,
    resource_name: String,
    registered_by: address,
}

// ===== Registry Management =====

/// Create the main permission registry (typically done once at deployment)
public fun create_permission_registry(
    registry_name: vector<u8>,
    ctx: &mut TxContext,
): PermissionRegistry {
    let super_admin = tx_context::sender(ctx);

    let mut registry = PermissionRegistry {
        id: object::new(ctx),
        super_admin,
        role_definitions: table::new(ctx),
        user_roles: table::new(ctx),
        resource_permissions: table::new(ctx),
        registry_name: utils::safe_utf8(registry_name),
        registry_version: 1,
        total_users: 0,
        total_resources: 0,
        is_registration_open: true,
        require_admin_approval: false,
    };

    // Create default system roles
    create_default_roles(&mut registry, ctx);

    // Give super admin all permissions
    assign_super_admin_permissions(&mut registry, super_admin, ctx);

    event::emit(PermissionRegistryCreated {
        registry_id: object::id(&registry),
        super_admin,
        registry_name: registry.registry_name,
    });

    registry
}

/// Create default system roles with their permissions
fun create_default_roles(registry: &mut PermissionRegistry, ctx: &mut TxContext) {
    let current_time = utils::current_time_ms();
    let creator = tx_context::sender(ctx);

    // Super Admin - all permissions
    let mut super_admin_permissions = vec_set::empty<String>();
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_ADMIN));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_TOKEN_ISSUER));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_COLLECTIBLE_MINTER));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_TICKET_ISSUER));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_LOYALTY_MANAGER));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_KIOSK_MANAGER));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_CLAIM_MANAGER));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_PLATFORM_MODERATOR));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_MERCHANT_VERIFIER));
    vec_set::insert(&mut super_admin_permissions, utils::safe_utf8(PERMISSION_FINANCIAL_OPERATOR));

    table::add(
        &mut registry.role_definitions,
        utils::safe_utf8(ROLE_SUPER_ADMIN),
        RoleDefinition {
            role_name: utils::safe_utf8(ROLE_SUPER_ADMIN),
            role_description: string::utf8(b"Super administrator with all system permissions"),
            permissions: super_admin_permissions,
            inherits_from: option::none(),
            is_system_role: true,
            created_at: current_time,
            created_by: creator,
        },
    );

    // Platform Admin - platform management
    let mut platform_admin_permissions = vec_set::empty<String>();
    vec_set::insert(
        &mut platform_admin_permissions,
        utils::safe_utf8(PERMISSION_PLATFORM_MODERATOR),
    );
    vec_set::insert(
        &mut platform_admin_permissions,
        utils::safe_utf8(PERMISSION_MERCHANT_VERIFIER),
    );
    vec_set::insert(&mut platform_admin_permissions, utils::safe_utf8(PERMISSION_KIOSK_MANAGER));

    table::add(
        &mut registry.role_definitions,
        utils::safe_utf8(ROLE_PLATFORM_ADMIN),
        RoleDefinition {
            role_name: utils::safe_utf8(ROLE_PLATFORM_ADMIN),
            role_description: string::utf8(b"Platform administrator for marketplace operations"),
            permissions: platform_admin_permissions,
            inherits_from: option::none(),
            is_system_role: true,
            created_at: current_time,
            created_by: creator,
        },
    );

    // Merchant - basic merchant permissions
    let mut merchant_permissions = vec_set::empty<String>();
    vec_set::insert(&mut merchant_permissions, utils::safe_utf8(PERMISSION_TOKEN_ISSUER));
    vec_set::insert(&mut merchant_permissions, utils::safe_utf8(PERMISSION_COLLECTIBLE_MINTER));
    vec_set::insert(&mut merchant_permissions, utils::safe_utf8(PERMISSION_CLAIM_MANAGER));

    table::add(
        &mut registry.role_definitions,
        utils::safe_utf8(ROLE_MERCHANT),
        RoleDefinition {
            role_name: utils::safe_utf8(ROLE_MERCHANT),
            role_description: string::utf8(b"Merchant with token and collectible creation rights"),
            permissions: merchant_permissions,
            inherits_from: option::none(),
            is_system_role: true,
            created_at: current_time,
            created_by: creator,
        },
    );

    // Add other default roles...
}

/// Assign super admin all permissions
fun assign_super_admin_permissions(
    registry: &mut PermissionRegistry,
    super_admin: address,
    ctx: &mut TxContext,
) {
    let current_time = utils::current_time_ms();

    let mut global_roles = vec_set::empty<String>();
    vec_set::insert(&mut global_roles, utils::safe_utf8(ROLE_SUPER_ADMIN));

    let user_permissions = UserPermissions {
        user_address: super_admin,
        global_roles,
        resource_roles: vec_map::empty(),
        direct_permissions: vec_set::empty(),
        revoked_permissions: vec_set::empty(),
        assigned_by: super_admin,
        assigned_at: current_time,
        last_updated: current_time,
        is_active: true,
    };

    table::add(&mut registry.user_roles, super_admin, user_permissions);
    registry.total_users = 1;
}

/// Create registry and share it
public entry fun create_shared_permission_registry(registry_name: vector<u8>, ctx: &mut TxContext) {
    let registry = create_permission_registry(registry_name, ctx);
    transfer::share_object(registry);
}

// ===== Role Management =====

/// Create a new custom role
public fun create_role(
    registry: &mut PermissionRegistry,
    role_name: vector<u8>,
    role_description: vector<u8>,
    permissions: vector<vector<u8>>,
    inherits_from: Option<String>,
    ctx: &mut TxContext,
) {
    assert!(
        has_permission(
            registry,
            tx_context::sender(ctx),
            string::utf8(PERMISSION_ADMIN),
            option::none(),
        ),
        base::not_authorized_error(),
    );

    let role_name_string = utils::safe_utf8(role_name);
    assert!(
        !table::contains(&registry.role_definitions, role_name_string),
        base::role_exists_error(),
    );

    let mut permission_set = vec_set::empty<String>();
    let mut i = 0;
    while (i < vector::length(&permissions)) {
        vec_set::insert(&mut permission_set, utils::safe_utf8(*vector::borrow(&permissions, i)));
        i = i + 1;
    };

    let role_def = RoleDefinition {
        role_name: role_name_string,
        role_description: utils::safe_utf8(role_description),
        permissions: permission_set,
        inherits_from,
        is_system_role: false,
        created_at: utils::current_time_ms(),
        created_by: tx_context::sender(ctx),
    };

    table::add(&mut registry.role_definitions, role_name_string, role_def);

    event::emit(RoleCreated {
        role_name: role_name_string,
        created_by: tx_context::sender(ctx),
        permissions_count: vec_set::size(&permission_set),
    });
}

/// Assign a global role to a user
public fun assign_global_role(
    registry: &mut PermissionRegistry,
    user: address,
    role_name: String,
    ctx: &mut TxContext,
) {
    assert!(
        has_permission(
            registry,
            tx_context::sender(ctx),
            string::utf8(PERMISSION_ADMIN),
            option::none(),
        ),
        base::not_authorized_error(),
    );
    assert!(table::contains(&registry.role_definitions, role_name), base::role_not_found_error());

    if (!table::contains(&registry.user_roles, user)) {
        create_user_permissions(registry, user, ctx);
    };

    let user_perms = table::borrow_mut(&mut registry.user_roles, user);
    vec_set::insert(&mut user_perms.global_roles, role_name);
    user_perms.last_updated = utils::current_time_ms();

    event::emit(RoleAssigned {
        user,
        role_name,
        assigned_by: tx_context::sender(ctx),
        is_global: true,
        resource_id: option::none(),
    });
}

/// Assign a resource-specific role to a user
public fun assign_resource_role(
    registry: &mut PermissionRegistry,
    user: address,
    resource_id: ID,
    role_name: String,
    ctx: &mut TxContext,
) {
    assert!(
        has_permission(
            registry,
            tx_context::sender(ctx),
            string::utf8(PERMISSION_ADMIN),
            option::some(resource_id),
        ),
        base::not_authorized_error(),
    );

    if (!table::contains(&registry.user_roles, user)) {
        create_user_permissions(registry, user, ctx);
    };

    let user_perms = table::borrow_mut(&mut registry.user_roles, user);

    if (!vec_map::contains(&user_perms.resource_roles, &resource_id)) {
        vec_map::insert(&mut user_perms.resource_roles, resource_id, vec_set::empty<String>());
    };

    let resource_roles = vec_map::get_mut(&mut user_perms.resource_roles, &resource_id);
    vec_set::insert(resource_roles, role_name);
    user_perms.last_updated = utils::current_time_ms();

    event::emit(RoleAssigned {
        user,
        role_name,
        assigned_by: tx_context::sender(ctx),
        is_global: false,
        resource_id: option::some(resource_id),
    });
}

// ===== Resource Registration =====

/// Register a new resource (token type, collection, etc.) with the permission system
public fun register_resource(
    registry: &mut PermissionRegistry,
    resource_id: ID,
    resource_type: vector<u8>,
    resource_name: vector<u8>,
    is_public: bool,
    requires_approval: bool,
    ctx: &mut TxContext,
) {
    let creator = tx_context::sender(ctx);

    let mut admins = vec_set::empty<address>();
    vec_set::insert(&mut admins, creator);

    let resource_perms = ResourcePermissions {
        resource_id,
        resource_type: utils::safe_utf8(resource_type),
        resource_name: utils::safe_utf8(resource_name),
        admins,
        issuers: vec_set::empty(),
        moderators: vec_set::empty(),
        custom_permissions: vec_map::empty(),
        is_public,
        requires_approval,
        created_by: creator,
        created_at: utils::current_time_ms(),
    };

    table::add(&mut registry.resource_permissions, resource_id, resource_perms);
    registry.total_resources = registry.total_resources + 1;

    event::emit(ResourceRegistered {
        resource_id,
        resource_type: utils::safe_utf8(resource_type),
        resource_name: utils::safe_utf8(resource_name),
        registered_by: creator,
    });
}

/// Add an issuer to a specific resource
public fun add_resource_issuer(
    registry: &mut PermissionRegistry,
    resource_id: ID,
    issuer: address,
    ctx: &mut TxContext,
) {
    assert!(
        is_resource_admin(registry, resource_id, tx_context::sender(ctx)),
        base::not_authorized_error(),
    );

    let resource_perms = table::borrow_mut(&mut registry.resource_permissions, resource_id);
    vec_set::insert(&mut resource_perms.issuers, issuer);
}

// ===== Permission Checking =====

/// Check if a user has a specific permission (global or resource-specific)
public fun has_permission(
    registry: &PermissionRegistry,
    user: address,
    permission: String,
    resource_id: Option<ID>,
): bool {
    if (!table::contains(&registry.user_roles, user)) {
        return false
    };

    let user_perms = table::borrow(&registry.user_roles, user);

    if (!user_perms.is_active) {
        return false
    };

    // Check if permission is revoked
    if (vec_set::contains(&user_perms.revoked_permissions, &permission)) {
        return false
    };

    // Check direct permissions
    if (vec_set::contains(&user_perms.direct_permissions, &permission)) {
        return true
    };

    // For now, simplified permission checking
    // In a full implementation, you'd check roles and their permissions
    false
}

/// Check if user is admin of a specific resource
public fun is_resource_admin(registry: &PermissionRegistry, resource_id: ID, user: address): bool {
    if (!table::contains(&registry.resource_permissions, resource_id)) {
        return false
    };

    let resource_perms = table::borrow(&registry.resource_permissions, resource_id);
    vec_set::contains(&resource_perms.admins, &user)
}

/// Check if user can issue tokens/NFTs for a specific resource
public fun is_resource_issuer(registry: &PermissionRegistry, resource_id: ID, user: address): bool {
    if (!table::contains(&registry.resource_permissions, resource_id)) {
        return false
    };

    let resource_perms = table::borrow(&registry.resource_permissions, resource_id);
    vec_set::contains(&resource_perms.issuers, &user) ||
    is_resource_admin(registry, resource_id, user)
}

// ===== Helper Functions =====

/// Simplified user permission creation
fun create_user_permissions(registry: &mut PermissionRegistry, user: address, ctx: &mut TxContext) {
    let current_time = utils::current_time_ms();

    let user_perms = UserPermissions {
        user_address: user,
        global_roles: vec_set::empty(),
        resource_roles: vec_map::empty(),
        direct_permissions: vec_set::empty(),
        revoked_permissions: vec_set::empty(),
        assigned_by: tx_context::sender(ctx),
        assigned_at: current_time,
        last_updated: current_time,
        is_active: true,
    };

    table::add(&mut registry.user_roles, user, user_perms);
    registry.total_users = registry.total_users + 1;
}

// ===== View Functions =====

/// Get user's permissions info
public fun get_user_permissions(
    registry: &PermissionRegistry,
    user: address,
): (VecSet<String>, u64, bool) {
    if (!table::contains(&registry.user_roles, user)) {
        return (vec_set::empty(), 0, false)
    };

    let user_perms = table::borrow(&registry.user_roles, user);
    (user_perms.global_roles, user_perms.last_updated, user_perms.is_active)
}

/// Get resource permissions info
public fun get_resource_info(
    registry: &PermissionRegistry,
    resource_id: ID,
): (String, String, VecSet<address>, VecSet<address>, bool) {
    assert!(
        table::contains(&registry.resource_permissions, resource_id),
        base::token_not_found_error(),
    );

    let resource_perms = table::borrow(&registry.resource_permissions, resource_id);
    (
        resource_perms.resource_type,
        resource_perms.resource_name,
        resource_perms.admins,
        resource_perms.issuers,
        resource_perms.is_public,
    )
}

/// Check if registry exists and get basic info
public fun get_registry_info(registry: &PermissionRegistry): (String, u64, u64, u64, address) {
    (
        registry.registry_name,
        registry.registry_version,
        registry.total_users,
        registry.total_resources,
        registry.super_admin,
    )
}
