# 🏗️ Base Module

The **Base Module** (`otl::base`) serves as the foundation of the Onoal Token Library, providing essential constants, error codes, version management, and feature flags used throughout the entire ecosystem.

## 📋 Overview

The base module establishes the core infrastructure that all other OTL modules depend on. It defines standardized error codes, version compatibility, feature management, and module configuration systems.

## 🎯 Key Features

- **🔢 Standardized Error Codes** - Consistent error handling across all modules
- **📦 Version Management** - Backward compatibility and migration support
- **🚩 Feature Flags** - Dynamic feature enablement and configuration
- **🏷️ Module Types** - Classification system for different module categories
- **⚙️ Configuration Management** - Extensible module configuration system

## 📊 Constants

### Version Management

```move
const OTL_VERSION: u64 = 1;
const MIN_COMPATIBLE_VERSION: u64 = 1;
const API_VERSION: u64 = 1;
```

### Error Codes

| Code   | Constant               | Description                      |
| ------ | ---------------------- | -------------------------------- |
| `1001` | `INSUFFICIENT_BALANCE` | Not enough balance for operation |
| `1002` | `INVALID_AMOUNT`       | Invalid amount specified         |
| `1003` | `NOT_AUTHORIZED`       | Caller not authorized            |
| `1004` | `SUPPLY_EXCEEDED`      | Token supply limit exceeded      |
| `1005` | `INVALID_METADATA`     | Invalid metadata provided        |
| `1006` | `TOKEN_NOT_FOUND`      | Token does not exist             |
| `1007` | `TOKEN_EXISTS`         | Token already exists             |
| `1008` | `MINTER_EXISTS`        | Minter already registered        |
| `1009` | `INVALID_DESCRIPTION`  | Invalid description format       |
| `1010` | `INVALID_URL`          | Invalid URL format               |
| `1011` | `INVALID_ADDRESS`      | Invalid address                  |
| `1012` | `BATCH_TOO_LARGE`      | Batch operation too large        |
| `1013` | `FEATURE_NOT_ENABLED`  | Required feature not enabled     |
| `1014` | `VERSION_INCOMPATIBLE` | Version incompatibility          |
| `1015` | `MIGRATION_REQUIRED`   | Migration required               |

### Feature Flags (Bitfield)

| Flag                       | Value | Description             |
| -------------------------- | ----- | ----------------------- |
| `FEATURE_STAKING`          | `1`   | Staking functionality   |
| `FEATURE_GOVERNANCE`       | `2`   | Governance features     |
| `FEATURE_YIELD_FARMING`    | `4`   | Yield farming support   |
| `FEATURE_CROSS_CHAIN`      | `8`   | Cross-chain operations  |
| `FEATURE_ANALYTICS`        | `16`  | Analytics and reporting |
| `FEATURE_BATCH_OPERATIONS` | `32`  | Batch processing        |
| `FEATURE_ADVANCED_PRICING` | `64`  | Advanced pricing models |
| `FEATURE_COMPLIANCE`       | `128` | Compliance features     |

### Module Types

| Type                      | Value | Description                |
| ------------------------- | ----- | -------------------------- |
| `MODULE_TYPE_TOKEN`       | `1`   | Token-related modules      |
| `MODULE_TYPE_COLLECTIBLE` | `2`   | NFT/Collectible modules    |
| `MODULE_TYPE_TICKET`      | `3`   | Ticket/Access modules      |
| `MODULE_TYPE_LOYALTY`     | `4`   | Loyalty program modules    |
| `MODULE_TYPE_UTILITY`     | `5`   | Utility/Helper modules     |
| `MODULE_TYPE_SOCIAL`      | `6`   | Social feature modules     |
| `MODULE_TYPE_PAYMENT`     | `7`   | Payment processing modules |
| `MODULE_TYPE_ANALYTICS`   | `8`   | Analytics modules          |

## 🏗️ Core Structures

### ModuleConfig

Configuration structure for individual modules with versioning and feature flags.

```move
public struct ModuleConfig has copy, drop, store {
    version: u64,
    api_version: u64,
    feature_flags: u64,
    module_type: u8,
    is_enabled: bool,
    created_at: u64,
    updated_at: u64,
    config_attributes: VecMap<String, String>,
}
```

**Fields:**

- `version` - Module version number
- `api_version` - API compatibility version
- `feature_flags` - Enabled features (bitfield)
- `module_type` - Module category classification
- `is_enabled` - Whether module is active
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp
- `config_attributes` - Extensible key-value configuration

