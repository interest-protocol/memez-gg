module memez_wrapper::memez_wrapper;

use ipx_coin_standard::ipx_coin_standard::MetadataCap;
use memez_fun::memez_fun::MemezFun;
use std::string::String;
use sui::{event::emit, vec_map::VecMap};

// === Structs ===

public struct Event<T: copy + drop>(T) has copy, drop;

// === Events ===

public struct UpdateMetadata has copy, drop {
    pool: address,
    metadata: VecMap<String, String>,
}

// === Public Package Functions ===

public fun update_metadata<Curve, Meme, Quote>(
    pool: &mut MemezFun<Curve, Meme, Quote>,
    metadata_cap: &MetadataCap,
    metadata: VecMap<String, String>,
) {
    pool.update_metadata(metadata_cap, metadata);

    emit(
        Event(UpdateMetadata {
            pool: object::id_address(pool),
            metadata: metadata,
        }),
    );
}
