// Payment & Transfer Module - Gas Efficient Transactions & Airdrops
module otl::payment_transfer;

use otl::base;
use otl::batch_utils::{Self, BatchProcessor, BatchResult};
use otl::utils;
use std::string::{Self, String};
use std::vector;
use sui::balance::{Self, Balance};
use sui::bcs;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::event;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

// ===== Constants =====
const MAX_AIRDROP_RECIPIENTS: u64 = 10000;
const MAX_BULK_TRANSFERS: u64 = 1000;
const MIN_PAYMENT_AMOUNT: u64 = 1;
const BATCH_OPERATION_GAS_ESTIMATE: u64 = 50000;

// Operation Types
const OP_AIRDROP: u8 = 1;
const OP_BULK_TRANSFER: u8 = 2;
const OP_PAYMENT: u8 = 3;
const OP_VENDOR_SETTLEMENT: u8 = 4;

// ===== Core Structs =====

/// Gas-efficient payment processor
public struct PaymentProcessor<phantom T> has key {
    id: UID,
    /// Treasury for minting/burning
    treasury_cap: TreasuryCap<T>,
    /// Payment statistics
    total_payments: u64,
    total_volume: u64,
    total_gas_saved: u64,
    /// Batch processing
    batch_processor: BatchProcessor,
    /// Fee configuration
    base_fee: u64,
    bulk_discount: u8, // Percentage discount for bulk operations
    /// Access control
    authorized_operators: VecSet<address>,
    owner: address,
    is_active: bool,
}

/// Airdrop campaign for mass token distribution
public struct AirdropCampaign<phantom T> has key {
    id: UID,
    campaign_name: String,
    description: String,
    /// Distribution parameters
    total_amount: u64,
    amount_per_recipient: u64,
    max_recipients: u64,
    current_recipients: u64,
    /// Recipient tracking
    recipients: Table<address, bool>, // address -> claimed
    whitelist: VecSet<address>, // Optional whitelist
    /// Campaign timing
    start_time: u64,
    end_time: u64,
    /// Campaign state
    is_active: bool,
    is_whitelist_only: bool,
    /// Statistics
    total_claimed: u64,
    total_distributed: u64,
    created_at: u64,
}

/// Bulk transfer batch for gas optimization
public struct BulkTransferBatch<phantom T> has key {
    id: UID,
    /// Transfer details
    transfers: VecMap<address, u64>, // recipient -> amount
    total_amount: u64,
    transfer_count: u64,
    /// Batch state
    is_executed: bool,
    created_by: address,
    created_at: u64,
    executed_at: u64,
    /// Gas optimization
    estimated_gas: u64,
    actual_gas_used: u64,
}

/// Vendor payment settlement (minimal on-chain data)
public struct VendorSettlement has key {
    id: UID,
    event_id: ID,
    vendor: address,
    /// Settlement period
    settlement_period: u64, // Daily, weekly, etc.
    start_time: u64,
    end_time: u64,
    /// Aggregated data
    total_transactions: u64,
    total_volume: u64,
    total_fees: u64,
    /// Settlement state
    is_finalized: bool,
    finalized_at: u64,
    /// Off-chain references
    transaction_hashes: vector<String>, // References to detailed off-chain data
}

/// Payment card for prepaid transactions
public struct PaymentCard<phantom T> has key, store {
    id: UID,
    card_number: String,
    holder: address,
    /// Balance and limits
    balance: u64,
    daily_limit: u64,
    monthly_limit: u64,
    /// Usage tracking
    daily_spent: u64,
    monthly_spent: u64,
    last_reset_day: u64,
    last_reset_month: u64,
    /// Card state
    is_active: bool,
    is_transferable: bool,
    /// Statistics
    total_loaded: u64,
    total_spent: u64,
    transaction_count: u64,
    created_at: u64,
    expires_at: u64,
}

// ===== Events =====

public struct PaymentProcessed<phantom T> has copy, drop {
    processor_id: ID,
    payer: address,
    recipient: address,
    amount: u64,
    fee: u64,
    payment_type: String,
    timestamp: u64,
}

