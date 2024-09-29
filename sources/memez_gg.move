module memez_gg::memez_gg;
// === Imports ===

use std::type_name::{Self, TypeName};

use sui::{
    sui::SUI,
    table::{Self, Table},
    dynamic_object_field as dof,
    coin::{Coin,TreasuryCap, CoinMetadata},
};

use amm::{
    swap as af_swap,
    price as af_price,
    deposit as af_deposit, 
    withdraw as af_withdraw,
    pool_registry::PoolRegistry,
    pool_factory::create_pool_2_coins,
    pool::{CreatePoolCap, Pool as AftermathPool},
};

use treasury::treasury::Treasury;

use protocol_fee_vault::vault::ProtocolFeeVault;

use insurance_fund::insurance_fund::InsuranceFund;

use referral_vault::referral_vault::ReferralVault;

use memez_gg::{
    events,
    revenue,
    allowlist,
    black_ice,
    liquidity,
    lp_metadata,
    acl::AuthWitness,
    version::CurrentVersion,
};

// === Constants ===

// @dev Maximum volatility
const FLATNESS: u64 = 0; 

// @dev 1 billion total supply with 9 decimals
const MEME_SUPPLY: u64 = 1_000_000_000__000_000_000;

// @dev 900M - 90% of the supply
const MAX_BURN_AMOUNT: u64 = 900_000_000__000_000_000;

// @dev 100%
const MAX_WEIGHT: u64 = 1__000_000_000_000_000_000;

// @dev 50%
const MAX_SUI_WEIGHT: u64 = 500_000_000_000_000_000;

// @dev 0.3% 
const SWAP_FEE_IN: u64 = 3_000_000_000_000_000;

// === Errors ===

#[error]
const InvalidMemeSupply: vector<u8> = b"Meme TreasuryCap must have 0 supply";

#[error]
const InvalidMemeDecimals: vector<u8> = b"Meme Coin must have 9 decimals";

#[error]
const InvalidBurnAmount: vector<u8> = b"You cannot burn more than 90% of the supply";

#[error]
const InvalidWeights: vector<u8> = b"Weights are out of range";

#[error]
const InvalidSuiWeight: vector<u8> = b"Max weight for Sui is 50%";

#[error]
const InvalidWeightLength: vector<u8> = b"Please provide two weight values";

#[error]
const InvalidPool: vector<u8> = b"The pair already exists";

#[error]
const InvalidLiquidityManagement: vector<u8> = b"Adding or removing liquidity is not supported";

// Structs 

public struct RegistryKey<phantom CoinX, phantom CoinY>() has copy, store, drop;

public struct MemezRegistry has key {
    id: UID, 
    pools: Table<TypeName, address>,
    lp_coins: Table<TypeName, address>,
}

public struct AftermathPoolKey() has store, copy, drop;

public struct MemezPool<phantom LpCoin> has key {
    id: UID,
    allows_liquidity_management: bool,
}

public struct DeployerCap<phantom LpCoin> has key, store {
    id: UID,
    pool: address
}

// === Initializers ===

fun init(ctx: &mut TxContext) {
    let registry = MemezRegistry {
        id: object::new(ctx),
        pools: table::new(ctx),
        lp_coins: table::new(ctx),
    };

    transfer::share_object(registry);
}

// === Create Pools ===

#[allow(lint(share_owned))]
public fun new<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    meme_coin: Coin<Meme>,
    fees: vector<u64>,
    beneficiary: address,
    version: &CurrentVersion,
    allows_liquidity_management: bool,
    ctx: &mut TxContext,
): (MemezPool<LpCoin>, DeployerCap<LpCoin>, Coin<LpCoin>) {
    version.assert_is_valid();

    new_impl(
        memez_registry,
        pool_registry,
        meme_metadata,
        create_pool_cap,
        weights,
        sui_coin,
        meme_coin,
        fees,
        beneficiary,
        allows_liquidity_management,
        ctx
    )
}

public fun launch<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    meme_treasury: TreasuryCap<Meme>,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    burn_amount: u64,
    fees: vector<u64>,
    beneficiary: address,
    version: &CurrentVersion,
    allows_liquidity_management: bool,
    ctx: &mut TxContext,
): (MemezPool<LpCoin>, DeployerCap<LpCoin>) {
    version.assert_is_valid();

    launch_impl(
        memez_registry, 
        pool_registry, 
        meme_treasury, 
        meme_metadata, 
        create_pool_cap, 
        weights,
        sui_coin, 
        burn_amount, 
        fees,
        beneficiary,
        allows_liquidity_management,
        ctx
    )
}

