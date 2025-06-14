# 🏛️ OTL Registry Module

The **OTL Registry Module** (`otl::otl_registry`) serves as the central hub for module management, plugin registration, and cross-module communication within the Onoal Token Library ecosystem.

## 📋 Overview

The OTL Registry provides a comprehensive system for registering, discovering, and managing all modules within the OTL ecosystem. It supports dynamic module loading, dependency validation, plugin architecture, and event-driven communication between modules.

## 🎯 Key Features

- **📦 Module Registration** - Dynamic registration and discovery of OTL modules
- **🔗 Dependency Management** - Automatic validation of module dependencies
- **🔌 Plugin System** - Extensible plugin architecture with hooks
- **📡 Event Communication** - Cross-module event routing and handling
- **🚩 Feature Management** - Global and custom feature flag management
- **📊 Registry Analytics** - Comprehensive tracking and monitoring

## 🏗️ Core Structures

### OTLRegistry

The main registry structure that manages all modules and plugins.

```move
public struct OTLRegistry has key {
    id: UID,
    version: u64,
    created_at: u64,
    last_updated: u64,

    // Module management
    modules: Table<String, ModuleRecord>,
    module_dependencies: Table<String, vector<String>>,

    // Plugin system
    plugins: Table<String, PluginRecord>,
    plugin_hooks: Table<String, vector<String>>,

    // Feature management
    global_features: u64, // Bitfield
    custom_features: VecMap<String, u64>,

    // Event system
    event_hooks: Table<String, vector<String>>,

    // Statistics
    total_modules: u64,
    total_plugins: u64,
    total_events_processed: u64,
}
```

### ModuleRecord

Information about a registered module.

```move
public struct ModuleRecord has store {
    module_id: String,
    module_type: u8,
    version: u64,
    api_version: u64,

    // Dependencies
    dependencies: vector<String>,
    provides: vector<String>,
    requires: vector<String>,

    // Features
    feature_flags: u64,

    // Status
    is_active: bool,
    registered_at: u64,
    registered_by: address,

    // Metadata
    description: String,
    module_attributes: VecMap<String, String>,
}
```

### PluginRecord

Information about a registered plugin.

```move
public struct PluginRecord has store {
    plugin_id: String,
    plugin_type: u8, // 0=extension, 1=middleware, 2=hook
    target_module: String,

    // Plugin configuration
    config: VecMap<String, String>,
    priority: u8,

    // Status
    is_active: bool,
    registered_at: u64,
    registered_by: address,
}
```

### EventHook

Configuration for cross-module event handling.

```move
public struct EventHook has store {
    event_name: String,
    target_module: String,
    handler_function: String,
    is_active: bool,
    priority: u8,
}
```

## 🔧 Core Functions

### Registry Management

```move
// Create new OTL registry
public fun create_otl_registry(ctx: &mut TxContext): OTLRegistry

// Create and share registry
public entry fun create_and_share_otl_registry(ctx: &mut TxContext)

// Get registry information
public fun get_registry_info(registry: &OTLRegistry): (u64, u64, u64, u64, u64)
```

### Module Registration

```move
// Register a new module
public fun register_module(
    registry: &mut OTLRegistry,
    module_id: String,
    module_type: u8,
    version: u64,
    api_version: u64,
    dependencies: vector<String>,
    provides: vector<String>,
    requires: vector<String>,
    feature_flags: u64,
    ctx: &mut TxContext,
)

// Unregister module
public fun unregister_module(
    registry: &mut OTLRegistry,
    module_id: String,
    ctx: &mut TxContext,
)

// Update module status
public fun update_module_status(
    registry: &mut OTLRegistry,
    module_id: String,
    is_active: bool,
    ctx: &mut TxContext,
)
```

### Dependency Management

```move
// Check module dependencies
public fun check_module_dependencies(
    registry: &OTLRegistry,
    module_id: String,
): bool

// Validate dependency chain
public fun validate_dependency_chain(
    registry: &OTLRegistry,
    module_id: String,
): (bool, vector<String>)

// Get module dependencies
public fun get_module_dependencies(
    registry: &OTLRegistry,
    module_id: String,
): vector<String>
```

### Plugin System

```move
// Register plugin
public fun register_plugin(
    registry: &mut OTLRegistry,
    plugin_id: String,
    plugin_type: u8,
    target_module: String,
    config: VecMap<String, String>,
    priority: u8,
    ctx: &mut TxContext,
)

// Unregister plugin
public fun unregister_plugin(
    registry: &mut OTLRegistry,
    plugin_id: String,
    ctx: &mut TxContext,
)

// Get plugins for module
public fun get_module_plugins(
    registry: &OTLRegistry,
    module_id: String,
): vector<String>
```

### Feature Management

```move
// Enable global feature
public fun enable_global_feature(
    registry: &mut OTLRegistry,
    feature_flag: u64,
    ctx: &mut TxContext,
)

// Disable global feature
public fun disable_global_feature(
    registry: &mut OTLRegistry,
    feature_flag: u64,
    ctx: &mut TxContext,
)

// Check if feature is enabled
public fun is_feature_enabled(
    registry: &OTLRegistry,
    feature_flag: u64,
): bool

// Add custom feature
public fun add_custom_feature(
    registry: &mut OTLRegistry,
    feature_name: String,
    feature_id: u64,
    ctx: &mut TxContext,
)
```

### Event System

```move
// Add event hook
public fun add_event_hook(
    registry: &mut OTLRegistry,
    event_name: String,
    target_module: String,
    ctx: &mut TxContext,
)

// Remove event hook
public fun remove_event_hook(
    registry: &mut OTLRegistry,
    event_name: String,
    target_module: String,
    ctx: &mut TxContext,
)

// Get event handlers
public fun get_event_handlers(
    registry: &OTLRegistry,
    event_name: String,
): vector<String>
```

