// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module amm_extension_dao_fee::withdraw {
    use amm_extension_dao_fee::pool::DaoFeePool;
    use amm_extension_dao_fee::version::Version;

    use amm::pool_registry::PoolRegistry;
    use amm::pool::Pool;

    use insurance_fund::insurance_fund::InsuranceFund;
    use referral_vault::referral_vault::ReferralVault;
    use protocol_fee_vault::vault::ProtocolFeeVault;
    use treasury::treasury::Treasury;

    use sui::coin::Coin;

    use fun amm::withdraw::all_coin_withdraw_2_coins as Pool.all_coin_withdraw_2_coins;
    use fun amm::withdraw::all_coin_withdraw_3_coins as Pool.all_coin_withdraw_3_coins;
    use fun amm::withdraw::all_coin_withdraw_4_coins as Pool.all_coin_withdraw_4_coins;
    use fun amm::withdraw::all_coin_withdraw_5_coins as Pool.all_coin_withdraw_5_coins;
    use fun amm::withdraw::all_coin_withdraw_6_coins as Pool.all_coin_withdraw_6_coins;
    use fun amm::withdraw::all_coin_withdraw_7_coins as Pool.all_coin_withdraw_7_coins;
    use fun amm::withdraw::all_coin_withdraw_8_coins as Pool.all_coin_withdraw_8_coins;

    //**************************************************************************************************//
    // All-Coin Withdraw                                                                                //
    //**************************************************************************************************//

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C2>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. DAO and protocol fees are charged on the coins being withdrawn.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::withdraw::EInvalidProtocolVersion]
    /// iii. [amm::withdraw::EInvalidPoolSize]
    ///  iv. [amm::withdraw::EZeroValue]
    ///   v. [amm::withdraw::EDuplicateTypes]
    ///  iv. [amm::math::EZeroLpRatio]
    public fun all_coin_withdraw_2_coins<L, C1, C2>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,

        ctx: &mut TxContext,
    ): (Coin<C1>, Coin<C2>) {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Perform the withdrawal.
        let (mut coin_1, mut coin_2) = 
            dao_fee_pool.borrow_mut_pool().all_coin_withdraw_2_coins(
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                ctx,
            );

        // iii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);

        (coin_1, coin_2)
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C3>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. DAO and protocol fees are charged on the coins being withdrawn.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::withdraw::EInvalidProtocolVersion]
    /// iii. [amm::withdraw::EInvalidPoolSize]
    ///  iv. [amm::withdraw::EZeroValue]
    ///   v. [amm::withdraw::EDuplicateTypes]
    ///  iv. [amm::math::EZeroLpRatio]
    public fun all_coin_withdraw_3_coins<L, C1, C2, C3>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,

        ctx: &mut TxContext,
    ): (Coin<C1>, Coin<C2>, Coin<C3>) {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Perform the withdrawal.
        let (mut coin_1, mut coin_2, mut coin_3) = 
            dao_fee_pool.borrow_mut_pool().all_coin_withdraw_3_coins(
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                ctx,
            );

        // iii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);

        (coin_1, coin_2, coin_3)
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C4>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. DAO and protocol fees are charged on the coins being withdrawn.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::withdraw::EInvalidProtocolVersion]
    /// iii. [amm::withdraw::EInvalidPoolSize]
    ///  iv. [amm::withdraw::EZeroValue]
    ///   v. [amm::withdraw::EDuplicateTypes]
    ///  iv. [amm::math::EZeroLpRatio]
    public fun all_coin_withdraw_4_coins<L, C1, C2, C3, C4>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,

        ctx: &mut TxContext,
    ): (Coin<C1>, Coin<C2>, Coin<C3>, Coin<C4>) {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Perform the withdrawal.
        let (mut coin_1, mut coin_2, mut coin_3, mut coin_4) = 
            dao_fee_pool.borrow_mut_pool().all_coin_withdraw_4_coins(
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                ctx,
            );

        // iii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);

        (coin_1, coin_2, coin_3, coin_4)
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C5>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. DAO and protocol fees are charged on the coins being withdrawn.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::withdraw::EInvalidProtocolVersion]
    /// iii. [amm::withdraw::EInvalidPoolSize]
    ///  iv. [amm::withdraw::EZeroValue]
    ///   v. [amm::withdraw::EDuplicateTypes]
    ///  iv. [amm::math::EZeroLpRatio]
    public fun all_coin_withdraw_5_coins<L, C1, C2, C3, C4, C5>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,

        ctx: &mut TxContext,
    ): (Coin<C1>, Coin<C2>, Coin<C3>, Coin<C4>, Coin<C5>) {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Perform the withdrawal.
        let (mut coin_1, mut coin_2, mut coin_3, mut coin_4, mut coin_5) = 
            dao_fee_pool.borrow_mut_pool().all_coin_withdraw_5_coins(
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                ctx,
            );

        // iii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);

        (coin_1, coin_2, coin_3, coin_4, coin_5)
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C6>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. DAO and protocol fees are charged on the coins being withdrawn.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::withdraw::EInvalidProtocolVersion]
    /// iii. [amm::withdraw::EInvalidPoolSize]
    ///  iv. [amm::withdraw::EZeroValue]
    ///   v. [amm::withdraw::EDuplicateTypes]
    ///  iv. [amm::math::EZeroLpRatio]
    public fun all_coin_withdraw_6_coins<L, C1, C2, C3, C4, C5, C6>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,

        ctx: &mut TxContext,
    ): (Coin<C1>, Coin<C2>, Coin<C3>, Coin<C4>, Coin<C5>, Coin<C6>) {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Perform the withdrawal.
        let (mut coin_1, mut coin_2, mut coin_3, mut coin_4, mut coin_5, mut coin_6) = 
            dao_fee_pool.borrow_mut_pool().all_coin_withdraw_6_coins(
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                ctx,
            );

        // iii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_6, ctx);

        (coin_1, coin_2, coin_3, coin_4, coin_5, coin_6)
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C7>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. DAO and protocol fees are charged on the coins being withdrawn.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::withdraw::EInvalidProtocolVersion]
    /// iii. [amm::withdraw::EInvalidPoolSize]
    ///  iv. [amm::withdraw::EZeroValue]
    ///   v. [amm::withdraw::EDuplicateTypes]
    ///  iv. [amm::math::EZeroLpRatio]
    public fun all_coin_withdraw_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,

        ctx: &mut TxContext,
    ): (Coin<C1>, Coin<C2>, Coin<C3>, Coin<C4>, Coin<C5>, Coin<C6>, Coin<C7>) {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Perform the withdrawal.
        let (mut coin_1, mut coin_2, mut coin_3, mut coin_4, mut coin_5, mut coin_6, mut coin_7) = 
            dao_fee_pool.borrow_mut_pool().all_coin_withdraw_7_coins(
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                ctx,
            );

        // iii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_6, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_7, ctx);

        (coin_1, coin_2, coin_3, coin_4, coin_5, coin_6, coin_7)
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C8>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. DAO and protocol fees are charged on the coins being withdrawn.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::withdraw::EInvalidProtocolVersion]
    /// iii. [amm::withdraw::EInvalidPoolSize]
    ///  iv. [amm::withdraw::EZeroValue]
    ///   v. [amm::withdraw::EDuplicateTypes]
    ///  iv. [amm::math::EZeroLpRatio]
    public fun all_coin_withdraw_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,

        ctx: &mut TxContext,
    ): (Coin<C1>, Coin<C2>, Coin<C3>, Coin<C4>, Coin<C5>, Coin<C6>, Coin<C7>, Coin<C8>) {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Perform the withdrawal.
        let (mut coin_1, mut coin_2, mut coin_3, mut coin_4, mut coin_5, mut coin_6, mut coin_7, mut coin_8) = 
            dao_fee_pool.borrow_mut_pool().all_coin_withdraw_8_coins(
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                ctx,
            );

        // iii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_6, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_7, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_8, ctx);

        (coin_1, coin_2, coin_3, coin_4, coin_5, coin_6, coin_7, coin_8)
    }
}
