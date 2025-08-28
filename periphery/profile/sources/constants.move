#[allow(unused_const)]
module blast_profile::blast_profile_constants;

#[test_only]
const MAX_COINS_PER_EPOCH: u64 = 100;

#[test_only]
const CONFIG_METADATA_KEY: vector<u8> = b"config_key";

#[test_only]
const PACKAGE_VERSION: u64 = 1;

public(package) macro fun max_coins_per_epoch(): u64 {
    100
}

public(package) macro fun config_key_field(): vector<u8> {
    b"config_key"
}

public(package) macro fun package_version(): u64 {
    1
}

public(package) macro fun config_key_value(): vector<u8> {
    b"0x5afcb4c691bd3af2eb5de4c416b2ed501e843e81209f83ce6928bc3a10d0205c::xpump::ConfigKey"
}
