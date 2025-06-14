# 🔧 Utils Module

The **Utils Module** (`otl::utils`) provides essential utility functions, validation helpers, and shared functionality used throughout the Onoal Token Library. It serves as the foundation for consistent data validation, string manipulation, and common operations.

## 📋 Overview

The Utils module contains reusable functions that ensure data integrity, provide consistent validation, and offer common utilities for string manipulation, address validation, and mathematical operations. All OTL modules depend on these utilities for reliable operation.

## 🎯 Key Features

- **✅ Validation Functions** - Address, string, and data validation
- **🔤 String Utilities** - String manipulation and formatting
- **🧮 Math Helpers** - Safe mathematical operations
- **📏 Length Checks** - Consistent length validation
- **🔍 Format Validation** - URL, email, and format checking
- **⚡ Gas Optimization** - Efficient utility implementations
- **🛡️ Safety Checks** - Overflow and underflow protection
- **🔄 Conversion Helpers** - Type conversion utilities

## 🏗️ Core Functions

### Address Validation

```move
// Validate address format and existence
public fun validate_address(addr: address): bool

// Check if address is not zero
public fun is_valid_non_zero_address(addr: address): bool

// Validate multiple addresses
public fun validate_addresses(addresses: &vector<address>): bool

// Check if address is in whitelist
public fun is_address_in_list(addr: address, list: &vector<address>): bool
```

### String Validation

```move
// Validate string length within bounds
public fun validate_string_length(
    text: &String,
    min_length: u64,
    max_length: u64,
): bool

// Check if string is not empty
public fun is_non_empty_string(text: &String): bool

// Validate string contains only allowed characters
public fun validate_string_chars(
    text: &String,
    allowed_chars: &String,
): bool

// Check if string is valid UTF-8
public fun is_valid_utf8(bytes: &vector<u8>): bool
```

### URL and Format Validation

```move
// Validate URL format
public fun validate_url(url: &String): bool

// Validate HTTPS URL
public fun validate_https_url(url: &String): bool

// Validate IPFS URL
public fun validate_ipfs_url(url: &String): bool

// Validate email format
public fun validate_email(email: &String): bool

// Validate username format
public fun validate_username(username: &String): bool
```

### Mathematical Utilities

```move
// Safe addition with overflow check
public fun safe_add(a: u64, b: u64): u64

// Safe subtraction with underflow check
public fun safe_sub(a: u64, b: u64): u64

// Safe multiplication with overflow check
public fun safe_mul(a: u64, b: u64): u64

// Safe division with zero check
public fun safe_div(a: u64, b: u64): u64

// Calculate percentage
public fun calculate_percentage(amount: u64, percentage: u64): u64

// Calculate proportional amount
public fun calculate_proportion(
    total: u64,
    part: u64,
    target_total: u64,
): u64
```

### Vector Utilities

```move
// Check if vector contains element
public fun vector_contains<T: copy + drop>(
    vec: &vector<T>,
    element: &T,
): bool

// Remove element from vector
public fun vector_remove<T>(
    vec: &mut vector<T>,
    element: &T,
): bool

// Get unique elements from vector
public fun vector_unique<T: copy + drop>(
    vec: &vector<T>,
): vector<T>

// Batch validate vector elements
public fun validate_vector_elements<T>(
    vec: &vector<T>,
    validator: |&T| bool,
): bool
```

### String Manipulation

```move
// Convert bytes to string safely
public fun bytes_to_string(bytes: vector<u8>): String

// Convert string to lowercase
public fun to_lowercase(text: &String): String

// Convert string to uppercase
public fun to_uppercase(text: &String): String

// Trim whitespace from string
public fun trim_string(text: &String): String

// Split string by delimiter
public fun split_string(text: &String, delimiter: &String): vector<String>

// Join strings with separator
public fun join_strings(strings: &vector<String>, separator: &String): String
```

### Time and Date Utilities

