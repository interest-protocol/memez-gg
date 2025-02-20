module constant_product::constant_product;

// === Errors ===

#[error]
const ENoZeroCoin: vector<u8> = b"You cannot swap 0 coins";

#[error]
const EInsufficientLiquidity: vector<u8> = b"Insufficient liquidity";

// === Public-View Functions ===

public fun k(x: u64, y: u64): u256 {
    (x as u256) * (y as u256)
}

public fun get_amount_in(coin_out_amount: u64, balance_in: u64, balance_out: u64): u64 {
    assert!(coin_out_amount != 0, ENoZeroCoin);
    assert!(balance_in != 0 && balance_out != 0 && balance_out > coin_out_amount, EInsufficientLiquidity);

    let (coin_out_amount, balance_in, balance_out) = (
        (coin_out_amount as u256),
        (balance_in as u256),
        (balance_out as u256)
    );

    let numerator = balance_in * coin_out_amount;
    let denominator = balance_out - coin_out_amount; 

    ((if (numerator == 0) 0 else 1 + (numerator - 1) / denominator) as u64)
}

public fun get_amount_out(coin_in_amount: u64, balance_in: u64, balance_out: u64): u64 {
    assert!(coin_in_amount != 0, ENoZeroCoin);
    assert!(balance_in != 0 && balance_out != 0, EInsufficientLiquidity);

    let (coin_in_amount, balance_in, balance_out) = (
        (coin_in_amount as u256),
        (balance_in as u256),
        (balance_out as u256)
    );

    let numerator = balance_out * coin_in_amount;
    let denominator = balance_in + coin_in_amount; 

    ((numerator / denominator) as u64) 
}