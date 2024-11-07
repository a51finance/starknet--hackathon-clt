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

#[derive(Copy, Drop, Serde, Hash, starknet::Store)]
struct Account {
    fee0: u256,
    fee1: u256,
    balance0: u256,
    balance1: u256,
    total_shares: u256,
    jediswap_liquidity: u128,
    fee_growth_inside0_last_x128: u256,
    fee_growth_inside1_last_x128: u256,
    fee_growth_outside0_last_x128: u256,
    fee_growth_outside1_last_x128: u256,
}

#[derive(Drop, Serde)]
struct PositionActions {
    mode: u256,
    exit_strategy: Array<StrategyPayload>, // Array of exit strategies
    rebase_strategy: Array<StrategyPayload>, // Array of rebase strategies
    liquidity_distribution: Array<StrategyPayload> // Array of liquidity distribution strategies
}

#[derive(Copy, Drop, Serde, Hash, starknet::Store)]
struct StrategyData {
    key: StrategyKey,
    owner: ContractAddress,
    actions: felt252,
    action_status: felt252,
    is_compound: bool,
    is_private: bool,
    management_fee: u256,
    performance_fee: u256,
    account: Account,
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
    use super::{StrategyKey, StrategyPayload, PositionActions, Account};

    // Poseidon hashing
    use core::poseidon::poseidon_hash_span;

    // Starknet imports
    use starknet::{
        contract_address::ContractAddress, ClassHash, get_caller_address, get_contract_address,
        get_block_timestamp, get_block_number, syscalls::keccak_syscall,
    };

    // OpenZeppelin imports for ERC20 handling
    use openzeppelin::token::erc20::{
        ERC20Component, ERC20ABIDispatcher, interface::{ERC20ABIDispatcherTrait, IERC20Metadata},
    };

    // Jediswap core imports
    use jediswap_v2_core::{
        jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait},
    };

    #[derive(Copy, Drop, Serde, Hash, starknet::Store)]
    struct StrategyData {
        key: StrategyKey,
        owner: ContractAddress,
        actions: felt252,
        action_status: felt252,
        is_compound: bool,
        is_private: bool,
        management_fee: u256,
        performance_fee: u256,
        account: Account,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress, // Owner address for administrative functions
        _shares_Id: u256,
        governance_fee_handler_address: ContractAddress,
        strategies: LegacyMap<felt252, StrategyData>,
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    // EVENTS
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StrategyCreated: StrategyCreated
    }

    #[derive(Drop, starknet::Event)]
    struct StrategyCreated {
        #[key] // Mark this as an indexed field, similar to `indexed` in Solidity
        strategy_id: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress,) {
        self.owner.write(owner); // Set the owner during contract deployment
        self._shares_Id.write(1);
    }

    fn generate_strategy_id(ref self: ContractState) -> felt252 {
        let caller = get_caller_address();

        let current_id = self._shares_Id.read();
        let new_id = current_id + 1;
        self._shares_Id.write(new_id);

        let mut strategyIDHash = array![];

        Serde::serialize(@caller, ref strategyIDHash);
        Serde::serialize(@get_block_number(), ref strategyIDHash);
        Serde::serialize(@get_block_timestamp(), ref strategyIDHash);

        // encoding the hash
        let strategy_id = poseidon_hash_span(strategyIDHash.span());
        strategy_id
    }

    // Create Strategy 
    fn create_strategy(
        ref self: ContractState,
        key: StrategyKey,
        actions: PositionActions,
        management_fee: u256,
        performance_fee: u256,
        is_compound: bool,
        is_private: bool
    ) {
        let sender_address = get_caller_address();

        let mut position_action_hash = array![];
        Serde::serialize(@actions, ref position_action_hash);
        let hashed_position_action = poseidon_hash_span(position_action_hash.span());

        let strategy_id = generate_strategy_id(ref self);

        let strategy_data = StrategyData {
            key,
            owner: sender_address,
            actions: hashed_position_action,
            action_status: '',
            is_compound,
            is_private,
            management_fee,
            performance_fee,
            account: Account {
                fee0: 0.into(),
                fee1: 0.into(),
                balance0: 0.into(),
                balance1: 0.into(),
                total_shares: 0.into(),
                jediswap_liquidity: 0,
                fee_growth_inside0_last_x128: 0.into(),
                fee_growth_inside1_last_x128: 0.into(),
                fee_growth_outside0_last_x128: 0.into(),
                fee_growth_outside1_last_x128: 0.into(),
            },
        };
        self.strategies.write(strategy_id, strategy_data);

        // add governance handler

        self.emit(StrategyCreated { strategy_id });
    }
}
