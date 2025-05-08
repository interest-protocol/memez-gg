# Interest Access Control

Access Control is a simple library to manage access control for your package. It allows the creation of admins with custom roles.

## Overview

The package resolves around three objects:

-   **ACL:** It is intended to be a shared object that registers the current list of admins and their roles.
-   **SuperAdmin:** It is a key only object with the capability to create and add/remove admins from the `ACL` object.
-   **Admin:** It is an object that can issue an AdminWitness used to gate admin functions. Admins can have roles.

`SuperAdmin` has the highest authority in the system, it should be kept safe under a multisig or under a `DAO` if possible. Admins issue a [Witness](https://move-book.com/programmability/witness-pattern.html?highlight=witness#pattern-witness) to prove their capability rights.

The `SuperAdmin` is a key only object that can only be transferred via a two-step function with a delay in between to allow users to adjust before ownership is transferred.

Functions can be admin gated by accepting a reference of an `AdminWitness` in their arguments.

## Modules

-   access_control: It has the core logic of the package.
-   errors: It has all the error codes thrown by the package.
-   events: it has all the event structs.
-   access_control_tests: It has unit tests for the access_control module.

## Installing

### [Move Registry CLI](https://docs.suins.io/move-registry)

```bash
# testnet
mvr add @interest/acl --network testnet

# mainnet
mvr add @interest/acl --network mainnet
```

### Manual

To add this library to your project, add this to your `Move.toml`.

```toml
# goes into [dependencies] section
interest_access_control = { r.mvr = "@interest/acl" }

# add this section to your Move.toml
[r.mvr]
network = "mainnet"
```

### Package Ids

Access control is an **immutable package** for security reasons. The UpgradeCap has been deleted in this [transaction](https://suiscan.xyz/mainnet/tx/J3f3TcYTi41jAYwo2cvVAHgqpRYxdetZXqvAUv18fixq).

It is deployed on Sui Network mainnet at: [0xb877fe150db8e9af55c399b4e49ba8afe658bd05317cb378c940344851125e9a](https://suiscan.xyz/mainnet/object/0xb877fe150db8e9af55c399b4e49ba8afe658bd05317cb378c940344851125e9a/tx-blocks)

It is deployed on Sui Network testnet at: [0x32ffaa298a6d6528864bf2b32acfcb7976a95e26dcc24e40e2535c0551b9d68a](https://suiscan.xyz/testnet/object/0x32ffaa298a6d6528864bf2b32acfcb7976a95e26dcc24e40e2535c0551b9d68a/tx-blocks)

### How to use

In your code, import and use the package as:

```move
module my::awesome_project;

use interest_access_control::access_control::{Self, AdminWitness};

const MINT_ROLE: u8 = 0;

public struct AWESOME_PROJECT() has drop;

fun init(otw: AWESOME_PROJECT, ctx: &mut TxContext) {
    let acl = access_control::default<AWESOME_PROJECT>(&otw, ctx);
}

/// Admin only Function
public fun only_admin(admin_witness: &AdminWitness<AWESOME_PROJECT>) {
    /// ... admin ops
}

/// Admin only Function With Mint Role
public fun only_mint_admin(admin_witness: &AdminWitness<AWESOME_PROJECT>) {
    admin_witness.assert_has_role(MINT_ROLE);
    /// ... admin ops
}
```

ACL objects require a `One Time Witness` for security reasons. You can read more about OTWs [here](https://move-book.com/programmability/witness-pattern.html?highlight=one%20time#one-time-witness).

## API Reference

**new:** It creates a `ACL`and `SuperAdmin`. The SuperAdmin is sent to the `super_admin_recipient`. The `delay` is the number of epochs that must pass before the SuperAdmin can be `transferred`.

```move
public fun new<T: drop>(
    otw: &T,
    delay: u64,
    super_admin_recipient: address,
    ctx: &mut TxContext,
): ACL<T>
```

**default:** It calls `new` with default arguments. The delay is set to 3 epochs and the `SuperAdmin` is sent to the `ctx.sender`.

```move
public  fun  default<T: drop>(otw: &T, ctx: &mut TxContext): ACL<T>
```

**new_admin:** It allows the `SuperAdmin` to create an `Admin`.

```move
public  fun  new_admin<T: drop>(acl: &mut ACL<T>, _: &SuperAdmin<T>, ctx: &mut TxContext): Admin<T>
```

**add_role:** It allows the `SuperAdmin` to create a role for an `Admin` using its address.

```move
public  fun  add_role<T: drop>(acl: &mut ACL<T>, _: &SuperAdmin<T>, admin: address, role: u8)
```

**remove_role:** It allows the `SuperAdmin` to remove a role from an `Admin` using its address.

```move
public  fun  remove_role<T: drop>(acl: &mut ACL<T>, _: &SuperAdmin<T>, admin: address, role: u8)
```

**revoke:** It allows the `SuperAdmin` to remove a an `Admin`. This operation removes an `Admin` from the `ACL` shared object. It will prevent the removed `Admin` from issuing an `AdminWitness`.

```move
public  fun  revoke<T: drop>(acl: &mut ACL<T>, _: &SuperAdmin<T>, to_revoke: address)
```

**sign_in:** It allows an `Admin` to prove its access rights by issuing an `AdminWitness` with its roles.

```move
public  fun  sign_in<T: drop>(acl: &ACL<T>, admin: &Admin<T>): AdminWitness<T>
```

**destroy_admin:** It allows an `Admin` to revoke its rights and delete the object for a Sui rebate.

```move
public  fun  destroy_admin<T: drop>(acl: &mut ACL<T>, admin: Admin<T>)
```

**destroy_super_admin:** It allows a `SuperAdmin` to revoke its rights and delete the object for a Sui rebate. **Please note, this is irreversible.**

```move
public  fun  destroy_super_admin<T: drop>(super_admin: SuperAdmin<T>)
```

**start_transfer:** It initiates the SuperAdmin transfer process.

```move
public fun start_transfer<T: drop>(
    super_admin: &mut SuperAdmin<T>,
    new_super_admin: address,
    ctx: &mut TxContext,
)
```

**finish_transfer:** It transfers the `SuperAdmin` to the recipient set at `start_transfer`. It can only be called after the `delay` period.

```move
public  fun  finish_transfer<T: drop>(mut super_admin: SuperAdmin<T>, ctx: &mut TxContext)
```

**assert_has_role:** It asserts that an `AdminWitness` has a `role`.

```move
public  fun  assert_has_role<T: drop>(witness: &AdminWitness<T>, role: u8)
```

**admin_address:** Returns the address of the `Admin`.

```move
public  fun  admin_address<T: drop>(admin: &Admin<T>): address
```

**is_admin:** Checks if the address is an `Admin`.

```move
public  fun  is_admin<T: drop>(acl: &ACL<T>, admin: address): bool
```

**has_role:** Checks if the address is an `Admin` has the `role`.

```move
public  fun  has_role<T: drop>(acl: &ACL<T>, admin: address, role: u8): bool
```

**permissions:** Returns all the roles of an `Admin`. It is tracked via bit map.

```move
public  fun  permissions<T: drop>(acl: &ACL<T>, admin: address): Option<u128>
```

## Errors

Errors are encoded in u64 .

| Error code | Reason                                                                                                                |
| ---------- | --------------------------------------------------------------------------------------------------------------------- |
| 0          | The new function was called without a `One Time Witness`. It is to make sure it can only be called in init functions. |
| 1          | `finish_transfer` was called before the delay has passed.                                                             |
| 2          | The `Admin` is not listed in the `ACL`.                                                                               |
| 3          | Caller tried to start the `SuperAdmin` transfer to the dead address or to himself/herself.                            |
| 4          | The maximum allowed role is 127u8.                                                                                    |
| 5          | The `Admin` does not have a specific role.                                                                            |

## Tags

### testnet/acl-v1.0.1 - Adds testnet package

-   Updates the Move.lock with testnet information.

### mainnet/acl-v1.0.1 - Adds Move.lock

-   adds Move.lock to keep track of deployments and versions.

### mainnet/acl-v1 - Initial package code

Adds the following modules:

-   `access_control.move` - access control logic
-   `errors.move` - error codes thrown by the package
-   `events.move` - events emitted by the package

## Disclaimer

This is provided on an "as is" and "as available" basis.

We do not give any warranties and will not be liable for any loss incurred through any use of this codebase.

While Interest Access Control has been heavily tested, there may be parts that may exhibit unexpected emergent behavior when used with other code, or may break in future Move versions.

Please always include your own thorough tests when using Interest Access Control to make sure it works correctly with your code.

## License

This package is licensed under Apache-2.0.