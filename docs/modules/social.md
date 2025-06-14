# 👥 Social Module

The **Social Module** (`otl::social`) provides comprehensive social features including user profiles, NFT showcases, community interactions, and social networking capabilities. It's designed to create engaging social experiences around digital assets and communities.

## 📋 Overview

The Social module enables users to create rich profiles, showcase their digital assets, build communities, and interact socially within the OTL ecosystem. It supports privacy controls, content curation, and social discovery features.

## 🎯 Key Features

- **👤 User Profiles** - Rich user profiles with customizable metadata
- **🖼️ NFT Showcases** - Curated displays of digital collectibles
- **🏛️ Community Spaces** - Create and manage communities
- **🤝 Social Interactions** - Follow, like, comment, and share
- **🔒 Privacy Controls** - Granular privacy settings
- **🏆 Achievement System** - Badges and reputation tracking
- **📊 Social Analytics** - Engagement metrics and insights
- **🎨 Customization** - Themes, layouts, and personalization

## 🏗️ Core Structures

### UserProfile

Main user profile structure with comprehensive social features.

```move
public struct UserProfile has key {
    id: UID,

    // Basic identity
    username: String,
    display_name: String,
    bio: String,

    // Visual identity
    avatar_url: String,
    banner_url: String,
    theme_settings: VecMap<String, String>,

    // Social stats
    followers_count: u64,
    following_count: u64,
    posts_count: u64,
    likes_received: u64,

    // Privacy settings (bitfield)
    privacy_settings: u8, // 0=public, 1=followers_only, 2=private

    // Profile features
    is_verified: bool,
    verification_level: u8, // 0=none, 1=email, 2=phone, 3=kyc
    account_type: u8, // 0=personal, 1=business, 2=creator, 3=organization

    // Timestamps
    created_at: u64,
    last_active: u64,

    // Linked accounts
    linked_accounts: VecMap<String, String>, // platform -> handle

    // Profile attributes
    custom_attributes: VecMap<String, String>,
}
```

### Showcase

Curated display of digital assets and achievements.

```move
public struct Showcase has key {
    id: UID,

    // Basic info
    owner: address,
    name: String,
    description: String,
    cover_image_url: String,

    // Content
    featured_items: vector<ShowcaseItem>,
    total_items: u64,

    // Organization
    categories: vector<String>,
    tags: vector<String>,

    // Social features
    views_count: u64,
    likes_count: u64,
    shares_count: u64,

    // Settings
    is_public: bool,
    allow_comments: bool,
    is_featured: bool,

    // Timestamps
    created_at: u64,
    updated_at: u64,

    // Layout settings
    layout_type: u8, // 0=grid, 1=list, 2=carousel, 3=masonry
    theme: String,
}
```

### ShowcaseItem

Individual item within a showcase.

```move
public struct ShowcaseItem has store {
    item_id: ID,
    item_type: u8, // 0=NFT, 1=Token, 2=Achievement, 3=Badge

    // Display info
    title: String,
    description: String,
    image_url: String,

    // Metadata
    collection_name: String,
    rarity: Option<String>,
    acquisition_date: u64,

    // Social stats
    likes_count: u64,
    comments_count: u64,

    // Position in showcase
    position: u64,
    is_featured: bool,
}
```

### Community

Community space for groups and organizations.

```move
public struct Community has key {
    id: UID,

    // Basic info
    name: String,
    description: String,
    category: String,

    // Visual identity
    logo_url: String,
    banner_url: String,
    theme_color: String,

    // Management
    creator: address,
    admins: Table<address, bool>,
    moderators: Table<address, bool>,

    // Membership
    members_count: u64,
    max_members: Option<u64>,
    is_invite_only: bool,

    // Content
    posts_count: u64,
    events_count: u64,

    // Settings
    is_public: bool,
    allow_member_posts: bool,
    require_approval: bool,

    // Features
    has_token: bool,
    token_address: Option<address>,
    has_nft_collection: bool,
    collection_address: Option<address>,

    // Timestamps
    created_at: u64,
    last_activity: u64,

    // Community attributes
    rules: vector<String>,
    tags: vector<String>,
    links: VecMap<String, String>,
}
```

### SocialPost

Posts and content shared by users.

```move
public struct SocialPost has key {
    id: UID,

    // Author info
    author: address,
    author_username: String,

    // Content
    content_type: u8, // 0=text, 1=image, 2=nft_share, 3=achievement
    text_content: String,
    media_urls: vector<String>,

    // Referenced items
    referenced_nft: Option<ID>,
    referenced_token: Option<ID>,
    referenced_post: Option<ID>, // For reposts/quotes

    // Social metrics
    likes_count: u64,
    comments_count: u64,
    reposts_count: u64,
    views_count: u64,

    // Engagement
    liked_by: Table<address, bool>,

    // Settings
    is_public: bool,
    allow_comments: bool,
    is_pinned: bool,

    // Timestamps
    created_at: u64,
    edited_at: Option<u64>,

    // Hashtags and mentions
    hashtags: vector<String>,
    mentions: vector<address>,
}
```

