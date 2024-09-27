// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module amm_extension_dao_fee::price {
    use amm_extension_dao_fee::pool::DaoFeePool;
    use amm_extension_dao_fee::version::Version;

    use amm::pool_registry::{PoolRegistry};
    use amm::pool::Pool;

    use fun amm::price::oracle_price as Pool.oracle_price;
    use fun amm::price::spot_price as Pool.spot_price;

    //**************************************************************************************************//
    // Oracle Price                                                                                     //
    //**************************************************************************************************//

    /// Obtain the Pool's intrinsic price of `Coin<BASE>` denominated in `Coin<QUOTE>`.
    ///  This function does not include fees.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::pool::EBadType]
    public fun oracle_price<L, BASE, QUOTE>(
        dao_fee_pool: &DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
    ): u128 {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Calculate the oracle price.
        dao_fee_pool.borrow_pool().oracle_price<L, BASE, QUOTE>(pool_registry)
    }

    //**************************************************************************************************//
    // Spot Price                                                                                       //
    //**************************************************************************************************//

    /// Obtain the Pool's intrinsic price of `Coin<BASE>` denominated in `Coin<QUOTE>`.
    ///  This function includes LP fees but does not include Protocol fees.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::pool::EBadType]
    public fun spot_price<L, BASE, QUOTE>(
        dao_fee_pool: &DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
    ): u128 {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Calculate the spot price.
        dao_fee_pool.borrow_pool().spot_price<L, BASE, QUOTE>(pool_registry)
    }
}
