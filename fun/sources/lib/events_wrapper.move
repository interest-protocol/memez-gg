// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_events_wrapper;

use sui::event::emit;

// === Structs ===

public struct Event<T: copy + drop>(T) has copy, drop;

// === Public Package Functions ===

public(package) fun emit_event<T: copy + drop>(event: T) {
    emit(Event(event));
}
