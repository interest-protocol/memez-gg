module memez_otc::errors;

// === Errors ===

const EWrongOwner: u64 = 0;

const EZeroPrice: u64 = 1;

const EZeroCoin: u64 = 2;

const EInvalidBuyAmount: u64 = 3;

const EVestedOTC: u64 = 4;

const ENormalOTC: u64 = 5;

const EDeadlinePassed: u64 = 6;

const EHasNoDeadline: u64 = 7;

const EHasDeadline: u64 = 8;

const EInvalidRecipient: u64 = 9;

const EDeadlineInPast: u64 = 10;

const ENotOwner: u64 = 11;

const EAllMemeSold: u64 = 12;

// === Public Package Functions ===

public(package) fun wrong_owner(): u64 {
    EWrongOwner
}

public(package) fun zero_price(): u64 {
    EZeroPrice
}

public(package) fun zero_coin(): u64 {
    EZeroCoin
}

public(package) fun invalid_buy_amount(): u64 {
    EInvalidBuyAmount
}

public(package) fun vested_otc(): u64 {
    EVestedOTC
}

public(package) fun normal_otc(): u64 {
    ENormalOTC
}

public(package) fun deadline_passed(): u64 {
    EDeadlinePassed
}

public(package) fun has_no_deadline(): u64 {
    EHasNoDeadline
}

public(package) fun has_deadline(): u64 {
    EHasDeadline
}

public(package) fun invalid_recipient(): u64 {
    EInvalidRecipient
}

public(package) fun deadline_in_past(): u64 {
    EDeadlineInPast
}

public(package) fun not_owner(): u64 {
    ENotOwner
}

public(package) fun all_meme_sold(): u64 {
    EAllMemeSold
}
