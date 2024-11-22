module memez_fun::memez_token_cap;

use sui::{coin::{Coin, TreasuryCap}, token::{Self, TokenPolicyCap, Token}};

// === Structs ===

public struct MemezTokenCap<phantom Meme> has store {
    policy: address,
    cap: TokenPolicyCap<Meme>,
}

// === Public Package Functions ===

#[allow(lint(share_owned))]
public(package) fun new<Meme>(
    treasury_cap: &TreasuryCap<Meme>,
    ctx: &mut TxContext,
): MemezTokenCap<Meme> {
    let (mut policy, cap) = token::new_policy(treasury_cap, ctx);

    let policy_address = object::id_address(&policy);

    policy.allow(&cap, token::transfer_action(), ctx);

    policy.share_policy();

    MemezTokenCap {
        cap,
        policy: policy_address,
    }
}

public(package) fun from_coin<Meme>(
    self: &MemezTokenCap<Meme>,
    coin: Coin<Meme>,
    ctx: &mut TxContext,
): Token<Meme> {
    let (token, action_request) = token::from_coin(coin, ctx);

    self.cap.confirm_with_policy_cap(action_request, ctx);

    token
}

public(package) fun to_coin<Meme>(
    self: &MemezTokenCap<Meme>,
    token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    let (meme_coin, action_request) = token::to_coin(token, ctx);

    self.cap.confirm_with_policy_cap(action_request, ctx);

    meme_coin
}
