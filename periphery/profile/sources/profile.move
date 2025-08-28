#[allow(unused_field)]
module blast_profile::blast_profile;

use memez_fun::memez_pump;
use std::{string::String, type_name::{Self, TypeName}};
use sui::{bcs, display, ed25519, package, table::{Self, Table}, vec_map::{Self, VecMap}};

// === Constants ===

const MAX_COINS_PER_EPOCH: u64 = 100;

const CONFIG_METADATA_KEY: vector<u8> = b"config_key";

// === Structs ===

public struct Trades has store {
    total_quote_coin: u64,
    quote_per_coin: VecMap<TypeName, u64>,
}

public struct BlastProfile has key {
    id: UID,
    name: String,
    image_url: String,
    /// ctx.epoch() -> Trades
    trades: Table<u64, Trades>,
    metadata: VecMap<String, String>,
    total_quote_coin: u64,
    owner: address,
}

public struct BlastProfileConfig has key {
    id: UID,
    /// ctx.sender() -> BlastProfile.id.to_address()
    profiles: Table<address, address>,
    /// BlastProfile.id.to_address() -> nonce
    nonces: Table<address, u64>,
    public_key: vector<u8>,
    minimum_quote_value: u64,
}

public struct BlastProfileAdmin has key, store {
    id: UID,
}

public struct SignatureMessage has copy, drop, store {
    blast_profile: address,
    new_metadata: VecMap<String, String>,
    nonce: u64,
}

public struct BLAST_PROFILE() has drop;

// === Initializer ===

fun init(otw: BLAST_PROFILE, ctx: &mut TxContext) {
    let sender = ctx.sender();

    let config = BlastProfileConfig {
        id: object::new(ctx),
        profiles: table::new(ctx),
        public_key: vector[],
        minimum_quote_value: 0,
        nonces: table::new(ctx),
    };

    let admin = BlastProfileAdmin {
        id: object::new(ctx),
    };

    let publisher = package::claim(otw, ctx);

    let fields = vector[
        b"name".to_string(),
        b"image_url".to_string(),
        b"user".to_string(),
        b"total_sui_spent".to_string(),
    ];

    let values = vector[
        b"{name}".to_string(),
        b"https://api.interestlabs.io/blast-profile/{id}.png".to_string(),
        b"{owner}".to_string(),
        b"{total_quote_coin}".to_string(),
    ];

    let mut display = display::new_with_fields<BlastProfile>(&publisher, fields, values, ctx);

    display.update_version();

    transfer::share_object(config);
    transfer::public_transfer(admin, sender);
    transfer::public_transfer(display, sender);
    transfer::public_transfer(publisher, sender);
}

// === Public Mutative Functions ===

public fun new(
    config: &mut BlastProfileConfig,
    name: String,
    image_url: String,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();

    assert!(!config.profiles.contains(sender));

    let profile = BlastProfile {
        id: object::new(ctx),
        name,
        image_url,
        metadata: vec_map::empty(),
        total_quote_coin: 0,
        owner: sender,
        trades: table::new(ctx),
    };

    config.profiles.add(sender, profile.id.to_address());

    transfer::transfer(profile, sender);
}

public fun update_image_url(profile: &mut BlastProfile, image_url: String, _ctx: &mut TxContext) {
    profile.image_url = image_url;
}

public fun update_name(profile: &mut BlastProfile, name: String, _ctx: &mut TxContext) {
    profile.name = name;
}

public fun update_metadata(
    config: &mut BlastProfileConfig,
    profile: &mut BlastProfile,
    metadata: VecMap<String, String>,
    signature: vector<u8>,
    _ctx: &mut TxContext,
) {
    let profile_address = profile.id.to_address();

    if (!config.nonces.contains(profile_address)) {
        config.nonces.add(profile_address, 0);
    };

    let nonce = &mut config.nonces[profile_address];

    let message = SignatureMessage {
        blast_profile: profile_address,
        new_metadata: metadata,
        nonce: *nonce,
    };

    *nonce = *nonce + 1;

    assert!(ed25519::ed25519_verify(&signature, &config.public_key, &bcs::to_bytes(&message)));

    profile.metadata = metadata;
}

// === View Functions ===

public fun next_nonce(config: &BlastProfileConfig, profile: address): u64 {
    if (!config.nonces.contains(profile)) 0 else config.nonces[profile]
}

// === Admin Only Functions ===

public fun set_public_key(
    config: &mut BlastProfileConfig,
    _: &BlastProfileAdmin,
    public_key: vector<u8>,
) {
    config.public_key = public_key;
}

public fun set_minimum_quote_value(
    config: &mut BlastProfileConfig,
    _: &BlastProfileAdmin,
    minimum_quote_value: u64,
) {
    assert!(minimum_quote_value != 0);
    config.minimum_quote_value = minimum_quote_value;
}
