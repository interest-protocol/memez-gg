module memez_router::memez_router;

use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::{
    memez_allowed_versions::AllowedVersions,
    memez_fun::MemezFun,
    memez_pump::{Self, Pump}
};
use memez_wallet::memez_wallet::MemezWalletRegistry;
use sui::coin::Coin;

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
        get_wallet(registry, referrer, ctx),
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
        get_wallet(registry, referrer, ctx),
        min_amount_out,
        allowed_versions,
        ctx,
    )
}

// === Private ===

fun get_wallet(
    registry: &mut MemezWalletRegistry,
    referrer: Option<address>,
    ctx: &mut TxContext,
): Option<address> {
    if (referrer.is_none()) {
        referrer
    } else {
        let referrer = referrer.destroy_some();

        let referrer_wallet = registry.wallet_address(referrer);

        if (referrer_wallet.is_some()) {
            referrer_wallet
        } else {
            let wallet = registry.new(referrer, ctx);

            let wallet_address = object::id_address(&wallet);

            wallet.share();

            option::some(wallet_address)
        }
    }
}
