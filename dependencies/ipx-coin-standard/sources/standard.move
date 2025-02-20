module ipx_coin_standard::ipx_coin_standard;

use std::{ascii, string, type_name::{Self, TypeName}};
use sui::{coin::{TreasuryCap, CoinMetadata, Coin}, dynamic_object_field as dof, event::emit};

// === Constants ===

const MAX_U64: u64 = 18446744073709551615;

// === Errors ===

const EInvalidCap: u64 = 0;

const ECapAlreadyCreated: u64 = 1;

const ETreasuryCannotBurn: u64 = 2;

const EInvalidTreasury: u64 = 3;

const EMaximumSupplyExceeded: u64 = 4;

// === Structs ===

public struct Witness {
    ipx_treasury: address,
    name: TypeName,
    mint_cap: Option<address>,
    burn_cap: Option<address>,
    metadata_cap: Option<address>,
    maximum_supply: Option<u64>,
}

public struct MintCap has key, store {
    id: UID,
    ipx_treasury: address,
    name: TypeName,
}

public struct BurnCap has key, store {
    id: UID,
    ipx_treasury: address,
    name: TypeName,
}

public struct MetadataCap has key, store {
    id: UID,
    ipx_treasury: address,
    name: TypeName,
}

public struct IPXTreasuryStandard has key, store {
    id: UID,
    name: TypeName,
    can_burn: bool,
    maximum_supply: Option<u64>,
}

// === Events ===

public struct New has copy, drop {
    name: TypeName,
    ipx_treasury: address,
    treasury: address,
    mint_cap: Option<address>,
    burn_cap: Option<address>,
    metadata_cap: Option<address>,
}

public struct Mint(TypeName, u64) has copy, drop;

public struct Burn(TypeName, u64) has copy, drop;

public struct DestroyMintCap has copy, drop {
    ipx_treasury: address,
    name: TypeName,
}

public struct DestroyBurnCap has copy, drop {
    ipx_treasury: address,
    name: TypeName,
}

public struct DestroyMetadataCap has copy, drop {
    ipx_treasury: address,
    name: TypeName,
}

public struct UpdateName(TypeName, string::String) has copy, drop;

public struct UpdateSymbol(TypeName, ascii::String) has copy, drop;

public struct UpdateDescription(TypeName, string::String) has copy, drop;

public struct UpdateIconUrl(TypeName, ascii::String) has copy, drop;

// === Public Mutative ===

public fun new<T>(cap: TreasuryCap<T>, ctx: &mut TxContext): (IPXTreasuryStandard, Witness) {
    let name = type_name::get<T>();

    let mut ipx_treasury_standard = IPXTreasuryStandard {
        id: object::new(ctx),
        name,
        can_burn: false,
        maximum_supply: option::none(),
    };

    let ipx_treasury = ipx_treasury_standard.id.to_address();

    dof::add(&mut ipx_treasury_standard.id, name, cap);

    (
        ipx_treasury_standard,
        Witness {
            ipx_treasury,
            name,
            mint_cap: option::none(),
            burn_cap: option::none(),
            metadata_cap: option::none(),
            maximum_supply: option::none(),
        },
    )
}

public fun set_maximum_supply(witness: &mut Witness, maximum_supply: u64) {
    witness.maximum_supply = option::some(maximum_supply);
}

// === Capabilities API ===

public fun create_mint_cap(witness: &mut Witness, ctx: &mut TxContext): MintCap {
    assert!(witness.mint_cap.is_none(), ECapAlreadyCreated);

    let id = object::new(ctx);

    witness.mint_cap = option::some(id.to_address());

    MintCap {
        id,
        ipx_treasury: witness.ipx_treasury,
        name: witness.name,
    }
}

public fun create_burn_cap(witness: &mut Witness, ctx: &mut TxContext): BurnCap {
    assert!(witness.burn_cap.is_none(), ECapAlreadyCreated);

    let id = object::new(ctx);

    witness.burn_cap = option::some(id.to_address());

    BurnCap {
        id,
        ipx_treasury: witness.ipx_treasury,
        name: witness.name,
    }
}

public fun create_metadata_cap(witness: &mut Witness, ctx: &mut TxContext): MetadataCap {
    assert!(witness.metadata_cap.is_none(), ECapAlreadyCreated);

    let id = object::new(ctx);

    witness.metadata_cap = option::some(id.to_address());

    MetadataCap {
        id,
        ipx_treasury: witness.ipx_treasury,
        name: witness.name,
    }
}

public fun allow_public_burn(witness: &mut Witness, self: &mut IPXTreasuryStandard) {
    assert!(witness.burn_cap.is_none(), ECapAlreadyCreated);

    witness.burn_cap = option::some(self.id.to_address());

    self.can_burn = true;
}

#[allow(implicit_const_copy)]
public fun destroy_witness<T>(self: &mut IPXTreasuryStandard, witness: Witness) {
    let Witness {
        mint_cap,
        burn_cap,
        metadata_cap,
        ipx_treasury,
        maximum_supply,
        ..,
    } = witness;

    assert!(ipx_treasury == self.id.to_address(), EInvalidTreasury);

    let maximum_supply_value = *maximum_supply.borrow_with_default(&MAX_U64);

    let cap = dof::borrow_mut<TypeName, TreasuryCap<T>>(&mut self.id, self.name);

    assert!(maximum_supply_value >= cap.total_supply(), EMaximumSupplyExceeded);

    self.maximum_supply = maximum_supply;

    emit(New {
        name: self.name,
        treasury: object::id_address(cap),
        ipx_treasury: ipx_treasury,
        mint_cap,
        burn_cap,
        metadata_cap,
    });
}

