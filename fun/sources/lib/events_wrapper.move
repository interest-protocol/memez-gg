module memez_fun::memez_events_wrapper;

use sui::event::emit;

// === Structs ===

public struct Event<T: copy + drop> has copy, drop (T)

// === Public Package Functions ===

public(package) fun emit_event<T: copy + drop>(event: T) {
    emit(Event(event));
}
