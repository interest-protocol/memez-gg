module memez::memez_vault;

use interest_access_control::access_control::AdminWitness;
use memez::memez::MEMEZ;
use sui::{coin::{Self, Coin}, table::{Self, Table}, transfer::Receiving};

// === Structs ===

public struct MemezVault has key {
    id: UID,
    owner: address,
}

public struct MemezVaultRegistry has key {
    id: UID,
    /// ctx.sender() -> vault.id.to_address()
    wallets: Table<address, address>,
}

// === Public Mutative Functions ===

public fun new(registry: &mut MemezVaultRegistry, owner: address, ctx: &mut TxContext) {
    assert!(!registry.wallets.contains(owner));

    let vault = MemezVault {
        id: object::new(ctx),
        owner,
    };

    registry.wallets.add(owner, vault.id.to_address());

    transfer::share_object(vault);
}

public fun merge_coins<T>(
    vault: &mut MemezVault,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
) {
    transfer::public_transfer(vault.merge(coins, ctx), vault.id.to_address());
}

public fun public_receive<T: key + store>(
    vault: &mut MemezVault,
    object: Receiving<T>,
    ctx: &mut TxContext,
): T {
    vault.assert_is_owner(ctx);

    transfer::public_receive(&mut vault.id, object)
}

public fun public_receive_coins<T>(
    vault: &mut MemezVault,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    vault.assert_is_owner(ctx);

    vault.merge(coins, ctx)
}

// === Public View Functions ===

public fun vault_address(registry: &MemezVaultRegistry, owner: address): Option<address> {
    if (registry.wallets.contains(owner)) {
        option::some(registry.wallets[owner])
    } else {
        option::none()
    }
}

// === Admin Functions ===

public fun initialize_registry(_: &AdminWitness<MEMEZ>, ctx: &mut TxContext) {
    let registry = MemezVaultRegistry {
        id: object::new(ctx),
        wallets: table::new(ctx),
    };

    transfer::share_object(registry);
}

// === Private Functions ===

fun assert_is_owner(vault: &MemezVault, ctx: &TxContext) {
    assert!(vault.owner == ctx.sender());
}

fun merge<T>(
    vault: &mut MemezVault,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    coins.fold!(coin::zero<T>(ctx), |mut acc, coin| {
        acc.join(transfer::public_receive(&mut vault.id, coin));

        acc
    })
}
