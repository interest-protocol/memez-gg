module memez_fun::memez_config; 
// === Imports ===  

use sui::{
    sui::SUI,
    balance::Balance,
    coin::{Coin, CoinMetadata, TreasuryCap}, 
};

use ipx_coin_standard::ipx_coin_standard::{Self, MetadataCap};

use memez_acl::acl::AuthWitness;

// === Constants ===  

const CREATION_FEE: u64 = 2__000_000_000; 

const MIGRATION_FEE: u64 = 200__000_000_000;

const TOTAL_MEME_SUPPLY: u64 = 1_000_000_000__000_000_000;

const MEME_DECIMALS: u8 = 9;

// === Errors === 

#[error]
const ENotEnoughSuiForCreationFee: vector<u8> = b"Not enough SUI for creation fee";

#[error]
const ENotEnoughSuiForMigrationFee: vector<u8> = b"Not enough SUI for migration fee";

#[error]
const EWrongDecimals: vector<u8> = b"Wrong decimals";

#[error]
const EPreMint: vector<u8> = b"Pre-mint";

// === Structs ===  

public struct MemezConfig has key {
    id: UID, 
    creation_fee: u64,
    migration_fee: u64,
    treasury: address,
}

// === Initializer === 

fun init(ctx: &mut TxContext) {
    let config = MemezConfig {
        id: object::new(ctx),
        creation_fee: CREATION_FEE,
        migration_fee: MIGRATION_FEE,
        treasury: ctx.sender(),
    };

    transfer::share_object(config);
}

// === Public Admin Functions === 

public fun set_creation_fee(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.creation_fee = amount;
}

public fun set_migration_fee(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.migration_fee = amount;
}

public fun set_treasury(self: &mut MemezConfig, _: &AuthWitness, treasury: address) {
    self.treasury = treasury;
} 

// === Public Package Functions ===  

#[allow(lint(share_owned))]
public(package) fun set_up_treasury<Meme>(
    meme_metadata: &CoinMetadata<Meme>, 
    mut meme_treasury_cap: TreasuryCap<Meme>, 
    ctx: &mut TxContext
): (address, MetadataCap, Balance<Meme>) {
    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EWrongDecimals); 
    assert!(meme_treasury_cap.total_supply() == 0, EPreMint); 

    let meme_balance = meme_treasury_cap.mint_balance(TOTAL_MEME_SUPPLY);

    let (mut ipx_treasury_standard, mut cap_witness) = ipx_coin_standard::new(meme_treasury_cap, ctx);

    cap_witness.add_burn_capability(&mut ipx_treasury_standard);

    let treasury_address = object::id(&ipx_treasury_standard).to_address();

    transfer::public_share_object(ipx_treasury_standard);

    (treasury_address, cap_witness.create_metadata_cap(ctx), meme_balance)
}

public(package) fun uid(self: &MemezConfig): &UID {
    &self.id
}

public(package)  fun uid_mut(self: &mut MemezConfig): &mut UID {
    &mut self.id
}

public(package) fun migration_fee(self: &MemezConfig): u64 {
    self.migration_fee
}

public(package) fun take_creation_fee(self: &MemezConfig, creation_fee: Coin<SUI>) {
    assert!(creation_fee.value() >= self.creation_fee, ENotEnoughSuiForCreationFee);

    transfer::public_transfer(creation_fee, self.treasury);
}

public(package) fun take_migration_fee(self: &MemezConfig, migration_fee: Coin<SUI>) {
    assert!(migration_fee.value() >= self.migration_fee, ENotEnoughSuiForMigrationFee);

    transfer::public_transfer(migration_fee, self.treasury);
}

public(package) fun fees(self: &MemezConfig): (u64, u64) {
    (self.creation_fee, self.migration_fee)
}