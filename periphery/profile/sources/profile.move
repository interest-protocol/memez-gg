#[allow(unused_field)]
module memez_profile::memez_profile;

use std::{string::String, type_name::{Self, TypeName}};
use sui::{table::{Self, Table}, vec_map::{Self, VecMap}, package, display};
use memez_fun::memez_pump;

// === Structs ===

public struct Trades has store {
    total_quote_coin: u64,
    quote_per_coin: VecMap<TypeName, u64>,
}

public struct MemezProfile has key {
    id: UID,
    name: String,
    image_url: String,
    trades: Table<u64, Trades>,
    socials: VecMap<String, String>,
}

public struct MemezProfileConfig has key {
    id: UID,
    // ctx.sender() -> MemezProfile.id.to_address()
    sender_profile: Table<address, address>,
    public_key: vector<u8>,
    minimum_quote_value: u64,
}

public struct MemezProfileAdmin has key, store {
    id: UID
}

public struct MEMEZ_PROFILE() has drop;

// === Initializer ===

fun init(otw: MEMEZ_PROFILE, ctx: &mut TxContext) {
    let sender = ctx.sender();

    let config = MemezProfileConfig {
        id: object::new(ctx),
        sender_profile: table::new(ctx),
        public_key: vector[],
        minimum_quote_value: 0,
    };

    let admin = MemezProfileAdmin {
        id: object::new(ctx),
    };

    let publisher = package::claim(otw, ctx);

    let fields = vector[b"name".to_string(), b"image_url".to_string()];
    let values = vector[b"{name}".to_string(), b"{image_url}".to_string()];

    let mut display = display::new_with_fields<MemezProfile>(&publisher, fields, values, ctx);

    display.update_version();

    transfer::share_object(config);
    transfer::public_transfer(admin, sender);
    transfer::public_transfer(display, sender);
    transfer::public_transfer(publisher, sender);
}