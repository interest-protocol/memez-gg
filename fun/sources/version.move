// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_version;

use memez_acl::acl::AuthWitness;
use memez_fun::memez_errors;

// === Constants ===

const VERSION: u64 = 1;

// === Structs ===

public struct Version has key {
    id: UID,
    version: u64,
}

public struct CurrentVersion(u64) has drop;

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let version = Version {
        id: object::new(ctx),
        version: VERSION,
    };

    transfer::share_object(version);
}

// === Public View Functions ===

public fun get_version(self: &Version): CurrentVersion {
    CurrentVersion(self.version)
}

// === Admin Functions ===

public fun update(self: &mut Version, _: &AuthWitness) {
    self.version = self.version + 1;
}

// === Public Package Functions ===

public(package) fun assert_is_valid(self: &CurrentVersion) {
    assert!(self.0 == VERSION, memez_errors::outdated_package_version());
}

// === Test Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun version(self: &Version): u64 {
    self.version
}

#[test_only]
public fun get_version_for_testing(version: u64): CurrentVersion {
    CurrentVersion(version)
}
