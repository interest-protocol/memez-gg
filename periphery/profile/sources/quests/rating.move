module blast_profile::pool_rating;

use blast_profile::blast_profile::{Self, BlastProfileConfig, BlastProfile, BlastProfileAdmin};
use sui::{table::{Self, Table}, vec_map::{Self, VecMap}};

// === Structs ===

public enum Rating has copy, drop, store {
    Rocket,
    Fire,
    Poop,
    RedFlag,
}

public struct PoolRatingConfig has store {
    ratings: Table<address, VecMap<Rating, u64>>,
}

public struct ConfigKey() has copy, drop, store;

public struct ProfileRating has store {
    ratings: Table<address, Rating>,
}

// === Admin Only Functions ===

public fun init_quest(config: &mut BlastProfileConfig, _: &BlastProfileAdmin, ctx: &mut TxContext) {
    config
        .quests_config_mut()
        .add(
            ConfigKey(),
            PoolRatingConfig {
                ratings: table::new(ctx),
            },
        );
}
