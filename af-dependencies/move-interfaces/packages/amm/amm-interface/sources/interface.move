// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module amm_interface::amm_interface {
    use amm::pool::{Self, CreatePoolCap, Pool};
    use amm::pool_registry::PoolRegistry;
    use amm::pool_factory;
    use amm::withdraw;
    use amm::deposit;
    use amm::swap;
    use amm::price;

    use protocol_fee_vault::vault::ProtocolFeeVault;
    use insurance_fund::insurance_fund::InsuranceFund;
    use referral_vault::referral_vault::ReferralVault;
    use treasury::treasury::Treasury;

    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::transfer;

    use std::option::Option;
    
    //**************************************************************************************************
    // Errors
    //**************************************************************************************************

    // Error legend:
    //    i.   0-9 -> pool.move
    //   ii. 10-19 -> pool_factory.move
    //  iii. 20-29 -> deposit.move
    //   iv. 30-39 -> withdraw.move
    //    v. 40-49 -> swap.move
    //   vi. 50-59 -> math.move
    //  vii. 60-69 -> pool_registry.move

    //**************************************************************************************************
    // Create
    //**************************************************************************************************

    // NOTE: because you can't have a function interact with a OTW and a shared object, we must split
    //  Pool creation into two steps:
    //    i. Create the underlying LP Coin type using a OTW,
    //   ii. Create the Pool and register it with the shared `PoolRegistry` object.
    //
    /// Create the `TreasuryCap` that will become a Pool's `Supply` of LP coins and the LP coins. 
    ///  associated `CoinMetadata` struct. This function creates a `CreatePoolCap<L>` object that can 
    ///  only be used as input to one of the `create_pool_n_coins` functions.
    /// 
    /// Aborts:
    ///  i. `EBadWitness`: the provided `witness` is not a OTW.
    public entry fun create_lp_coin<L: drop>(
        witness: L,
        decimals: u8,
        ctx: &mut TxContext
    ) {
        let create_pool_cap = pool_factory::create_lp_coin<L>(
            witness,
            decimals,
            ctx
        );

        pool::transfer_create_pool_cap(create_pool_cap, tx_context::sender(ctx));
    }

    /// Create a two-coin Pool if the provided parameters are valid. Adds a mapping of the Pool's LP 
    ///  coin type name to the Pool's `ID` to `PoolRegistry`.
    /// 
    /// A nonzero initial deposit is required for each of the Pool's underlying Coins, and an amount of
    ///  LP coins are minted in return. A minimum bound of `MIN_LP_SUPPLY` is enforced on the size of
    ///  LP coins to mint, and thus a lower bound exists for the size of the initial deposit. A portion
    ///  the initial LP supply (`MIN_LP_SUPPLY`) is locked by the Pool.
    ///
    /// Aborts:
    ///     i. `EZeroValue`: any of the initial deposits have a value of zero.
    ///    ii. `EFlatnessNotNormalized`: `flatness` is greater than `FIXED_ONE`.
    ///   iii. `EFlatnessNotSupported`: `flatness` is set to a value we do not support.
    ///    iv. `EBadVectorLength`: one of the input vectors has a length notequal to the desired Pool size.
    ///     v. `EInvalidWeight`: one of the individual weights is outside of the bound [MIN_WEIGHT, MAX_WEIGHT].
    ///    vi. `EInvalidFee`: this can occur for two reasons:
    ///        1) an entry of `fees_swap_in` is outside the bounds of [MIN_FEE, MAX_FEE],
    ///        2) an entry of `fees_swap_out`, `fees_deposit`, or `fees_withdraw` is set to a nonzero value,
    ///   vii. `EWeightsNotNormalized`: `weights` does not sum to `FIXED_ONE`.
    ///  viii. `ENotSorted`: the Pool's tpye generics were not supplied in lexicographical order.
    ///    ix. `EDuplicatePool`: a `Pool` already exists with the provided Pool configuration.
    ///     x. `ENotEnoughInitialLiquidity`: the initial deposit would mint less than `MIN_LP_SUPPLY` LP coins.
    ///    xi. `ENonZeroTotalSupply`: the `TreasuryCap` stored within `create_pool_cap` has a nonzero Supply
    ///       value.
    ///   xii. `EFieldAlreadyExists`: the types `C1` and `C2` are the same.
    public entry fun create_pool_2_coins<L, C1, C2>(
        create_pool_cap: CreatePoolCap<L>,
        pool_registry: &mut PoolRegistry,
        name: vector<u8>,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        lp_description: vector<u8>,
        lp_icon_url: vector<u8>,
        weights: vector<u64>,
        flatness: u64,
        fees_swap_in: vector<u64>,
        fees_swap_out: vector<u64>,
        fees_deposit: vector<u64>,
        fees_withdraw: vector<u64>,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        decimals: Option<vector<u8>>,
        respect_decimals: bool,
        force_lp_decimals: Option<u8>,
        ctx: &mut TxContext
    ) {
        let (pool, lp_coin) = pool_factory::create_pool_2_coins<L, C1, C2>(
            create_pool_cap,
            pool_registry,
            name,
            lp_name,
            lp_symbol,
            lp_description,
            lp_icon_url,
            weights,
            flatness,
            fees_swap_in,
            fees_swap_out,
            fees_deposit,
            fees_withdraw,
            coin_1,
            coin_2,
            decimals,
            respect_decimals,
            force_lp_decimals,
            ctx
        );

        pool::share(pool);
        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Create a three-coin Pool if the provided parameters are valid. Adds a mapping of the Pool's LP 
    ///  coin type name to the Pool's `ID` to `PoolRegistry`.
    /// 
    /// A nonzero initial deposit is required for each of the Pool's underlying Coins, and an amount of
    ///  LP coins are minted in return. A minimum bound of `MIN_LP_SUPPLY` is enforced on the size of
    ///  LP coins to mint, and thus a lower bound exists for the size of the initial deposit. A portion
    ///  the initial LP supply (`MIN_LP_SUPPLY`) is locked by the Pool.
    ///
    /// Aborts:
    ///     i. `EZeroValue`: any of the initial deposits have a value of zero.
    ///    ii. `EFlatnessNotNormalized`: `flatness` is greater than `FIXED_ONE`.
    ///   iii. `EFlatnessNotSupported`: `flatness` is set to a value we do not support.
    ///    iv. `EBadVectorLength`: one of the input vectors has a length notequal to the desired Pool size.
    ///     v. `EInvalidWeight`: one of the individual weights is outside of the bound [MIN_WEIGHT, MAX_WEIGHT].
    ///    vi. `EInvalidFee`: this can occur for two reasons:
    ///        1) an entry of `fees_swap_in` is outside the bounds of [MIN_FEE, MAX_FEE],
    ///        2) an entry of `fees_swap_out`, `fees_deposit`, or `fees_withdraw` is set to a nonzero value,
    ///   vii. `EWeightsNotNormalized`: `weights` does not sum to `FIXED_ONE`.
    ///  viii. `ENotSorted`: the Pool's tpye generics were not supplied in lexicographical order.
    ///    ix. `EDuplicatePool`: a `Pool` already exists with the provided Pool configuration.
    ///     x. `ENotEnoughInitialLiquidity`: the initial deposit would mint less than `MIN_LP_SUPPLY` LP coins.
    ///    xi. `ENonZeroTotalSupply`: the `TreasuryCap` stored within `create_pool_cap` has a nonzero Supply
    ///       value.
    ///   xii. `EFieldAlreadyExists`: any of the types `C1`, ..., `C3` are the duplicates.
    public entry fun create_pool_3_coins<L, C1, C2, C3>(
        create_pool_cap: CreatePoolCap<L>,
        pool_registry: &mut PoolRegistry,
        name: vector<u8>,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        lp_description: vector<u8>,
        lp_icon_url: vector<u8>,
        weights: vector<u64>,
        flatness: u64,
        fees_swap_in: vector<u64>,
        fees_swap_out: vector<u64>,
        fees_deposit: vector<u64>,
        fees_withdraw: vector<u64>,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        decimals: Option<vector<u8>>,
        respect_decimals: bool,
        force_lp_decimals: Option<u8>,
        ctx: &mut TxContext
    ) {
        let (pool, lp_coin) = pool_factory::create_pool_3_coins<L, C1, C2, C3>(
            create_pool_cap,
            pool_registry,
            name,
            lp_name,
            lp_symbol,
            lp_description,
            lp_icon_url,
            weights,
            flatness,
            fees_swap_in,
            fees_swap_out,
            fees_deposit,
            fees_withdraw,
            coin_1,
            coin_2,
            coin_3,
            decimals,
            respect_decimals,
            force_lp_decimals,
            ctx
        );

        pool::share(pool);
        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Create a four-coin Pool if the provided parameters are valid. Adds a mapping of the Pool's LP 
    ///  coin type name to the Pool's `ID` to `PoolRegistry`.
    /// 
    /// A nonzero initial deposit is required for each of the Pool's underlying Coins, and an amount of
    ///  LP coins are minted in return. A minimum bound of `MIN_LP_SUPPLY` is enforced on the size of
    ///  LP coins to mint, and thus a lower bound exists for the size of the initial deposit. A portion
    ///  the initial LP supply (`MIN_LP_SUPPLY`) is locked by the Pool.
    ///
    /// Aborts:
    ///     i. `EZeroValue`: any of the initial deposits have a value of zero.
    ///    ii. `EFlatnessNotNormalized`: `flatness` is greater than `FIXED_ONE`.
    ///   iii. `EFlatnessNotSupported`: `flatness` is set to a value we do not support.
    ///    iv. `EBadVectorLength`: one of the input vectors has a length notequal to the desired Pool size.
    ///     v. `EInvalidWeight`: one of the individual weights is outside of the bound [MIN_WEIGHT, MAX_WEIGHT].
    ///    vi. `EInvalidFee`: this can occur for two reasons:
    ///        1) an entry of `fees_swap_in` is outside the bounds of [MIN_FEE, MAX_FEE],
    ///        2) an entry of `fees_swap_out`, `fees_deposit`, or `fees_withdraw` is set to a nonzero value,
    ///   vii. `EWeightsNotNormalized`: `weights` does not sum to `FIXED_ONE`.
    ///  viii. `ENotSorted`: the Pool's tpye generics were not supplied in lexicographical order.
    ///    ix. `EDuplicatePool`: a `Pool` already exists with the provided Pool configuration.
    ///     x. `ENotEnoughInitialLiquidity`: the initial deposit would mint less than `MIN_LP_SUPPLY` LP coins.
    ///    xi. `ENonZeroTotalSupply`: the `TreasuryCap` stored within `create_pool_cap` has a nonzero Supply
    ///       value.
    ///   xii. `EFieldAlreadyExists`: any of the types `C1`, ..., `C4` are the duplicates.
    public entry fun create_pool_4_coins<L, C1, C2, C3, C4>(
        create_pool_cap: CreatePoolCap<L>,
        pool_registry: &mut PoolRegistry,
        name: vector<u8>,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        lp_description: vector<u8>,
        lp_icon_url: vector<u8>,
        weights: vector<u64>,
        flatness: u64,
        fees_swap_in: vector<u64>,
        fees_swap_out: vector<u64>,
        fees_deposit: vector<u64>,
        fees_withdraw: vector<u64>,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        decimals: Option<vector<u8>>,
        respect_decimals: bool,
        force_lp_decimals: Option<u8>,
        ctx: &mut TxContext
    ) {
        let (pool, lp_coin) = pool_factory::create_pool_4_coins<L, C1, C2, C3, C4>(
            create_pool_cap,
            pool_registry,
            name,
            lp_name,
            lp_symbol,
            lp_description,
            lp_icon_url,
            weights,
            flatness,
            fees_swap_in,
            fees_swap_out,
            fees_deposit,
            fees_withdraw,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            decimals,
            respect_decimals,
            force_lp_decimals,
            ctx
        );

        pool::share(pool);
        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Create a five-coin Pool if the provided parameters are valid. Adds a mapping of the Pool's LP 
    ///  coin type name to the Pool's `ID` to `PoolRegistry`.
    /// 
    /// A nonzero initial deposit is required for each of the Pool's underlying Coins, and an amount of
    ///  LP coins are minted in return. A minimum bound of `MIN_LP_SUPPLY` is enforced on the size of
    ///  LP coins to mint, and thus a lower bound exists for the size of the initial deposit. A portion
    ///  the initial LP supply (`MIN_LP_SUPPLY`) is locked by the Pool.
    ///
    /// Aborts:
    ///     i. `EZeroValue`: any of the initial deposits have a value of zero.
    ///    ii. `EFlatnessNotNormalized`: `flatness` is greater than `FIXED_ONE`.
    ///   iii. `EFlatnessNotSupported`: `flatness` is set to a value we do not support.
    ///    iv. `EBadVectorLength`: one of the input vectors has a length notequal to the desired Pool size.
    ///     v. `EInvalidWeight`: one of the individual weights is outside of the bound [MIN_WEIGHT, MAX_WEIGHT].
    ///    vi. `EInvalidFee`: this can occur for two reasons:
    ///        1) an entry of `fees_swap_in` is outside the bounds of [MIN_FEE, MAX_FEE],
    ///        2) an entry of `fees_swap_out`, `fees_deposit`, or `fees_withdraw` is set to a nonzero value,
    ///   vii. `EWeightsNotNormalized`: `weights` does not sum to `FIXED_ONE`.
    ///  viii. `ENotSorted`: the Pool's tpye generics were not supplied in lexicographical order.
    ///    ix. `EDuplicatePool`: a `Pool` already exists with the provided Pool configuration.
    ///     x. `ENotEnoughInitialLiquidity`: the initial deposit would mint less than `MIN_LP_SUPPLY` LP coins.
    ///    xi. `ENonZeroTotalSupply`: the `TreasuryCap` stored within `create_pool_cap` has a nonzero Supply
    ///       value.
    ///   xii. `EFieldAlreadyExists`: any of the types `C1`, ..., `C5` are the duplicates.
    public entry fun create_pool_5_coins<L, C1, C2, C3, C4, C5>(
        create_pool_cap: CreatePoolCap<L>,
        pool_registry: &mut PoolRegistry,
        name: vector<u8>,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        lp_description: vector<u8>,
        lp_icon_url: vector<u8>,
        weights: vector<u64>,
        flatness: u64,
        fees_swap_in: vector<u64>,
        fees_swap_out: vector<u64>,
        fees_deposit: vector<u64>,
        fees_withdraw: vector<u64>,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        decimals: Option<vector<u8>>,
        respect_decimals: bool,
        force_lp_decimals: Option<u8>,
        ctx: &mut TxContext
    ) {
        let (pool, lp_coin) = pool_factory::create_pool_5_coins<L, C1, C2, C3, C4, C5>(
            create_pool_cap,
            pool_registry,
            name,
            lp_name,
            lp_symbol,
            lp_description,
            lp_icon_url,
            weights,
            flatness,
            fees_swap_in,
            fees_swap_out,
            fees_deposit,
            fees_withdraw,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            decimals,
            respect_decimals,
            force_lp_decimals,
            ctx
        );

        pool::share(pool);
        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Create a six-coin Pool if the provided parameters are valid. Adds a mapping of the Pool's LP 
    ///  coin type name to the Pool's `ID` to `PoolRegistry`.
    /// 
    /// A nonzero initial deposit is required for each of the Pool's underlying Coins, and an amount of
    ///  LP coins are minted in return. A minimum bound of `MIN_LP_SUPPLY` is enforced on the size of
    ///  LP coins to mint, and thus a lower bound exists for the size of the initial deposit. A portion
    ///  the initial LP supply (`MIN_LP_SUPPLY`) is locked by the Pool.
    ///
    /// Aborts:
    ///     i. `EZeroValue`: any of the initial deposits have a value of zero.
    ///    ii. `EFlatnessNotNormalized`: `flatness` is greater than `FIXED_ONE`.
    ///   iii. `EFlatnessNotSupported`: `flatness` is set to a value we do not support.
    ///    iv. `EBadVectorLength`: one of the input vectors has a length notequal to the desired Pool size.
    ///     v. `EInvalidWeight`: one of the individual weights is outside of the bound [MIN_WEIGHT, MAX_WEIGHT].
    ///    vi. `EInvalidFee`: this can occur for two reasons:
    ///        1) an entry of `fees_swap_in` is outside the bounds of [MIN_FEE, MAX_FEE],
    ///        2) an entry of `fees_swap_out`, `fees_deposit`, or `fees_withdraw` is set to a nonzero value,
    ///   vii. `EWeightsNotNormalized`: `weights` does not sum to `FIXED_ONE`.
    ///  viii. `ENotSorted`: the Pool's tpye generics were not supplied in lexicographical order.
    ///    ix. `EDuplicatePool`: a `Pool` already exists with the provided Pool configuration.
    ///     x. `ENotEnoughInitialLiquidity`: the initial deposit would mint less than `MIN_LP_SUPPLY` LP coins.
    ///    xi. `ENonZeroTotalSupply`: the `TreasuryCap` stored within `create_pool_cap` has a nonzero Supply
    ///       value.
    ///   xii. `EFieldAlreadyExists`: any of the types `C1`, ..., `C6` are the duplicates.
    public entry fun create_pool_6_coins<L, C1, C2, C3, C4, C5, C6>(
        create_pool_cap: CreatePoolCap<L>,
        pool_registry: &mut PoolRegistry,
        name: vector<u8>,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        lp_description: vector<u8>,
        lp_icon_url: vector<u8>,
        weights: vector<u64>,
        flatness: u64,
        fees_swap_in: vector<u64>,
        fees_swap_out: vector<u64>,
        fees_deposit: vector<u64>,
        fees_withdraw: vector<u64>,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        decimals: Option<vector<u8>>,
        respect_decimals: bool,
        force_lp_decimals: Option<u8>,
        ctx: &mut TxContext
    ) {
        let (pool, lp_coin) = pool_factory::create_pool_6_coins<L, C1, C2, C3, C4, C5, C6>(
            create_pool_cap,
            pool_registry,
            name,
            lp_name,
            lp_symbol,
            lp_description,
            lp_icon_url,
            weights,
            flatness,
            fees_swap_in,
            fees_swap_out,
            fees_deposit,
            fees_withdraw,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            decimals,
            respect_decimals,
            force_lp_decimals,
            ctx
        );

        pool::share(pool);
        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Create a seven-coin Pool if the provided parameters are valid. Adds a mapping of the Pool's LP 
    ///  coin type name to the Pool's `ID` to `PoolRegistry`.
    /// 
    /// A nonzero initial deposit is required for each of the Pool's underlying Coins, and an amount of
    ///  LP coins are minted in return. A minimum bound of `MIN_LP_SUPPLY` is enforced on the size of
    ///  LP coins to mint, and thus a lower bound exists for the size of the initial deposit. A portion
    ///  the initial LP supply (`MIN_LP_SUPPLY`) is locked by the Pool.
    ///
    /// Aborts:
    ///     i. `EZeroValue`: any of the initial deposits have a value of zero.
    ///    ii. `EFlatnessNotNormalized`: `flatness` is greater than `FIXED_ONE`.
    ///   iii. `EFlatnessNotSupported`: `flatness` is set to a value we do not support.
    ///    iv. `EBadVectorLength`: one of the input vectors has a length notequal to the desired Pool size.
    ///     v. `EInvalidWeight`: one of the individual weights is outside of the bound [MIN_WEIGHT, MAX_WEIGHT].
    ///    vi. `EInvalidFee`: this can occur for two reasons:
    ///        1) an entry of `fees_swap_in` is outside the bounds of [MIN_FEE, MAX_FEE],
    ///        2) an entry of `fees_swap_out`, `fees_deposit`, or `fees_withdraw` is set to a nonzero value,
    ///   vii. `EWeightsNotNormalized`: `weights` does not sum to `FIXED_ONE`.
    ///  viii. `ENotSorted`: the Pool's tpye generics were not supplied in lexicographical order.
    ///    ix. `EDuplicatePool`: a `Pool` already exists with the provided Pool configuration.
    ///     x. `ENotEnoughInitialLiquidity`: the initial deposit would mint less than `MIN_LP_SUPPLY` LP coins.
    ///    xi. `ENonZeroTotalSupply`: the `TreasuryCap` stored within `create_pool_cap` has a nonzero Supply
    ///       value.
    ///   xii. `EFieldAlreadyExists`: any of the types `C1`, ..., `C7` are the duplicates.
    public entry fun create_pool_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
        create_pool_cap: CreatePoolCap<L>,
        pool_registry: &mut PoolRegistry,
        name: vector<u8>,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        lp_description: vector<u8>,
        lp_icon_url: vector<u8>,
        weights: vector<u64>,
        flatness: u64,
        fees_swap_in: vector<u64>,
        fees_swap_out: vector<u64>,
        fees_deposit: vector<u64>,
        fees_withdraw: vector<u64>,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        coin_7: Coin<C7>,
        decimals: Option<vector<u8>>,
        respect_decimals: bool,
        force_lp_decimals: Option<u8>,
        ctx: &mut TxContext
    ) {
        let (pool, lp_coin) = pool_factory::create_pool_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
            create_pool_cap,
            pool_registry,
            name,
            lp_name,
            lp_symbol,
            lp_description,
            lp_icon_url,
            weights,
            flatness,
            fees_swap_in,
            fees_swap_out,
            fees_deposit,
            fees_withdraw,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            coin_7,
            decimals,
            respect_decimals,
            force_lp_decimals,
            ctx
        );

        pool::share(pool);
        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Create a eight-coin Pool if the provided parameters are valid. Adds a mapping of the Pool's LP 
    ///  coin type name to the Pool's `ID` to `PoolRegistry`.
    /// 
    /// A nonzero initial deposit is required for each of the Pool's underlying Coins, and an amount of
    ///  LP coins are minted in return. A minimum bound of `MIN_LP_SUPPLY` is enforced on the size of
    ///  LP coins to mint, and thus a lower bound exists for the size of the initial deposit. A portion
    ///  the initial LP supply (`MIN_LP_SUPPLY`) is locked by the Pool.
    ///
    /// Aborts:
    ///     i. `EZeroValue`: any of the initial deposits have a value of zero.
    ///    ii. `EFlatnessNotNormalized`: `flatness` is greater than `FIXED_ONE`.
    ///   iii. `EFlatnessNotSupported`: `flatness` is set to a value we do not support.
    ///    iv. `EBadVectorLength`: one of the input vectors has a length notequal to the desired Pool size.
    ///     v. `EInvalidWeight`: one of the individual weights is outside of the bound [MIN_WEIGHT, MAX_WEIGHT].
    ///    vi. `EInvalidFee`: this can occur for two reasons:
    ///        1) an entry of `fees_swap_in` is outside the bounds of [MIN_FEE, MAX_FEE],
    ///        2) an entry of `fees_swap_out`, `fees_deposit`, or `fees_withdraw` is set to a nonzero value,
    ///   vii. `EWeightsNotNormalized`: `weights` does not sum to `FIXED_ONE`.
    ///  viii. `ENotSorted`: the Pool's tpye generics were not supplied in lexicographical order.
    ///    ix. `EDuplicatePool`: a `Pool` already exists with the provided Pool configuration.
    ///     x. `ENotEnoughInitialLiquidity`: the initial deposit would mint less than `MIN_LP_SUPPLY` LP coins.
    ///    xi. `ENonZeroTotalSupply`: the `TreasuryCap` stored within `create_pool_cap` has a nonzero Supply
    ///       value.
    ///   xii. `EFieldAlreadyExists`: any of the types `C1`, ..., `C8` are the duplicates.
    public entry fun create_pool_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
        create_pool_cap: CreatePoolCap<L>,
        pool_registry: &mut PoolRegistry,
        name: vector<u8>,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        lp_description: vector<u8>,
        lp_icon_url: vector<u8>,
        weights: vector<u64>,
        flatness: u64,
        fees_swap_in: vector<u64>,
        fees_swap_out: vector<u64>,
        fees_deposit: vector<u64>,
        fees_withdraw: vector<u64>,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        coin_7: Coin<C7>,
        coin_8: Coin<C8>,
        decimals: Option<vector<u8>>,
        respect_decimals: bool,
        force_lp_decimals: Option<u8>,
        ctx: &mut TxContext
    ) {
        let (pool, lp_coin) = pool_factory::create_pool_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
            create_pool_cap,
            pool_registry,
            name,
            lp_name,
            lp_symbol,
            lp_description,
            lp_icon_url,
            weights,
            flatness,
            fees_swap_in,
            fees_swap_out,
            fees_deposit,
            fees_withdraw,
            coin_1,
            coin_2,
            coin_3,
            coin_4,
            coin_5,
            coin_6,
            coin_7,
            coin_8,
            decimals,
            respect_decimals,
            force_lp_decimals,
            ctx
        );

        pool::share(pool);
        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    //**************************************************************************************************
    // Price
    //**************************************************************************************************
    
    /// Obtain the Pool's intrinsic price of `Coin<BASE>` denominated in `Coin<QUOTE>`.
    ///  This function does not include fees.
    /// 
    /// Aborts: 
    ///   i. `EBadType`: the Pool doesn't contain the Coin type `BASE` or `QUOTE`.
    ///  ii. `ArithmeticError`: the Pool's balance of `Coin<QUOTE>` is zero.
    public entry fun oracle_price<L, BASE, QUOTE>(
        pool: &Pool<L>,
        pool_registry: &PoolRegistry,
        _ctx: &TxContext,
    ) {
        price::oracle_price<L, BASE, QUOTE>(
            pool,
            pool_registry,
        );
    }

    /// Obtain the Pool's intrinsic price of `Coin<BASE>` denominated in `Coin<QUOTE>`.
    ///  This function includes LP fees but does not include Protocol fees.
    /// 
    /// Aborts:
    ///   i. `EBadType`: the Pool doesn't contain the Coin type `BASE` or `QUOTE`.
    ///  ii. `ArithmeticError`: the Pool's balance of `Coin<QUOTE>` is zero.
    public entry fun spot_price<L, BASE, QUOTE>(
        pool: &Pool<L>,
        pool_registry: &PoolRegistry,
        _ctx: &TxContext,
    ) {
        price::spot_price<L, BASE, QUOTE>(
            pool,
            pool_registry,
        );
    }

    //**************************************************************************************************
    // Swap | One-to-one | Exact in
    //**************************************************************************************************

    /// Swap `coin_in` for an equal-valued amount of `Coin<CO>`. Protocol fees are charged on the Coin
    ///  being swapped in.
    ///
    /// Aborts:
    ///    i. `EZeroValue`: `coin_in` has a value of zero.
    ///   ii. `ESlippage`: `actual_amount_out` lies outside of the Slippage bound set by `acceptable_slippage`.
    ///  iii. `EZeroAmountOut`: `amount_in` is worth zero amount of `Coin<CO>`.
    ///   iv. `EInvalidSwapAmountOut`: the swap would result in more than `MAX_SWAP_AMOUNT_OUT` worth of
    ///    `Coin<CO>` exiting the Pool.
    public entry fun swap_exact_in<L, CI, CO>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_in: Coin<CI>,
        expected_coin_out: u64,
        allowable_slippage: u64,
        ctx: &mut TxContext,
    ) {
        let coin_out = swap::swap_exact_in<L, CI, CO>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_in,
            expected_coin_out,
            allowable_slippage,
            ctx
        );

        transfer::public_transfer(coin_out, tx_context::sender(ctx));
    }

    //**************************************************************************************************
    // Swap | One-to-one | Exact out
    //**************************************************************************************************

    /// Swap `coin_in` for an equal-valued amount of `Coin<CO>`. Protocol fees are charged on the Coin
    ///  being swapped in.
    /// 
    /// Aborts with:
    ///    i. `EZeroValue`: this can occur for two reasons:
    ///        1) `coin_in` has a value of zero.
    ///        2) `amount_out` has a value of zero.
    ///   ii. `EInsufficientCoinIn`: `coin_in` has a value less than what is needed to swap for 
    ///      `amount_out` of `Coin<CO>`.
    ///  iii. `ESlippage`: `actual_amount_in` lies outside of the Slippage bound set by `acceptable_slippage`.
    ///   iv. `EZeroAmountIn`: `amount_out` is worth zero amount of `Coin<CI>`.
    ///    v. `EInvalidSwapAmountOut`: the user requests to withdraw more than `MAX_SWAP_AMOUNT_OUT` worth of
    ///      `Coin<CO>` from the Pool.
    public entry fun swap_exact_out<L, CI, CO>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        amount_out: u64,
        coin_in: Coin<CI>,
        expected_coin_in: u64,
        allowable_slippage: u64,
        ctx: &mut TxContext,
    ) {        
        let (coin_out) = swap::swap_exact_out<L, CI, CO>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            amount_out,
            &mut coin_in,
            expected_coin_in,
            allowable_slippage,
            ctx
        );

        let sender = tx_context::sender(ctx);

        transfer_if_nonzero(coin_in, sender);
        transfer::public_transfer(coin_out, sender);
    }

    //**************************************************************************************************
    // Multi-Coin Deposit
    //**************************************************************************************************

    /// Deposit `coin_1` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`) and an estimated
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EZeroValue`: `coin_1` has a value of zero.  
    ///   ii. `EBadType`: `pool` doesn't contain the Coin type `C1`.
    ///  iii. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_1_coins<L, C1>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_1_coins<L, C1>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            expected_lp_ratio,
            slippage,
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Deposit `coin_1` and `coin_2` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1` and `coin_2`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EZeroValue`: any of `coin_1` or `coin_2` have a value of zero.  
    ///   ii. `EBadType`: `pool` doesn't contain one of the Coin types `C1` or `C2`.
    ///  iii. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///   vi. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_2_coins<L, C1, C2>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_2_coins<L, C1, C2>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            coin_1,
            coin_2,
            expected_lp_ratio,
            slippage,
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Deposit `coin_1`, ..., `coin_3` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_3`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool is < 3.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_3` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C3`.
    ///   iv. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///    v. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_3_coins<L, C1, C2, C3>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_3_coins<L, C1, C2, C3>(
            pool,
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
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Deposit `coin_1`, ..., `coin_4` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_4`) and an
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool is < 4.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_4` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C4`.
    ///   iv. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///    v. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_4_coins<L, C1, C2, C3, C4>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_4_coins<L, C1, C2, C3, C4>(
            pool,
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
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Deposit `coin_1`, ..., `coin_6` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_6`) estimated
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool is < 6.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_6` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C6`.
    ///   iv. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///    v. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_5_coins<L, C1, C2, C3, C4, C5>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_5_coins<L, C1, C2, C3, C4, C5>(
            pool,
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
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Deposit `coin_1`, ..., `coin_6` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_6`) estimated
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool is < 6.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_6` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C6`.
    ///   iv. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///    v. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_6_coins<L, C1, C2, C3, C4, C5, C6>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_6_coins<L, C1, C2, C3, C4, C5, C6>(
            pool,
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
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Deposit `coin_1`, ..., `coin_7` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_7`) estimated
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool is < 7.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_7` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C7`.
    ///   iv. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///    v. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        coin_7: Coin<C7>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
            pool,
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
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    /// Deposit `coin_1`, ..., `coin_8` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// This deposit accepts an exact amount of coins to deposit (`coin_1`, ..., `coin_8`) estimated
    ///  estimated post-deposit LP ratio (`expected_lp_ratio`) and calculates the number of LP coins
    ///  to mint for the provided coins.
    /// 
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool is < 8.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_8` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C8`.
    ///   iv. `ESlippage`: the deposit ends up being worth less by a factor of `acceptable_slippage`.
    ///    v. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun deposit_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        coin_7: Coin<C7>,
        coin_8: Coin<C8>,
        expected_lp_ratio: u128,
        slippage: u64,
        ctx: &mut TxContext
    ) {
        let lp_coin = deposit::deposit_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
            pool,
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
            ctx
        );

        transfer::public_transfer(lp_coin, tx_context::sender(ctx));
    }

    //**************************************************************************************************
    // All-Coin Deposit
    //**************************************************************************************************

    /// Deposit `coin_1` and `coin_2` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 1.
    ///   ii. `EZeroValue`: `coin_1` or `coin_2` has a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C2`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun all_coin_deposit_2_coins<L, C1, C2>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        ctx: &mut TxContext,
    ) {
        let lp_coin = deposit::all_coin_deposit_2_coins<L, C1, C2>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            &mut coin_1,
            &mut coin_2,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lp_coin, sender);
        transfer_if_nonzero(coin_1, sender);
        transfer_if_nonzero(coin_2, sender);
    }

    /// Deposit `coin_1`, ..., `coin_3` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 3.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_3` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C3`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun all_coin_deposit_3_coins<L, C1, C2, C3>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        ctx: &mut TxContext,
    ) {
        let lp_coin = deposit::all_coin_deposit_3_coins<L, C1, C2, C3>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            &mut coin_1,
            &mut coin_2,
            &mut coin_3,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lp_coin, sender);
        transfer_if_nonzero(coin_1, sender);
        transfer_if_nonzero(coin_2, sender);
        transfer_if_nonzero(coin_3, sender);
    }

    /// Deposit `coin_1`, ..., `coin_4` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 4.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_4` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C4`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun all_coin_deposit_4_coins<L, C1, C2, C3, C4>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        ctx: &mut TxContext,
    ) {
        let lp_coin = deposit::all_coin_deposit_4_coins<L, C1, C2, C3, C4>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            &mut coin_1,
            &mut coin_2,
            &mut coin_3,
            &mut coin_4,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lp_coin, sender);
        transfer_if_nonzero(coin_1, sender);
        transfer_if_nonzero(coin_2, sender);
        transfer_if_nonzero(coin_3, sender);
        transfer_if_nonzero(coin_4, sender);
    }


    /// Deposit `coin_1`, ..., `coin_5` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 5.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_5` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C5`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun all_coin_deposit_5_coins<L, C1, C2, C3, C4, C5>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        ctx: &mut TxContext,
    ) {
        let lp_coin = deposit::all_coin_deposit_5_coins<L, C1, C2, C3, C4, C5>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            &mut coin_1,
            &mut coin_2,
            &mut coin_3,
            &mut coin_4,
            &mut coin_5,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lp_coin, sender);
        transfer_if_nonzero(coin_1, sender);
        transfer_if_nonzero(coin_2, sender);
        transfer_if_nonzero(coin_3, sender);
        transfer_if_nonzero(coin_4, sender);
        transfer_if_nonzero(coin_5, sender);
    }

    /// Deposit `coin_1`, ..., `coin_6` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 6.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_6` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C6`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun all_coin_deposit_6_coins<L, C1, C2, C3, C4, C5, C6>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        ctx: &mut TxContext,
    ) {
        let lp_coin = deposit::all_coin_deposit_6_coins<L, C1, C2, C3, C4, C5, C6>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            &mut coin_1,
            &mut coin_2,
            &mut coin_3,
            &mut coin_4,
            &mut coin_5,
            &mut coin_6,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lp_coin, sender);
        transfer_if_nonzero(coin_1, sender);
        transfer_if_nonzero(coin_2, sender);
        transfer_if_nonzero(coin_3, sender);
        transfer_if_nonzero(coin_4, sender);
        transfer_if_nonzero(coin_5, sender);
        transfer_if_nonzero(coin_6, sender);
    }

    /// Deposit `coin_1`, ..., `coin_7` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 7.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_7` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C7`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun all_coin_deposit_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        coin_7: Coin<C7>,
        ctx: &mut TxContext,
    ) {
        let lp_coin = deposit::all_coin_deposit_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            &mut coin_1,
            &mut coin_2,
            &mut coin_3,
            &mut coin_4,
            &mut coin_5,
            &mut coin_6,
            &mut coin_7,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lp_coin, sender);
        transfer_if_nonzero(coin_1, sender);
        transfer_if_nonzero(coin_2, sender);
        transfer_if_nonzero(coin_3, sender);
        transfer_if_nonzero(coin_4, sender);
        transfer_if_nonzero(coin_5, sender);
        transfer_if_nonzero(coin_6, sender);
        transfer_if_nonzero(coin_7, sender);
    }

    /// Deposit `coin_1`, ..., `coin_8` into the Pool and mint a pro-rata amount of lp coins. Protocol 
    ///  fees are charged on the Coin's being deposited.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 8.
    ///   ii. `EZeroValue`: any of `coin_1`, ..., `coin_8` have a value of zero.  
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C8`.
    ///   iv. `EZeroLpOut`: the deposit is worth zero LP Coins.
    public entry fun all_coin_deposit_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        coin_1: Coin<C1>,
        coin_2: Coin<C2>,
        coin_3: Coin<C3>,
        coin_4: Coin<C4>,
        coin_5: Coin<C5>,
        coin_6: Coin<C6>,
        coin_7: Coin<C7>,
        coin_8: Coin<C8>,
        ctx: &mut TxContext,
    ) {
        let lp_coin = deposit::all_coin_deposit_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            &mut coin_1,
            &mut coin_2,
            &mut coin_3,
            &mut coin_4,
            &mut coin_5,
            &mut coin_6,
            &mut coin_7,
            &mut coin_8,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lp_coin, sender);
        transfer_if_nonzero(coin_1, sender);
        transfer_if_nonzero(coin_2, sender);
        transfer_if_nonzero(coin_3, sender);
        transfer_if_nonzero(coin_4, sender);
        transfer_if_nonzero(coin_5, sender);
        transfer_if_nonzero(coin_6, sender);
        transfer_if_nonzero(coin_7, sender);
        transfer_if_nonzero(coin_8, sender);
    }

    //**************************************************************************************************
    // All-Coin Withdraw
    //**************************************************************************************************

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C2>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. Protocol fees are charged on the Coin's being withdrawn.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 2.
    ///   ii. `EZeroValue`: the user supplies an `lp_coin` with value zero.
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C2`.
    ///   iv. `EZeroLpRatio`: `lp_coin` is so small it's value rounds to zero amount of the Pool's
    ///     liquidity.
    public entry fun all_coin_withdraw_2_coins<L, C1, C2>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,
        ctx: &mut TxContext,
    ) {
        let (coin_1, coin_2) = withdraw::all_coin_withdraw_2_coins<L, C1, C2>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            lp_coin,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_1, sender);
        transfer::public_transfer(coin_2, sender);
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C3>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. Protocol fees are charged on the Coin's being withdrawn.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 3.
    ///   ii. `EZeroValue`: the user supplies an `lp_coin` with value zero.
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C3`.
    ///   iv. `EZeroLpRatio`: `lp_coin` is so small it's value rounds to zero amount of the Pool's
    ///     liquidity.
    public entry fun all_coin_withdraw_3_coins<L, C1, C2, C3>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,
        ctx: &mut TxContext,
    ) {
        let (coin_1, coin_2, coin_3) = withdraw::all_coin_withdraw_3_coins<L, C1, C2, C3>(
            pool,
            pool_registry,
            protocol_fee_vault,
            treasury,
            insurance_fund,
            referral_vault,
            lp_coin,
            ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_1, sender);
        transfer::public_transfer(coin_2, sender);
        transfer::public_transfer(coin_3, sender);
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C4>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. Protocol fees are charged on the Coin's being withdrawn.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 4.
    ///   ii. `EZeroValue`: the user supplies an `lp_coin` with value zero.
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C4`.
    ///   iv. `EZeroLpRatio`: `lp_coin` is so small it's value rounds to zero amount of the Pool's
    ///     liquidity.
    public entry fun all_coin_withdraw_4_coins<L, C1, C2, C3, C4>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,
        ctx: &mut TxContext,
    ) {
        let (coin_1, coin_2, coin_3, coin_4) = 
            withdraw::all_coin_withdraw_4_coins<L, C1, C2, C3, C4>(
                pool,
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                    ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_1, sender);
        transfer::public_transfer(coin_2, sender);
        transfer::public_transfer(coin_3, sender);
        transfer::public_transfer(coin_4, sender);
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C5>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. Protocol fees are charged on the Coin's being withdrawn.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 5.
    ///   ii. `EZeroValue`: the user supplies an `lp_coin` with value zero.
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C5`.
    ///   iv. `EZeroLpRatio`: `lp_coin` is so small it's value rounds to zero amount of the Pool's
    ///     liquidity.
    public entry fun all_coin_withdraw_5_coins<L, C1, C2, C3, C4, C5>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,
        ctx: &mut TxContext,
    ) {
        let (coin_1, coin_2, coin_3, coin_4, coin_5) = 
            withdraw::all_coin_withdraw_5_coins<L, C1, C2, C3, C4, C5>(
                pool,
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                    ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_1, sender);
        transfer::public_transfer(coin_2, sender);
        transfer::public_transfer(coin_3, sender);
        transfer::public_transfer(coin_4, sender);
        transfer::public_transfer(coin_5, sender);
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C6>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. Protocol fees are charged on the Coin's being withdrawn.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 6.
    ///   ii. `EZeroValue`: the user supplies an `lp_coin` with value zero.
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C6`.
    ///   iv. `EZeroLpRatio`: `lp_coin` is so small it's value rounds to zero amount of the Pool's
    ///     liquidity.
    public entry fun all_coin_withdraw_6_coins<L, C1, C2, C3, C4, C5, C6>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,
        ctx: &mut TxContext,
    ) {
        let (coin_1, coin_2, coin_3, coin_4, coin_5, coin_6) = 
            withdraw::all_coin_withdraw_6_coins<L, C1, C2, C3, C4, C5, C6>(
                pool,
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                    ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_1, sender);
        transfer::public_transfer(coin_2, sender);
        transfer::public_transfer(coin_3, sender);
        transfer::public_transfer(coin_4, sender);
        transfer::public_transfer(coin_5, sender);
        transfer::public_transfer(coin_6, sender);
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C7>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. Protocol fees are charged on the Coin's being withdrawn.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 7.
    ///   ii. `EZeroValue`: the user supplies an `lp_coin` with value zero.
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C7`.
    ///   iv. `EZeroLpRatio`: `lp_coin` is so small it's value rounds to zero amount of the Pool's
    ///     liquidity.
    public entry fun all_coin_withdraw_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,
        ctx: &mut TxContext,
    ) {
        let (coin_1, coin_2, coin_3, coin_4, coin_5, coin_6, coin_7) = 
            withdraw::all_coin_withdraw_7_coins<L, C1, C2, C3, C4, C5, C6, C7>(
                pool,
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                    ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_1, sender);
        transfer::public_transfer(coin_2, sender);
        transfer::public_transfer(coin_3, sender);
        transfer::public_transfer(coin_4, sender);
        transfer::public_transfer(coin_5, sender);
        transfer::public_transfer(coin_6, sender);
        transfer::public_transfer(coin_7, sender);
    }

    /// Withdraw an amount of `Coin<C1>`, ..., `Coin<C8>` from `pool` equivalent to the pro-rata amount
    ///  of lp coins burned. Protocol fees are charged on the Coin's being withdrawn.
    ///
    /// Aborts:
    ///    i. `EInvalidPoolSize`: the size of the Pool isn't 8.
    ///   ii. `EZeroValue`: the user supplies an `lp_coin` with value zero.
    ///  iii. `EBadType`: `pool` doesn't contain one of the Coin types `C1`, ..., or `C8`.
    ///   iv. `EZeroLpRatio`: `lp_coin` is so small it's value rounds to zero amount of the Pool's
    ///     liquidity.
    public entry fun all_coin_withdraw_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
        pool: &mut Pool<L>,
        pool_registry: &PoolRegistry,
        protocol_fee_vault: &ProtocolFeeVault,
        treasury: &mut Treasury,
        insurance_fund: &mut InsuranceFund,
        referral_vault: &ReferralVault,
        lp_coin: Coin<L>,
        ctx: &mut TxContext,
    ) {
        let (coin_1, coin_2, coin_3, coin_4, coin_5, coin_6, coin_7, coin_8) = 
            withdraw::all_coin_withdraw_8_coins<L, C1, C2, C3, C4, C5, C6, C7, C8>(
                pool,
                pool_registry,
                protocol_fee_vault,
                treasury,
                insurance_fund,
                referral_vault,
                lp_coin,
                    ctx
        );

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_1, sender);
        transfer::public_transfer(coin_2, sender);
        transfer::public_transfer(coin_3, sender);
        transfer::public_transfer(coin_4, sender);
        transfer::public_transfer(coin_5, sender);
        transfer::public_transfer(coin_6, sender);
        transfer::public_transfer(coin_7, sender);
        transfer::public_transfer(coin_8, sender);
    }

    //**************************************************************************************************
    // Helpers
    //**************************************************************************************************

    public fun transfer_if_nonzero<C>(coin: Coin<C>, recipeint: address) {
        if (coin::value(&coin) > 0) {
            transfer::public_transfer(coin, recipeint);
        } else {
            coin::destroy_zero(coin)
        };
    }
}
