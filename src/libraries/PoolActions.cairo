mod PoolActions {
    use core::result::ResultTrait;
    use core::traits::Into;

    // Jediswap Core imports
    use jediswap_v2_core::{
        jediswap_v2_factory::{IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait},
        jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait},
        libraries::{
            signed_integers::i32::i32, full_math::{mul_div},
            tick_math::TickMath::get_sqrt_ratio_at_tick, sqrt_price_math::SqrtPriceMath,
            sqrt_price_math::SqrtPriceMath::{Q96, Q128,}, position,
        }
    };

    // Jediswap Periphery imports
    use jediswap_v2_periphery::libraries::liquidity_amounts::LiquidityAmounts;

    // CLTBase-specific imports
    use cltbase::{
        interfaces::IcltBase::CLTInterfaces::StrategyKey, Errors::Errors,
        libraries::Constants::Constants
    };

    // Starknet imports
    use starknet::{contract_address::ContractAddress, get_contract_address};


    pub fn update_position(key: StrategyKey,) -> u128 {
        let (liquidity, _, _, _, _) = get_position_liquidity(key);
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };
        if liquidity > 0 {
            pool_dispatcher.burn(key.tick_lower, key.tick_upper, 0);
        }
        liquidity
    }


    // Burn complete liquidity of strategy in a range from the pool
    fn burn_liquidity(key: StrategyKey, strategy_liquidity: u128) -> (u256, u256, u256, u256) {
        let mut amount0: u256 = 0;
        let mut amount1: u256 = 0;
        let mut fees0: u256 = 0;
        let mut fees1: u256 = 0;

        // Only burn individual strategy liquidity
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };

        if strategy_liquidity > 0 {
            // Call burn and get `amount0` and `amount1`
            let (amt0, amt1) = pool_dispatcher
                .burn(key.tick_lower, key.tick_upper, strategy_liquidity);

            amount0 = amt0.into();
            amount1 = amt1.into();

            // If there are amounts, collect the fees
            if amount0 > 0 || amount1 > 0 {
                let (collect0, collect1) = pool_dispatcher
                    .collect(
                        get_contract_address(),
                        key.tick_lower,
                        key.tick_upper,
                        Constants::MAX_UINT128,
                        Constants::MAX_UINT128,
                    );

                // Calculate fees
                fees0 = (collect0.into() - amt0).into();
                fees1 = (collect1.into() - amt1).into();
            }
        }

        (amount0, amount1, fees0, fees1)
    }


    fn burn_user_liquidity(
        key: StrategyKey, strategy_liquidity: u128, user_share_percentage: u256,
    ) -> (u128, u256, u256, u256, u256) {
        let mut liquidity: u128 = 0;
        let mut amount0: u256 = 0;
        let mut amount1: u256 = 0;
        let mut fees0: u256 = 0;
        let mut fees1: u256 = 0;

        // Only proceed if there is liquidity to burn
        if strategy_liquidity > 0 {
            // Calculate user-specific liquidity based on share percentage
            liquidity =
                u256_to_u128(
                    mul_div(strategy_liquidity.into(), user_share_percentage, Constants::ONE.into())
                )
                .unwrap();

            // Burn liquidity in the pool within the specified tick range
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };
            let (amt0, amt1) = pool_dispatcher
                .burn(key.tick_lower, key.tick_upper, liquidity.into());

            amount0 = amt0.into();
            amount1 = amt1.into();

            // If amounts are greater than zero, collect the corresponding fees
            if amount0 > 0 || amount1 > 0 {
                let (collect0, collect1) = pool_dispatcher
                    .collect(
                        get_contract_address(),
                        key.tick_lower,
                        key.tick_upper,
                        Constants::MAX_UINT128,
                        Constants::MAX_UINT128,
                    );

                // Calculate the fees collected
                fees0 = (collect0.into() - amount0).into();
                fees1 = (collect1.into() - amount1).into();
            }
        }

        (liquidity, amount0, amount1, fees0, fees1)
    }


    // Mint liquidity for a given strategy position
    fn mint_liquidity(
        key: StrategyKey,
        amount0_desired: u256,
        amount1_desired: u256,
        callback_data: Array<felt252>,
    ) -> (u128, u256, u256) {
        let liquidity = get_liquidity_for_amounts(key, amount0_desired, amount1_desired);
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };

        let (amount0, amount1) = pool_dispatcher
            .mint(
                get_contract_address(), key.tick_lower, key.tick_upper, liquidity, callback_data,
            );

        (liquidity, amount0, amount1)
    }


    fn get_liquidity_for_amounts(key: StrategyKey, amount0: u256, amount1: u256) -> u128 {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();

        LiquidityAmounts::get_liquidity_for_amounts(
            sqrt_price_x96,
            get_sqrt_ratio_at_tick(key.tick_lower),
            get_sqrt_ratio_at_tick(key.tick_upper),
            amount0,
            amount1
        )
    }


    fn get_amounts_for_liquidity(key: StrategyKey, liquidity: u128) -> (u256, u256) {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();
        let current_tick = pool_dispatcher.get_tick();

        let mut amount0: u256 = 0.into();
        let mut amount1: u256 = 0.into();

        // Calculate amounts based on the tick range
        if current_tick < key.tick_lower {
            amount0 =
                SqrtPriceMath::get_amount0_delta(
                    get_sqrt_ratio_at_tick(key.tick_lower),
                    get_sqrt_ratio_at_tick(key.tick_upper),
                    liquidity.into()
                )
                .mag;
        } else if current_tick < key.tick_upper {
            amount0 =
                SqrtPriceMath::get_amount0_delta(
                    sqrt_price_x96, get_sqrt_ratio_at_tick(key.tick_upper), liquidity.into()
                )
                .mag;

            amount1 =
                SqrtPriceMath::get_amount1_delta(
                    get_sqrt_ratio_at_tick(key.tick_lower), sqrt_price_x96, liquidity.into()
                )
                .mag;
        } else {
            amount1 =
                SqrtPriceMath::get_amount1_delta(
                    get_sqrt_ratio_at_tick(key.tick_lower),
                    get_sqrt_ratio_at_tick(key.tick_upper),
                    liquidity.into()
                )
                .mag;
        }

        (amount0, amount1)
    }


    fn get_position_liquidity(key: StrategyKey) -> (u128, u256, u256, u128, u128) {
        // Create a PositionKey using the StrategyKey's owner and tick range
        let position_key = position::PositionKey {
            owner: get_contract_address(), tick_lower: key.tick_lower, tick_upper: key.tick_upper,
        };

        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };

        let position_info = pool_dispatcher.get_position_info(position_key);

        (
            position_info.liquidity,
            position_info.fee_growth_inside_0_last_X128,
            position_info.fee_growth_inside_1_last_X128,
            position_info.tokens_owed_0,
            position_info.tokens_owed_1,
        )
    }


    // Collect pending fees for a strategy
    fn collect_pending_fees(
        key: StrategyKey, tokens_owed0: u128, tokens_owed1: u128, recipient: ContractAddress,
    ) -> (u256, u256) {
        // Collect up to maximum amount of fees owed
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: key.pool };
        let (collect0, collect1) = pool_dispatcher
            .collect(recipient, key.tick_lower, key.tick_upper, tokens_owed0, tokens_owed1);

        (collect0.into(), collect1.into())
    }

    // compounding is not included as of yet
    // // Compound collected fees to add liquidity
    // fn compound_fees(key: StrategyKey, balance0: u256, balance1: u256,) -> (u128, u256, u256) {
    //     let (collect0, collect1) = collect_pending_fees(
    //         key, Constants::MAX_UINT128, Constants::MAX_UINT128, get_contract_address()
    //     );

    //     let total0 = collect0 + balance0;
    //     let total1 = collect1 + balance1;

    //     // Mint liquidity with collected fees
    //     let liquidity = get_liquidity_for_amounts(key, total0, total1);
    //     if liquidity > 0 {
    //         let (new_liquidity, amount0, amount1) = mint_liquidity(key, total0, total1);
    //         let balance0_after_mint = total0 - amount0;
    //         let balance1_after_mint = total1 - amount1;
    //         (new_liquidity, balance0_after_mint, balance1_after_mint)
    //     } else {
    //         (0.into(), balance0, balance1)
    //     }
    // }

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

