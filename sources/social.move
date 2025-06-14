#[allow(unused_const, duplicate_alias, unused_field)]
module otl::social;

use otl::base;
use otl::utils;
use std::string::{Self, String};
use sui::display;
use sui::event;
use sui::object::{Self, UID, ID};
use sui::package;
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

// ===== Constants =====
const MAX_SHOWCASE_ITEMS: u64 = 50;
const MAX_COLLECTIONS: u64 = 10;
const MAX_FOLLOWERS: u64 = 10000;
const MAX_BIO_LENGTH: u64 = 500;

// ===== Privacy Levels =====
const PRIVACY_PUBLIC: u8 = 0;
const PRIVACY_FOLLOWERS_ONLY: u8 = 1;
const PRIVACY_PRIVATE: u8 = 2;

// ===== Core Structs =====

/// User profile for social features
public struct UserProfile has key, store {
    id: UID,
    /// Profile owner
    owner: address,
    /// Profile metadata
    username: String,
    display_name: String,
    bio: String,
    avatar_url: String,
    banner_url: String,
    /// Social stats
    followers_count: u64,
    following_count: u64,
    showcases_count: u64,
    /// Privacy settings
    privacy_level: u8,
    /// Verification status
    is_verified: bool,
    verified_at: u64,
    /// Activity timestamps
    created_at: u64,
    last_active: u64,
    /// Social connections
    followers: Table<address, FollowRelation>,
    following: Table<address, FollowRelation>,
    /// User collections and showcases
    showcases: Table<String, ID>, // showcase_name -> Showcase ID
    /// Profile attributes
    profile_attributes: VecMap<String, String>,
}

/// Follow relationship between users
public struct FollowRelation has store {
    follower: address,
    following: address,
    followed_at: u64,
    is_mutual: bool,
}

/// Curated collection showcase
public struct Showcase has key, store {
    id: UID,
    /// Showcase metadata
    name: String,
    description: String,
    cover_image: String,
    /// Showcase owner
    owner: address,
    /// Showcase content
    featured_items: VecSet<ID>, // NFT/Token IDs
    item_descriptions: Table<ID, String>, // Custom descriptions for items
    /// Showcase settings
    is_public: bool,
    is_featured: bool,
    /// Social metrics
    views_count: u64,
    likes_count: u64,
    /// Timestamps
    created_at: u64,
    updated_at: u64,
    /// Showcase tags
    tags: vector<String>,
}

/// Social interaction (like, comment, share)
public struct SocialInteraction has key, store {
    id: UID,
    /// Interaction details
    interaction_type: u8, // 0 = like, 1 = comment, 2 = share
    from_user: address,
    target_id: ID, // Showcase, Profile, or Item ID
    target_type: u8, // 0 = showcase, 1 = profile, 2 = item
    /// Interaction content
    content: String, // Comment text, share message, etc.
    /// Timestamp
    created_at: u64,
}

/// Social notification
public struct SocialNotification has key, store {
    id: UID,
    /// Notification details
    recipient: address,
    sender: address,
    notification_type: u8, // 0 = follow, 1 = like, 2 = comment, 3 = mention
    /// Related content
    related_id: ID,
    message: String,
    /// Status
    is_read: bool,
    created_at: u64,
}

/// One-time witness for Display
public struct SOCIAL has drop {}

// ===== Events =====

public struct ProfileCreated has copy, drop {
    profile_id: ID,
    owner: address,
    username: String,
    created_at: u64,
}

public struct UserFollowed has copy, drop {
    follower: address,
    following: address,
    is_mutual: bool,
}

public struct ShowcaseCreated has copy, drop {
    showcase_id: ID,
    owner: address,
    name: String,
    item_count: u64,
}

public struct ShowcaseLiked has copy, drop {
    showcase_id: ID,
    liked_by: address,
    total_likes: u64,
}

// ===== Profile Management =====