public struct AirdropClaimed<phantom T> has copy, drop {
    campaign_id: ID,
    recipient: address,
    amount: u64,
    timestamp: u64,
}

public struct BulkTransferExecuted<phantom T> has copy, drop {
    batch_id: ID,
    transfer_count: u64,
    total_amount: u64,
    gas_used: u64,
    gas_saved: u64,
    timestamp: u64,
}

public struct VendorSettlementFinalized has copy, drop {
    settlement_id: ID,
    vendor: address,
    total_volume: u64,
    transaction_count: u64,
    settlement_period: u64,
}

public struct PaymentCardLoaded<phantom T> has copy, drop {
    card_id: ID,
    holder: address,
    amount_loaded: u64,
    new_balance: u64,
}

public struct PaymentCardUsed<phantom T> has copy, drop {
    card_id: ID,
    holder: address,
    amount: u64,
    remaining_balance: u64,
    vendor: address,
}

// ===== Core Functions =====

/// Create payment processor
public fun create_payment_processor<T>(
    treasury_cap: TreasuryCap<T>,
    base_fee: u64,
    bulk_discount: u8,
    ctx: &mut TxContext,
): PaymentProcessor<T> {
    assert!(bulk_discount <= 100, base::invalid_amount_error());

    let batch_processor = batch_utils::create_batch_processor(1000, ctx);
    let owner = tx_context::sender(ctx);

    let mut authorized_operators = vec_set::empty<address>();
    vec_set::insert(&mut authorized_operators, owner);

    PaymentProcessor {
        id: object::new(ctx),
        treasury_cap,
        total_payments: 0,
        total_volume: 0,
        total_gas_saved: 0,
        batch_processor,
        base_fee,
        bulk_discount,
        authorized_operators,
        owner,
        is_active: true,
    }
}

/// Create airdrop campaign
public fun create_airdrop_campaign<T>(
    campaign_name: vector<u8>,
    description: vector<u8>,
    total_amount: u64,
    amount_per_recipient: u64,
    max_recipients: u64,
    start_time: u64,
    end_time: u64,
    is_whitelist_only: bool,
    clock: &Clock,
    ctx: &mut TxContext,
): AirdropCampaign<T> {
    assert!(total_amount > 0, base::invalid_amount_error());
    assert!(amount_per_recipient > 0, base::invalid_amount_error());
    assert!(max_recipients <= MAX_AIRDROP_RECIPIENTS, base::invalid_amount_error());
    assert!(end_time > start_time, base::invalid_metadata_error());

    let current_time = clock::timestamp_ms(clock);
    assert!(start_time >= current_time, base::invalid_metadata_error());

    AirdropCampaign {
        id: object::new(ctx),
        campaign_name: utils::safe_utf8(campaign_name),
        description: utils::safe_utf8(description),
        total_amount,
        amount_per_recipient,
        max_recipients,
        current_recipients: 0,
        recipients: table::new(ctx),
        whitelist: vec_set::empty(),
        start_time,
        end_time,
        is_active: true,
        is_whitelist_only,
        total_claimed: 0,
        total_distributed: 0,
        created_at: current_time,
    }
}

/// Add addresses to airdrop whitelist
public fun add_to_whitelist<T>(
    campaign: &mut AirdropCampaign<T>,
    addresses: vector<address>,
    ctx: &mut TxContext,
) {
    let mut i = 0;
    while (i < vector::length(&addresses)) {
        let addr = *vector::borrow(&addresses, i);
        vec_set::insert(&mut campaign.whitelist, addr);
        i = i + 1;
    };
}

