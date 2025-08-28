module blast_profile::blast_profile;

use std::string::String;
use sui::{
    bag::{Self, Bag},
    bcs,
    display,
    ed25519,
    package,
    table::{Self, Table},
    vec_map::{Self, VecMap}
};

// === Structs ===

public struct BlastProfile has key {
    id: UID,
    name: String,
    image_url: String,
    quests: Bag,
    owner: address,
    feedback: Table<address, bool>,
    metadata: VecMap<String, String>,
}

public struct Feedback has store {
    likes: u64,
    dislikes: u64,
}

public struct BlastProfileConfig has key {
    id: UID,
    public_key: vector<u8>,
    /// ctx.sender() -> BlastProfile.id.to_address()
    profiles: Table<address, address>,
    /// BlastProfile.id.to_address() -> nonce
    nonces: Table<address, u64>,
    /// BlastProfile.id.to_address() -> Feedback
    feedback: Table<address, Feedback>,
    quests_config: Bag,
    version: u64,
}

public struct BlastProfileAdmin has key, store {
    id: UID,
}

public struct MetadataMessage has copy, drop, store {
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
        public_key: vector[],
        profiles: table::new(ctx),
        feedback: table::new(ctx),
        quests_config: bag::new(ctx),
        nonces: table::new(ctx),
        version: blast_profile::blast_profile_constants::package_version!(),
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

    assert!(
        !config.profiles.contains(sender),
        blast_profile::blast_profile_errors::profile_already_created!(),
    );

    let profile = BlastProfile {
        id: object::new(ctx),
        name,
        image_url,
        quests: bag::new(ctx),
        owner: sender,
        feedback: table::new(ctx),
        metadata: vec_map::empty(),
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

public fun feedback(
    config: &mut BlastProfileConfig,
    profile: &mut BlastProfile,
    user: address,
    like: bool,
    _ctx: &mut TxContext,
) {
    assert!(
        config.feedback.contains(user),
        blast_profile::blast_profile_errors::profile_does_not_exist!(),
    );

    let config_feedback = &mut config.feedback[user];

    if (profile.feedback.contains(user)) {
        let feedback = &mut profile.feedback[user];

        assert!(*feedback != like, blast_profile::blast_profile_errors::repeated_feedback!());

        config_feedback.switch_feedback(like);

        *feedback = like;
    } else {
        config_feedback.increment_feedback(like);

        profile.feedback.add(user, like);
    };
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

    let message = MetadataMessage {
        blast_profile: profile_address,
        new_metadata: metadata,
        nonce: *nonce,
    };

    *nonce = *nonce + 1;

    assert!(
        ed25519::ed25519_verify(&signature, &config.public_key, &bcs::to_bytes(&message)),
        blast_profile::blast_profile_errors::invalid_metadata_signature!(),
    );

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

public fun set_version(config: &mut BlastProfileConfig, version: u64) {
    config.version = version;
}

// === Package Only Functions ===

public(package) fun quests_config_mut(config: &mut BlastProfileConfig): &mut Bag {
    &mut config.quests_config
}

public(package) fun profile_quests_mut(profile: &mut BlastProfile): &mut Bag {
    &mut profile.quests
}

// === Private Functions ===

fun increment_feedback(feedback: &mut Feedback, like: bool) {
    if (like) {
        feedback.likes = feedback.likes + 1;
    } else {
        feedback.dislikes = feedback.dislikes + 1;
    };
}

fun switch_feedback(feedback: &mut Feedback, like: bool) {
    if (like) {
        feedback.likes = feedback.likes + 1;
        feedback.dislikes = feedback.dislikes - 1;
    } else {
        feedback.dislikes = feedback.dislikes + 1;
        feedback.likes = feedback.likes - 1;
    };
}