/// Create a new user profile
public fun create_user_profile(
    username: vector<u8>,
    display_name: vector<u8>,
    bio: vector<u8>,
    avatar_url: vector<u8>,
    banner_url: vector<u8>,
    privacy_level: u8,
    ctx: &mut TxContext,
): UserProfile {
    assert!(!vector::is_empty(&username), base::invalid_metadata_error());
    assert!(vector::length(&bio) <= MAX_BIO_LENGTH, base::invalid_metadata_error());
    assert!(privacy_level <= PRIVACY_PRIVATE, base::invalid_metadata_error());

    let owner = tx_context::sender(ctx);
    let current_time = utils::current_time_ms();

    let profile = UserProfile {
        id: object::new(ctx),
        owner,
        username: utils::safe_utf8(username),
        display_name: utils::safe_utf8(display_name),
        bio: utils::safe_utf8(bio),
        avatar_url: utils::safe_utf8(avatar_url),
        banner_url: utils::safe_utf8(banner_url),
        followers_count: 0,
        following_count: 0,
        showcases_count: 0,
        privacy_level,
        is_verified: false,
        verified_at: 0,
        created_at: current_time,
        last_active: current_time,
        followers: table::new(ctx),
        following: table::new(ctx),
        showcases: table::new(ctx),
        profile_attributes: vec_map::empty(),
    };

    event::emit(ProfileCreated {
        profile_id: object::id(&profile),
        owner,
        username: profile.username,
        created_at: current_time,
    });

    profile
}

/// Create profile and transfer to owner
public entry fun create_user_profile_entry(
    username: vector<u8>,
    display_name: vector<u8>,
    bio: vector<u8>,
    avatar_url: vector<u8>,
    banner_url: vector<u8>,
    privacy_level: u8,
    ctx: &mut TxContext,
) {
    let profile = create_user_profile(
        username,
        display_name,
        bio,
        avatar_url,
        banner_url,
        privacy_level,
        ctx,
    );
    transfer::public_transfer(profile, tx_context::sender(ctx));
}

/// Follow another user
public fun follow_user(
    follower_profile: &mut UserProfile,
    following_profile: &mut UserProfile,
    ctx: &mut TxContext,
) {
    let follower_addr = tx_context::sender(ctx);
    assert!(follower_addr == follower_profile.owner, base::not_authorized_error());
    assert!(follower_addr != following_profile.owner, base::invalid_metadata_error());

    let following_addr = following_profile.owner;

    // Check if already following
    assert!(
        !table::contains(&follower_profile.following, following_addr),
        base::account_exists_error(),
    );

    let current_time = utils::current_time_ms();

    // Check if it's mutual
    let is_mutual = table::contains(&following_profile.following, follower_addr);

    // Create follow relations
    let follow_relation = FollowRelation {
        follower: follower_addr,
        following: following_addr,
        followed_at: current_time,
        is_mutual,
    };

    let follower_relation = FollowRelation {
        follower: follower_addr,
        following: following_addr,
        followed_at: current_time,
        is_mutual,
    };

    // Update follower's following list
    table::add(&mut follower_profile.following, following_addr, follow_relation);
    follower_profile.following_count = follower_profile.following_count + 1;

    // Update following's followers list
    table::add(&mut following_profile.followers, follower_addr, follower_relation);
    following_profile.followers_count = following_profile.followers_count + 1;

    // Update mutual status if needed
    if (is_mutual) {
        let mutual_relation = table::borrow_mut(&mut following_profile.following, follower_addr);
        mutual_relation.is_mutual = true;
    };

    // Update activity timestamps
    follower_profile.last_active = current_time;
    following_profile.last_active = current_time;

    event::emit(UserFollowed {
        follower: follower_addr,
        following: following_addr,
        is_mutual,
    });
}

// ===== Showcase Management =====

/// Create a new showcase
public fun create_showcase(
    profile: &mut UserProfile,
    name: vector<u8>,
    description: vector<u8>,
    cover_image: vector<u8>,
    is_public: bool,
    tags: vector<vector<u8>>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == profile.owner, base::not_authorized_error());
    assert!(!vector::is_empty(&name), base::invalid_metadata_error());
    assert!(profile.showcases_count < MAX_COLLECTIONS, base::supply_exceeded_error());

    let name_str = utils::safe_utf8(name);
    assert!(!table::contains(&profile.showcases, name_str), base::token_exists_error());

    let current_time = utils::current_time_ms();

    // Convert tags
    let mut tag_strings = vector::empty<String>();
    let mut i = 0;
    while (i < vector::length(&tags)) {
        let tag = utils::safe_utf8(*vector::borrow(&tags, i));
        vector::push_back(&mut tag_strings, tag);
        i = i + 1;
    };

    let showcase = Showcase {
        id: object::new(ctx),
        name: name_str,
        description: utils::safe_utf8(description),
        cover_image: utils::safe_utf8(cover_image),
        owner: profile.owner,
        featured_items: vec_set::empty(),
        item_descriptions: table::new(ctx),
        is_public,
        is_featured: false,
        views_count: 0,
        likes_count: 0,
        created_at: current_time,
        updated_at: current_time,
        tags: tag_strings,
    };

    let showcase_id = object::id(&showcase);

    // Register showcase in profile
    table::add(&mut profile.showcases, showcase.name, showcase_id);
    profile.showcases_count = profile.showcases_count + 1;
    profile.last_active = current_time;

    event::emit(ShowcaseCreated {
        showcase_id,
        owner: profile.owner,
        name: showcase.name,
        item_count: 0,
    });

    // Transfer showcase to owner
    transfer::public_transfer(showcase, profile.owner);
}

