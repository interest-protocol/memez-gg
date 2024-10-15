module memez_launch::launch_lock;
// === Imports === 

use std::{
    ascii,
    string,
    type_name::{Self, TypeName}
};

use sui::{
    vec_map::{Self, VecMap},
    dynamic_object_field as dof,
    coin::{TreasuryCap, CoinMetadata},
};

// === Errors === 

#[error] 
const EInvalidEpoch: vector<u8> = b"The epoch cannot be in the past.";

#[error]
const EPositionLocked: vector<u8> = b"The position is still locked.";

// === Structs === 

public struct TreasuryKey has store, copy, drop(TypeName)

public struct PositionKey has store, copy, drop(address)

public struct LaunchLock has key, store {
    id: UID,
    unlock_epoch: VecMap<address, u64>,
}

// === Public Mutative === 

public fun new(ctx: &mut TxContext): LaunchLock {
    LaunchLock {
        id: object::new(ctx), 
        unlock_epoch: vec_map::empty(), 
    }
}

public fun lock_treasury_cap<CoinType>(self: &mut LaunchLock, cap: TreasuryCap<CoinType>) {
    let key = TreasuryKey(type_name::get<CoinType>());

    dof::add(&mut self.id, key, cap);
}

public fun update_name<T>(
    self: &LaunchLock, 
    metadata: &mut CoinMetadata<T>, 
    name: string::String
) {
   let cap = dof::borrow<TreasuryKey ,TreasuryCap<T>>(&self.id, TreasuryKey(type_name::get<T>()));

   cap.update_name(metadata, name);
}

public fun update_symbol<T>(
    self: &LaunchLock, 
    metadata: &mut CoinMetadata<T>, 
    symbol: ascii::String
) {
   let cap = dof::borrow<TreasuryKey ,TreasuryCap<T>>(&self.id, TreasuryKey(type_name::get<T>()));

   cap.update_symbol(metadata, symbol);
}

public fun update_description<T>(
    self: &LaunchLock, 
    metadata: &mut CoinMetadata<T>, 
    description: string::String
) {
    let cap = dof::borrow<TreasuryKey ,TreasuryCap<T>>(&self.id, TreasuryKey(type_name::get<T>()));

    cap.update_description(metadata, description);
}

public fun update_icon_url<T>(
    self: &LaunchLock, 
    metadata: &mut CoinMetadata<T>, 
    url: ascii::String
) {
    let cap = dof::borrow<TreasuryKey ,TreasuryCap<T>>(&self.id, TreasuryKey(type_name::get<T>()));

    cap.update_icon_url(metadata, url);
}

// === Public Package Functions ===  

public(package) fun lock_position<T: key + store>( 
    self: &mut LaunchLock, 
    position: T, 
    unlock_epoch: u64,
    ctx: &TxContext
) {
    assert!(unlock_epoch > ctx.epoch(), EInvalidEpoch);

    let position_address = object::id(&position).to_address();
    
    let key  = PositionKey(position_address);

    self.unlock_epoch.insert(position_address, unlock_epoch);

    dof::add(&mut self.id, key, position);
}

public(package) fun unlock_position<T: key + store>(self: &mut LaunchLock, position_address: address, ctx: &TxContext): T {
    let (_, unlock_epoch) = self.unlock_epoch.remove(&position_address);

    assert!(unlock_epoch > ctx.epoch(), EPositionLocked);
    
    dof::remove(&mut self.id, PositionKey(position_address))
}

public(package) fun position_borrow<T: key + store>(self: &LaunchLock, position_address: address): &T {
    dof::borrow(&self.id, PositionKey(position_address))
}


public(package) fun position_borrow_mut<T: key + store>(self: &mut LaunchLock, position_address: address): &mut T {
    dof::borrow_mut(&mut self.id, PositionKey(position_address))
}