### Achievement

User achievements and badges.

```move
public struct Achievement has key, store {
    id: UID,

    // Achievement info
    title: String,
    description: String,
    category: String,

    // Visual
    badge_image_url: String,
    rarity: u8, // 0=common, 1=rare, 2=epic, 3=legendary

    // Criteria
    achievement_type: u8, // 0=collection, 1=trading, 2=social, 3=event
    requirements: VecMap<String, String>,

    // Recipient
    recipient: address,
    earned_at: u64,

    // Verification
    is_verified: bool,
    issued_by: address,

    // Metadata
    points_value: u64,
    is_transferable: bool,
    expiry_date: Option<u64>,
}
```

## 🔧 Core Functions

### Profile Management

```move
// Create user profile
public fun create_user_profile(
    username: vector<u8>,
    display_name: vector<u8>,
    bio: vector<u8>,
    avatar_url: vector<u8>,
    banner_url: vector<u8>,
    privacy_settings: u8,
    ctx: &mut TxContext,
): UserProfile

// Update profile information
public fun update_profile(
    profile: &mut UserProfile,
    display_name: Option<vector<u8>>,
    bio: Option<vector<u8>>,
    avatar_url: Option<vector<u8>>,
    banner_url: Option<vector<u8>>,
    ctx: &mut TxContext,
)

// Set privacy settings
public fun update_privacy_settings(
    profile: &mut UserProfile,
    privacy_settings: u8,
    ctx: &mut TxContext,
)
```

### Showcase Management

```move
// Create showcase
public fun create_showcase(
    profile: &mut UserProfile,
    name: vector<u8>,
    description: vector<u8>,
    cover_image_url: vector<u8>,
    is_public: bool,
    ctx: &mut TxContext,
): Showcase

// Add item to showcase
public fun add_nft_to_showcase(
    showcase: &mut Showcase,
    nft_id: ID,
    title: vector<u8>,
    description: vector<u8>,
    ctx: &mut TxContext,
)

// Add token to showcase
public fun add_token_to_showcase(
    showcase: &mut Showcase,
    token_info: TokenDisplayInfo,
    title: vector<u8>,
    description: vector<u8>,
    ctx: &mut TxContext,
)

// Reorder showcase items
public fun reorder_showcase_items(
    showcase: &mut Showcase,
    new_positions: vector<u64>,
    ctx: &mut TxContext,
)
```

### Community Features

```move
// Create community
public fun create_community(
    name: vector<u8>,
    description: vector<u8>,
    category: vector<u8>,
    logo_url: vector<u8>,
    banner_url: vector<u8>,
    is_public: bool,
    is_invite_only: bool,
    max_members: Option<u64>,
    ctx: &mut TxContext,
): Community

// Join community
public fun join_community(
    community: &mut Community,
    profile: &UserProfile,
    ctx: &mut TxContext,
)

// Add community admin
public fun add_community_admin(
    community: &mut Community,
    admin_address: address,
    ctx: &mut TxContext,
)
```

### Social Interactions

```move
// Follow user
public fun follow_user(
    follower_profile: &mut UserProfile,
    target_profile: &mut UserProfile,
    ctx: &mut TxContext,
)

// Create social post
public fun create_post(
    profile: &mut UserProfile,
    content_type: u8,
    text_content: vector<u8>,
    media_urls: vector<String>,
    referenced_nft: Option<ID>,
    is_public: bool,
    hashtags: vector<String>,
    ctx: &mut TxContext,
): SocialPost

// Like post
public fun like_post(
    post: &mut SocialPost,
    liker_profile: &UserProfile,
    ctx: &mut TxContext,
)

// Comment on post
public fun comment_on_post(
    post: &mut SocialPost,
    commenter_profile: &UserProfile,
    comment_text: vector<u8>,
    ctx: &mut TxContext,
)
```

### Achievement System

```move
// Award achievement
public fun award_achievement(
    recipient: address,
    title: vector<u8>,
    description: vector<u8>,
    category: vector<u8>,
    badge_image_url: vector<u8>,
    rarity: u8,
    achievement_type: u8,
    points_value: u64,
    ctx: &mut TxContext,
): Achievement

// Verify achievement
public fun verify_achievement(
    achievement: &mut Achievement,
    verifier: address,
    ctx: &mut TxContext,
)
```

## 🎯 Usage Examples

### Create User Profile

