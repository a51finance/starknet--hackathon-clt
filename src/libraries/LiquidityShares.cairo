mod LiquidityShares {
    use jediswap_v2_core::libraries::full_math::{mul_div};
    use cltbase::CLT_Base::CLTBase;
    use cltbase::{
        CLT_Base::CLTBase::StrategyKey, Errors::Errors,
        libraries::{Constants::Constants, PoolActions::PoolActions}
    };
    use jediswap_v2_periphery::libraries::{liquidity_amounts::LiquidityAmounts};


    fn get_reserves(key: CLTBase::StrategyKey, liquidity: u128,) -> (u256, u256) {
        // Update the pool position for the given strategy key
        // PoolActions::update_position(key);

        let mut reserves0 = 0.into();
        let mut reserves1 = 0.into();

        // Check if liquidity is greater than zero
        if liquidity > 0 { // Retrieve earnable amounts for this position (assumed to be zero due to previous claims)
            let (_, _, _, earnable0, earnable1) = PoolActions::get_position_liquidity(key);

            // Calculate the burnable amounts based on the provided liquidity
            let (burnable0, burnable1) = PoolActions::get_amounts_for_liquidity(key, liquidity);

            // Compute the reserves by adding burnable and earnable amounts
            reserves0 = burnable0 + earnable0.into();
            reserves1 = burnable1 + earnable1.into();
        }

        (reserves0, reserves1)
    }


    fn compute_liquidity_share(
        strategy: CLTBase::StrategyData, amount0_max: u256, amount1_max: u256,
    ) -> (u256, u256, u256) {
        // Retrieve existing liquidity reserves
        let (mut reserve0, mut reserve1) = get_reserves(
            strategy.key, strategy.account.jediswap_liquidity
        );

        // Add unused balances
        reserve0 += strategy.account.balance0;
        reserve1 += strategy.account.balance1;

        // Ensure strategy is valid
        assert(
            strategy.account.total_shares == 0 || reserve0 != 0.into() || reserve1 != 0.into(),
            Errors::INVALID_SHARE_AMOUNT,
        );

        // Calculate shares, amount0, and amount1 based on desired max amounts and current reserves
        let (shares, amount0, amount1) = calculate_share(
            amount0_max, amount1_max, reserve0, reserve1, strategy.account.total_shares,
        );

        (shares, amount0, amount1)
    }

    fn calculate_share(
        amount0_max: u256, amount1_max: u256, reserve0: u256, reserve1: u256, total_supply: u256,
    ) -> (u256, u256, u256) {
        let mut shares = 0.into();
        let mut amount0 = 0.into();
        let mut amount1 = 0.into();

        if total_supply == 0.into() {
            // Initial deposit: use the desired amounts directly
            amount0 = amount0_max;
            amount1 = amount1_max;
            shares = if amount0 > amount1 {
                amount0
            } else {
                amount1
            }; // max(amount0, amount1)
        } else if reserve0 == 0.into() {
            // If reserve0 is zero, only amount1 is used
            amount1 = amount1_max;
            shares = mul_div(amount1, total_supply, reserve1);
        } else if reserve1 == 0.into() {
            // If reserve1 is zero, only amount0 is used
            amount0 = amount0_max;
            shares = mul_div(amount0, total_supply, reserve0);
        } else {
            // General case: calculate amount0 based on amount1Max and reserves
            amount0 = mul_div(amount1_max, reserve0, reserve1);
            if amount0 < amount0_max {
                // Use amount1_max if amount0 calculation is within the max
                amount1 = amount1_max;
                shares = mul_div(amount1, total_supply, reserve1);
            } else {
                // Otherwise, use amount0_max and calculate amount1
                amount0 = amount0_max;
                amount1 = mul_div(amount0, reserve1, reserve0);
                shares = mul_div(amount0, total_supply, reserve0);
            }
        }

        (shares, amount0, amount1)
    }
}
