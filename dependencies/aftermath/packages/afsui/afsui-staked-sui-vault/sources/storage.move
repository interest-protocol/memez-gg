// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module lsd::storage {
	struct ProcessingState has store {
		is_totals_calculating: bool,
		total_sui_amount: u64,
		total_rewards_amount: u64,
		pool_id_opt: std::option::Option<sui::object::ID>,
		stake_number: u64,
		is_sorting_processing: bool,
		inactive_pools_amount: u64
	}

	struct StorageStateV1 has store, key {
		id: sui::object::UID,
		stakes: sui::linked_table::LinkedTable<sui::object::ID, sui::table_vec::TableVec<sui_system::staking_pool::StakedSui>>,
		unstaking_deque: linked_set::linked_set::LinkedSet<sui::object::ID>,
		inactive_pools_amount: u64,
		sorting_sandbox: vector<sui::object::ID>,
		sorting_keys: vector<u64>,
		processing_state: lsd::storage::ProcessingState,
		is_sandbox_sorted: bool
	}

	struct Storage has store {
		id: sui::object::UID
	}
}