```move
// Create a comprehensive user profile
let profile = social::create_user_profile(
    b"alice_creator",
    b"Alice Smith",
    b"Digital artist and NFT creator passionate about blockchain art",
    b"https://alice.com/avatar.jpg",
    b"https://alice.com/banner.jpg",
    0, // public profile
    ctx,
);

// Add linked social accounts
social::add_linked_account(
    &mut profile,
    string::utf8(b"twitter"),
    string::utf8(b"@alice_creates"),
    ctx,
);

social::add_linked_account(
    &mut profile,
    string::utf8(b"instagram"),
    string::utf8(b"alice.creates"),
    ctx,
);

transfer::public_transfer(profile, tx_context::sender(ctx));
```

### Create NFT Showcase

```move
// Create a showcase for digital art collection
let showcase = social::create_showcase(
    &mut profile,
    b"My Digital Art Collection",
    b"A curated selection of my favorite digital artworks and NFTs",
    b"https://alice.com/showcase-cover.jpg",
    true, // public showcase
    ctx,
);

// Add NFTs to showcase
social::add_nft_to_showcase(
    &mut showcase,
    nft_id_1,
    b"Cosmic Dreams #42",
    b"One of my favorite pieces from the Cosmic Dreams collection",
    ctx,
);

social::add_nft_to_showcase(
    &mut showcase,
    nft_id_2,
    b"Abstract Emotions",
    b"This piece represents the complexity of human emotions",
    ctx,
);

transfer::public_transfer(showcase, tx_context::sender(ctx));
```

### Create Community

```move
// Create a community for digital artists
let community = social::create_community(
    b"Digital Artists Collective",
    b"A community for digital artists to share, collaborate, and grow together",
    b"Art & Design",
    b"https://dac.com/logo.png",
    b"https://dac.com/banner.jpg",
    true, // public community
    false, // not invite only
    option::some(10000), // max 10k members
    ctx,
);

// Set community rules
social::add_community_rule(
    &mut community,
    string::utf8(b"Be respectful and supportive of fellow artists"),
    ctx,
);

social::add_community_rule(
    &mut community,
    string::utf8(b"Share original artwork only"),
    ctx,
);

social::add_community_rule(
    &mut community,
    string::utf8(b"No spam or self-promotion without context"),
    ctx,
);

transfer::share_object(community);
```

### Social Interactions

```move
// Create a post sharing an NFT
let post = social::create_post(
    &mut profile,
    2, // NFT share type
    b"Just minted this amazing piece! What do you think? 🎨✨",
    vector::empty(), // no additional media
    option::some(nft_id),
    true, // public post
    vector[
        string::utf8(b"NFT"),
        string::utf8(b"DigitalArt"),
        string::utf8(b"NewMint")
    ],
    ctx,
);

// Follow another user
social::follow_user(
    &mut my_profile,
    &mut artist_profile,
    ctx,
);

// Like a post
social::like_post(
    &mut post,
    &profile,
    ctx,
);

transfer::public_transfer(post, tx_context::sender(ctx));
```

### Award Achievements

```move
// Award achievement for first NFT creation
let achievement = social::award_achievement(
    @new_creator,
    b"First Creation",
    b"Minted your first NFT! Welcome to the creator economy.",
    b"Creation",
    b"https://achievements.com/first-creation.png",
    0, // common rarity
    0, // collection type
    100, // 100 points
    ctx,
);

// Award rare achievement for community milestone
let rare_achievement = social::award_achievement(
    @community_leader,
    b"Community Builder",
    b"Built a thriving community with 1000+ members",
    b"Leadership",
    b"https://achievements.com/community-builder.png",
    2, // epic rarity
    2, // social type
    1000, // 1000 points
    ctx,
);

transfer::public_transfer(achievement, @new_creator);
transfer::public_transfer(rare_achievement, @community_leader);
```

## 👤 Profile Features

### Account Types

| Type             | Value | Description       | Features                         |
| ---------------- | ----- | ----------------- | -------------------------------- |
| **Personal**     | `0`   | Individual users  | Basic social features            |
| **Business**     | `1`   | Companies/brands  | Business verification, analytics |
| **Creator**      | `2`   | Content creators  | Creator tools, monetization      |
| **Organization** | `3`   | Non-profits, DAOs | Multi-admin, governance          |

### Verification Levels

| Level | Name      | Requirements          | Benefits             |
| ----- | --------- | --------------------- | -------------------- |
| `0`   | **None**  | Just username         | Basic features       |
| `1`   | **Email** | Email verification    | Increased trust      |
| `2`   | **Phone** | Phone verification    | Enhanced security    |
| `3`   | **KYC**   | Identity verification | Full platform access |

### Privacy Settings

