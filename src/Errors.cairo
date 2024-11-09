mod Errors {
    const POOL_NOT_INITIALIZED: felt252 = 'Pool is not initialized';
    const INVALID_FEE_CAP: felt252 = 'Invalid fee cap';
    const INVALID_FEE_PERCENTAGE: felt252 = 'Invalid fee percentage';
    const INVALID_SHARE_AMOUNT: felt252 = 'Invalid share amount';
    const POSITION_LENGTH_EXCEEDS_LIMIT: felt252 = 'Position length exceeds limit';
    const INVALID_PRICE_SLIPPAGE: felt252 = 'Invalid price slippage';
    const POSITION_DOES_NOT_EXIST: felt252 = 'Position does not exist';
    const ZERO_LIQUIDITY: felt252 = 'Zero liquidity';
    const SWAP_RATE_LIMIT: felt252 = 'Swap rate limit';
    const CALLER_IS_NOT_MANAGER: felt252 = 'Caller is not manager';
    const CALLER_IS_NOT_REWARD_CLAIMER: felt252 = 'Caller is not reward claimer';
    const INVALID_CALLBACK_STATUS: felt252 = 'Invalid callback status';
    const INVALID_CALLBACK_CALLER: felt252 = 'Invalid callback caller';
    const SWAP_IN_ZERO_LIQUIDITY_REGION: felt252 = 'Swap in zero liquidity region';
    const TRANSACTION_EXPIRED: felt252 = 'Transaction expired';
    const INVALID_SWAP_TOKEN: felt252 = 'Invalid swap token';
    const INVALID_SWAP_RECEIVER: felt252 = 'Invalid swap receiver';
    const INSUFFICIENT_SWAP_RESULT: felt252 = 'Insufficient swap result';
    const INVALID_TOKEN_ORDER: felt252 = 'Invalid token order';
    const INVALID_INDEX: felt252 = 'Invalid index';
    const SET_ARRAY_FAILED: felt252 = 'Set array failed';
    const APPEND_ARRAY_FAILED: felt252 = 'Append array failed';
    const POP_ARRAY_FAILED: felt252 = 'Pop array failed';
    const UNAUTHORIZED: felt252 = 'Unauthorized access';
    const MIN_AMOUNT_EXCEEDED: felt252 = 'MinimumAmountsExceeded';
}
