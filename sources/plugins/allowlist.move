module memez_gg::allowlist;
// === Imports ===

use sui::{
    dynamic_field as df,
    vec_set::{Self, VecSet},
};

// === Structs ===

public struct AllowlistKey() has store, copy, drop;

public struct Allowlist has store {
    inner: VecSet<address>
}

// === Public Package Functions ===

public(package) fun is_allowed(id: &UID, sender: address): bool {
    if (!supports(id)) return true;

    let allowlist = allowlist(id);
    allowlist.inner.contains(&sender)
}

public(package) fun supports(id: &UID): bool {
    df::exists_(id, AllowlistKey())
}

public(package) fun new(id: &mut UID) {
    let allowlist = Allowlist {
        inner: vec_set::empty()
    };

    df::add(id, AllowlistKey(), allowlist);
}

public(package) fun contains(id: &UID, sender: address): bool {
    if (!supports(id)) return false; 

    let allowlist = allowlist(id);
    allowlist.inner.contains(&sender)
}

public(package) fun add(id: &mut UID, sender: address) {
    let allowlist = allowlist_mut(id);

    if (!allowlist.inner.contains(&sender))
        allowlist.inner.insert(sender);
}

public(package) fun remove(id: &mut UID, sender: address) {
    let allowlist = allowlist_mut(id);

    if (allowlist.inner.contains(&sender))
        allowlist.inner.remove(&sender);

}

public(package) fun delete(id: &mut UID) {

    let Allowlist { .. } = df::remove(id, AllowlistKey());
}

// === Private Functions === 

fun allowlist(id: &UID): &Allowlist {
    df::borrow(id, AllowlistKey())
}

fun allowlist_mut(id: &mut UID): &mut Allowlist {
    df::borrow_mut(id, AllowlistKey())
}