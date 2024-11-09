// SPDX-License-Identifier: UNLICENSED

#[starknet::contract]
mod CLTPayments {
    use core::traits::Into;
    use jediswap_v2_core::jediswap_v2_factory::{
        IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait
    };
    use cltbase::{cltBase::cltBase::StrategyKey, Errors::Errors, libraries::Constants::Constants};
    use starknet::{contract_address::ContractAddress, get_contract_address, get_caller_address};
    use jediswap_v2_periphery::libraries::periphery_payments::PeripheryPayments::pay;
    use jediswap_v2_core::libraries::signed_integers::{
        i32::i32, i256::i256, integer_trait::IntegerTrait
    };


    use jediswap_v2_core::{
        jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait},
        libraries::{
            full_math::{mul_div}, tick_math::TickMath::get_sqrt_ratio_at_tick,
            sqrt_price_math::SqrtPriceMath::{Q96, Q128}, position,
        }
    };


    use cltbase::Governance_fee_handler::{
        IGovernanceFeeHandlerDispatcher, IGovernanceFeeHandlerDispatcherTrait
    };


    use openzeppelin::token::erc20::interface::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20CamelDispatcher, IERC20CamelDispatcherTrait
    };


    #[storage]
    struct Storage {
        factory: IJediSwapV2FactoryDispatcher,
    }

    #[derive(Copy, Drop, Serde)]
    struct MintCallbackData {
        /// @notice The payer for adding liquidity
        payer: ContractAddress,
        token0: ContractAddress,
        token1: ContractAddress,
        fee: u32,
    }

    #[derive(Copy, Drop, Serde)]
    struct SwapCallbackData {
        token0: ContractAddress,
        token1: ContractAddress,
        fee: u32,
        zero_for_one: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, factory_address: ContractAddress) {
        self.factory.write(IJediSwapV2FactoryDispatcher { contract_address: factory_address });
    }

    fn jediswap_v2_mint_callback(
        ref self: ContractState,
        amount0_owed: u256,
        amount1_owed: u256,
        mut callback_data_span: Span<felt252>
    ) {
        let caller = get_caller_address();
        let decoded_data = Serde::<MintCallbackData>::deserialize(ref callback_data_span).unwrap();

        if amount0_owed > 0 {
            pay(decoded_data.token0, decoded_data.payer, caller, amount0_owed);
        }
        if amount1_owed > 0 {
            pay(decoded_data.token1, decoded_data.payer, caller, amount1_owed);
        }
    }

    fn jediswap_v2_swap_callback(
        ref self: ContractState,
        amount0_delta: i256,
        amount1_delta: i256,
        mut callback_data_span: Span<felt252>
    ) {
        let caller = get_caller_address();

        let decoded_data = Serde::<SwapCallbackData>::deserialize(ref callback_data_span).unwrap();
        let zero = IntegerTrait::<i256>::new(0, false);

        if (amount0_delta > zero) {
            pay(decoded_data.token0, get_contract_address(), caller, amount0_delta.mag);
        }

        if (amount1_delta > zero) {
            pay(decoded_data.token1, get_contract_address(), caller, amount1_delta.mag);
        }
    }

    fn transfer_funds(
        refund_as_eth: bool, recipient: ContractAddress, token: ContractAddress, amount: u256,
    ) {
        // If refund_as_eth is true, handle as ETH transfer, otherwise use ERC20
        if refund_as_eth {
            pay(token, get_contract_address(), recipient, amount);
        } else {
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer(recipient, amount);
        }
    }


    fn transfer_fee(
        key: StrategyKey,
        protocol_percentage: u256,
        percentage: u256,
        amount0: u256,
        amount1: u256,
        governance: ContractAddress,
        strategy_owner: ContractAddress,
    ) -> (u256, u256) {
        let mut fee0: u256 = 0.into();
        let mut fee1: u256 = 0.into();

        if percentage > 0.into() {
            // Calculate and transfer fees for amount0
            let pool_Dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };
            if amount0 > 0.into() {
                let token0_dispatcher = IERC20Dispatcher {
                    contract_address: pool_Dispatcher.get_token0()
                };

                fee0 = mul_div(amount0, percentage, Constants::ONE.into());
                let protocol_share0 = mul_div(fee0, protocol_percentage, Constants::ONE.into());

                // Transfer fee0 minus protocol share to the strategy owner
                token0_dispatcher.transfer(strategy_owner, fee0 - protocol_share0);

                // If there is a protocol share, transfer it to governance
                if protocol_share0 > 0.into() {
                    token0_dispatcher.transfer(governance, protocol_share0);
                }
            }

            if amount1 > 0.into() {
                let token1_dispatcher = IERC20Dispatcher {
                    contract_address: pool_Dispatcher.get_token1()
                };

                fee1 = mul_div(amount1, percentage, Constants::ONE.into());
                let protocol_share1 = mul_div(fee1, protocol_percentage, Constants::ONE.into());

                // Transfer fee1 minus protocol share to the strategy owner
                token1_dispatcher.transfer(strategy_owner, fee1 - protocol_share1);

                // If there is a protocol share, transfer it to governance
                if protocol_share1 > 0.into() {
                    token1_dispatcher.transfer(governance, protocol_share1);
                }
            }
        }

        (fee0, fee1)
    }
// fn _verify_callback(
//     ref self: ContractState, token0: ContractAddress, token1: ContractAddress, fee: u256
// ) {
//     let pool = self.factory.get_pool(token0, token1, fee);
//     assert(get_caller_address() == pool, "Unauthorized callback");
// }

}

