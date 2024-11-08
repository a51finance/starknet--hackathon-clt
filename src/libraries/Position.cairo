mod Position {
    use starknet::ContractAddress;
    use jediswap_v2_core::libraries::signed_integers::{i32::i32, i256::i256};
    use starknet::get_caller_address;
    use core::poseidon::poseidon_hash_span;

    use cltbase::{
        cltBase::cltBase,
        cltBase::cltBase::{StrategyKey, GlobalAccount, ContractState, StrategyData},
        CLTPayments::CLTPayments::{MintCallbackData}, Errors::Errors,
        Governance_fee_handler::{
            IGovernanceFeeHandlerDispatcher, IGovernanceFeeHandlerDispatcherTrait
        },
        libraries::{
            LiquidityShares::LiquidityShares, Constants::Constants, PoolActions::PoolActions
        },
    };


    // Function to update liquidity and balances in the strategy
    fn update(
        ref strategy: StrategyData,
        ref global: GlobalAccount,
        liquidity_added: u128,
        share: u256,
        amount0_desired: u256,
        amount1_desired: u256,
        amount0_added: u256,
        amount1_added: u256,
    ) {
        let balance0 = amount0_desired - amount0_added;
        let balance1 = amount1_desired - amount1_added;

        if balance0 > 0 || balance1 > 0 {
            strategy.account.balance0 += balance0;
            strategy.account.balance1 += balance1;
        }

        if share > 0 {
            let is_exit = false; //get_hodl_status(strategy);

            strategy.account.total_shares += share;
            strategy.account.jediswap_liquidity += liquidity_added;

            if !is_exit {
                global.total_liquidity += share;
            }
        }
    }
    // // Function to update position after a fee compound
    // #[external]
    // fn updateForCompound(
    //     ref self: ContractState,
    //     liquidity_added: u128,
    //     amount0_added: u256,
    //     amount1_added: u256,
    // ) {
    //     self.account.balance0.write(amount0_added);
    //     self.account.balance1.write(amount1_added);

    //     self.account.fee0.write(0);
    //     self.account.fee1.write(0);

    //     let uniswap_liquidity = self.account.jediswap_liquidity.read();
    //     self.account.jediswap_liquidity.write(uniswap_liquidity + liquidity_added);
    // }

    // Function to update strategy and mint new position on AMM
    // Update the strategy state with new liquidity and balances in Cairo
    fn update_strategy(
        ref self: ContractState,
        ref strategy: StrategyData,
        key: StrategyKey,
        status: Array<felt252>, // Replacing bytes with Array<felt252> equivalent
        liquidity: u128,
        balance0: u256,
        balance1: u256,
    ) {
        // Update the strategy's key with the new key provided
        strategy.key = key;

        let mut global = cltBase::get_global_account(@self, key);

        // Update the strategy's account with the new balances
        strategy.account.balance0 = balance0;
        strategy.account.balance1 = balance1;

        // Set the action status based on the provided status
        strategy.action_status = poseidon_hash_span(status.span());

        // Update the strategy’s liquidity with the new liquidity
        strategy.account.jediswap_liquidity = liquidity;

        // Determine if the strategy is in HODL mode
        let is_exit = false; //get_hodl_status(strategy);

        // If the strategy is not in HODL mode, update the global liquidity
        if !is_exit {
            global.total_liquidity += strategy.account.total_shares;
        }

        // Clear fees for compounding strategies
        if strategy.is_compound {
            strategy.account.fee0 = 0.into();
            strategy.account.fee1 = 0.into();
        }

        // Update fee growth values for out-of-range positions
        strategy.account.fee_growth_outside0_last_x128 = global.fee_growth_inside0_last_x128;
        strategy.account.fee_growth_outside1_last_x128 = global.fee_growth_inside1_last_x128;

        cltBase::set_global_account(ref self, key, global);
    }
// // Function to update the strategy state
// #[external]
// fn updateStrategyState(
//     ref self: ContractState,
//     new_owner: ContractAddress,
//     management_fee: u256,
//     performance_fee: u256,
//     new_actions: felt252,
// ) {
//     self.actions.write(new_actions);

//     if self.owner.read() != new_owner {
//         self.owner.write(new_owner);
//     }
//     if self.management_fee.read() != management_fee {
//         self.management_fee.write(management_fee);
//     }
//     if self.performance_fee.read() != performance_fee {
//         self.performance_fee.write(performance_fee);
//     }

//     let is_exit = get_hodl_status(@self);

//     if is_exit {
//         self.action_status.write(poseidon_hash_span(&[felt252(0), felt252(is_exit)]));
//     } else {
//         self.action_status.write(0);
//     }
// }

// // Helper function to get HODL status
// fn get_hodl_status(self: @ContractState) -> bool {
//     if self.action_status.read() > 0 {
//         // Unpack the HODL status from `action_status`
//         let (_, is_exit) = abi_decode(self.action_status.read(), (u256, bool));
//         is_exit
//     } else {
//         false
//     }
// }
}