/// Claim airdrop tokens
public fun claim_airdrop<T>(
    campaign: &mut AirdropCampaign<T>,
    processor: &mut PaymentProcessor<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<T> {
    let recipient = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);

    // Validate campaign state
    assert!(campaign.is_active, base::invalid_metadata_error());
    assert!(current_time >= campaign.start_time, base::invalid_metadata_error());
    assert!(current_time <= campaign.end_time, base::invalid_metadata_error());
    assert!(campaign.current_recipients < campaign.max_recipients, base::supply_exceeded_error());

    // Check if already claimed
    assert!(!table::contains(&campaign.recipients, recipient), base::token_exists_error());

    // Check whitelist if required
    if (campaign.is_whitelist_only) {
        assert!(vec_set::contains(&campaign.whitelist, &recipient), base::not_authorized_error());
    };

    // Mint tokens
    let tokens = coin::mint(&mut processor.treasury_cap, campaign.amount_per_recipient, ctx);

    // Update campaign state
    table::add(&mut campaign.recipients, recipient, true);
    campaign.current_recipients = campaign.current_recipients + 1;
    campaign.total_claimed = campaign.total_claimed + 1;
    campaign.total_distributed = campaign.total_distributed + campaign.amount_per_recipient;

    // Update processor stats
    processor.total_payments = processor.total_payments + 1;
    processor.total_volume = processor.total_volume + campaign.amount_per_recipient;

    event::emit(AirdropClaimed<T> {
        campaign_id: object::id(campaign),
        recipient,
        amount: campaign.amount_per_recipient,
        timestamp: current_time,
    });

    tokens
}

/// Create bulk transfer batch
public fun create_bulk_transfer_batch<T>(
    transfers: VecMap<address, u64>,
    ctx: &mut TxContext,
): BulkTransferBatch<T> {
    let transfer_count = vec_map::size(&transfers);
    assert!(transfer_count <= MAX_BULK_TRANSFERS, base::invalid_amount_error());

    // Calculate total amount
    let mut total_amount = 0u64;
    let recipients = vec_map::keys(&transfers);
    let mut i = 0;
    while (i < vector::length(&recipients)) {
        let recipient = *vector::borrow(&recipients, i);
        let amount = *vec_map::get(&transfers, &recipient);
        assert!(amount >= MIN_PAYMENT_AMOUNT, base::invalid_amount_error());
        total_amount = total_amount + amount;
        i = i + 1;
    };

    let estimated_gas = transfer_count * BATCH_OPERATION_GAS_ESTIMATE;

    BulkTransferBatch {
        id: object::new(ctx),
        transfers,
        total_amount,
        transfer_count,
        is_executed: false,
        created_by: tx_context::sender(ctx),
        created_at: 0, // Will be set when executed
        executed_at: 0,
        estimated_gas,
        actual_gas_used: 0,
    }
}

/// Execute bulk transfer batch (gas optimized)
public fun execute_bulk_transfer<T>(
    batch: &mut BulkTransferBatch<T>,
    processor: &mut PaymentProcessor<T>,
    mut payment_coins: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(!batch.is_executed, base::invalid_metadata_error());
    assert!(tx_context::sender(ctx) == batch.created_by, base::not_authorized_error());
    assert!(processor.is_active, base::invalid_metadata_error());

    let current_time = clock::timestamp_ms(clock);
    let payment_amount = coin::value(&payment_coins);

    // Calculate fees with bulk discount
    let base_fee_total = batch.transfer_count * processor.base_fee;
    let discount_amount = (base_fee_total * (processor.bulk_discount as u64)) / 100;
    let total_fees = base_fee_total - discount_amount;
    let required_amount = batch.total_amount + total_fees;

    assert!(payment_amount >= required_amount, base::insufficient_balance_error());

    // Split payment for fees
    let fee_coins = coin::split(&mut payment_coins, total_fees, ctx);

    // Burn fee coins (or transfer to treasury)
    coin::burn(&mut processor.treasury_cap, fee_coins);

    // Execute transfers using batch processing
    let recipients = vec_map::keys(&batch.transfers);
    let mut i = 0;
    while (i < vector::length(&recipients)) {
        let recipient = *vector::borrow(&recipients, i);
        let amount = *vec_map::get(&batch.transfers, &recipient);

        // Split coins for this transfer
        let transfer_coins = coin::split(&mut payment_coins, amount, ctx);
        transfer::public_transfer(transfer_coins, recipient);

        i = i + 1;
    };

    // Burn any remaining coins (should be 0)
    if (coin::value(&payment_coins) > 0) {
        coin::burn(&mut processor.treasury_cap, payment_coins);
    } else {
        coin::destroy_zero(payment_coins);
    };

    // Update batch state
    batch.is_executed = true;
    batch.created_at = current_time;
    batch.executed_at = current_time;
    batch.actual_gas_used = batch.estimated_gas; // Simplified

    // Update processor stats
    processor.total_payments = processor.total_payments + batch.transfer_count;
    processor.total_volume = processor.total_volume + batch.total_amount;
    let gas_saved = (batch.transfer_count * BATCH_OPERATION_GAS_ESTIMATE) / 3; // Estimate 3x savings
    processor.total_gas_saved = processor.total_gas_saved + gas_saved;

    event::emit(BulkTransferExecuted<T> {
        batch_id: object::id(batch),
        transfer_count: batch.transfer_count,
        total_amount: batch.total_amount,
        gas_used: batch.actual_gas_used,
        gas_saved,
        timestamp: current_time,
    });
}

