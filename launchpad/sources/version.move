module memez_pad::version;
// === Imports === 

use memez_acl::acl::AuthWitness;

// === Constants ===

const VERSION: u64 = 1; 

// === Errors ===

#[error]
const InvalidVersion: vector<u8> = b"This package is out of date, please call the latest version of the package";

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
        version: VERSION
    };

    transfer::share_object(version);
}

// === Public Functions ===

public fun get_version(self: &Version): CurrentVersion {
    CurrentVersion(self.version)
}

// === Admin Functions === 

public fun update_version(self: &mut Version, _: &AuthWitness) {
    self.version = self.version + 1;
}

// === Public Package Functions ===

public(package) fun assert_is_valid(self: &CurrentVersion) {
    assert!(self.0 == VERSION, InvalidVersion);
}