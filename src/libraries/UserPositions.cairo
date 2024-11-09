mod UserPositions {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use jediswap_v2_core::{
        jediswap_v2_factory::{IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait},
        jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait},
        libraries::{
            signed_integers::i32::i32, full_math::{mul_div},
            tick_math::TickMath::get_sqrt_ratio_at_tick,
            sqrt_price_math::SqrtPriceMath::{Q96, Q128}, position,
        }
    };


    use cltbase::{
        cltBase::ICLTBase,
        cltBase::cltBase::{StrategyKey, GlobalAccount, ContractState, StrategyData},
        CLTPayments::CLTPayments::{MintCallbackData}, Errors::Errors,
        Governance_fee_handler::{
            IGovernanceFeeHandlerDispatcher, IGovernanceFeeHandlerDispatcherTrait
        },
        utils::{helpers::HelperFunctions::{u256_to_u128},},
        libraries::{
            LiquidityShares::LiquidityShares, Constants::Constants, PoolActions::PoolActions,
        },
    };

    #[derive(Copy, Drop, Serde, Hash, starknet::Store)]
    struct Data {
        strategy_id: felt252,
        liquidity_share: u256,
        fee_growth_inside0_last_x128: u256,
        fee_growth_inside1_last_x128: u256,
        tokens_owed0: u128,
        tokens_owed1: u128,
    }
    // /// @notice Collects up to a maximum amount of fees owed to a user from the strategy fees
    // /// @param self The individual user position to update
    // /// @param fee_growth_inside0_last_x128 The all-time fee growth in token0, per unit of liquidity in strategy
    // /// @param fee_growth_inside1_last_x128 The all-time fee growth in token1, per unit of liquidity in strategy
    // fn update_user_position(
    //     ref self: Data, fee_growth_inside0_last_x128: u256, fee_growth_inside1_last_x128: u256,
    // ) {
    //     // Calculate tokens owed in token0 and token1, adding to the user’s balance
    //     let tokens_owed0 = (fee_growth_inside0_last_x128 - self.fee_growth_inside0_last_x128)
    //         * self.liquidity_share
    //         / Q128;
    //     let tokens_owed1 = (fee_growth_inside1_last_x128 - self.fee_growth_inside1_last_x128)
    //         * self.liquidity_share
    //         / Q128;

    //     // Update the tokens owed
    //     self.tokens_owed0.write(self.tokens_owed0.read() + tokens_owed0.into());
    //     self.tokens_owed1.write(self.tokens_owed1.read() + tokens_owed1.into());

    //     // Update fee growth for the user
    //     self.fee_growth_inside0_last_x128.write(fee_growth_inside0_last_x128);
    //     self.fee_growth_inside1_last_x128.write(fee_growth_inside1_last_x128);
    // }

    fn claim_fee_for_non_compounders(ref self: Data, ref strategy: StrategyData,) -> (u128, u128) {
        let tokens_owed0: u256 = self.tokens_owed0.into();
        let tokens_owed1: u256 = self.tokens_owed1.into();

        let fee_growth_inside0_last_x128 = strategy.account.fee_growth_inside0_last_x128;
        let fee_growth_inside1_last_x128 = strategy.account.fee_growth_inside1_last_x128;

        // Calculate total fees in token0 and token1 for non-compounding strategy

        let total0 = tokens_owed0
            + ((fee_growth_inside0_last_x128 - self.fee_growth_inside0_last_x128)
                * self.liquidity_share
                / Q128);

        let total1 = tokens_owed1
            + ((fee_growth_inside1_last_x128 - self.fee_growth_inside1_last_x128)
                * self.liquidity_share
                / Q128);

        // Update fee growth for the user position
        self.fee_growth_inside0_last_x128 = fee_growth_inside0_last_x128;
        self.fee_growth_inside1_last_x128 = fee_growth_inside1_last_x128;

        // Update the owed tokens balance for the user position
        self.tokens_owed0 = u256_to_u128(total0).unwrap();
        self.tokens_owed1 = u256_to_u128(total1).unwrap();

        // Subtract the total owed from the strategy's fee balance to avoid underflow
        strategy.account.fee0 = strategy.account.fee0 - total0.into();
        strategy.account.fee1 = strategy.account.fee1 - total1.into();

        (u256_to_u128(total0).unwrap(), u256_to_u128(total1).unwrap())
    }
// /// @notice Collects fees for compounding strategies
// /// @param self The individual user position to update
// /// @param strategy The individual strategy position
// /// @return fee0 The amount of fees collected in token0
// /// @return fee1 The amount of fees collected in token1
// fn claim_fee_for_compounders(ref self: Data, ref strategy: StrategyData,) -> (u256, u256) {
//     let fee0 = strategy.account.fee0.read()
//         * self.liquidity_share
//         / strategy.account.total_shares.read();
//     let fee1 = strategy.account.fee1.read()
//         * self.liquidity_share
//         / strategy.account.total_shares.read();

//     // Deduct fees from strategy's account fees
//     strategy.account.fee0.write(strategy.account.fee0.read() - fee0);
//     strategy.account.fee1.write(strategy.account.fee1.read() - fee1);

//     (fee0, fee1)
// }

}
