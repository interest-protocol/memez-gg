module memez_router::memez_router;

use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};
use memez_fun::{
    memez_allowed_versions::AllowedVersions,
    memez_config::MemezConfig,
    memez_fun::MemezFun,
    memez_metadata::MemezMetadata,
    memez_pump::{Self, Pump},
    memez_pump_config::PumpConfig
};
use memez_wallet::memez_wallet::MemezWalletRegistry;
use sui::{coin::{Coin, TreasuryCap}, sui::SUI};

/// @dev Only works with Blast Config because it expects a dynamic stake holder
public fun new_with_developer_stake_holder<Meme, Quote, ConfigKey, MigrationWitness>(
    registry: &mut MemezWalletRegistry,
    config: &MemezConfig,
    meme_treasury_cap: TreasuryCap<Meme>,
    creation_fee: Coin<SUI>,
    pump_config: PumpConfig,
    first_purchase: Coin<Quote>,
    metadata: MemezMetadata,
    is_protected: bool,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): (MemezFun<Pump, Meme, Quote>, MetadataCap) {
    let sender = ctx.sender();

    let memez_wallet = get_wallet(registry, sender, ctx);

    memez_pump::new<Meme, Quote, ConfigKey, MigrationWitness>(
        config,
        meme_treasury_cap,
        creation_fee,
        pump_config,
        first_purchase,
        metadata,
        vector[memez_wallet.destroy_some()],
        is_protected,
        sender,
        allowed_versions,
        ctx,
    )
}

public fun pump<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    registry: &mut MemezWalletRegistry,
    quote_coin: Coin<Quote>,
    referrer: Option<address>,
    signature: Option<vector<u8>>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Meme> {
    memez_pump::pump(
        self,
        quote_coin,
        get_referrer_wallet(registry, referrer, ctx),
        signature,
        min_amount_out,
        allowed_versions,
        ctx,
    )
}

public fun dump<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    registry: &mut MemezWalletRegistry,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_coin: Coin<Meme>,
    referrer: Option<address>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    memez_pump::dump(
        self,
        treasury_cap,
        meme_coin,
        get_referrer_wallet(registry, referrer, ctx),
        min_amount_out,
        allowed_versions,
        ctx,
    )
}

// === Private ===

fun get_referrer_wallet(
    registry: &mut MemezWalletRegistry,
    referrer: Option<address>,
    ctx: &mut TxContext,
): Option<address> {
    if (referrer.is_none()) {
        referrer
    } else {
        get_wallet(registry, referrer.destroy_some(), ctx)
    }
}

fun get_wallet(
    registry: &mut MemezWalletRegistry,
    user_address: address,
    ctx: &mut TxContext,
): Option<address> {
    let user_wallet = registry.wallet_address(user_address);

    if (user_wallet.is_some()) {
        user_wallet
    } else {
        let wallet = registry.new(user_address, ctx);

        let wallet_address = object::id_address(&wallet);

        wallet.share();

        option::some(wallet_address)
    }
}
