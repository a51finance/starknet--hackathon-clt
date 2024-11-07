// SPDX-License-Identifier: UNLICENSED
// GovernanceFeeHandler in Cairo

use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::Event;


#[starknet::interface]
trait IGovernanceFeeHandler<TContractState> {
    fn only_owner(ref self: TContractState);

    fn set_public_fee_registry(
        ref self: TContractState, new_public_strategy_fee_registry: ProtocolFeeRegistry
    );

    fn set_private_fee_registry(
        ref self: TContractState, new_private_strategy_fee_registry: ProtocolFeeRegistry
    );

    fn get_governance_fee(self: @TContractState, is_private: bool) -> (u256, u256, u256, u256);

    fn check_limit(ref self: TContractState, fee_params: ProtocolFeeRegistry);
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct ProtocolFeeRegistry {
    lp_automation_fee: u256,
    strategy_creation_fee: u256,
    protocol_fee_on_management: u256,
    protocol_fee_on_performance: u256,
}


#[starknet::contract]
mod GovernanceFeeHandler {
    use super::{ProtocolFeeRegistry};
    use starknet::{get_caller_address, ContractAddress};


    // EVENTS
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PublicFeeRegistryUpdated: PublicFeeRegistryUpdated,
        PrivateFeeRegistryUpdated: PrivateFeeRegistryUpdated,
    }


    #[derive(Drop, starknet::Event)]
    struct PublicFeeRegistryUpdated {
        new_fee_registry: ProtocolFeeRegistry,
    }

    #[derive(Drop, starknet::Event)]
    struct PrivateFeeRegistryUpdated {
        new_fee_registry: ProtocolFeeRegistry,
    }


    #[storage]
    struct Storage {
        owner: ContractAddress,
        public_strategy_fee_registry: ProtocolFeeRegistry,
        private_strategy_fee_registry: ProtocolFeeRegistry,
    }

    const MAX_MANAGEMENT_FEE: u256 = 200000000000000000; // 2e17
    const MAX_PERFORMANCE_FEE: u256 = 200000000000000000; // 2e17
    const MAX_PROTOCOL_MANAGEMENT_FEE: u256 = 200000000000000000; // 2e17
    const MAX_PROTOCOL_PERFORMANCE_FEE: u256 = 200000000000000000; // 2e17
    const MAX_AUTOMATION_FEE: u256 = 200000000000000000; // 2e17
    const MAX_STRATEGY_CREATION_FEE: u256 = 500000000000000000; // 5e17

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        public_strategy_fee_registry: ProtocolFeeRegistry,
        private_strategy_fee_registry: ProtocolFeeRegistry
    ) {
        self.owner.write(owner);
        self.public_strategy_fee_registry.write(public_strategy_fee_registry);
        self.private_strategy_fee_registry.write(private_strategy_fee_registry);
    }

    // Move the functions to an impl block for `ContractState`
    #[abi(embed_v0)]
    impl GovernanceFeeHandlerImpl of super::IGovernanceFeeHandler<ContractState> {
        fn only_owner(ref self: ContractState) {
            assert(get_caller_address() != self.owner.read(), 'Unauthorized'.into());
        }

        fn set_public_fee_registry(
            ref self: ContractState, new_public_strategy_fee_registry: ProtocolFeeRegistry
        ) {
            self.only_owner();
            self.check_limit(new_public_strategy_fee_registry);
            self.public_strategy_fee_registry.write(new_public_strategy_fee_registry);

            self
                .emit(
                    PublicFeeRegistryUpdated { new_fee_registry: new_public_strategy_fee_registry }
                )
        }

        fn set_private_fee_registry(
            ref self: ContractState, new_private_strategy_fee_registry: ProtocolFeeRegistry
        ) {
            self.only_owner();
            self.check_limit(new_private_strategy_fee_registry);
            self.private_strategy_fee_registry.write(new_private_strategy_fee_registry);
            self
                .emit(
                    PrivateFeeRegistryUpdated {
                        new_fee_registry: new_private_strategy_fee_registry
                    }
                )
        }

        fn get_governance_fee(self: @ContractState, is_private: bool) -> (u256, u256, u256, u256) {
            let fee_registry = if is_private {
                self.private_strategy_fee_registry.read()
            } else {
                self.public_strategy_fee_registry.read()
            };

            return (
                fee_registry.lp_automation_fee,
                fee_registry.strategy_creation_fee,
                fee_registry.protocol_fee_on_management,
                fee_registry.protocol_fee_on_performance
            );
        }

        fn check_limit(ref self: ContractState, fee_params: ProtocolFeeRegistry) {
            assert(
                fee_params.lp_automation_fee > MAX_AUTOMATION_FEE,
                'LP Automation Fee Exceeded'.into()
            );

            assert(
                fee_params.strategy_creation_fee > MAX_STRATEGY_CREATION_FEE,
                'Strategy Creation Fee Exceeded'.into()
            );

            assert(
                fee_params.protocol_fee_on_management > MAX_PROTOCOL_MANAGEMENT_FEE,
                'Management Fee Exceeded'.into()
            );

            assert(
                fee_params.protocol_fee_on_performance > MAX_PROTOCOL_PERFORMANCE_FEE,
                'Performance Fee Exceeded'.into()
            );
        }
    }
}