## 🎯 Usage Examples

### Create and Initialize Registry

```move
// Create the main OTL registry
public entry fun initialize_otl_system(ctx: &mut TxContext) {
    let mut registry = otl_registry::create_otl_registry(ctx);

    // Register core modules
    otl_registry::register_module(
        &mut registry,
        string::utf8(b"base"),
        base::module_type_utility(),
        1, // version
        1, // api_version
        vector::empty(), // no dependencies
        vector[string::utf8(b"error_handling"), string::utf8(b"validation")],
        vector::empty(),
        base::feature_analytics(),
        ctx,
    );

    // Share the registry
    transfer::share_object(registry);
}
```

### Register a New Module

```move
// Register the ONOAL token module
otl_registry::register_module(
    &mut registry,
    string::utf8(b"onoal_token"),
    base::module_type_token(),
    1, // version
    1, // api_version
    vector[string::utf8(b"base"), string::utf8(b"utils")], // dependencies
    vector[
        string::utf8(b"native_token"),
        string::utf8(b"fixed_pricing"),
        string::utf8(b"minter_management"),
    ], // provides
    vector[string::utf8(b"validation"), string::utf8(b"error_handling")], // requires
    base::feature_governance() | base::feature_analytics(), // features
    ctx,
);
```

### Register Plugin

```move
// Register analytics plugin for token module
otl_registry::register_plugin(
    &mut registry,
    string::utf8(b"token_analytics"),
    0, // extension type
    string::utf8(b"onoal_token"),
    vec_map::empty(), // no config
    5, // priority
    ctx,
);
```

### Set Up Event Hooks

```move
// Set up cross-module communication
otl_registry::add_event_hook(
    &mut registry,
    string::utf8(b"token_minted"),
    string::utf8(b"otl_wallet"),
    ctx,
);

otl_registry::add_event_hook(
    &mut registry,
    string::utf8(b"token_minted"),
    string::utf8(b"social"),
    ctx,
);
```

### Feature Management

```move
// Enable global features
otl_registry::enable_global_feature(
    &mut registry,
    base::feature_batch_operations(),
    ctx,
);

// Add custom feature
otl_registry::add_custom_feature(
    &mut registry,
    string::utf8(b"defi_integration"),
    512, // custom feature ID
    ctx,
);
```

## 🔌 Plugin Types

### Extension Plugins (Type 0)

Extend module functionality with additional features.

```move
// Example: Analytics extension for tokens
PluginRecord {
    plugin_id: "token_analytics",
    plugin_type: 0,
    target_module: "onoal_token",
    config: {"metrics": "all", "interval": "daily"},
    priority: 5,
    // ...
}
```

### Middleware Plugins (Type 1)

Intercept and modify module operations.

```move
// Example: Rate limiting middleware
PluginRecord {
    plugin_id: "rate_limiter",
    plugin_type: 1,
    target_module: "payment_transfer",
    config: {"max_requests": "100", "window": "3600"},
    priority: 10,
    // ...
}
```

### Hook Plugins (Type 2)

React to module events and trigger actions.

```move
// Example: Notification hook
PluginRecord {
    plugin_id: "notification_hook",
    plugin_type: 2,
    target_module: "social",
    config: {"webhook_url": "https://api.onoal.com/notify"},
    priority: 1,
    // ...
}
```

## 📊 Registry Analytics

### Module Statistics

```move
// Get comprehensive registry information
let (version, total_modules, total_plugins, created_at, last_updated) =
    otl_registry::get_registry_info(&registry);

// Check module health
let is_healthy = otl_registry::check_module_dependencies(&registry, module_id);
```

### Dependency Visualization

```move
// Get dependency chain for troubleshooting
let (is_valid, missing_deps) = otl_registry::validate_dependency_chain(
    &registry,
    string::utf8(b"collectible")
);

if (!is_valid) {
    // Handle missing dependencies
    debug::print(&missing_deps);
}
```

## 🚨 Important Notes

1. **Module Dependencies** - Always register dependencies before dependent modules
2. **Plugin Priority** - Higher priority plugins execute first (10 > 5 > 1)
3. **Event Hooks** - Events are processed in registration order
4. **Feature Flags** - Use bitwise operations for combining features
5. **Registry Sharing** - Registry should be shared for global access

## 🔄 Migration and Updates

### Module Updates

```move
// Update module to new version
otl_registry::update_module_version(
    &mut registry,
    string::utf8(b"onoal_token"),
    2, // new version
    ctx,
);
```

### Plugin Migration

```move
// Migrate plugin configuration
otl_registry::update_plugin_config(
    &mut registry,
    string::utf8(b"analytics_plugin"),
    new_config,
    ctx,
);
```

## 🔗 Integration Patterns

### Module Discovery

```move
// Discover available modules
let available_modules = otl_registry::get_all_modules(&registry);

// Check if specific module is available
let has_social = otl_registry::is_module_registered(
    &registry,
    string::utf8(b"social")
);
```

### Cross-Module Communication

```move
// Emit event that other modules can handle
otl_registry::emit_cross_module_event(
    &registry,
    string::utf8(b"user_registered"),
    event_data,
    ctx,
);
```

## 📚 Related Documentation

- [OTL Interfaces](./otl_interfaces.md) - Interface compliance system
- [OTL Adapters](./otl_adapters.md) - Backward compatibility
- [OTL Init](./otl_init.md) - System initialization
- [Base Module](./base.md) - Foundation constants and types
