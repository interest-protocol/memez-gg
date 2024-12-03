#[test_only]
module memez_fun::memez_fees_tests;

use sui::{test_scenario as ts, coin::{mint_for_testing, Coin}};
use std::unit_test::assert_eq;
use memez_fun::{memez_errors, memez_fees, memez_utils};

public struct Meme()

#[test]
fun test_new() {
    let fees = memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
            vector[@0x2],
        ]
    );

    let payloads = fees.payloads();

    assert_eq!(payloads[0].payload_value(), 2);
    assert_eq!(payloads[1].payload_value(), 30);
    assert_eq!(payloads[2].payload_value(), 6);

    assert_eq!(payloads[0].payload_percentages(), vector[7_000, 3_000]);
    assert_eq!(payloads[1].payload_percentages(), vector[5_000, 5_000]);
    assert_eq!(payloads[2].payload_percentages(), vector[10_000, 0]);

    assert_eq!(payloads[0].payload_recipients(), vector[@0x0, @0x1]);
    assert_eq!(payloads[1].payload_recipients(), vector[@0x1]);
    assert_eq!(payloads[2].payload_recipients(), vector[@0x2]);
}

#[test]
fun test_calculate() {
    let fees = memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
            vector[@0x2],
        ]
    );

    let creation_fee = fees.creation();
    let swap_fee = fees.swap(@0x7);
    let migration_fee = fees.migration(@0x8);

    assert_eq!(creation_fee.recipients().length(), 2);
    assert_eq!(swap_fee.recipients().length(), 2);
    assert_eq!(migration_fee.recipients().length(), 2);

    let (last_creation_recipient_addy, last_creation_recipient_bps) = creation_fee.recipients()[1].recipient_data();
    let (last_swap_recipient_addy, last_swap_recipient_bps) = swap_fee.recipients()[1].recipient_data();
    let (last_migration_recipient_addy, last_migration_recipient_bps) = migration_fee.recipients()[1].recipient_data();

    assert_eq!(last_creation_recipient_addy, @0x1);
    assert_eq!(last_creation_recipient_bps.value(), 3_000);

    assert_eq!(last_swap_recipient_addy, @0x7);
    assert_eq!(last_swap_recipient_bps.value(), 5_000);

    assert_eq!(last_migration_recipient_addy, @0x8);
    assert_eq!(last_migration_recipient_bps.value(), 0);

    assert_eq!(creation_fee.calculate(0), 2);
    assert_eq!(swap_fee.calculate(1000), 3);
    assert_eq!(migration_fee.calculate(2), 6);
}

#[test]
fun test_take() {
    let alice = @0x0;
    let bob = @0x1;
    let charlie = @0x2;
    let jose = @0x3;

    let fees = memez_fees::new(
        vector[
            vector[7_000, 3_000, 20],
            vector[5_000, 2_000, 3_000, 300],
            vector[2_500, 2_500, 2_500, 2_500, 60],
        ],
        vector[
            vector[alice, bob],
            vector[bob, alice],
            vector[charlie, jose, alice],
        ]
    );

    let mut scenario = ts::begin(@0x9);

    let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

    fees.creation().take(&mut asset, scenario.ctx());

    assert_eq!(asset.burn_for_testing(), 980);

    scenario.next_tx(@0x0);

    let alice_creation_coin = scenario.take_from_address<Coin<Meme>>(alice);
    let bob_creation_coin = scenario.take_from_address<Coin<Meme>>(bob);

    assert_eq!(alice_creation_coin.burn_for_testing(), 14);
    assert_eq!(bob_creation_coin.burn_for_testing(), 6);

    let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

    fees.swap(charlie).take(&mut asset, scenario.ctx());

    assert_eq!(asset.burn_for_testing(), 970);

    scenario.next_tx(@0x0);

    let bob_swap_coin = scenario.take_from_address<Coin<Meme>>(bob); 
    let alice_swap_coin = scenario.take_from_address<Coin<Meme>>(alice); 
    let charlie_swap_coin = scenario.take_from_address<Coin<Meme>>(charlie); 

    assert_eq!(bob_swap_coin.burn_for_testing(), 15);
    assert_eq!(alice_swap_coin.burn_for_testing(), 6);
    assert_eq!(charlie_swap_coin.burn_for_testing(), 9);

    let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

    fees.migration(bob).take(&mut asset, scenario.ctx());

    assert_eq!(asset.burn_for_testing(), 940);

    scenario.next_tx(@0x0);

    let bob_swap_coin = scenario.take_from_address<Coin<Meme>>(bob); 
    let alice_swap_coin = scenario.take_from_address<Coin<Meme>>(alice); 
    let charlie_swap_coin = scenario.take_from_address<Coin<Meme>>(charlie); 
    let jose_swap_coin = scenario.take_from_address<Coin<Meme>>(jose); 

    assert_eq!(bob_swap_coin.burn_for_testing(), 15);
    assert_eq!(alice_swap_coin.burn_for_testing(), 15);
    assert_eq!(charlie_swap_coin.burn_for_testing(), 15);
    assert_eq!(jose_swap_coin.burn_for_testing(), 15);

    let fees = memez_fees::new(
        vector[
            vector[7_000, 3_000, 0],
            vector[5_000, 2_000, 3_000, 0],
            vector[2_500, 2_500, 2_500, 2_500, 0],
        ],
        vector[
            vector[alice, bob],
            vector[bob, alice],
            vector[charlie, jose, alice],
        ]
    );

    let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

    fees.creation().take(&mut asset, scenario.ctx());
    fees.swap(charlie).take(&mut asset, scenario.ctx());
    fees.migration(bob).take(&mut asset, scenario.ctx());

    assert_eq!(asset.burn_for_testing(), 1000);

    scenario.end();
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_fees)]
fun test_new_invalid_config() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
        ]
    );
}   

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
fun test_new_invalid_creation_percentages() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000 - 1, 2],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
            vector[@0x2],
        ]
    );
} 

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
fun test_new_invalid_swap_percentages() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000 - 1, 5_000, 30],
            vector[10_000, 0, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
            vector[@0x2],
        ]
    );
} 

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
fun test_new_invalid_migration_percentages() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[10_000, 1, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
            vector[@0x2],
        ]
    );
} 

#[test, expected_failure(abort_code = memez_errors::EWrongRecipientsLength, location = memez_fees)]
fun test_new_wrong_creation_recipients() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 0, 30],
            vector[10_000, 0, 6],
        ],
        vector[
            vector[@0x0],
            vector[@0x1],
            vector[@0x2],
        ]
    );
} 


#[test, expected_failure(abort_code = memez_errors::EWrongRecipientsLength, location = memez_fees)]
fun test_new_wrong_swap_recipients() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 0, 30],
            vector[10_000, 0, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
            vector[@0x2],
        ]
    );
} 

#[test, expected_failure(abort_code = memez_errors::EWrongRecipientsLength, location = memez_fees)]
fun test_new_wrong_migration_recipients() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 0, 6],
        ],
        vector[
            vector[@0x0, @0x1],
            vector[@0x1],
            vector[@0x2],
        ]
    );
} 