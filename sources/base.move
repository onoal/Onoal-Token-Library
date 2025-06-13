module otl::base;

// ===== Error Codes =====
const EInsufficientBalance: u64 = 0;
const EInvalidAmount: u64 = 1;
const ENotAuthorized: u64 = 2;
const ESupplyExceeded: u64 = 3;
const EInvalidMetadata: u64 = 4;
const ETokenNotFound: u64 = 5;
const EInvalidName: u64 = 6;
const EInvalidSymbol: u64 = 7;
const EInvalidDescription: u64 = 8;
const EInvalidDecimals: u64 = 9;
const EInvalidSupply: u64 = 10;
const EAccountExists: u64 = 11;
const EAccountNotFound: u64 = 12;
const EMinterExists: u64 = 13;
const EMinterNotFound: u64 = 14;
const EInvalidUrl: u64 = 15;
const ETokenExists: u64 = 16;

// ===== Constants =====
const MAX_NAME_LENGTH: u64 = 100;
const MAX_SYMBOL_LENGTH: u64 = 20;
const MAX_DESCRIPTION_LENGTH: u64 = 500;
const MAX_URL_LENGTH: u64 = 200;
const MAX_DECIMALS: u8 = 18;
const MAX_SUPPLY: u64 = 1000000000000000000; // 1 quintillion

// ===== Public Constants Access =====

public fun insufficient_balance_error(): u64 { EInsufficientBalance }

public fun invalid_amount_error(): u64 { EInvalidAmount }

public fun not_authorized_error(): u64 { ENotAuthorized }

public fun supply_exceeded_error(): u64 { ESupplyExceeded }

public fun invalid_metadata_error(): u64 { EInvalidMetadata }

public fun token_not_found_error(): u64 { ETokenNotFound }

public fun invalid_name_error(): u64 { EInvalidName }

public fun invalid_symbol_error(): u64 { EInvalidSymbol }

public fun invalid_description_error(): u64 { EInvalidDescription }

public fun invalid_decimals_error(): u64 { EInvalidDecimals }

public fun invalid_supply_error(): u64 { EInvalidSupply }

public fun account_exists_error(): u64 { EAccountExists }

public fun account_not_found_error(): u64 { EAccountNotFound }

public fun minter_exists_error(): u64 { EMinterExists }

public fun minter_not_found_error(): u64 { EMinterNotFound }

public fun invalid_url_error(): u64 { EInvalidUrl }

public fun token_exists_error(): u64 { ETokenExists }

public fun max_name_length(): u64 { MAX_NAME_LENGTH }

public fun max_symbol_length(): u64 { MAX_SYMBOL_LENGTH }

public fun max_description_length(): u64 { MAX_DESCRIPTION_LENGTH }

public fun max_url_length(): u64 { MAX_URL_LENGTH }

public fun max_decimals(): u8 { MAX_DECIMALS }

public fun max_supply(): u64 { MAX_SUPPLY }
