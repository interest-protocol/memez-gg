module memez_gg::math64;

// === Package Functions ===

public(package) fun mul_div_up(x: u64, y: u64, z: u64): u64 {
    let r = (x as u256) * (y as u256) / (z as u256);
    ((r + if ((x * y) % z > 0) 1 else 0) as u64)
}