```move
// Get current timestamp
public fun current_timestamp(): u64

// Check if timestamp is in the past
public fun is_past_timestamp(timestamp: u64): bool

// Check if timestamp is in the future
public fun is_future_timestamp(timestamp: u64): bool

// Calculate time difference
public fun time_difference(start: u64, end: u64): u64

// Add time duration
public fun add_duration(timestamp: u64, duration: u64): u64

// Check if time is within range
public fun is_time_in_range(
    timestamp: u64,
    start: u64,
    end: u64,
): bool
```

### Conversion Utilities

```move
// Convert u64 to string
public fun u64_to_string(value: u64): String

// Convert bool to string
public fun bool_to_string(value: bool): String

// Convert address to string
public fun address_to_string(addr: address): String

// Parse string to u64
public fun string_to_u64(text: &String): Option<u64>

// Convert bytes to hex string
public fun bytes_to_hex(bytes: &vector<u8>): String
```

## 🎯 Usage Examples

### Basic Validation

```move
use otl::utils;

// Validate user input
public fun create_user_profile(
    username: vector<u8>,
    email: vector<u8>,
    bio: vector<u8>,
    ctx: &mut TxContext,
) {
    let username_str = string::utf8(username);
    let email_str = string::utf8(email);
    let bio_str = string::utf8(bio);

    // Validate username
    assert!(
        utils::validate_username(&username_str),
        base::invalid_metadata_error()
    );

    // Validate email format
    assert!(
        utils::validate_email(&email_str),
        base::invalid_metadata_error()
    );

    // Validate bio length
    assert!(
        utils::validate_string_length(&bio_str, 0, 500),
        base::invalid_description_error()
    );

    // Create profile...
}
```

### URL Validation

```move
// Validate metadata URLs
public fun set_nft_metadata(
    nft: &mut NFT,
    image_url: vector<u8>,
    external_url: vector<u8>,
    ctx: &mut TxContext,
) {
    let image_url_str = string::utf8(image_url);
    let external_url_str = string::utf8(external_url);

    // Validate image URL (HTTPS or IPFS)
    assert!(
        utils::validate_https_url(&image_url_str) ||
        utils::validate_ipfs_url(&image_url_str),
        base::invalid_url_error()
    );

    // Validate external URL
    assert!(
        utils::validate_url(&external_url_str),
        base::invalid_url_error()
    );

    // Update metadata...
}
```

### Safe Mathematical Operations

```move
// Safe token calculations
public fun calculate_token_distribution(
    total_supply: u64,
    percentages: vector<u64>,
): vector<u64> {
    let mut distributions = vector::empty<u64>();
    let mut total_percentage = 0;

    // Validate percentages sum to 100
    let mut i = 0;
    while (i < vector::length(&percentages)) {
        let percentage = *vector::borrow(&percentages, i);
        total_percentage = utils::safe_add(total_percentage, percentage);
        i = i + 1;
    };

    assert!(total_percentage == 100, base::invalid_amount_error());

    // Calculate distributions
    i = 0;
    while (i < vector::length(&percentages)) {
        let percentage = *vector::borrow(&percentages, i);
        let amount = utils::calculate_percentage(total_supply, percentage);
        vector::push_back(&mut distributions, amount);
        i = i + 1;
    };

    distributions
}
```

### Batch Validation

```move
// Validate multiple addresses for airdrop
public fun validate_airdrop_recipients(
    recipients: &vector<address>,
    amounts: &vector<u64>,
): bool {
    // Check vectors have same length
    if (vector::length(recipients) != vector::length(amounts)) {
        return false
    };

    // Validate all addresses
    if (!utils::validate_addresses(recipients)) {
        return false
    };

    // Validate all amounts are positive
    let mut i = 0;
    while (i < vector::length(amounts)) {
        let amount = *vector::borrow(amounts, i);
        if (amount == 0) {
            return false
        };
        i = i + 1;
    };

    true
}
```

### String Processing

