// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_verifier;

use sui::{bcs, ed25519, table::{Self, Table}};

public struct Nonces has store {
    inner: Table<address, u64>,
}

public struct Message has copy, drop, store {
    pool: address,
    amount: u64,
    nonce: u64,
    sender: address,
}

// === Package Only Functions ===

public(package) fun new(ctx: &mut TxContext): Nonces {
    Nonces {
        inner: table::new(ctx),
    }
}

public(package) fun next_nonce(nonces: &Nonces, sender: address): u64 {
    if (!nonces.inner.contains(sender)) 0 else nonces.inner[sender]
}

public(package) fun assert_can_buy(
    nonces: &mut Nonces,
    public_key: vector<u8>,
    signature: Option<vector<u8>>,
    pool: address,
    amount: u64,
    ctx: &TxContext,
) {
    if (public_key.length() == 0) return;

    let sender = ctx.sender();

    if (!nonces.inner.contains(sender)) nonces.inner.add(sender, 0);

    let current_nonce = &mut nonces.inner[sender];

    let message = Message {
        pool,
        amount,
        nonce: *current_nonce,
        sender,
    };

    *current_nonce = *current_nonce + 1;

    assert!(
        ed25519::ed25519_verify(&signature.destroy_some(), &public_key, &bcs::to_bytes(&message)),
        memez_fun::memez_errors::invalid_pump_signature!(),
    );
}
