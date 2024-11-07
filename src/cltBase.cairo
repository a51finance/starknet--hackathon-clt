// SPDX-License-Identifier: BUSL-1.1
// A51 Finance
use starknet::ContractAddress;

use cltbase::interfaces::IcltBase::CLTInterfaces::{
    ICLTBase, StrategyKey, PositionActions, StrategyPayload, Account, StrategyData, StrategyCreated,
};


// Base Contract
#[starknet::contract]
mod cltBase {
    use super::{
        StrategyKey, StrategyData, StrategyCreated, StrategyPayload, PositionActions, Account
    };

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
