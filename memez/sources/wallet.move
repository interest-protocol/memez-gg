module memez::memez_wallet;

use std::{string::String, type_name};
use sui::{coin::{Self, Coin}, display::{Self, Display}, package::Publisher, transfer::Receiving};

// === Constants ===

const MEMEZ_FUN_ORIGINAL_PACKAGE_ID: address =
    @0x779829966a2e8642c310bed79e6ba603e5acd3c31b25d7d4511e2c9303d6e3ef;

// === Structs ===

public struct MemezWallet has key {
    id: UID,
    config_key: String,
}

// === Public Mutative Functions ===

public fun public_receive<T: key + store>(
    wallet: &mut MemezWallet,
    object: Receiving<T>,
    _ctx: &mut TxContext,
): T {
    transfer::public_receive(&mut wallet.id, object)
}

public fun public_receive_coins<T: key + store>(
    wallet: &mut MemezWallet,
    coins: vector<Receiving<Coin<T>>>,
    ctx: &mut TxContext,
): Coin<T> {
    let mut coin_to_send = coin::zero<T>(ctx);

    coins.do!(|coin| {
        coin_to_send.join(transfer::public_receive(&mut wallet.id, coin));
    });

    coin_to_send
}

// === Memez Fun Only Functions ===

public fun new<T>(config_key: String, ctx: &mut TxContext): MemezWallet {
    assert_is_authorized<T>();
    MemezWallet {
        id: object::new(ctx),
        config_key,
    }
}

public fun transfer<T>(wallet: MemezWallet, to: address) {
    assert_is_authorized<T>();
    transfer::transfer(wallet, to);
}

// === Admin Functions ===

public fun initialize_display(publisher: &Publisher, ctx: &mut TxContext): Display<MemezWallet> {
    let fields = vector[b"name".to_string(), b"image_url".to_string()];
    let values = vector[b"Memez Wallet".to_string(), b"https://api.interestlabs.io/memez/image/{config_key}.png ".to_string()];

    display::new_with_fields(publisher, fields, values, ctx)
}

// === Private Functions ===

fun assert_is_authorized<T>() {
    assert!(is_authorized<T>());
}

fun is_authorized<T>(): bool {
    type_name::get_with_original_ids<T>().get_address() == MEMEZ_FUN_ORIGINAL_PACKAGE_ID.to_ascii_string()
}
