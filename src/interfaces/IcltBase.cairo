// Interfaces
use starknet::ContractAddress;
pub mod CLTInterfaces {
    use starknet::{
        contract_address::ContractAddress, ClassHash, get_caller_address, get_contract_address,
        get_block_timestamp, get_block_number, syscalls::keccak_syscall,
    };

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

    #[derive(Drop, Serde)]
    struct PositionActions {
        mode: u256,
        exit_strategy: Array<StrategyPayload>, // Array of exit strategies
        rebase_strategy: Array<StrategyPayload>, // Array of rebase strategies
        liquidity_distribution: Array<StrategyPayload> // Array of liquidity distribution strategies
    }

    #[starknet::interface]
    pub trait ICLTBase<TContractState> {
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
}
