module memez_wallet::memez_wallet;

use sui::{coin::{Self, Coin}, package, table::{Self, Table}, transfer::Receiving};

// === Errors ===

const EInvalidOwner: u64 = 0;

// === Structs ===

public struct MEMEZ_WALLET() has drop;

public struct MemezWallet has key {
    id: UID,
    owner: address,
}

public struct MemezWalletRegistry has key {
    id: UID,
    /// ctx.sender() -> vault.id.to_address()
    wallets: Table<address, address>,
}

// === Initializer ===

fun init(otw: MEMEZ_WALLET, ctx: &mut TxContext) {
    let registry = MemezWalletRegistry {
        id: object::new(ctx),
        wallets: table::new(ctx),
    };

    transfer::share_object(registry);

    package::claim_and_keep(otw, ctx);
}

// === Public Mutative Functions ===

public fun new(
    registry: &mut MemezWalletRegistry,
    owner: address,
    ctx: &mut TxContext,
): MemezWallet {
    assert!(!registry.wallets.contains(owner));

    let vault = MemezWallet {
        id: object::new(ctx),
        owner,
    };

    registry.wallets.add(owner, vault.id.to_address());

    vault
}

public fun share(vault: MemezWallet) {
    transfer::share_object(vault);
}

public fun merge_coins<T>(
    vault: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
) {
    transfer::public_transfer(vault.merge(coins, ctx), vault.id.to_address());
}

public fun public_receive<T: key + store>(
    vault: &mut MemezWallet,
    object: Receiving<T>,
    ctx: &mut TxContext,
): T {
    vault.assert_is_owner(ctx);

    transfer::public_receive(&mut vault.id, object)
}

public fun public_receive_coins<T>(
    vault: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    vault.assert_is_owner(ctx);

    vault.merge(coins, ctx)
}

// === Public View Functions ===

public fun vault_address(registry: &MemezWalletRegistry, owner: address): Option<address> {
    if (registry.wallets.contains(owner)) {
        option::some(registry.wallets[owner])
    } else {
        option::none()
    }
}

// === Private Functions ===

fun assert_is_owner(vault: &MemezWallet, ctx: &TxContext) {
    assert!(vault.owner == ctx.sender(), EInvalidOwner);
}

fun merge<T>(
    vault: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    coins.fold!(coin::zero<T>(ctx), |mut acc, coin| {
        acc.join(transfer::public_receive(&mut vault.id, coin));

        acc
    })
}

// === Test Functions ===

#[test_only]
public fun init_for_test(ctx: &mut TxContext) {
    init(MEMEZ_WALLET(), ctx);
}