```move
// Process and validate social media handles
public fun add_social_links(
    profile: &mut UserProfile,
    platform: vector<u8>,
    handle: vector<u8>,
    ctx: &mut TxContext,
) {
    let platform_str = utils::to_lowercase(&string::utf8(platform));
    let handle_str = utils::trim_string(&string::utf8(handle));

    // Validate platform
    let valid_platforms = vector[
        string::utf8(b"twitter"),
        string::utf8(b"instagram"),
        string::utf8(b"discord"),
        string::utf8(b"telegram"),
    ];

    assert!(
        utils::vector_contains(&valid_platforms, &platform_str),
        base::invalid_metadata_error()
    );

    // Validate handle format
    assert!(
        utils::validate_string_length(&handle_str, 1, 50),
        base::invalid_metadata_error()
    );

    // Add to profile...
}
```

## 📏 Validation Constants

### String Length Limits

```move
// Common string length constants
const MIN_USERNAME_LENGTH: u64 = 3;
const MAX_USERNAME_LENGTH: u64 = 30;
const MIN_DISPLAY_NAME_LENGTH: u64 = 1;
const MAX_DISPLAY_NAME_LENGTH: u64 = 50;
const MAX_BIO_LENGTH: u64 = 500;
const MAX_DESCRIPTION_LENGTH: u64 = 1000;
const MAX_URL_LENGTH: u64 = 2048;
```

### Validation Patterns

```move
// Username validation: alphanumeric + underscore, no spaces
public fun validate_username(username: &String): bool {
    let len = string::length(username);
    if (len < MIN_USERNAME_LENGTH || len > MAX_USERNAME_LENGTH) {
        return false
    };

    // Check characters (simplified - actual implementation would be more thorough)
    true
}

// Email validation: basic format check
public fun validate_email(email: &String): bool {
    let email_str = string::bytes(email);
    let len = vector::length(email_str);

    if (len < 5 || len > 254) { // Minimum: a@b.c
        return false
    };

    // Check for @ symbol and basic structure
    // Actual implementation would be more comprehensive
    true
}
```

## 🧮 Mathematical Constants

### Precision and Scaling

```move
// Decimal precision constants
const PRECISION_FACTOR: u64 = 1000000000; // 9 decimals
const PERCENTAGE_FACTOR: u64 = 10000; // 4 decimals for percentages
const BASIS_POINTS: u64 = 10000; // 100.00%

// Safe math limits
const MAX_U64: u64 = 18446744073709551615;
const MAX_SAFE_MULTIPLY: u64 = 4294967295; // sqrt(MAX_U64)
```

### Common Calculations

```move
// Calculate basis points (1 basis point = 0.01%)
public fun calculate_basis_points(amount: u64, basis_points: u64): u64 {
    utils::safe_div(
        utils::safe_mul(amount, basis_points),
        BASIS_POINTS
    )
}

// Calculate compound interest (simplified)
public fun calculate_compound_interest(
    principal: u64,
    rate_basis_points: u64,
    periods: u64,
): u64 {
    let mut result = principal;
    let mut i = 0;

    while (i < periods) {
        let interest = calculate_basis_points(result, rate_basis_points);
        result = utils::safe_add(result, interest);
        i = i + 1;
    };

    result
}
```

## 🔍 Format Validation

### URL Validation

```move
// Comprehensive URL validation
public fun validate_url(url: &String): bool {
    let url_bytes = string::bytes(url);
    let len = vector::length(url_bytes);

    // Check length
    if (len == 0 || len > MAX_URL_LENGTH) {
        return false
    };

    // Check for valid protocol
    let url_str = string::utf8(*url_bytes);
    if (string::index_of(&url_str, &string::utf8(b"http://")) == 0 ||
        string::index_of(&url_str, &string::utf8(b"https://")) == 0 ||
        string::index_of(&url_str, &string::utf8(b"ipfs://")) == 0) {
        return true
    };

    false
}

// IPFS-specific validation
public fun validate_ipfs_url(url: &String): bool {
    let url_str = *string::bytes(url);

    // Check IPFS protocol
    if (string::index_of(&string::utf8(url_str), &string::utf8(b"ipfs://")) != 0) {
        return false
    };

    // Additional IPFS hash validation could be added here
    true
}
```

