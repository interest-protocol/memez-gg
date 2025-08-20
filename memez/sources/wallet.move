module memez::memez_wallet;

use interest_access_control::access_control::AdminWitness;
use memez::memez::MEMEZ;
use sui::{coin::{Self, Coin}, table::{Self, Table}, transfer::Receiving};

// === Structs ===

public struct MemezWallet has key {
    id: UID,
    owner: address,
}

public struct MemezWalletRegistry has key {
    id: UID,
    /// ctx.sender() -> wallet.id.to_address()
    wallets: Table<address, address>,
}

// === Public Mutative Functions ===

public fun merge_coins<T: key + store>(
    wallet: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
) {
    transfer::public_transfer(wallet.merge(coins, ctx), wallet.id.to_address());
}

public fun public_receive<T: key + store>(
    wallet: &mut MemezWallet,
    object: Receiving<T>,
    ctx: &mut TxContext,
): T {
    wallet.assert_is_owner(ctx);

    transfer::public_receive(&mut wallet.id, object)
}

public fun public_receive_coins<T: key + store>(
    wallet: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    wallet.assert_is_owner(ctx);

    wallet.merge(coins, ctx)
}

// === Public View Functions ===

public fun wallet_address(registry: &MemezWalletRegistry, sender: address): Option<address> {
    if (registry.wallets.contains(sender)) {
        option::some(registry.wallets[sender])
    } else {
        option::none()
    }
}

// === Admin Only Functions ===

public fun new(registry: &mut MemezWalletRegistry, ctx: &mut TxContext) {
    assert!(!registry.wallets.contains(ctx.sender()));

    let sender = ctx.sender();

    let wallet = MemezWallet {
        id: object::new(ctx),
        owner: sender,
    };

    registry.wallets.add(sender, wallet.id.to_address());

    transfer::share_object(wallet);
}

// === Admin Functions ===

public fun initialize_registry(_: &AdminWitness<MEMEZ>, ctx: &mut TxContext) {
    let registry = MemezWalletRegistry {
        id: object::new(ctx),
        wallets: table::new(ctx),
    };

    transfer::share_object(registry);
}

// === Private Functions ===

fun assert_is_owner(wallet: &MemezWallet, ctx: &TxContext) {
    assert!(wallet.owner == ctx.sender());
}

fun merge<T: key + store>(
    wallet: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    coins.fold!(coin::zero<T>(ctx), |mut acc, coin| {
        acc.join(transfer::public_receive(&mut wallet.id, coin));

        acc
    })
}
