module memez_wallet::memez_wallet;

use sui::{coin::{Self, Coin}, package, table::{Self, Table}, transfer::Receiving};

// === Errors ===

const EInvalidOwner: u64 = 0;

const EDuplicateWallet: u64 = 1;

// === Structs ===

public struct MEMEZ_WALLET() has drop;

public struct MemezWallet has key {
    id: UID,
    owner: address,
}

public struct MemezWalletRegistry has key {
    id: UID,
    /// Owner -> wallet.id.to_address()
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

public fun new_wallet_registry(ctx: &mut TxContext) {
    let registry = MemezWalletRegistry {
        id: object::new(ctx),
        wallets: table::new(ctx),
    };

    transfer::share_object(registry);
}

public fun new(
    registry: &mut MemezWalletRegistry,
    owner: address,
    ctx: &mut TxContext,
): MemezWallet {
    assert!(!registry.wallets.contains(owner), EDuplicateWallet);

    let wallet = MemezWallet {
        id: object::new(ctx),
        owner,
    };

    registry.wallets.add(owner, wallet.id.to_address());

    wallet
}

public fun share(wallet: MemezWallet) {
    transfer::share_object(wallet);
}

public fun merge_coins<T>(
    wallet: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
) {
    transfer::public_transfer(wallet.merge(coins, ctx), wallet.id.to_address());
}

public fun receive<T: key + store>(
    wallet: &mut MemezWallet,
    object: Receiving<T>,
    ctx: &mut TxContext,
): T {
    wallet.assert_is_owner(ctx);

    transfer::public_receive(&mut wallet.id, object)
}

public fun receive_coins<T>(
    wallet: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    wallet.assert_is_owner(ctx);

    wallet.merge(coins, ctx)
}

// === Public View Functions ===

public fun wallet_address(registry: &MemezWalletRegistry, owner: address): Option<address> {
    if (registry.wallets.contains(owner)) {
        option::some(registry.wallets[owner])
    } else {
        option::none()
    }
}

// === Private Functions ===

fun assert_is_owner(wallet: &MemezWallet, ctx: &TxContext) {
    assert!(wallet.owner == ctx.sender(), EInvalidOwner);
}

fun merge<T>(
    wallet: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    coins.fold!(coin::zero<T>(ctx), |mut acc, coin| {
        acc.join(transfer::public_receive(&mut wallet.id, coin));

        acc
    })
}

// === Test Functions ===

#[test_only]
public fun init_for_test(ctx: &mut TxContext) {
    init(MEMEZ_WALLET(), ctx);
}

#[test_only]
public fun owner(wallet: &MemezWallet): address {
    wallet.owner
}
