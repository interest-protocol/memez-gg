module blast_profile::pool_rating;

use blast_profile::blast_profile::{BlastProfileConfig, BlastProfile};
use sui::table::{Self, Table};

// === Structs ===

public enum Rating has copy, drop, store {
    Rocket(u64),
    Poop(u64),
}

public struct PoolRatingConfig has store {
    ratings: Table<address, Rating>,
}

public struct ConfigKey() has copy, drop, store;

public struct ProfileRating has store {
    ratings: Table<address, Rating>,
}

// === Initialization ===

public fun init_quest(config: &mut BlastProfileConfig, ctx: &mut TxContext) {
    let config_mut = config.quests_config_mut();
    let key = ConfigKey();

    assert!(
        !config_mut.contains(key),
        blast_profile::blast_profile_errors::quest_already_initialized!(),
    );

    config_mut.add(
        key,
        PoolRatingConfig {
            ratings: table::new(ctx),
        },
    );
}
