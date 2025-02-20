# Interest BPS

## It provides Basis Point arithmetic operations.

### It supports the following operations:

- `new`: Create a new BPS struct.
- `add`: Add two BPS structs.
- `sub`: Subtract two BPS structs.
- `mul`: Multiply a BPS struct by a scalar.
- `div`: Divide a BPS struct by a scalar.
- `calc`: Calculate the value of a BPS percentage from a total.
- `max_bps`: It returns the maximum BPS value.
- `value`: It returns the raw value of the BPS.

### Error codes

- `EOverflow`: It is raised when the BPS value is greater than the maximum BPS value (10,000).
- `EUnderflow`: It is raised when you try to subtract a BPS value from a smaller BPS value.
- `EDivideByZero`: It is raised when you try to divide by zero.

## Immutable

[The package is immutable](https://suiscan.xyz/mainnet/tx/EAaXc6j9ET2cbDt5JERBQV1A4dNzW17TENgeqtisEAwc)

## Mainnet Code

[Explorer](https://suiscan.xyz/mainnet/object/0xdd7e07fc30acb942fc757ff732d1b4db104e0aba9717133b4eac82260dcd9f18/contracts)
