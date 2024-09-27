module memez_gg::vault;
// === Imports ===

use std::type_name::{Self, TypeName};

use sui::{
    sui::SUI,
    coin::Coin,
    dynamic_field as df,
    balance::{Self, Balance},
    transfer::{Receiving, public_receive}
};

use memez_gg::{
    math64,
    acl::AuthWitness,
    version::CurrentVersion,
};

// === Constants ===

// 1e9
const FEE_DENOMINATOR: u64 = 1_000_000_000;
// 10% 
const DEFAULT_FEE: u64 = 100_000_000;
// 20%
const MAX_FEE: u64 = 200_000_000;

// === Errors ===

#[error]
const InvalidFee: vector<u8> = b"The maximum fee is 20%";
#[error]
const InvalidCap: vector<u8> = b"The cap is not for this vault";

// Structs 

public struct BalanceKey has copy, store, drop {
    coin_type: TypeName,
}

public struct AdminBalanceKey has copy, store, drop {
    coin_type: TypeName,
}

public struct MemezVault<phantom CoinType> has key {
    id: UID,
    fee: u64,
}

public struct MemezVaultCap<phantom CoinType> has key, store {
    id: UID,
    vault_id: address
}

public struct MemezVaultConfig has key {
    id: UID,
    fee: u64,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let config = MemezVaultConfig {
        id: object::new(ctx),
        fee: DEFAULT_FEE,
    };

    transfer::share_object(config);
}

// === Mutative Functions ===

public fun receive<Meme, LpCoin>(
    vault: &mut MemezVault<LpCoin>,
    sui_receiving: Receiving<Coin<SUI>>,
    meme_receiving: Receiving<Coin<Meme>>,
    version: &CurrentVersion
) {
    version.assert_is_valid();

    let sui_coin = public_receive(&mut vault.id, sui_receiving);
    let meme_coin = public_receive(&mut vault.id, meme_receiving);

    vault.borrow_balance_mut<SUI, LpCoin>().join(sui_coin.into_balance());
    vault.borrow_balance_mut<Meme, LpCoin>().join(meme_coin.into_balance());
}

public fun collect<Meme, LpCoin>(
    vault: &mut MemezVault<LpCoin>,
    cap: &MemezVaultCap<LpCoin>,
    version: &CurrentVersion,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<Meme>) {
    version.assert_is_valid();

    // @dev sanity check as LpCoins are OTWs
    assert!(vault.id.to_address() == cap.vault_id, InvalidCap);

    let mut balance_sui = vault.borrow_balance_mut<SUI, LpCoin>().withdraw_all();
    let mut balance_meme = vault.borrow_balance_mut<Meme, LpCoin>().withdraw_all();

    let sui_value = balance_sui.value();
    let meme_value = balance_meme.value();

    let sui_fee = math64::mul_div_up(sui_value, vault.fee, FEE_DENOMINATOR);
    let meme_fee = math64::mul_div_up(meme_value, vault.fee, FEE_DENOMINATOR);

    let admin_balance_sui = vault.borrow_admin_balance_mut<SUI, LpCoin>();
    admin_balance_sui.join(balance_sui.split(sui_fee));

    let admin_balance_meme = vault.borrow_admin_balance_mut<Meme, LpCoin>();
    admin_balance_meme.join(balance_meme.split(meme_fee));

    (balance_sui.into_coin(ctx), balance_meme.into_coin(ctx))
}   

// View Functions 

public fun balances<Meme, LpCoin>(vault: &MemezVault<LpCoin>): (u64, u64) {
    let sui_value = vault.borrow_balance<Meme, LpCoin>().value();
    let meme_value = vault.borrow_balance<Meme, LpCoin>().value();

    (sui_value, meme_value)
}

public use fun vault_address as MemezVault.addy;
public fun vault_address<LpCoin>(vault: &MemezVault<LpCoin>): address {
    vault.id.to_address()
}

public use fun cap_address as MemezVaultCap.addy;
public fun cap_address<LpCoin>(cap: &MemezVaultCap<LpCoin>): address {
    cap.id.to_address()
}

// === Package Functions ===

public(package) fun new<Meme, LpCoin>(
    config: &MemezVaultConfig,
    ctx: &mut TxContext
): (MemezVault<LpCoin>, MemezVaultCap<LpCoin>) {    
    let mut vault = MemezVault {
        id: object::new(ctx),
        fee: config.fee,
    };

    let cap = MemezVaultCap<LpCoin> {
        id: object::new(ctx),
        vault_id: vault.id.to_address()
    };

    vault.register_coin<SUI, LpCoin>();
    vault.register_coin<Meme, LpCoin>();

    (vault, cap)
}

#[allow(lint(share_owned))]
public(package) fun share<CoinType>(vault: MemezVault<CoinType>) {
    transfer::share_object(vault);
}

// === Admin Functions ===

public use fun set_default_fee as MemezVaultConfig.set_fee;
public fun set_default_fee(
    config: &mut MemezVaultConfig,
    _auth: &AuthWitness,
    fee: u64,
) {
    assert!(MAX_FEE >= fee, InvalidFee);
    config.fee = fee;
}

public fun set_fee<LpCoin>(
    vault: &mut MemezVault<LpCoin>,
    _auth: &AuthWitness,
    fee: u64,
) {
    assert!(MAX_FEE >= fee, InvalidFee);
    vault.fee = fee;
}

public fun collect_fee<Meme, LpCoin>(
    vault: &mut MemezVault<LpCoin>,
    _auth: &AuthWitness,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<Meme>) {
    let balance_sui = vault.borrow_admin_balance_mut<SUI, LpCoin>().withdraw_all();
    let balance_meme = vault.borrow_admin_balance_mut<Meme, LpCoin>().withdraw_all();

    (balance_sui.into_coin(ctx), balance_meme.into_coin(ctx))
}

// === Private Functions ===

fun register_coin<CoinType, LpCoin>(
    vault: &mut MemezVault<LpCoin>,
) {
    df::add(
        &mut vault.id, 
        BalanceKey { coin_type: type_name::get<CoinType>() },
        balance::zero<CoinType>()
    );

    df::add(
        &mut vault.id, 
        AdminBalanceKey { coin_type: type_name::get<CoinType>() },
        balance::zero<CoinType>()
    );
}

fun borrow_balance<CoinType, LpCoin>(
    vault: &MemezVault<LpCoin>,
): &Balance<CoinType> {
    df::borrow(
        &vault.id, 
        BalanceKey { coin_type: type_name::get<CoinType>() },
    )
}

fun borrow_balance_mut<CoinType, LpCoin>(
    vault: &mut MemezVault<LpCoin>,
): &mut Balance<CoinType> {
    df::borrow_mut(
        &mut vault.id, 
        BalanceKey { coin_type: type_name::get<CoinType>() },
    )
}

fun borrow_admin_balance_mut<CoinType, LpCoin>(
    vault: &mut MemezVault<LpCoin>,
): &mut Balance<CoinType> {
    df::borrow_mut(
        &mut vault.id, 
        AdminBalanceKey { coin_type: type_name::get<CoinType>() },
    )
}