// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module amm_extension_dao_fee::events {
    use sui::event::emit;

    //**************************************************************************************************//
    // CreatedDaoFeePoolEvent                                                                           //
    //**************************************************************************************************//

    public struct CreatedDaoFeePoolEvent has copy, drop {
        dao_fee_pool_id: ID,
        inner_pool_id: ID,
        fee_bps: u16,
        fee_recipient: address,
    }

    public(package) fun emit_created_pool_event(
        dao_fee_pool_id: ID,
        inner_pool_id: ID,
        fee_bps: u16,
        fee_recipient: address,
    ) {
        emit(CreatedDaoFeePoolEvent {
            dao_fee_pool_id,
            inner_pool_id,
            fee_bps,
            fee_recipient,
        })
    }

    //**************************************************************************************************//
    // UpdatedFeeBpsEvent                                                                               //
    //**************************************************************************************************//

    public struct UpdatedFeeBpsEvent has copy, drop {
        dao_fee_pool_id: ID,
        old_fee_bps: u16,
        new_fee_bps: u16,
    }

    public(package) fun emit_updated_fee_bps_event(
        dao_fee_pool_id: ID,
        old_fee_bps: u16,
        new_fee_bps: u16,
    ) {
        emit(UpdatedFeeBpsEvent {
            dao_fee_pool_id,
            old_fee_bps,
            new_fee_bps,
        })
    }

    //**************************************************************************************************//
    // UpdatedFeeRecipientEvent                                                                         //
    //**************************************************************************************************//

    public struct UpdatedFeeRecipientEvent has copy, drop {
        dao_fee_pool_id: ID,
        old_fee_address: address,
        new_fee_address: address,
    }

    public(package) fun emit_updated_fee_recipient_event(
        dao_fee_pool_id: ID,
        old_fee_address: address,
        new_fee_address: address,
    ) {
        emit(UpdatedFeeRecipientEvent {
            dao_fee_pool_id,
            old_fee_address,
            new_fee_address,
        })
    }
}