```move
// Privacy levels (bitfield)
const PRIVACY_PUBLIC: u8 = 0;        // 000 - Fully public
const PRIVACY_FOLLOWERS_ONLY: u8 = 1; // 001 - Followers only
const PRIVACY_PRIVATE: u8 = 2;        // 010 - Private profile
const PRIVACY_NO_SEARCH: u8 = 4;      // 100 - Not searchable
```

## 🖼️ Showcase Layouts

### Layout Types

| Type         | Value | Description                | Best For              |
| ------------ | ----- | -------------------------- | --------------------- |
| **Grid**     | `0`   | Uniform grid layout        | Large collections     |
| **List**     | `1`   | Vertical list with details | Detailed descriptions |
| **Carousel** | `2`   | Horizontal scrolling       | Featured items        |
| **Masonry**  | `3`   | Pinterest-style layout     | Mixed media sizes     |

### Showcase Themes

```move
// Predefined themes
let themes = vector[
    string::utf8(b"minimal"),
    string::utf8(b"dark"),
    string::utf8(b"colorful"),
    string::utf8(b"elegant"),
    string::utf8(b"cyberpunk"),
];
```

## 🏛️ Community Management

### Community Categories

- **Art & Design** - Creative communities
- **Gaming** - Game-related communities
- **DeFi** - Financial and trading communities
- **Technology** - Tech and development communities
- **Entertainment** - Media and entertainment
- **Education** - Learning and knowledge sharing
- **Lifestyle** - General interest communities

### Moderation Tools

```move
// Community moderation functions
public fun ban_member(community: &mut Community, member: address, ctx: &mut TxContext)
public fun mute_member(community: &mut Community, member: address, duration: u64, ctx: &mut TxContext)
public fun pin_post(community: &mut Community, post_id: ID, ctx: &mut TxContext)
public fun remove_post(community: &mut Community, post_id: ID, ctx: &mut TxContext)
```

## 🏆 Achievement Categories

### Achievement Types

| Type           | Value | Description                | Examples                         |
| -------------- | ----- | -------------------------- | -------------------------------- |
| **Collection** | `0`   | Asset-related achievements | First NFT, Rare collector        |
| **Trading**    | `1`   | Trading milestones         | Volume trader, Profit master     |
| **Social**     | `2`   | Social engagement          | Influencer, Community builder    |
| **Event**      | `3`   | Event participation        | Festival attendee, Early adopter |

### Rarity Levels

| Rarity        | Value | Color  | Percentage |
| ------------- | ----- | ------ | ---------- |
| **Common**    | `0`   | Gray   | 60%        |
| **Rare**      | `1`   | Blue   | 25%        |
| **Epic**      | `2`   | Purple | 10%        |
| **Legendary** | `3`   | Gold   | 5%         |

## 📊 Social Analytics

### Profile Metrics

```move
// Get profile analytics
public fun get_profile_analytics(
    profile: &UserProfile,
): (u64, u64, u64, u64, u64) // (followers, following, posts, likes_received, profile_views)
```

### Showcase Performance

```move
// Get showcase metrics
public fun get_showcase_analytics(
    showcase: &Showcase,
): (u64, u64, u64, u64) // (views, likes, shares, items_count)
```

### Community Insights

```move
// Get community statistics
public fun get_community_analytics(
    community: &Community,
): (u64, u64, u64, u64) // (members, posts, events, engagement_rate)
```

## 🔒 Privacy & Security

### Privacy Controls

- **Profile Visibility** - Control who can see your profile
- **Showcase Privacy** - Public, followers-only, or private showcases
- **Activity Visibility** - Control activity feed visibility
- **Search Visibility** - Opt out of search results

### Content Moderation

- **Automated Filtering** - AI-powered content filtering
- **Community Reporting** - User-driven content reporting
- **Admin Controls** - Community admin moderation tools
- **Appeal System** - Content removal appeals

## 🔗 Integration Examples

### With OnoalID

```move
// Link social profile to OnoalID
social::link_onoal_id(
    &mut profile,
    &onoal_id,
    ctx,
);
```

### With NFT Collections

```move
// Auto-add new NFTs to showcase
social::enable_auto_showcase(
    &mut showcase,
    collection_id,
    true, // auto-add new mints
    ctx,
);
```

### With Events

```move
// Create event-specific community
let event_community = social::create_event_community(
    &event_registry,
    event_id,
    b"Summer Festival 2024 Attendees",
    ctx,
);
```

## 📚 Related Documentation

- [OnoalID Module](./onoal_id.md) - Identity and verification system
- [Collectible Module](./collectible.md) - NFT management
- [Events & Festivals](./events_festivals.md) - Event-based communities
- [OTL Wallet](./otl_wallet.md) - Asset management integration