#[allow(lint(share_owned))]
public fun share<LpCoin>(self: MemezPool<LpCoin>) {
    transfer::share_object(self);
}

// === Swap Functions ===

public fun swap_exact_in<CoinIn, CoinOut, LpCoin>(
    self: &mut MemezPool<LpCoin>,
    pool_registry: &PoolRegistry,
    protocol_fee_vault: &ProtocolFeeVault,
    treasury: &mut Treasury,
    insurance_fund: &mut InsuranceFund,
    referral_vault: &ReferralVault,
    coin_in: &mut Coin<CoinIn>,
    expected_coin_out: u64,
    allowable_slippage: u64,
    version: &CurrentVersion,
    ctx: &mut TxContext,
): Coin<CoinOut> {
    version.assert_is_valid();

    revenue::take_swap_fee(&self.id, coin_in, ctx);
    revenue::take_freeze_fee(&self.id, coin_in, ctx);

    let coin_in_value = coin_in.value();

    af_swap::swap_exact_in(
        self.af_pool_mut<LpCoin>(),
        pool_registry,
        protocol_fee_vault,
        treasury,
        insurance_fund,
        referral_vault,
        coin_in.split(coin_in_value, ctx),
        expected_coin_out,
        allowable_slippage,
        ctx,
    )
}

public fun swap_exact_out<CoinIn, CoinOut, LpCoin>(
    self: &mut MemezPool<LpCoin>,
    pool_registry: &PoolRegistry,
    protocol_fee_vault: &ProtocolFeeVault,
    treasury: &mut Treasury,
    insurance_fund: &mut InsuranceFund,
    referral_vault: &ReferralVault,
    amount_out: u64,
    coin_in: &mut Coin<CoinIn>,
    expected_coin_out: u64,
    allowable_slippage: u64,
    version: &CurrentVersion,
    ctx: &mut TxContext,
): Coin<CoinOut> {
    version.assert_is_valid();

    revenue::take_swap_fee(&self.id, coin_in, ctx);
    revenue::take_freeze_fee(&self.id, coin_in, ctx);

    let sui_coin = liquidity::start(&mut self.id, ctx);

    if (sui_coin.value() == 0) {
        sui_coin.destroy_zero();
    } else {
        let lp_coin =af_deposit::deposit_1_coins(
            self.af_pool_mut<LpCoin>(),
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            sui_coin,
            0,
            0,
            ctx
        );

        black_ice::freeze_it(lp_coin, ctx);
    };

    af_swap::swap_exact_out(
        self.af_pool_mut<LpCoin>(),
        pool_registry,
        protocol_fee_vault,
        treasury,
        insurance_fund,
        referral_vault,
        amount_out,
        coin_in,
        expected_coin_out,
        allowable_slippage,
        ctx,
    )
}

// === Liquidity Management Functions ===

public fun add_liquidity<Meme, LpCoin>(
    self: &mut MemezPool<LpCoin>,
    pool_registry: &PoolRegistry,
    protocol_fee_vault: &ProtocolFeeVault,
    treasury: &mut Treasury,
    insurance_fund: &mut InsuranceFund,
    referral_vault: &ReferralVault,
    sui_coin: &mut Coin<SUI>,
    meme_coin: &mut Coin<Meme>,
    version: &CurrentVersion,
    ctx: &mut TxContext,
): Coin<LpCoin> {
    assert!(self.allows_liquidity_management, InvalidLiquidityManagement);
    version.assert_is_valid();

    revenue::take_liquidity_management_fee(&self.id, sui_coin, ctx);
    revenue::take_liquidity_management_fee(&self.id, meme_coin, ctx);

    af_deposit::all_coin_deposit_2_coins(
        self.af_pool_mut<LpCoin>(),
        pool_registry,
        protocol_fee_vault,
        treasury,
        insurance_fund,
        referral_vault,
        sui_coin,
        meme_coin,
        ctx,
    )
}

