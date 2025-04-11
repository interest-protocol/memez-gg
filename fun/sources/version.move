// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

#[allow(implicit_const_copy)]
module memez_fun::memez_allowed_versions;

use memez_acl::acl::AuthWitness;
use sui::vec_set::{Self, VecSet};

// === Constants ===

const VERSION: u64 = 1;

// === Structs ===

public struct MemezAV has key {
    id: UID,
    allowed_versions: VecSet<u64>,
}

public struct AllowedVersions(vector<u64>) has drop;

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let version = MemezAV {
        id: object::new(ctx),
        allowed_versions: vec_set::singleton(VERSION),
    };

    transfer::share_object(version);
}

// === Public View Functions ===

public fun get_allowed_versions(self: &MemezAV): AllowedVersions {
    AllowedVersions(*self.allowed_versions.keys())
}

// === Admin Functions ===

public fun add(self: &mut MemezAV, _: &AuthWitness, version: u64) {
    self.allowed_versions.insert(version);
}

public fun remove(self: &mut MemezAV, _: &AuthWitness, version: u64) {
    assert!(version != VERSION, memez_fun::memez_errors::remove_current_version_not_allowed!());
    self.allowed_versions.remove(&version);
}

// === Public Package Functions ===

public(package) fun assert_pkg_version(self: &AllowedVersions) {
    assert!(self.0.contains(&VERSION), memez_fun::memez_errors::outdated_package_version!());
}

// === Test Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun allowed_versions(self: &MemezAV): vector<u64> {
    *self.allowed_versions.keys()
}

#[test_only]
public fun get_allowed_versions_for_testing(version: u64): AllowedVersions {
    AllowedVersions(vector[version])
}

#[test_only]
public fun remove_for_testing(self: &mut MemezAV, version: u64) {
    self.allowed_versions.remove(&version);
}
