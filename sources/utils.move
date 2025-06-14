#[allow(duplicate_alias, deprecated_usage, unused_use)]
module otl::utils;

use otl::base;
use std::string::{Self, String};
use std::vector;
use sui::clock;

// ===== Validation Functions =====

/// Validate token name
public fun validate_name(name: &vector<u8>): bool {
    let len = vector::length(name);
    len > 0 && len <= base::max_name_length()
}

/// Validate token symbol
public fun validate_symbol(symbol: &vector<u8>): bool {
    let len = vector::length(symbol);
    len > 0 && len <= base::max_symbol_length()
}

/// Validate description
public fun validate_description(description: &vector<u8>): bool {
    let len = vector::length(description);
    len > 0 && len <= base::max_description_length()
}

/// Validate URL
public fun validate_url(url: &vector<u8>): bool {
    let len = vector::length(url);
    len <= base::max_url_length()
}

/// Validate decimals
public fun validate_decimals(decimals: u8): bool {
    decimals <= base::max_decimals()
}

/// Validate supply
public fun validate_supply(supply: u64): bool {
    supply > 0 && supply <= base::max_supply()
}

/// Validate amount (must be greater than 0)
public fun validate_amount(amount: u64): bool {
    amount > 0
}

/// Validate address (must not be zero address)
public fun validate_address(addr: address): bool {
    addr != @0x0
}

// ===== String Utilities =====

/// Convert vector<u8> to String with validation
public fun safe_utf8(bytes: vector<u8>): String {
    string::utf8(bytes)
}

/// Check if string is empty
public fun is_empty_string(s: &String): bool {
    string::length(s) == 0
}

/// Truncate string to max length
public fun truncate_string(s: String, max_len: u64): String {
    if (string::length(&s) <= max_len) {
        s
    } else {
        let bytes = string::as_bytes(&s);
        let mut truncated = vector::empty<u8>();
        let mut i = 0;
        while (i < max_len) {
            vector::push_back(&mut truncated, *vector::borrow(bytes, i));
            i = i + 1;
        };
        string::utf8(truncated)
    }
}

// ===== Math Utilities =====

/// Safe addition that checks for overflow
public fun safe_add(a: u64, b: u64): u64 {
    assert!(a <= 18446744073709551615 - b, base::invalid_amount_error()); // u64::MAX - b
    a + b
}

/// Safe subtraction that checks for underflow
public fun safe_sub(a: u64, b: u64): u64 {
    assert!(a >= b, base::insufficient_balance_error());
    a - b
}

/// Safe multiplication that checks for overflow
public fun safe_mul(a: u64, b: u64): u64 {
    if (a == 0 || b == 0) {
        return 0
    };
    assert!(a <= 18446744073709551615 / b, base::invalid_amount_error()); // u64::MAX / b
    a * b
}

/// Calculate percentage of amount
public fun percentage(amount: u64, percent: u64): u64 {
    assert!(percent <= 100, base::invalid_amount_error());
    safe_mul(amount, percent) / 100
}

// ===== Vector Utilities =====

/// Check if vector contains an element
public fun vector_contains<T: copy + drop>(vec: &vector<T>, item: &T): bool {
    let mut i = 0;
    let len = vector::length(vec);
    while (i < len) {
        if (vector::borrow(vec, i) == item) {
            return true
        };
        i = i + 1;
    };
    false
}

/// Remove element from vector if it exists
public fun vector_remove_item<T: copy + drop>(vec: &mut vector<T>, item: &T) {
    let mut i = 0;
    let len = vector::length(vec);
    while (i < len) {
        if (vector::borrow(vec, i) == item) {
            vector::remove(vec, i);
            return
        };
        i = i + 1;
    };
}

/// Get index of element in vector
public fun vector_index_of<T: copy + drop>(vec: &vector<T>, item: &T): (bool, u64) {
    let mut i = 0;
    let len = vector::length(vec);
    while (i < len) {
        if (vector::borrow(vec, i) == item) {
            return (true, i)
        };
        i = i + 1;
    };
    (false, 0)
}

