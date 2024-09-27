// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module lsd::validator {
	struct UnverifiedValidatorOperationCap has store, key {
		id: sui::object::UID,
		authorizer_validator_address: address
	}

	struct ValidatorOperationCap has drop {
		authorizer_validator_address: address
	}

	public fun transfer_unverified_validator_operation_cap(
		_arg0: lsd::validator::UnverifiedValidatorOperationCap,
		_arg1: address
	)
	{
		abort 0
	}
}