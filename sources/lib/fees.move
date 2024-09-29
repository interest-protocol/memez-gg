module memez_gg::fees;

// === Constants ===    

// 1e9
const FEE_DENOMINATOR: u64 = 1_000_000_000;

// 5%
const MAX_LIQUIDITY_FEE: u64 = 50_000_000;

// 50%
const MAX_SWAP_FEE: u64 = 500_000_000;

// 10%
const MAX_FREEZE_FEE: u64 = 100_000_000;

// 10% 
const MAX_LIQUIDITY_MANAGEMENT_FEE: u64 = 100_000_000;

// 10% 
const DEFAULT_AMDIN_FEE: u64 = 100_000_000;

// 20%
const MAX_ADMIN_FEE: u64 = 200_000_000;

// === Public Package Functions ===

public(package) fun max_liquidity_fee(): u64 {
    MAX_LIQUIDITY_FEE
}

public(package) fun max_swap_fee(): u64 {
    MAX_SWAP_FEE
}

public(package) fun max_freeze_fee(): u64 {
    MAX_FREEZE_FEE
}   

public(package) fun max_liquidity_management_fee(): u64 {
    MAX_LIQUIDITY_MANAGEMENT_FEE
}

public(package) fun default_admin_fee(): u64 {
    DEFAULT_AMDIN_FEE
}

public(package) fun max_admin_fee(): u64 {
    MAX_ADMIN_FEE
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