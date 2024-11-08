// SPDX-License-Identifier: GPL-2.0-or-later

/// @title StrategyFeeShares
/// @notice Contains methods for tracking fees owed to strategies relative to global fees

mod StrategyFeeShares {
    use core::result::ResultTrait;
    use core::traits::Into;

    // Poseidon hashing
    use core::poseidon::poseidon_hash_span;

    // CLTBase-specific imports
    use cltbase::{
        cltBase::cltBase, cltBase::cltBase::{StrategyKey, ContractState, StrategyData},
        CLTPayments::CLTPayments::{MintCallbackData}, Errors::Errors,
        Governance_fee_handler::{
            IGovernanceFeeHandlerDispatcher, IGovernanceFeeHandlerDispatcherTrait
        },
        libraries::{
            LiquidityShares::LiquidityShares, Constants::Constants, PoolActions::PoolActions
        },
    };


    // Jediswap Core imports
    use jediswap_v2_core::{
        jediswap_v2_factory::{IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait},
        jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait},
        libraries::{
            signed_integers::i32::i32, full_math::{mul_div},
            tick_math::TickMath::get_sqrt_ratio_at_tick,
            sqrt_price_math::SqrtPriceMath::{Q96, Q128}, position,
        }
    };

    // Jediswap Periphery imports
    use jediswap_v2_periphery::libraries::liquidity_amounts::LiquidityAmounts;

    // Starknet imports
    use starknet::{contract_address::ContractAddress, get_contract_address};


    #[derive(Copy, Drop, Serde, Hash, starknet::Store)]
    struct GlobalAccount {
        position_fee0: u256,
        position_fee1: u256,
        total_liquidity: u256,
        fee_growth_inside0_last_x128: u256,
        fee_growth_inside1_last_x128: u256,
    }
    fn update_global_strategy_fees(
        ref self: ContractState, strategyId: felt252, key: StrategyKey,
    ) -> GlobalAccount {
        // Serialize the StrategyKey to generate a unique hash

        // Retrieve the existing GlobalAccount entry from storage using the hash
        let mut account = cltBase::get_global_account(@self, key);

        // Update the position within PoolActions
        PoolActions::update_position(key);

        // If there is liquidity in the account, collect fees and update fee growth
        if account.total_liquidity > 0.into() {
            let (fees0, fees1) = PoolActions::collect_pending_fees(
                key, Constants::MAX_UINT128, Constants::MAX_UINT128, get_contract_address()
            );

            account.position_fee0 += fees0;
            account.position_fee1 += fees1;

            account
                .fee_growth_inside0_last_x128 +=
                    mul_div(fees0, Q128.into(), account.total_liquidity);

            account
                .fee_growth_inside1_last_x128 +=
                    mul_div(fees1, Q128.into(), account.total_liquidity);
        }

        // Write the updated account back to the contract's storage
        cltBase::set_global_account(ref self, key, account);

        account
    }
    /// @notice Credits accumulated fees to a strategy from the global position
    fn update_strategy_fees(ref self: StrategyData, ref global: GlobalAccount,) -> (u256, u256) {
        let mut total0: u256 = 0.into();
        let mut total1: u256 = 0.into();

        // Retrieve fee growth from the global account
        let fee_growth_inside0_last_x128 = global.fee_growth_inside0_last_x128;
        let fee_growth_inside1_last_x128 = global.fee_growth_inside1_last_x128;

        // Check if the strategy is in HODL mode
        let is_exit = false; // get_hodl_status(self);

        if !is_exit {
            // Calculate accumulated fees for the strategy
            total0 =
                mul_div(
                    fee_growth_inside0_last_x128 - self.account.fee_growth_outside0_last_x128,
                    self.account.total_shares,
                    Q128.into()
                )
                .into();

            total1 =
                mul_div(
                    fee_growth_inside1_last_x128 - self.account.fee_growth_outside1_last_x128,
                    self.account.total_shares,
                    Q128.into()
                )
                .into();
        }

        // Prevent underflow by safely subtracting from the global account
        if global.position_fee0 >= total0 {
            global.position_fee0 -= total0;
        }
        if global.position_fee1 >= total1 {
            global.position_fee1 -= total1;
        }

        // Update the strategy's fee balances
        self.account.fee0 += total0;
        self.account.fee1 += total1;

        // Update the strategy’s fee growth based on the global position
        self.account.fee_growth_outside0_last_x128 = fee_growth_inside0_last_x128;
        self.account.fee_growth_outside1_last_x128 = fee_growth_inside1_last_x128;

        // Update fee growth for strategy participants based on their shares
        if self.account.total_shares > 0.into() {
            self
                .account
                .fee_growth_inside0_last_x128 +=
                    mul_div(total0, Q128.into(), self.account.total_shares);
            self
                .account
                .fee_growth_inside1_last_x128 +=
                    mul_div(total1, Q128.into(), self.account.total_shares);
        }

        (total0, total1)
    }
// /// @notice Returns if the strategy is in HODL mode based on its status
// fn get_hodl_status(self: StrategyData) -> bool {
//     let action_status_len = self.action_status.len();
//     if action_status_len > 0 {
//         let (_, is_exit): (u256, bool) = self.action_status; // Decode action status
//         return is_exit;
//     }
//     false
// }
}