/// Create payment card
public fun create_payment_card<T>(
    initial_load: Coin<T>,
    daily_limit: u64,
    monthly_limit: u64,
    duration_days: u64,
    is_transferable: bool,
    clock: &Clock,
    ctx: &mut TxContext,
): PaymentCard<T> {
    let holder = tx_context::sender(ctx);
    let balance = coin::value(&initial_load);
    let current_time = clock::timestamp_ms(clock);

    assert!(balance > 0, base::invalid_amount_error());
    assert!(daily_limit <= monthly_limit, base::invalid_amount_error());

    // Generate card number (simplified)
    let mut card_data = vector::empty<u8>();
    vector::append(&mut card_data, bcs::to_bytes(&holder));
    vector::append(&mut card_data, bcs::to_bytes(&current_time));
    let card_number = string::utf8(card_data);

    // Store coins in card (simplified - in production would use proper escrow)
    transfer::public_transfer(initial_load, @0x0); // Placeholder

    PaymentCard {
        id: object::new(ctx),
        card_number,
        holder,
        balance,
        daily_limit,
        monthly_limit,
        daily_spent: 0,
        monthly_spent: 0,
        last_reset_day: current_time / (24 * 60 * 60 * 1000), // Day number
        last_reset_month: current_time / (30 * 24 * 60 * 60 * 1000), // Month number
        is_active: true,
        is_transferable,
        total_loaded: balance,
        total_spent: 0,
        transaction_count: 0,
        created_at: current_time,
        expires_at: current_time + (duration_days * 24 * 60 * 60 * 1000),
    }
}

/// Use payment card for transaction
public fun use_payment_card<T>(
    card: &mut PaymentCard<T>,
    amount: u64,
    vendor: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(card.is_active, base::invalid_metadata_error());
    assert!(amount > 0, base::invalid_amount_error());
    assert!(amount <= card.balance, base::insufficient_balance_error());

    let current_time = clock::timestamp_ms(clock);
    assert!(current_time < card.expires_at, base::invalid_metadata_error());

    let current_day = current_time / (24 * 60 * 60 * 1000);
    let current_month = current_time / (30 * 24 * 60 * 60 * 1000);

    // Reset daily/monthly counters if needed
    if (current_day > card.last_reset_day) {
        card.daily_spent = 0;
        card.last_reset_day = current_day;
    };
    if (current_month > card.last_reset_month) {
        card.monthly_spent = 0;
        card.last_reset_month = current_month;
    };

    // Check limits
    assert!(card.daily_spent + amount <= card.daily_limit, base::invalid_amount_error());
    assert!(card.monthly_spent + amount <= card.monthly_limit, base::invalid_amount_error());

    // Update card state
    card.balance = card.balance - amount;
    card.daily_spent = card.daily_spent + amount;
    card.monthly_spent = card.monthly_spent + amount;
    card.total_spent = card.total_spent + amount;
    card.transaction_count = card.transaction_count + 1;

    event::emit(PaymentCardUsed<T> {
        card_id: object::id(card),
        holder: card.holder,
        amount,
        remaining_balance: card.balance,
        vendor,
    });
}

