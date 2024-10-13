module memez_dex::utils; 
// === Imports ===

use std::type_name;

use sui::sui::SUI;

// === Public Functions ===

public(package) fun is_sui<CoinType>(): bool{
    type_name::get<CoinType>() == type_name::get<SUI>()
}