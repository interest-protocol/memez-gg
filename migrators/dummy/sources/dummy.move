module dummy::dummy;

use memez_fun::memez_fun::MemezMigrator;

// === Structs ===

public struct Witness() has drop;

// === Public Mutative Functions ===

#[allow(lint(self_transfer))]
public fun migrate<Meme, Quote>(
    migrator: MemezMigrator<Meme, Quote>,
    ctx: &mut TxContext,
) {
    let (_,meme_balance, quote_balance) = migrator.destroy(Witness());

    let sender = ctx.sender();

    transfer::public_transfer(meme_balance.into_coin(ctx), sender);
    transfer::public_transfer(quote_balance.into_coin(ctx), sender);
}