module memez_gg::memez_gg;
// === Imports ===

use std::type_name::{Self, TypeName};

use sui::{
    sui::SUI,
    table::{Self, Table},
    coin::{Coin,TreasuryCap, CoinMetadata},
};

use amm::{
    pool::CreatePoolCap,
    pool_registry::PoolRegistry,
    pool_factory::create_pool_2_coins
};

use amm_extension_dao_fee::pool::{Self as dao_pool, DaoFeePool};

use memez_gg::{
    events,
    black_ice,
    lp_metadata,
    version::CurrentVersion,
    vault::{MemezVaultConfig, MemezVaultCap},
};

// === Constants ===

// @dev Maximum volatility
const FLATNESS: u64 = 0; 

// @dev 1 billion total supply with 9 decimals
const MEME_SUPPLY: u64 = 1_000_000_000__000_000_000;

// @dev 900M - 90% of the supply
const MAX_BURN_AMOUNT: u64 = 900_000_000__000_000_000;

// @dev 2% fee
const TWO_PERCENT_BPS: u16 = 200;

// @dev 100%
const MAX_WEIGHT: u64 = 1__000_000_000_000_000_000;

// @dev 50%
const MAX_SUI_WEIGHT: u64 = 500_000_000_000_000_000;

// @dev 0.3% 
const SWAP_FEE_IN: u64 = 3_000_000_000_000_000;

// Constants 

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

// Structs 

public struct RegistryKey<phantom CoinX, phantom CoinY>() has copy, store, drop;

public struct MemezRegistry has key {
    id: UID, 
    pools: Table<TypeName, address>,
    lp_coins: Table<TypeName, address>,
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

// === Public View Functions ===

public fun pool_exists<Meme>(memez_registry: &MemezRegistry): bool{
    memez_registry.lp_coins.contains(type_name::get<RegistryKey<SUI, Meme>>())
}

public fun pool_from_lp_coin<LpCoin>(memez_registry: &MemezRegistry): address {
    *memez_registry.lp_coins.borrow(type_name::get<LpCoin>())
}

public fun pool_from_meme<Meme>(memez_registry: &MemezRegistry): address {
    *memez_registry.lp_coins.borrow(type_name::get<RegistryKey<SUI, Meme>>())
}

// === Public Mutative Functions ===

#[allow(lint(share_owned))]
public fun new<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    vault_config: &MemezVaultConfig,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    meme_coin: Coin<Meme>,
    version: &CurrentVersion,
    ctx: &mut TxContext,
): (DaoFeePool<LpCoin>, MemezVaultCap<LpCoin>, Coin<LpCoin>) {
    version.assert_is_valid();

    new_pool_and_vault(
        memez_registry,
        pool_registry,
        vault_config,
        meme_metadata,
        create_pool_cap,
        weights,
        sui_coin,
        meme_coin,
        ctx
    )
}

public fun launch<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    vault_config: &MemezVaultConfig,
    meme_treasury: TreasuryCap<Meme>,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    burn_amount: u64,
    version: &CurrentVersion,
    ctx: &mut TxContext,
): (DaoFeePool<LpCoin>, MemezVaultCap<LpCoin>) {
    version.assert_is_valid();

    launch_impl(
        memez_registry, 
        pool_registry, 
        vault_config, 
        meme_treasury, 
        meme_metadata, 
        create_pool_cap, 
        weights,
        sui_coin, 
        burn_amount, 
        ctx
    )
}

#[allow(lint(share_owned))]
public fun share<LpCoin>(pool: DaoFeePool<LpCoin>) {
    transfer::public_share_object(pool);
}

// === Private Functions ===

fun launch_impl<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    vault_config: &MemezVaultConfig,
    mut meme_treasury: TreasuryCap<Meme>,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    burn_amount: u64,
    ctx: &mut TxContext,
): (DaoFeePool<LpCoin>, MemezVaultCap<LpCoin>) {
    assert!(meme_treasury.total_supply() == 0, InvalidMemeSupply);
    assert!(meme_metadata.get_decimals() == 9, InvalidMemeDecimals);
    assert!(MAX_BURN_AMOUNT >= burn_amount, InvalidBurnAmount);

    let mut meme_coin = meme_treasury.mint(MEME_SUPPLY, ctx);

    black_ice::freeze_it(meme_coin.split(burn_amount, ctx), ctx); 
    black_ice::freeze_it(meme_treasury, ctx);

    let (pool, cap, lp_coin) = new_pool_and_vault(
        memez_registry,
        pool_registry,
        vault_config,
        meme_metadata,
        create_pool_cap,
        weights,
        sui_coin,
        meme_coin,
        ctx
    );

    black_ice::freeze_it(lp_coin, ctx);

    (pool, cap)
}

fun new_pool_and_vault<Meme, LpCoin>(
    memez_registry: &mut MemezRegistry,
    pool_registry: &mut PoolRegistry,
    vault_config: &MemezVaultConfig,
    meme_metadata: &CoinMetadata<Meme>,
    create_pool_cap: CreatePoolCap<LpCoin>,
    weights: vector<u64>,
    sui_coin: Coin<SUI>,
    meme_coin: Coin<Meme>,
    ctx: &mut TxContext,
): (DaoFeePool<LpCoin>, MemezVaultCap<LpCoin>, Coin<LpCoin>) {
    assert_weights(weights);
    assert!(!memez_registry.pool_exists<Meme>(), InvalidPool);

    let (pool, lp_coin) = create_pool_2_coins<LpCoin, SUI, Meme>(
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

    let pool_address = object::id(&pool).to_address();

    memez_registry.lp_coins.add(type_name::get<LpCoin>(), pool_address);
    memez_registry.pools.add(type_name::get<RegistryKey<SUI, Meme>>(), pool_address);

    let (vault, cap) = vault_config.new<Meme, LpCoin>(ctx);

    let vault_address = vault.addy();
    
    let (pool, owner_cap) = dao_pool::new(pool, TWO_PERCENT_BPS, vault_address, ctx);

    events::new_pool<Meme, LpCoin>(
        pool_address,
        vault_address,
        cap.addy()
    );

    vault.share();
    transfer::public_transfer(owner_cap, @admin);

    (pool, cap, lp_coin)
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