public fun remove_liquidity<Meme, LpCoin>(
    self: &mut MemezPool<LpCoin>,
    pool_registry: &PoolRegistry,
    protocol_fee_vault: &ProtocolFeeVault,
    treasury: &mut Treasury,
    insurance_fund: &mut InsuranceFund,
    referral_vault: &ReferralVault,
    lp_coin: Coin<LpCoin>,
    version: &CurrentVersion,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<Meme>) {
    assert!(self.allows_liquidity_management, InvalidLiquidityManagement);
    version.assert_is_valid();

    let (mut sui_coin, mut meme_coin) = af_withdraw::all_coin_withdraw_2_coins(
        self.af_pool_mut<LpCoin>(),
        pool_registry,
        protocol_fee_vault,
        treasury,
        insurance_fund,
        referral_vault,
        lp_coin,
        ctx,
    );

    revenue::take_liquidity_management_fee(&self.id, &mut sui_coin, ctx);
    revenue::take_liquidity_management_fee(&self.id, &mut meme_coin, ctx);

    (sui_coin, meme_coin)
}

// === Destroy ===

public fun destroy<LpCoin>(deployer_cap: DeployerCap<LpCoin>) {
    let DeployerCap { id, .. } = deployer_cap;
    id.delete();
}

// === Registry === 

public fun contains<Meme>(memez_registry: &MemezRegistry): bool{
    memez_registry.lp_coins.contains(type_name::get<RegistryKey<SUI, Meme>>())
}

public fun from_lp_coin<LpCoin>(memez_registry: &MemezRegistry): address {
    *memez_registry.lp_coins.borrow(type_name::get<LpCoin>())
}

public fun from_meme<Meme>(memez_registry: &MemezRegistry): address {
    *memez_registry.lp_coins.borrow(type_name::get<RegistryKey<SUI, Meme>>())
}

// === Oracle Functions ===

public fun spot_price<Base, Quote, LpCoin>(
    self: &MemezPool<LpCoin>,
    pool_registry: &PoolRegistry,
): u128 {
    af_price::spot_price<LpCoin, Base, Quote>(self.af_pool<LpCoin>(), pool_registry)
}

public fun oracle_price<Base, Quote, LpCoin>(
    self: &MemezPool<LpCoin>,
    pool_registry: &PoolRegistry,
): u128 {
    af_price::oracle_price<LpCoin, Base, Quote>(self.af_pool<LpCoin>(), pool_registry)
}

// === Revenue Functions ===

public fun swap_fee<LpCoin>(self: &MemezPool<LpCoin>): u64 {
    revenue::swap_fee(&self.id)
}

public fun liquidity_management_fee<LpCoin>(self: &MemezPool<LpCoin>): u64 {
    revenue::liquidity_management_fee(&self.id)
}

public fun admin_fee<LpCoin>(self: &MemezPool<LpCoin>): u64 {
    revenue::admin_fee(&self.id)
} 

public fun beneficiary<LpCoin>(self: &MemezPool<LpCoin>): address {
    revenue::beneficiary(&self.id)
}

public fun set_revenue_admin_fee<LpCoin>(self: &mut MemezPool<LpCoin>, _: &AuthWitness, admin_fee: u64) {
    revenue::set_admin_fee(&mut self.id, admin_fee);
}

// == Allowlist Functions ==

public fun add_allowlist_plugin<LpCoin>(self: &mut MemezPool<LpCoin>, _: &DeployerCap<LpCoin>) {
    allowlist::new(&mut self.id);
}

public fun supports_allowlist<LpCoin>(self: &MemezPool<LpCoin>): bool {
    allowlist::supports(&self.id)
}

public fun is_allowed<LpCoin>(self: &MemezPool<LpCoin>, sender: address): bool {
    allowlist::contains(&self.id, sender)
}

public fun add_to_allowlist<LpCoin>(self: &mut MemezPool<LpCoin>, _: &DeployerCap<LpCoin>, sender: address) {
    allowlist::add(&mut self.id, sender)
}

public fun remove_from_allowlist<LpCoin>(self: &mut MemezPool<LpCoin>, _: &DeployerCap<LpCoin>, sender: address) {
    allowlist::remove(&mut self.id, sender);
}

public fun remove_allowlist_plugin<LpCoin>(self: &mut MemezPool<LpCoin>, _: &DeployerCap<LpCoin>) {
    allowlist::delete(&mut self.id);
}

// == Liquidity Events Functions ==