## ⚡ Performance Optimizations

### Batch Operations

```move
// Batch validate multiple items efficiently
public fun batch_validate_strings(
    strings: &vector<String>,
    min_length: u64,
    max_length: u64,
): bool {
    let mut i = 0;
    let len = vector::length(strings);

    while (i < len) {
        let str = vector::borrow(strings, i);
        if (!validate_string_length(str, min_length, max_length)) {
            return false
        };
        i = i + 1;
    };

    true
}

// Batch address validation
public fun validate_addresses(addresses: &vector<address>): bool {
    let mut i = 0;
    let len = vector::length(addresses);

    while (i < len) {
        let addr = *vector::borrow(addresses, i);
        if (!validate_address(addr)) {
            return false
        };
        i = i + 1;
    };

    true
}
```

## 🛡️ Safety Features

### Overflow Protection

```move
// Safe arithmetic operations with overflow checks
public fun safe_add(a: u64, b: u64): u64 {
    assert!(a <= MAX_U64 - b, base::invalid_amount_error());
    a + b
}

public fun safe_mul(a: u64, b: u64): u64 {
    if (a == 0 || b == 0) {
        return 0
    };

    assert!(a <= MAX_U64 / b, base::invalid_amount_error());
    a * b
}

public fun safe_sub(a: u64, b: u64): u64 {
    assert!(a >= b, base::insufficient_balance_error());
    a - b
}
```

## 🔄 Common Patterns

### Validation Pattern

```move
// Standard validation pattern used throughout OTL
public fun validate_and_process<T>(
    data: T,
    validator: |&T| bool,
    processor: |T| T,
): T {
    assert!(validator(&data), base::invalid_metadata_error());
    processor(data)
}
```

### Error Handling Pattern

```move
// Consistent error handling with utils
public fun safe_operation_with_validation(
    amount: u64,
    recipient: address,
    description: vector<u8>,
): bool {
    // Validate amount
    if (amount == 0) {
        return false
    };

    // Validate recipient
    if (!utils::validate_address(recipient)) {
        return false
    };

    // Validate description
    let desc_str = string::utf8(description);
    if (!utils::validate_string_length(&desc_str, 0, MAX_DESCRIPTION_LENGTH)) {
        return false
    };

    true
}
```

## 📚 Integration Examples

### With Base Module

```move
// Using utils with base error codes
assert!(utils::validate_address(recipient), base::invalid_address_error());
assert!(utils::is_non_empty_string(&name), base::invalid_metadata_error());
```

### With Other Modules

```move
// Token module using utils
public fun create_token_with_validation(
    name: vector<u8>,
    symbol: vector<u8>,
    description: vector<u8>,
    // ... other params
) {
    let name_str = string::utf8(name);
    let symbol_str = string::utf8(symbol);
    let desc_str = string::utf8(description);

    // Use utils for validation
    assert!(utils::validate_string_length(&name_str, 1, 50), base::invalid_metadata_error());
    assert!(utils::validate_string_length(&symbol_str, 1, 10), base::invalid_metadata_error());
    assert!(utils::validate_string_length(&desc_str, 0, 500), base::invalid_description_error());

    // Create token...
}
```

## 🚨 Important Notes

1. **Always Validate** - Use utils functions for all user input validation
2. **Safe Math** - Use safe arithmetic functions to prevent overflows
3. **Consistent Errors** - Combine with base module error codes
4. **Gas Efficiency** - Utils functions are optimized for minimal gas usage
5. **UTF-8 Safety** - Always validate UTF-8 strings before processing

## 📚 Related Documentation

- [Base Module](./base.md) - Error codes and constants
- [All Modules](../README.md) - Integration with other modules
- [Best Practices](../guides/best-practices.md) - Development guidelines