public fun destroy_mint_cap(cap: MintCap) {
    let MintCap { id, name, ipx_treasury } = cap;

    emit(DestroyMintCap {
        ipx_treasury,
        name,
    });

    id.delete();
}

public fun destroy_burn_cap(cap: BurnCap) {
    let BurnCap { id, name, ipx_treasury } = cap;

    emit(DestroyBurnCap {
        ipx_treasury,
        name,
    });

    id.delete();
}

public fun destroy_metadata_cap(cap: MetadataCap) {
    let MetadataCap { id, name, ipx_treasury } = cap;

    emit(DestroyMetadataCap {
        ipx_treasury,
        name,
    });

    id.delete();
}

// === Mint/Burn API ===

public fun mint<T>(
    cap: &MintCap,
    self: &mut IPXTreasuryStandard,
    amount: u64,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(cap.ipx_treasury == self.id.to_address(), EInvalidCap);

    emit(Mint(self.name, amount));

    let maximum_supply = self.maximum_supply.destroy_or!(MAX_U64);

    let cap = dof::borrow_mut<TypeName, TreasuryCap<T>>(&mut self.id, self.name);

    assert!(maximum_supply >= cap.total_supply() + amount, EMaximumSupplyExceeded);

    cap.mint(amount, ctx)
}

public fun cap_burn<T>(cap: &BurnCap, self: &mut IPXTreasuryStandard, coin: Coin<T>) {
    assert!(cap.ipx_treasury == self.id.to_address(), EInvalidCap);

    emit(Burn(self.name, coin.value()));

    let cap = dof::borrow_mut<TypeName, TreasuryCap<T>>(&mut self.id, self.name);

    cap.burn(coin);
}

public fun treasury_burn<T>(self: &mut IPXTreasuryStandard, coin: Coin<T>) {
    assert!(self.can_burn, ETreasuryCannotBurn);

    emit(Burn(self.name, coin.value()));

    let cap = dof::borrow_mut<TypeName, TreasuryCap<T>>(&mut self.id, self.name);

    cap.burn(coin);
}

// === Metadata API ===

public fun update_name<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    name: string::String,
) {
    assert!(cap.ipx_treasury == self.id.to_address(), EInvalidCap);

    emit(UpdateName(self.name, name));

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_name(metadata, name);
}

public fun update_symbol<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    symbol: ascii::String,
) {
    assert!(cap.ipx_treasury == self.id.to_address(), EInvalidCap);

    emit(UpdateSymbol(self.name, symbol));

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_symbol(metadata, symbol);
}

public fun update_description<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    description: string::String,
) {
    assert!(cap.ipx_treasury == self.id.to_address(), EInvalidCap);

    emit(UpdateDescription(self.name, description));

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_description(metadata, description);
}

public fun update_icon_url<T>(
    self: &IPXTreasuryStandard,
    metadata: &mut CoinMetadata<T>,
    cap: &MetadataCap,
    url: ascii::String,
) {
    assert!(cap.ipx_treasury == self.id.to_address(), EInvalidCap);

    emit(UpdateIconUrl(self.name, url));

    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.update_icon_url(metadata, url);
}

// === Public View Functions ===

public fun total_supply<T>(self: &IPXTreasuryStandard): u64 {
    let cap = dof::borrow<TypeName, TreasuryCap<T>>(&self.id, self.name);

    cap.total_supply()
}

public fun maximum_supply(self: &IPXTreasuryStandard): Option<u64> {
    self.maximum_supply
}

public fun can_burn(self: &IPXTreasuryStandard): bool {
    self.can_burn
}

public fun mint_cap_ipx_treasury(cap: &MintCap): address {
    cap.ipx_treasury
}

public fun burn_cap_ipx_treasury(cap: &BurnCap): address {
    cap.ipx_treasury
}

public fun metadata_cap_ipx_treasury(cap: &MetadataCap): address {
    cap.ipx_treasury
}

public fun ipx_treasury_cap_name(cap: &IPXTreasuryStandard): TypeName {
    cap.name
}

public fun mint_cap_name(cap: &MintCap): TypeName {
    cap.name
}

public fun burn_cap_name(cap: &BurnCap): TypeName {
    cap.name
}

public fun metadata_cap_name(cap: &MetadataCap): TypeName {
    cap.name
}

// === Method Aliases ===

public use fun cap_burn as BurnCap.burn;
public use fun treasury_burn as IPXTreasuryStandard.burn;

public use fun mint_cap_ipx_treasury as MintCap.ipx_treasury;
public use fun burn_cap_ipx_treasury as BurnCap.ipx_treasury;
public use fun metadata_cap_ipx_treasury as MetadataCap.ipx_treasury;

public use fun ipx_treasury_cap_name as IPXTreasuryStandard.name;
public use fun mint_cap_name as MintCap.name;
public use fun burn_cap_name as BurnCap.name;
public use fun metadata_cap_name as MetadataCap.name;

public use fun destroy_mint_cap as MintCap.destroy;
public use fun destroy_burn_cap as BurnCap.destroy;
public use fun destroy_metadata_cap as MetadataCap.destroy;

// === Test Functions ===

#[test_only]
public fun mint_cap_address(witness: &Witness): Option<address> {
    witness.mint_cap
}

#[test_only]
public fun burn_cap_address(witness: &Witness): Option<address> {
    witness.burn_cap
}

#[test_only]
public fun metadata_cap_address(witness: &Witness): Option<address> {
    witness.metadata_cap
}

#[test_only]
public fun witness_name(witness: &Witness): TypeName {
    witness.name
}

#[test_only]
public fun witness_ipx_treasury(witness: &Witness): address {
    witness.ipx_treasury
}

// === Test Aliases ===

#[test_only]
public use fun witness_ipx_treasury as Witness.ipx_treasury;

#[test_only]
public use fun witness_name as Witness.name;
