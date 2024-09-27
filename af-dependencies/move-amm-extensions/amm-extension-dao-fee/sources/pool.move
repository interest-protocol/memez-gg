// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: pool
module amm_extension_dao_fee::pool {
    use amm_extension_dao_fee::version::init_package_version;
    use amm_extension_dao_fee::events;

    use amm::pool::Pool;

    use sui::dynamic_object_field::{Self as dof};
    use sui::transfer::public_transfer;
    use sui::coin::Coin;
    use sui::package;

    use fun sui::object::new as TxContext.new;
    use fun dof::borrow_mut as UID.borrow_mut;
    use fun dof::borrow as UID.borrow;
    use fun dof::add as UID.add;

    //**************************************************************************************************//
    // Constants                                                                                        //
    //**************************************************************************************************//

    const ONE_HUNDRED_PERCENT_BPS: u128 = 10_000;

    //**************************************************************************************************//
    // Package Init                                                                                     //
    //**************************************************************************************************//

    public struct POOL has drop {}

    fun init(witness: POOL, ctx: &mut TxContext) {
        let publisher = ctx.sender();

        // i. Create the singleton `Version` object.
        init_package_version(&witness, ctx);

        // ii. Give the publisher the `Publisher` object;
        public_transfer(
            package::claim(witness, ctx),
            publisher
        );
    }

    //**************************************************************************************************//
    // Pool                                                                                             //
    //**************************************************************************************************//

    public struct PoolKey has copy, drop, store {}

    public struct OwnerCap<phantom L> has key, store {
        id: UID
    }

    /// Extension of an Aftermath AMM pool that enforces a custom fee (configured through the pool's 
    ///  `fee_bps` field) on all pool actions (swap, deposit, withdraw).
    public struct DaoFeePool<phantom L> has key, store {
        /// Each `DaoFeePool` contains the underlying `Pool` object as a dynamic object field. This dof
        ///  is keyed by a `PoolKey` object; e.g. `PoolKey` -> `Pool`
        
        id: UID,
        /// The ID of the underlying Aftermath `Pool`.
        pool_id: ID,

        /// Amount of fee to take in basis points.
        fee_bps: u16,
        /// Address to send the dao fee too. Can correspond to a normal user, multisig or object address.
        fee_recipient: address,
    }

    //******************************************* Constructor ******************************************//

    // IMPORTANT: Shared objects cannot be added as dynamic fields or dynamic object fields, thus this
    //  function can only be called on a `Pool` object that has not yet been shared; e.g. post creation
    //  pre sharing.
    //
    /// Creates a `DaoFeePool` and store the underlying Aftermath `Pool` as a dof on the created
    ///  `DaoFeePool`. Also creates and returns the pool's `OwnerCap`.
    public fun new<L>(
        pool: Pool<L>,
        fee_bps: u16,
        fee_recipient: address,
        ctx: &mut TxContext
    ): (DaoFeePool<L>, OwnerCap<L>) {
        // ia. Create the `DaoFeePool`.
        let mut dao_fee_pool = DaoFeePool {
            id: ctx.new(),
            pool_id: object::id(&pool),
            fee_bps,
            fee_recipient
        };

        // ib. Store the `Pool` as a dynamic object field on the `DaoFeePool`.
        dao_fee_pool.id.add(PoolKey {}, pool);

        // ii. Create the `DaoFeePool`'s corresponding `OwnerCap`.
        let owner_cap = OwnerCap {
            id: ctx.new()
        };

        events::emit_created_pool_event(
            dao_fee_pool.id.to_inner(),
            dao_fee_pool.pool_id,
            fee_bps,
            fee_recipient
        );

        (dao_fee_pool, owner_cap)
    }

    //********************************************* Getters ********************************************//

    public fun fee_bps<L>(dao_fee_pool: &DaoFeePool<L>): u16 {
        dao_fee_pool.fee_bps
    }

    public fun fee_recipient<L>(dao_fee_pool: &DaoFeePool<L>): address {
        dao_fee_pool.fee_recipient
    }

    public(package) fun borrow_pool<L>(dao_fee_pool: &DaoFeePool<L>): &Pool<L> {
        dao_fee_pool.id.borrow(PoolKey {})
    }

    public(package) fun borrow_mut_pool<L>(dao_fee_pool: &mut DaoFeePool<L>): &mut Pool<L> {
        dao_fee_pool.id.borrow_mut(PoolKey {})
    }

    //**************************************************************************************************//
    // Internal Functions                                                                               //
    //**************************************************************************************************//

    /// Calculate the amount of `coin_in` that is reserved for DAO fee. 
    public(package) fun calculate_dao_fee<L, T>(
        dao_fee_pool: &DaoFeePool<L>,
        coin_in: &Coin<T>
    ): u64 {
            (((coin_in.value() as u128) * (dao_fee_pool.fee_bps as u128)) /
        // -----------------------------------------------------------------
                        ONE_HUNDRED_PERCENT_BPS as u64)
    }

    /// Take the DAO fee from `coin_in` and transfer it to the DAO-fee-recipient's address.
    public(package) fun collect_dao_fee<L, T>(
        dao_fee_pool: &DaoFeePool<L>,
        coin_in: &mut Coin<T>,
        ctx: &mut TxContext
    ) {
        let dao_fee = dao_fee_pool.calculate_dao_fee(coin_in);

        if (dao_fee != 0)
            public_transfer(
                coin_in.split(dao_fee, ctx),
                dao_fee_pool.fee_recipient
            );
    }

    //**************************************************************************************************//
    // Permissioned Functions                                                                           //
    //**************************************************************************************************//

    /// Update the fee that the `DaoFeePool` takes on all actions.
    /// 
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    public fun update_fee_bps<L>(
        _: &OwnerCap<L>,
        dao_fee_pool: &mut DaoFeePool<L>,
        new_fee_bps: u16
    ) {
        events::emit_updated_fee_bps_event(
            dao_fee_pool.id.to_inner(),
            dao_fee_pool.fee_bps,
            new_fee_bps
        );

        dao_fee_pool.fee_bps = new_fee_bps
    }

    /// Update the recipient of the fee that the `DaoFeePool` takes on all actions.
    /// 
    /// Aborts:
    ///   i. [amm_extension_dao_fee::version::EInvalidVersion]
    public fun update_fee_recipient<L>(
        _: &OwnerCap<L>,
        dao_fee_pool: &mut DaoFeePool<L>,
        new_fee_recipient: address
    ) {
        events::emit_updated_fee_recipient_event(
            dao_fee_pool.id.to_inner(),
            dao_fee_pool.fee_recipient,
            new_fee_recipient
        );

        dao_fee_pool.fee_recipient = new_fee_recipient
    }
}