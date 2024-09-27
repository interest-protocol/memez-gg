// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module amm_extension_dao_fee::deposit {
    use amm_extension_dao_fee::pool::DaoFeePool;
    use amm_extension_dao_fee::version::Version;

    use amm::pool_registry::PoolRegistry;
    use amm::pool::Pool;

    use insurance_fund::insurance_fund::InsuranceFund;
    use referral_vault::referral_vault::ReferralVault;
    use protocol_fee_vault::vault::ProtocolFeeVault;
    use treasury::treasury::Treasury;

    use sui::coin::Coin;

    use fun amm::deposit::deposit_1_coins as Pool.deposit_1_coins;
    use fun amm::deposit::deposit_2_coins as Pool.deposit_2_coins;
    use fun amm::deposit::deposit_3_coins as Pool.deposit_3_coins;
    use fun amm::deposit::deposit_4_coins as Pool.deposit_4_coins;
    use fun amm::deposit::deposit_5_coins as Pool.deposit_5_coins;
    use fun amm::deposit::deposit_6_coins as Pool.deposit_6_coins;
    use fun amm::deposit::deposit_7_coins as Pool.deposit_7_coins;
    use fun amm::deposit::deposit_8_coins as Pool.deposit_8_coins;

    use fun amm::deposit::all_coin_deposit_2_coins as Pool.all_coin_deposit_2_coins;
    use fun amm::deposit::all_coin_deposit_3_coins as Pool.all_coin_deposit_3_coins;
    use fun amm::deposit::all_coin_deposit_4_coins as Pool.all_coin_deposit_4_coins;
    use fun amm::deposit::all_coin_deposit_5_coins as Pool.all_coin_deposit_5_coins;
    use fun amm::deposit::all_coin_deposit_6_coins as Pool.all_coin_deposit_6_coins;
    use fun amm::deposit::all_coin_deposit_7_coins as Pool.all_coin_deposit_7_coins;
    use fun amm::deposit::all_coin_deposit_8_coins as Pool.all_coin_deposit_8_coins;

    //**************************************************************************************************//
    // Multi-Coin Deposit                                                                               //
    //**************************************************************************************************//

    /// Deposit `coin_1` into the Pool and mint a pro-rata amount of lp coins. DAO and protocol
    ///  fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`) and an estimated
    ///  post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_1_coins<L, C1>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        expected_lp_ratio: u128,
        slippage: u64,
        
        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_1_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    /// Deposit `coin_1` and `coin_2` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1` and `coin_2`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_2_coins<L, C1, C2>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        mut coin_2: Coin<C2>,
        expected_lp_ratio: u128,
        slippage: u64,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_2_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_3` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_3`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_3_coins<L, C1, C2, C3>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        mut coin_2: Coin<C2>,
        mut coin_3: Coin<C3>,
        expected_lp_ratio: u128,
        slippage: u64,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_3_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_4` into the Pool and mint a pro-rata amount of lp coins. Protocol
    ///  fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_4`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_4_coins<L, C1, C2, C3, C4>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        mut coin_2: Coin<C2>,
        mut coin_3: Coin<C3>,
        mut coin_4: Coin<C4>,
        expected_lp_ratio: u128,
        slippage: u64,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_4_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_6` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_6`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_5_coins<L, C1, C2, C3, C4, C5>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        mut coin_2: Coin<C2>,
        mut coin_3: Coin<C3>,
        mut coin_4: Coin<C4>,
        mut coin_5: Coin<C5>,
        expected_lp_ratio: u128,
        slippage: u64,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_5_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_6` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_6`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_6_coins<L, C1, C2, C3, C4, C5, C6>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        mut coin_2: Coin<C2>,
        mut coin_3: Coin<C3>,
        mut coin_4: Coin<C4>,
        mut coin_5: Coin<C5>,
        mut coin_6: Coin<C6>,
        expected_lp_ratio: u128,
        slippage: u64,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_6, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_6_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_7` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_7`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        mut coin_2: Coin<C2>,
        mut coin_3: Coin<C3>,
        mut coin_4: Coin<C4>,
        mut coin_5: Coin<C5>,
        mut coin_6: Coin<C6>,
        mut coin_7: Coin<C7>,
        expected_lp_ratio: u128,
        slippage: u64,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_6, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_7, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_7_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            coin_7,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_8` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_8`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::deposit::EInvalidProtocolVersion]
    /// iii. [amm::deposit::EZeroValue]
    ///  iv. [amm::deposit::EDuplicateTypes]
    ///   v. [amm::math::EZeroLpRatio]
    ///  vi. [amm::math::ESlippage]
    /// vii. [amm::math::EZeroLpOut]
    public fun deposit_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_1: Coin<C1>,
        mut coin_2: Coin<C2>,
        mut coin_3: Coin<C3>,
        mut coin_4: Coin<C4>,
        mut coin_5: Coin<C5>,
        mut coin_6: Coin<C6>,
        mut coin_7: Coin<C7>,
        mut coin_8: Coin<C8>,
        expected_lp_ratio: u128,
        slippage: u64,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_1, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_2, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_3, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_4, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_5, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_6, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_7, ctx);
        dao_fee_pool.collect_dao_fee(&mut coin_8, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().deposit_8_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            coin_7,
            coin_8,
            expected_lp_ratio,
            slippage,
            ctx,
        )
    }

    //**************************************************************************************************//
    // All-Coin Deposit                                                                                 //
    //**************************************************************************************************//

    /// Deposit `coin_1` and `coin_2` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  fees are charged on the Coins being deposited.
    ///
    /// Aborts:
    ///    i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///   ii. [amm::deposit::EInvalidProtocolVersion]
    ///  iii. [amm::deposit::EInvalidPoolSize]
    ///   iv. [amm::deposit::EZeroValue]
    ///    v. [amm::deposit::EDuplicateTypes]
    ///   vi. [amm::math::EZeroLpRatio]
    ///  vii. [amm::math::ESlippage]
    /// viii. [amm::math::EZeroLpOut]
    ///   ix. [amm::math::EZeroAmountIn]
    public fun all_coin_deposit_2_coins<L, C1, C2>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: &mut Coin<C1>,
        coin_2: &mut Coin<C2>,

        ctx: &mut TxContext,
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_1, ctx);
        dao_fee_pool.collect_dao_fee(coin_2, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().all_coin_deposit_2_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_3` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// Aborts:
    ///    i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///   ii. [amm::deposit::EInvalidProtocolVersion]
    ///  iii. [amm::deposit::EInvalidPoolSize]
    ///   iv. [amm::deposit::EZeroValue]
    ///    v. [amm::deposit::EDuplicateTypes]
    ///   vi. [amm::math::EZeroLpRatio]
    ///  vii. [amm::math::ESlippage]
    /// viii. [amm::math::EZeroLpOut]
    ///   ix. [amm::math::EZeroAmountIn]
    public fun all_coin_deposit_3_coins<L, C1, C2, C3>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: &mut Coin<C1>,
        coin_2: &mut Coin<C2>,
        coin_3: &mut Coin<C3>,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_1, ctx);
        dao_fee_pool.collect_dao_fee(coin_2, ctx);
        dao_fee_pool.collect_dao_fee(coin_3, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().all_coin_deposit_3_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_4` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// Aborts:
    ///    i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///   ii. [amm::deposit::EInvalidProtocolVersion]
    ///  iii. [amm::deposit::EInvalidPoolSize]
    ///   iv. [amm::deposit::EZeroValue]
    ///    v. [amm::deposit::EDuplicateTypes]
    ///   vi. [amm::math::EZeroLpRatio]
    ///  vii. [amm::math::ESlippage]
    /// viii. [amm::math::EZeroLpOut]
    ///   ix. [amm::math::EZeroAmountIn]
    public fun all_coin_deposit_4_coins<L, C1, C2, C3, C4>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: &mut Coin<C1>,
        coin_2: &mut Coin<C2>,
        coin_3: &mut Coin<C3>,
        coin_4: &mut Coin<C4>,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_1, ctx);
        dao_fee_pool.collect_dao_fee(coin_2, ctx);
        dao_fee_pool.collect_dao_fee(coin_3, ctx);
        dao_fee_pool.collect_dao_fee(coin_4, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().all_coin_deposit_4_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_5` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// Aborts:
    ///    i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///   ii. [amm::deposit::EInvalidProtocolVersion]
    ///  iii. [amm::deposit::EInvalidPoolSize]
    ///   iv. [amm::deposit::EZeroValue]
    ///    v. [amm::deposit::EDuplicateTypes]
    ///   vi. [amm::math::EZeroLpRatio]
    ///  vii. [amm::math::ESlippage]
    /// viii. [amm::math::EZeroLpOut]
    ///   ix. [amm::math::EZeroAmountIn]
    public fun all_coin_deposit_5_coins<L, C1, C2, C3, C4, C5>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: &mut Coin<C1>,
        coin_2: &mut Coin<C2>,
        coin_3: &mut Coin<C3>,
        coin_4: &mut Coin<C4>,
        coin_5: &mut Coin<C5>,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_1, ctx);
        dao_fee_pool.collect_dao_fee(coin_2, ctx);
        dao_fee_pool.collect_dao_fee(coin_3, ctx);
        dao_fee_pool.collect_dao_fee(coin_4, ctx);
        dao_fee_pool.collect_dao_fee(coin_5, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().all_coin_deposit_5_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_6` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// Aborts:
    ///    i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///   ii. [amm::deposit::EInvalidProtocolVersion]
    ///  iii. [amm::deposit::EInvalidPoolSize]
    ///   iv. [amm::deposit::EZeroValue]
    ///    v. [amm::deposit::EDuplicateTypes]
    ///   vi. [amm::math::EZeroLpRatio]
    ///  vii. [amm::math::ESlippage]
    /// viii. [amm::math::EZeroLpOut]
    ///   ix. [amm::math::EZeroAmountIn]
    public fun all_coin_deposit_6_coins<L, C1, C2, C3, C4, C5, C6>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: &mut Coin<C1>,
        coin_2: &mut Coin<C2>,
        coin_3: &mut Coin<C3>,
        coin_4: &mut Coin<C4>,
        coin_5: &mut Coin<C5>,
        coin_6: &mut Coin<C6>,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_1, ctx);
        dao_fee_pool.collect_dao_fee(coin_2, ctx);
        dao_fee_pool.collect_dao_fee(coin_3, ctx);
        dao_fee_pool.collect_dao_fee(coin_4, ctx);
        dao_fee_pool.collect_dao_fee(coin_5, ctx);
        dao_fee_pool.collect_dao_fee(coin_6, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().all_coin_deposit_6_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_7` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// Aborts:
    ///    i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///   ii. [amm::deposit::EInvalidProtocolVersion]
    ///  iii. [amm::deposit::EInvalidPoolSize]
    ///   iv. [amm::deposit::EZeroValue]
    ///    v. [amm::deposit::EDuplicateTypes]
    ///   vi. [amm::math::EZeroLpRatio]
    ///  vii. [amm::math::ESlippage]
    /// viii. [amm::math::EZeroLpOut]
    ///   ix. [amm::math::EZeroAmountIn]
    public fun all_coin_deposit_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: &mut Coin<C1>,
        coin_2: &mut Coin<C2>,
        coin_3: &mut Coin<C3>,
        coin_4: &mut Coin<C4>,
        coin_5: &mut Coin<C5>,
        coin_6: &mut Coin<C6>,
        coin_7: &mut Coin<C7>,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_1, ctx);
        dao_fee_pool.collect_dao_fee(coin_2, ctx);
        dao_fee_pool.collect_dao_fee(coin_3, ctx);
        dao_fee_pool.collect_dao_fee(coin_4, ctx);
        dao_fee_pool.collect_dao_fee(coin_5, ctx);
        dao_fee_pool.collect_dao_fee(coin_6, ctx);
        dao_fee_pool.collect_dao_fee(coin_7, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().all_coin_deposit_7_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            coin_7,
            ctx,
        )
    }

    /// Deposit `coin_1`, ..., `coin_8` into the Pool and mint a pro-rata amount of lp coins. DAO and
    ///  protocol fees are charged on the coins being deposited.
    ///
    /// Aborts:
    ///    i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///   ii. [amm::deposit::EInvalidProtocolVersion]
    ///  iii. [amm::deposit::EInvalidPoolSize]
    ///   iv. [amm::deposit::EZeroValue]
    ///    v. [amm::deposit::EDuplicateTypes]
    ///   vi. [amm::math::EZeroLpRatio]
    ///  vii. [amm::math::ESlippage]
    /// viii. [amm::math::EZeroLpOut]
    ///   ix. [amm::math::EZeroAmountIn]
    public fun all_coin_deposit_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: &mut Coin<C1>,
        coin_2: &mut Coin<C2>,
        coin_3: &mut Coin<C3>,
        coin_4: &mut Coin<C4>,
        coin_5: &mut Coin<C5>,
        coin_6: &mut Coin<C6>,
        coin_7: &mut Coin<C7>,
        coin_8: &mut Coin<C8>,

        ctx: &mut TxContext
    ): Coin<L> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_1, ctx);
        dao_fee_pool.collect_dao_fee(coin_2, ctx);
        dao_fee_pool.collect_dao_fee(coin_3, ctx);
        dao_fee_pool.collect_dao_fee(coin_4, ctx);
        dao_fee_pool.collect_dao_fee(coin_5, ctx);
        dao_fee_pool.collect_dao_fee(coin_6, ctx);
        dao_fee_pool.collect_dao_fee(coin_7, ctx);
        dao_fee_pool.collect_dao_fee(coin_8, ctx);

        // iii. Perform the deposit.
        dao_fee_pool.borrow_mut_pool().all_coin_deposit_8_coins(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            coin_7,
            coin_8,
            ctx,
        )
    }
}
