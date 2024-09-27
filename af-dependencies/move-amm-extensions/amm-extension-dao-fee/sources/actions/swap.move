// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module amm_extension_dao_fee::swap {
    use amm_extension_dao_fee::pool::DaoFeePool;
    use amm_extension_dao_fee::version::Version;

    use amm::pool_registry::PoolRegistry;
    use amm::pool::Pool;

    use insurance_fund::insurance_fund::InsuranceFund;
    use referral_vault::referral_vault::ReferralVault;
    use protocol_fee_vault::vault::ProtocolFeeVault;
    use treasury::treasury::Treasury;

    use sui::coin::Coin;

    use fun amm::swap::swap_exact_out as Pool.swap_exact_out;
    use fun amm::swap::swap_exact_in as Pool.swap_exact_in;

    //**************************************************************************************************
    // Swap | One-to-one | Exact in
    //**************************************************************************************************

    /// Swap `coin_in` for an equal-valued amount of `Coin<CO>`. DAO and protocol fees are both charged
    ///  on the Coin being swapped in.
    ///
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::swap::EZeroValue]
    /// iii. [amm::swap::ESlippage]
    ///  iv. [amm::swap::EZeroAmountOut]
    ///   v. [amm::swap::EInvalidSwapAmountOut]
    public fun swap_exact_in<L, CI, CO>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        mut coin_in: Coin<CI>,
        expected_coin_out: u64,
        allowable_slippage: u64,

        ctx: &mut TxContext,
    ): Coin<CO> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(&mut coin_in, ctx);

        // iii. Perform the swap.
        dao_fee_pool.borrow_mut_pool().swap_exact_in(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_in,
            expected_coin_out,
            allowable_slippage,
            ctx,
        )
    }

    //**************************************************************************************************//
    // Swap | One-to-one | Exact out                                                                    //
    //**************************************************************************************************//

    // NOTE: this functions takes `coin_in` as a mutable reference -- in the case where the users
    //  estimate is exact, all value will be split from `coin_in`.
    //
    /// Swap `coin_in` for an equal-valued amount of `Coin<CO>`. DAO and protocol fees are both charged
    ///  on the Coin being swapped in.
    /// 
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    ///  ii. [amm::swap::EZeroValue]
    /// iii. [amm::swap::EInsufficientCoinIn]
    ///  iv. [amm::swap::ESlippage]
    ///   v. [amm::swap::EZeroAmountIn]
    ///  vi. [amm::swap::EInvalidSwapAmountOut]
    public fun swap_exact_out<L, CI, CO>(
        dao_fee_pool: &mut DaoFeePool<L>,
        version: &Version,

        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        amount_out: u64,
        coin_in: &mut Coin<CI>,
        expected_coin_in: u64,
        allowable_slippage: u64,

        ctx: &mut TxContext,
    ): Coin<CO> {
        // i. Only allow calling this function from the most recent `AftermathAmmExtensionDaoFee` package.
        version.assert_interacting_with_most_up_to_date_package();

        // ii. Take DAO fee.
        dao_fee_pool.collect_dao_fee(coin_in, ctx);

        // iii. Perform the swap.
        dao_fee_pool.borrow_mut_pool().swap_exact_out(
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            amount_out,
            coin_in,
            expected_coin_in,
            allowable_slippage,
            ctx,
        )
    }
}
