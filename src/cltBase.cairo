// SPDX-License-Identifier: BUSL-1.1
// A51 Finance
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Hash, starknet::Store)]
struct StrategyKey {
    pool: ContractAddress,
    tick_lower: i32,
    tick_upper: i32,
}

#[derive(Drop, Serde)]
struct StrategyPayload {
    action_name: felt252, // Equivalent to bytes32 in Solidity
    data: Array<felt252>, // Equivalent to bytes in Solidity
}

// Interfaces

#[starknet::interface]
trait ICLTBase<TContractState> {
    fn create_strategy(
        ref self: TContractState,
        key: StrategyKey,
        actions: PositionActions,
        management_fee: u256,
        performance_fee: u256,
        is_compound: bool,
        is_private: bool
    );
}

// Base Contract
#[starknet::contract]
mod cltBase {
    use super::{StrategyKey, StrategyPayload};
    // OpenZeppelin imports for ERC20 handling
    use openzeppelin::token::erc20::{
        ERC20Component, ERC20ABIDispatcher, interface::{ERC20ABIDispatcherTrait, IERC20Metadata},
    };

    // Jediswap core imports
    use jediswap_v2_core::{
        jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait},
    };

    // EVENTS
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StrategyCreated: StrategyCreated
    }
}
