#[test_only]
module memez_fun::memez_verifier_tests;

use memez_fun::{memez_errors, memez_verifier};
use std::unit_test::assert_eq;
use sui::{test_scenario as ts, test_utils::destroy};

const SENDER: address = @0xbbf31f4075625942aa967daebcafe0b1c90e6fa9305c9064983b5052ec442ef7;

const PUBLIC_KEY: vector<u8> = x"ad84194c595cc2942e14be5269aa4c1de89a97434a88173bd9dabc06b83c0bc5";

const SIGNATURE: vector<u8> =
    x"7da869e51d9654979576829d7becdb87128cc039462f63986ba840c15dbee44570f9f9695e214a8382b384b222eb046539f48edc56f758c9b2cb2a6710f3d607";

const SIGNATURE_2: vector<u8> =
    x"260471dc1cc91aa05f8c36e081557439d4b8649b344b102d09cfda7c27b5905ad9469488cc2735b79cf7fe2d14d454c12537e4d20f62e9813c2da4293c5a3c05";

#[test]
fun test_assert_can_buy() {
    let mut scenario = ts::begin(SENDER);

    let mut nonces = memez_verifier::new(scenario.ctx());

    assert_eq!(nonces.next_nonce(SENDER), 0);

    // === doesn't throw if no public key is provided to emulate a pool that is not protected
    nonces.assert_can_buy(
        vector[],
        option::none(),
        @0x0,
        0,
        scenario.ctx(),
    );

    // === doesn't throw if the signature is valid
    nonces.assert_can_buy(
        PUBLIC_KEY,
        option::some(SIGNATURE),
        @0x2,
        123,
        scenario.ctx(),
    );

    assert_eq!(nonces.next_nonce(SENDER), 1);

    // === Uses the next nonce correctly
    nonces.assert_can_buy(
        PUBLIC_KEY,
        option::some(SIGNATURE_2),
        @0x2,
        123,
        scenario.ctx(),
    );

    assert_eq!(nonces.next_nonce(SENDER), 2);

    destroy(nonces);
    scenario.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidPumpSignature,
        location = memez_verifier,
    ),
]
fun test_assert_can_buy_invalid_amount() {
    let mut scenario = ts::begin(SENDER);

    let mut nonces = memez_verifier::new(scenario.ctx());

    nonces.assert_can_buy(
        PUBLIC_KEY,
        option::some(SIGNATURE),
        @0x2,
        123 + 1,
        scenario.ctx(),
    );

    destroy(nonces);
    scenario.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidPumpSignature,
        location = memez_verifier,
    ),
]
fun test_assert_can_buy_invalid_pool() {
    let mut scenario = ts::begin(SENDER);

    let mut nonces = memez_verifier::new(scenario.ctx());

    nonces.assert_can_buy(
        PUBLIC_KEY,
        option::some(SIGNATURE),
        @0x3,
        123,
        scenario.ctx(),
    );

    destroy(nonces);
    scenario.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidPumpSignature,
        location = memez_verifier,
    ),
]
fun test_assert_can_buy_invalid_sender() {
    let mut scenario = ts::begin(@0x0);

    let mut nonces = memez_verifier::new(scenario.ctx());

    nonces.assert_can_buy(
        PUBLIC_KEY,
        option::some(SIGNATURE),
        @0x3,
        123,
        scenario.ctx(),
    );

    destroy(nonces);
    scenario.end();
}
