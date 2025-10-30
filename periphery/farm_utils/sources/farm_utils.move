module farm_utils::farm_utils;

use interest_access_control::access_control::AdminWitness;
use interest_farms::interest_farm::{InterestFarm, InterestFarmAccount};
use sui::clock::Clock;
use sui::coin::Coin;

// === Public Mutative Functions ===

public fun harvest<Stake>(
    account: &mut InterestFarmAccount<Stake>,
    farm: &mut InterestFarm<Stake>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<Stake> {
    account.harvest(farm, clock, ctx)
}

public fun add_reward<Stake>(farm: &mut InterestFarm<Stake>, clock: &Clock, reward: Coin<Stake>) {
    farm.add_reward(clock, reward)
}

// === Admin Functions ===

public fun set_end_time<Stake, Admin>(
    farm: &mut InterestFarm<Stake>,
    clock: &Clock,
    admin: &AdminWitness<Admin>,
    end: u64,
) {
    farm.set_end_time<Stake, Stake, Admin>(clock, admin, end);
}

public fun set_rewards_per_second<Stake, Admin>(
    farm: &mut InterestFarm<Stake>,
    clock: &Clock,
    admin: &AdminWitness<Admin>,
    new_rewards_per_second: u64,
) {
    farm.set_rewards_per_second<Stake, Stake, Admin>(clock, admin, new_rewards_per_second);
}