### CompatibilityInfo

Information about version compatibility and breaking changes.

```move
public struct CompatibilityInfo has copy, drop, store {
    current_version: u64,
    min_compatible_version: u64,
    breaking_changes: vector<String>,
    deprecated_functions: vector<String>,
    migration_required: bool,
}
```

### FeatureRegistry

Dynamic feature management system for runtime feature control.

```move
public struct FeatureRegistry has store {
    enabled_features: u64, // Bitfield
    feature_configs: VecMap<String, String>,
    custom_features: VecMap<String, u64>, // Custom feature IDs
}
```

## 🔧 Core Functions

### Error Code Functions

```move
// Get standardized error codes
public fun insufficient_balance_error(): u64
public fun invalid_amount_error(): u64
public fun not_authorized_error(): u64
public fun supply_exceeded_error(): u64
// ... and more
```

### Version Management

```move
// Version compatibility checks
public fun get_otl_version(): u64
public fun get_api_version(): u64
public fun is_version_compatible(version: u64): bool

// Create compatibility information
public fun create_compatibility_info(
    current_version: u64,
    breaking_changes: vector<String>,
    deprecated_functions: vector<String>,
    migration_required: bool,
): CompatibilityInfo
```

### Feature Management

```move
// Create and manage feature registry
public fun create_feature_registry(): FeatureRegistry

// Enable/disable features
public fun enable_feature(registry: &mut FeatureRegistry, feature_flag: u64)
public fun disable_feature(registry: &mut FeatureRegistry, feature_flag: u64)
public fun is_feature_enabled(registry: &FeatureRegistry, feature_flag: u64): bool

// Custom features
public fun add_custom_feature(
    registry: &mut FeatureRegistry,
    feature_name: String,
    feature_id: u64,
)
public fun is_custom_feature_enabled(
    registry: &FeatureRegistry,
    feature_name: &String
): bool
```

### Module Configuration

```move
// Create module configuration
public fun create_module_config(module_type: u8, initial_features: u64): ModuleConfig

// Update configuration
public fun update_module_config(
    config: &mut ModuleConfig,
    new_features: u64,
    updated_at: u64
)

// Configuration queries
public fun get_module_version(config: &ModuleConfig): u64
public fun get_module_features(config: &ModuleConfig): u64
public fun is_module_enabled(config: &ModuleConfig): bool
```

## 🎯 Usage Examples

### Basic Error Handling

```move
// Check authorization
assert!(tx_context::sender(ctx) == owner, base::not_authorized_error());

// Validate amount
assert!(amount > 0, base::invalid_amount_error());

// Check supply limits
assert!(new_supply <= max_supply, base::supply_exceeded_error());
```

### Feature Flag Usage

```move
// Check if staking is enabled
let staking_enabled = base::is_feature_enabled(
    &feature_registry,
    base::feature_staking()
);

// Enable batch operations
base::enable_feature(&mut registry, base::feature_batch_operations());

// Combine multiple features
let combined_features = base::feature_staking() | base::feature_governance();
```

### Version Compatibility

```move
// Check if version is compatible
assert!(
    base::is_version_compatible(module_version),
    base::version_incompatible_error()
);

// Create compatibility info
let compat_info = base::create_compatibility_info(
    2, // current version
    vector[string::utf8(b"Breaking change in API")],
    vector[string::utf8(b"old_function_name")],
    true // migration required
);
```

## 🔗 Integration

The base module is automatically imported by all other OTL modules:

```move
use otl::base;

// Use error codes
assert!(condition, base::not_authorized_error());

// Check features
if (base::is_feature_enabled(&registry, base::feature_analytics())) {
    // Analytics code
};

// Get version info
let version = base::get_otl_version();
```

## 🚨 Important Notes

1. **Error Code Stability** - Error codes are guaranteed to remain stable across versions
2. **Feature Flags** - Use bitwise operations for combining multiple features
3. **Version Compatibility** - Always check version compatibility before operations
4. **Module Types** - Properly classify modules for registry organization

## 🔄 Migration Guide

When upgrading the base module:

1. Check `MIN_COMPATIBLE_VERSION` for breaking changes
2. Update feature flags if new features are added
3. Migrate deprecated error codes to new ones
4. Update module configurations with new attributes

## 📚 Related Documentation

- [OTL Registry](./otl_registry.md) - Module registration system
- [Utils Module](./utils.md) - Shared utility functions
- [Migration Guide](../guides/migration.md) - Version upgrade procedures
