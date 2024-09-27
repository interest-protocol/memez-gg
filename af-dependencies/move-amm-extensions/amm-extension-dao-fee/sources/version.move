// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: version
module amm_extension_dao_fee::version {
    use sui::types::is_one_time_witness;
    use sui::transfer::share_object;

    use fun sui::object::new as TxContext.new;

    //**************************************************************************************************//
    // Errors                                                                                           //
    //**************************************************************************************************//

    /// A user tried to interact with an old contract.
    const EInvalidVersion: u64 = 0;

    /// `init_package_version` has been called outside of this packages `init` function.
    const EVersionObjectAlreadyCreated: u64 = 1;

    //**************************************************************************************************//
    // Constants                                                                                        //
    //**************************************************************************************************//

    const CURRENT_VERSION: u64 = 1;

    //**************************************************************************************************//
    // Version                                                                                          //
    //**************************************************************************************************//

    public struct Version has key {
        id: UID,
        version: u64,
    }

    //******************************************* Constructor ******************************************//

    /// Create + share a unique `Version` object.
    /// 
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EVersionObjectAlreadyCreated]
    public(package) fun init_package_version<T: drop>(
        witness: &T,
        ctx: &mut TxContext
    ) {
        // i. `public(package)` + this check guarantee that this function can only ever be called from
        //  the packages `init` function, asserting that no two `Version`'s can ever exist.
        assert!(is_one_time_witness(witness), EVersionObjectAlreadyCreated);

        let version = Version {
            id: ctx.new(),
            version: CURRENT_VERSION,
        };

        share_object(version)
    }

    //**************************************************************************************************//
    // Validity Checks                                                                                  //
    //**************************************************************************************************//

    public(package) fun assert_interacting_with_most_up_to_date_package(version: &Version) {
        assert!(version.version == CURRENT_VERSION, EInvalidVersion);
    }
}