/// Add item to showcase
public fun add_item_to_showcase(
    showcase: &mut Showcase,
    item_id: ID,
    custom_description: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == showcase.owner, base::not_authorized_error());
    assert!(!vec_set::contains(&showcase.featured_items, &item_id), base::token_exists_error());
    assert!(
        vec_set::size(&showcase.featured_items) < MAX_SHOWCASE_ITEMS,
        base::supply_exceeded_error(),
    );

    vec_set::insert(&mut showcase.featured_items, item_id);

    if (!vector::is_empty(&custom_description)) {
        table::add(&mut showcase.item_descriptions, item_id, utils::safe_utf8(custom_description));
    };

    showcase.updated_at = utils::current_time_ms();
}

/// Like a showcase
public fun like_showcase(
    showcase: &mut Showcase,
    liker_profile: &UserProfile,
    ctx: &mut TxContext,
) {
    let liker = tx_context::sender(ctx);
    assert!(liker == liker_profile.owner, base::not_authorized_error());
    assert!(liker != showcase.owner, base::invalid_metadata_error());

    // In a real implementation, you'd track who liked what to prevent double-likes
    showcase.likes_count = showcase.likes_count + 1;
    showcase.updated_at = utils::current_time_ms();

    event::emit(ShowcaseLiked {
        showcase_id: object::id(showcase),
        liked_by: liker,
        total_likes: showcase.likes_count,
    });
}

/// View showcase (increment view count)
public fun view_showcase(showcase: &mut Showcase) {
    showcase.views_count = showcase.views_count + 1;
}

// ===== Social Interactions =====

/// Create a social interaction (like, comment, share)
public fun create_social_interaction(
    interaction_type: u8,
    target_id: ID,
    target_type: u8,
    content: vector<u8>,
    ctx: &mut TxContext,
): SocialInteraction {
    let interaction = SocialInteraction {
        id: object::new(ctx),
        interaction_type,
        from_user: tx_context::sender(ctx),
        target_id,
        target_type,
        content: utils::safe_utf8(content),
        created_at: utils::current_time_ms(),
    };

    interaction
}

// ===== View Functions =====

/// Get profile info
public fun get_profile_info(
    profile: &UserProfile,
): (String, String, String, u64, u64, u64, u8, bool) {
    (
        profile.username,
        profile.display_name,
        profile.bio,
        profile.followers_count,
        profile.following_count,
        profile.showcases_count,
        profile.privacy_level,
        profile.is_verified,
    )
}

/// Get showcase info
public fun get_showcase_info(showcase: &Showcase): (String, String, u64, u64, u64, bool, bool) {
    (
        showcase.name,
        showcase.description,
        vec_set::size(&showcase.featured_items),
        showcase.views_count,
        showcase.likes_count,
        showcase.is_public,
        showcase.is_featured,
    )
}

/// Check if user is following another user
public fun is_following(profile: &UserProfile, target_address: address): bool {
    table::contains(&profile.following, target_address)
}

/// Get follow relationship
public fun get_follow_relation(profile: &UserProfile, target_address: address): (bool, bool, u64) {
    if (table::contains(&profile.following, target_address)) {
        let relation = table::borrow(&profile.following, target_address);
        (true, relation.is_mutual, relation.followed_at)
    } else {
        (false, false, 0)
    }
}

/// Check if showcase contains item
public fun showcase_contains_item(showcase: &Showcase, item_id: ID): bool {
    vec_set::contains(&showcase.featured_items, &item_id)
}

/// Get showcase item description
public fun get_item_description(showcase: &Showcase, item_id: ID): String {
    if (table::contains(&showcase.item_descriptions, item_id)) {
        *table::borrow(&showcase.item_descriptions, item_id)
    } else {
        string::utf8(b"")
    }
}

/// Get showcase tags
public fun get_showcase_tags(showcase: &Showcase): vector<String> {
    showcase.tags
}