/// Create vendor settlement
public fun create_vendor_settlement(
    event_id: ID,
    vendor: address,
    settlement_period: u64,
    start_time: u64,
    end_time: u64,
    transaction_hashes: vector<String>,
    ctx: &mut TxContext,
): VendorSettlement {
    assert!(end_time > start_time, base::invalid_metadata_error());
    assert!(!vector::is_empty(&transaction_hashes), base::invalid_metadata_error());

    VendorSettlement {
        id: object::new(ctx),
        event_id,
        vendor,
        settlement_period,
        start_time,
        end_time,
        total_transactions: vector::length(&transaction_hashes),
        total_volume: 0, // Will be calculated off-chain
        total_fees: 0,
        is_finalized: false,
        finalized_at: 0,
        transaction_hashes,
    }
}

/// Finalize vendor settlement
public fun finalize_vendor_settlement(
    settlement: &mut VendorSettlement,
    total_volume: u64,
    total_fees: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(!settlement.is_finalized, base::invalid_metadata_error());
    assert!(total_volume > 0, base::invalid_amount_error());

    let current_time = clock::timestamp_ms(clock);
    settlement.total_volume = total_volume;
    settlement.total_fees = total_fees;
    settlement.is_finalized = true;
    settlement.finalized_at = current_time;

    event::emit(VendorSettlementFinalized {
        settlement_id: object::id(settlement),
        vendor: settlement.vendor,
        total_volume,
        transaction_count: settlement.total_transactions,
        settlement_period: settlement.settlement_period,
    });
}

// ===== View Functions =====

/// Get payment processor stats
public fun get_processor_stats<T>(processor: &PaymentProcessor<T>): (u64, u64, u64, u64, bool) {
    (
        processor.total_payments,
        processor.total_volume,
        processor.total_gas_saved,
        processor.base_fee,
        processor.is_active,
    )
}

/// Get airdrop campaign info
public fun get_campaign_info<T>(campaign: &AirdropCampaign<T>): (String, u64, u64, u64, u64, bool) {
    (
        campaign.campaign_name,
        campaign.total_amount,
        campaign.amount_per_recipient,
        campaign.current_recipients,
        campaign.max_recipients,
        campaign.is_active,
    )
}

/// Get payment card info
public fun get_card_info<T>(card: &PaymentCard<T>): (String, address, u64, u64, u64, bool) {
    (
        card.card_number,
        card.holder,
        card.balance,
        card.daily_limit,
        card.monthly_limit,
        card.is_active,
    )
}

/// Get bulk transfer batch info
public fun get_batch_info<T>(batch: &BulkTransferBatch<T>): (u64, u64, u64, bool, address) {
    (
        batch.transfer_count,
        batch.total_amount,
        batch.estimated_gas,
        batch.is_executed,
        batch.created_by,
    )
}

/// Check if address can claim airdrop
public fun can_claim_airdrop<T>(campaign: &AirdropCampaign<T>, recipient: address): bool {
    if (!campaign.is_active) return false;
    if (table::contains(&campaign.recipients, recipient)) return false;
    if (campaign.current_recipients >= campaign.max_recipients) return false;
    if (campaign.is_whitelist_only && !vec_set::contains(&campaign.whitelist, &recipient))
        return false;
    true
}

// ===== Entry Functions =====

/// Entry function to claim airdrop
public entry fun claim_airdrop_entry<T>(
    campaign: &mut AirdropCampaign<T>,
    processor: &mut PaymentProcessor<T>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let tokens = claim_airdrop(campaign, processor, clock, ctx);
    transfer::public_transfer(tokens, tx_context::sender(ctx));
}

/// Entry function to execute bulk transfer
public entry fun execute_bulk_transfer_entry<T>(
    batch: &mut BulkTransferBatch<T>,
    processor: &mut PaymentProcessor<T>,
    payment_coins: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    execute_bulk_transfer(batch, processor, payment_coins, clock, ctx);
}

/// Entry function to use payment card
public entry fun use_payment_card_entry<T>(
    card: &mut PaymentCard<T>,
    amount: u64,
    vendor: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    use_payment_card(card, amount, vendor, clock, ctx);
}