// ===== Batch Validation =====

/// Validate all token mint parameters at once
public fun validate_mint_params(
    name: &vector<u8>,
    symbol: &vector<u8>,
    description: &vector<u8>,
    icon_url: &vector<u8>,
    decimals: u8,
    total_supply: u64,
): (bool, u64) {
    if (!validate_name(name)) {
        return (false, base::invalid_name_error())
    };
    if (!validate_symbol(symbol)) {
        return (false, base::invalid_symbol_error())
    };
    if (!validate_description(description)) {
        return (false, base::invalid_description_error())
    };
    if (!validate_url(icon_url)) {
        return (false, base::invalid_url_error())
    };
    if (!validate_decimals(decimals)) {
        return (false, base::invalid_decimals_error())
    };
    if (!validate_supply(total_supply)) {
        return (false, base::invalid_supply_error())
    };
    (true, 0)
}

/// Validate all collection parameters for NFTs/collectibles
public fun validate_collection_params(
    name: &vector<u8>,
    symbol: &vector<u8>,
    description: &vector<u8>,
    image_url: &vector<u8>,
    max_supply: u64,
): (bool, u64) {
    if (!validate_name(name)) {
        return (false, base::invalid_name_error())
    };
    if (!validate_symbol(symbol)) {
        return (false, base::invalid_symbol_error())
    };
    if (!validate_description(description)) {
        return (false, base::invalid_description_error())
    };
    if (!validate_url(image_url)) {
        return (false, base::invalid_url_error())
    };
    if (!validate_supply(max_supply)) {
        return (false, base::invalid_supply_error())
    };
    (true, 0)
}

// ===== Format Utilities =====

/// Format token amount with decimals for display
public fun format_token_amount(amount: u64, decimals: u8): String {
    if (decimals == 0) {
        return string::utf8(format_u64(amount))
    };

    let divisor = pow(10, decimals);
    let whole = amount / divisor;
    let fractional = amount % divisor;

    let whole_str = format_u64(whole);
    let frac_str = format_u64_with_padding(fractional, decimals);

    let mut result = vector::empty<u8>();
    vector::append(&mut result, whole_str);
    vector::push_back(&mut result, 46); // '.' character
    vector::append(&mut result, frac_str);

    string::utf8(result)
}

/// Helper function to format u64 as bytes
fun format_u64(num: u64): vector<u8> {
    if (num == 0) {
        return vector[48] // '0'
    };

    let mut digits = vector::empty<u8>();
    let mut temp = num;
    while (temp > 0) {
        let digit = (temp % 10) as u8;
        vector::push_back(&mut digits, digit + 48); // Convert to ASCII
        temp = temp / 10;
    };

    vector::reverse(&mut digits);
    digits
}

/// Helper function to format u64 with padding
fun format_u64_with_padding(num: u64, padding: u8): vector<u8> {
    let digits = format_u64(num);
    let current_len = vector::length(&digits) as u8;

    if (current_len >= padding) {
        return digits
    };

    let mut padded = vector::empty<u8>();
    let mut i = current_len;
    while (i < padding) {
        vector::push_back(&mut padded, 48); // '0'
        i = i + 1;
    };
    vector::append(&mut padded, digits);
    padded
}

/// Helper function to calculate power
fun pow(base: u64, exp: u8): u64 {
    let mut result = 1;
    let mut i = 0;
    while (i < exp) {
        result = result * base;
        i = i + 1;
    };
    result
}

// ===== Time Utilities =====

/// Get current timestamp in milliseconds (placeholder implementation)
/// In a real implementation, this would use sui::clock or tx_context
public fun current_time_ms(): u64 {
    // This is a placeholder - in real implementation you'd pass Clock object
    // For now, return a fixed timestamp to avoid compilation errors
    1700000000000 // Nov 15, 2023 00:00:00 GMT
}