public fun supports_liquidity_event<LpCoin>(self: &MemezPool<LpCoin>): bool {
    liquidity::supports(&self.id)
}

public fun liquidity_event_fee<LpCoin>(self: &MemezPool<LpCoin>): u64 {
    liquidity::fee<SUI>(&self.id)
}

// === Private Functions ===

fun launch_impl<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    mut meme_treasury: TreasuryCap<Meme>,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    burn_amount: u64,
    fees: vector<u64>,
    beneficiary: address,
    allows_liquidity_management: bool,
    ctx: &mut TxContext,
): (MemezPool<LpCoin>, DeployerCap<LpCoin>) {
    assert!(meme_treasury.total_supply() == 0, InvalidMemeSupply);
    assert!(meme_metadata.get_decimals() == 9, InvalidMemeDecimals);
    assert!(MAX_BURN_AMOUNT >= burn_amount, InvalidBurnAmount);

    let mut meme_coin = meme_treasury.mint(MEME_SUPPLY, ctx);

    black_ice::freeze_it(meme_coin.split(burn_amount, ctx), ctx); 
    black_ice::freeze_it(meme_treasury, ctx);

    let (memez_pool, deployer, lp_coin) = new_impl(
        memez_registry,
        pool_registry,
        meme_metadata,
        create_pool_cap,
        weights,
        sui_coin,
        meme_coin,
        fees,
        beneficiary,
        allows_liquidity_management,
        ctx
    );

    black_ice::freeze_it(lp_coin, ctx);

    (memez_pool, deployer)
}

fun new_impl<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    meme_coin: Coin<Meme>,
    fees: vector<u64>,
    beneficiary: address,
    allows_liquidity_management: bool,
    ctx: &mut TxContext,
): (MemezPool<LpCoin>, DeployerCap<LpCoin>, Coin<LpCoin>) {
    assert_weights(weights);
    assert!(!memez_registry.contains<Meme>(), InvalidPool);

    let (af_pool, lp_coin) = create_pool_2_coins<LpCoin, SUI, Meme>(
        create_pool_cap,
        pool_registry, 
        lp_metadata::name(meme_metadata.get_name()),
        lp_metadata::name(meme_metadata.get_name()),
        lp_metadata::symbol(meme_metadata.get_symbol()), 
        lp_metadata::description(),
        lp_metadata::icon_url(), 
        weights,
        FLATNESS,
        vector[SWAP_FEE_IN, SWAP_FEE_IN],
        vector[0, 0],
        vector[0, 0],
        vector[0, 0],
        sui_coin,
        meme_coin,
        option::some(vector[9, 9]),
        true,
        option::some(9),
        ctx
    );

    let mut memez_pool = MemezPool {
        id: object::new(ctx),
        allows_liquidity_management,
    };

    let af_pool_address = object::id(&af_pool).to_address();

    dof::add(&mut memez_pool.id, AftermathPoolKey(), af_pool);
    revenue::new(&mut memez_pool.id, fees, beneficiary);
    
    let memez_pool_address = object::id(&memez_pool).to_address();

    memez_registry.lp_coins.add(type_name::get<LpCoin>(), memez_pool_address);
    memez_registry.pools.add(type_name::get<RegistryKey<SUI, Meme>>(), memez_pool_address);

    events::new_pool<Meme, LpCoin>(memez_pool_address, af_pool_address);

    let deployer = DeployerCap {
        id: object::new(ctx),
        pool: memez_pool_address
    };

    (memez_pool, deployer, lp_coin)
}

fun assert_weights(weights: vector<u64>) {
    assert!(weights.length() == 2, InvalidWeightLength);
    assert!(MAX_SUI_WEIGHT >= weights[0], InvalidSuiWeight);
    assert!(
        MAX_WEIGHT > weights[0] 
        && MAX_WEIGHT > weights[1]
        && weights[0] + weights[1] == MAX_WEIGHT,
        InvalidWeights
    );
}

fun af_pool<LpCoin>(self: &MemezPool<LpCoin>): &AftermathPool<LpCoin> {
    dof::borrow(&self.id, AftermathPoolKey())
}

fun af_pool_mut<LpCoin>(self: &mut MemezPool<LpCoin>): &mut AftermathPool<LpCoin> {
    dof::borrow_mut(&mut self.id, AftermathPoolKey())
}