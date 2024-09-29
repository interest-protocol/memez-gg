module memez_gg::fees;

// === Constants ===    

const FEE_DENOMINATOR: u64 = 1__000_000_000;

const FIVE_PERCENT: u64 = { FEE_DENOMINATOR / 20 };

const TEN_PERCENT: u64 = { FEE_DENOMINATOR / 10 };

const TWENTY_PERCENT: u64 = { FEE_DENOMINATOR / 5 };

const FIFTY_PERCENT: u64 = { FEE_DENOMINATOR / 2 };

// === Public Package Functions ===

public(package) fun five_percent(): u64 {
    FIVE_PERCENT
}

public(package) fun ten_percent(): u64 {
    TEN_PERCENT
}   

public(package) fun twenty_percent(): u64 {
    TWENTY_PERCENT
}

public(package) fun fifty_percent(): u64 {
    FIFTY_PERCENT
}

public(package) fun calculate(x: u64, y: u64): u64 {
    mul_div_up(x, y, FEE_DENOMINATOR)
}

// === Private Functions ===

fun mul_div_up(x: u64, y: u64, z: u64): u64 {
    let (x, y, z) = (x as u256, y as u256, z as u256);
    let r = x * y / z;
    ((r + if ((x * y) % z > 0) 1 else 0) as u64)
}