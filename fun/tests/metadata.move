#[test_only]
module memez_fun::memez_metadata_tests;

use memez_fun::memez_metadata;
use std::unit_test::assert_eq;
use sui::test_utils::destroy;

#[test]
fun test_end_to_end() {
    let mut ctx = tx_context::dummy();
    let mut metadata = memez_metadata::new(
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez_fun".to_string()],
        &mut ctx,
    );

    assert_eq!(
        metadata.borrow()[&b"Twitter".to_string()],
        b"https://twitter.com/memez_fun".to_string(),
    );

    metadata.borrow_mut().insert(b"Telegram".to_string(), b"https://t.me/memez_fun".to_string());

    assert_eq!(metadata.borrow()[&b"Telegram".to_string()], b"https://t.me/memez_fun".to_string());

    destroy(metadata);
}
