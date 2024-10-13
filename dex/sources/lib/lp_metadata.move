module memez_dex::lp_metadata; 
// === Imports ===

use std::{
    ascii,
    string
};

// === Package Functions ===

public(package) fun icon_url(): vector<u8> {
    b""
}

public(package) fun name(meme_name: string::String): vector<u8> {

    let mut name = b"Memez LP Sui/".to_string(); 

    name.append(meme_name);
    
    name.into_bytes()
}

public(package) fun symbol(meme_symbol: ascii::String): vector<u8> {
    let mut symbol = b"Memez LP Sui/".to_string(); 

    symbol.append(meme_symbol.to_string());
    
    symbol.into_bytes()
}

public(package) fun description(): vector<u8> {
    b"Memez.gg Liquidity Provider Coin"
}