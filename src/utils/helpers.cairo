mod HelperFunctions {
    fn u256_to_u128(value: u256) -> Result<u128, felt252> {
        if value.high == 0 {
            // If the high part is 0, the value can fit in a u128
            Result::Ok(value.low.try_into().unwrap())
        } else {
            // If the high part is not 0, the value is too large for u128
            Result::Err('Value too large for u128')
        }
    }
}
