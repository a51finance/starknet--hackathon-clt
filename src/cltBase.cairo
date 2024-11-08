// SPDX-License-Identifier: BUSL-1.1
// A51 Finance

use starknet::ContractAddress;
use jediswap_v2_core::libraries::signed_integers::{
    i32::i32, i256::i256, integer_trait::IntegerTrait
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


#[derive(Drop, Serde)]
struct DepositParams {
    strategy_id: felt252,
    amount0_desired: u256,
    amount1_desired: u256,
    amount0_min: u256,
    amount1_min: u256,
    recipient: ContractAddress,
}

#[derive(Drop, Serde)]
struct WithdrawParams {
    token_id: u256,
    recipient: ContractAddress,
    liquidity: u256,
    amount0_min: u256,
    amount1_min: u256,
// refund_as_eth: bool,
}

#[derive(Drop, Serde)]
struct ShiftLiquidityParams {
    key: StrategyKey,
    strategy_id: felt252, // Equivalent to bytes32 in Solidity
    should_mint: bool,
    zero_for_one: bool,
    swap_amount: i256,
    module_status: Array<felt252>, // Equivalent to bytes in Solidity
    sqrt_price_limit_x96: u256
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

    fn deposit(ref self: TContractState, params: DepositParams) -> (u256, u256, u256, u256);

    fn withdraw(ref self: TContractState, params: WithdrawParams) -> (u256, u256);

    fn shift_liquidity(ref self: TContractState, params: ShiftLiquidityParams);

    fn get_Owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod cltBase {
    use super::{
        StrategyKey, DepositParams, StrategyPayload, PositionActions, Account, WithdrawParams,
        ShiftLiquidityParams
    };

    // Starknet imports
    use starknet::{
        contract_address::ContractAddress, ClassHash, get_caller_address, get_contract_address,
        get_block_timestamp, get_block_number, syscalls::keccak_syscall,
    };

    // Poseidon hashing
    use core::poseidon::poseidon_hash_span;

    // CLTBase-specific imports
    use cltbase::{
        CLTPayments::{CLTPayments, CLTPayments::{MintCallbackData, SwapCallbackData}},
        Errors::Errors,
        Governance_fee_handler::{
            IGovernanceFeeHandlerDispatcher, IGovernanceFeeHandlerDispatcherTrait
        },
        libraries::{
            LiquidityShares::LiquidityShares, Constants::Constants, PoolActions::PoolActions,
            StrategyFeeShare::StrategyFeeShares,
            StrategyFeeShare::StrategyFeeShares::{GlobalAccount}, Position::Position,
            UserPositions::{UserPositions, UserPositions::{Data}},
        },
    };

    // OpenZeppelin imports for ERC21 handling
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;

    use jediswap_v2_periphery::libraries::periphery_payments::PeripheryPayments::pay;
    use jediswap_v2_core::{
        jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait},
    };


    component!(path: ERC721Component, storage: erc721_storage, event: ERC721Event);
    component!(path: SRC5Component, storage: src5_storage, event: SRC5Event);


    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;


    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;


    // EVENTS
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StrategyCreated: StrategyCreated,
        Deposited: Deposited,
        StrategyFee: StrategyFee,
        Withdraw: Withdraw,
        LiquidityShifted: LiquidityShifted,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct StrategyFee {
        #[key]
        strategy_id: felt252,
        earned0: u256,
        earned1: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposited {
        #[key] // indexed equivalent in Solidity
        token_id: u256,
        recipient: ContractAddress,
        share: u256,
        amount0: u256,
        amount1: u256,
    }


    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        token_id: u256,
        #[key]
        recipient: ContractAddress,
        liquidity: u256,
        amount0: u256,
        amount1: u256,
        fee0: u256,
        fee1: u256,
    }


    #[derive(Drop, starknet::Event)]
    struct StrategyCreated {
        #[key] // Mark this as an indexed field, similar to `indexed` in Solidity
        strategy_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityShifted {
        #[key]
        strategy_id: felt252,
        should_mint: bool,
        zero_for_one: bool,
        swap_amount: super::i256,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress, // Owner address for administrative functions
        _shares_Id: u256,
        governance_fee_handler_address: ContractAddress,
        strategies: LegacyMap<felt252, StrategyData>,
        strategyGlobalFees: LegacyMap<felt252, GlobalAccount>,
        positions: LegacyMap<u256, Data>,
        #[substorage(v0)]
        erc721_storage: ERC721Component::Storage,
        #[substorage(v0)]
        src5_storage: SRC5Component::Storage,
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


    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        governance_fee_handler_address: ContractAddress
    ) {
        self.erc721_storage.initializer("A51 Liquidity Positions NFT", "ALPhy", "");
        self.owner.write(owner); // Set the owner during contract deployment
        self._shares_Id.write(1);
        self.governance_fee_handler_address.write(governance_fee_handler_address);
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
        let strategy_id = poseidon_hash_span(strategyIDHash.span());
        strategy_id
    }


    // Helper function for strategy authorization
    fn authorization_of_strategy(self: @ContractState, strategy_id: felt252) {
        // Check if the strategy exists and retrieve it
        let strategy_data = self.strategies.read(strategy_id);

        // Check if the strategy is private
        if strategy_data.is_private {
            // Ensure the caller is the owner of the private strategy
            let caller_address = get_caller_address();
            assert(strategy_data.owner == caller_address, Errors::UNAUTHORIZED);
        }
    }


    fn _update_globals(
        ref self: ContractState, ref strategy: StrategyData, strategy_id: felt252
    ) -> GlobalAccount {
        // Update global fees for the strategy
        let mut global = StrategyFeeShares::update_global_strategy_fees(
            ref self, strategy_id, strategy.key
        );

        // Update the fees specific to the strategy itself
        let (earned0, earned1) = StrategyFeeShares::update_strategy_fees(ref strategy, ref global);

        // Emit the StrategyFee event
        self.emit(StrategyFee { strategy_id, earned0, earned1 });

        global
    }


    fn _deposit(
        ref self: ContractState,
        strategy_id: felt252,
        amount0_desired: u256,
        amount1_desired: u256,
        amount0_min: u256,
        amount1_min: u256,
    ) -> (u256, u256, u256, u256, u256) {
        let mut share: u256 = 0.into();
        let mut amount0: u256 = 0.into();
        let mut amount1: u256 = 0.into();
        let mut fee_growth_inside0_last_x128: u256 = 0.into();
        let mut fee_growth_inside1_last_x128: u256 = 0.into();

        // Access the strategy data from storage
        let mut strategy = self.strategies.read(strategy_id);
        let mut global = _update_globals(ref self, ref strategy, strategy_id);

        let mut vars = Account {
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
        };

        // Compute liquidity share without fees for non-compounders
        let (computed_share, amt0, amt1) = LiquidityShares::compute_liquidity_share(
            strategy, amount0_desired, amount1_desired
        );

        share = computed_share;
        amount0 = amt0;
        amount1 = amt1;

        // Check for front-running with liquidity
        assert(share == 0.into(), Errors::INVALID_SHARE_AMOUNT);

        if strategy.account.total_shares == 0.into() {
            assert(share < Constants::MIN_INITIAL_SHARES.into(), Errors::INVALID_SHARE_AMOUNT);
        }

        assert(amount0 < amount0_min || amount1 < amount1_min, Errors::MIN_AMOUNT_EXCEEDED);

        let pool_Dispatcher = IJediSwapV2PoolDispatcher { contract_address: strategy.key.pool };
        let token0 = pool_Dispatcher.get_token0();
        let token1 = pool_Dispatcher.get_token0();
        // Transfer funds to the contract
        pay(token0, get_caller_address(), get_contract_address(), amount0);
        pay(token1, get_caller_address(), get_contract_address(), amount1);

        // Update contract balance: includes new assets, unused assets, and fees
        let (jediswap_liquidity, balance0, balance1) = PoolActions::mint_liquidity(
            strategy.key,
            amount0,
            amount1,
            _get_mint_callback_data(get_caller_address(), token0, token1, pool_Dispatcher.get_fee())
        );
        vars.jediswap_liquidity = jediswap_liquidity;
        vars.balance0 = balance0;
        vars.balance1 = balance1;

        Position::update(
            ref strategy,
            ref global,
            vars.jediswap_liquidity,
            share,
            amount0,
            amount1,
            vars.balance0,
            vars.balance1
        );

        fee_growth_inside0_last_x128 = strategy.account.fee_growth_inside0_last_x128;
        fee_growth_inside1_last_x128 = strategy.account.fee_growth_inside1_last_x128;

        (share, amount0, amount1, fee_growth_inside0_last_x128, fee_growth_inside1_last_x128)
    }


    fn _get_mint_callback_data(
        payer: ContractAddress, token0: ContractAddress, token1: ContractAddress, fee: u32
    ) -> Array<felt252> {
        let mut mint_callback_data: Array<felt252> = ArrayTrait::new();
        let mint_callback_data_struct = MintCallbackData {
            payer: payer, token0: token0, token1: token1, fee: fee
        };
        Serde::<MintCallbackData>::serialize(@mint_callback_data_struct, ref mint_callback_data);

        mint_callback_data
    }


    fn _get_swap_callback_data(
        token0: ContractAddress, token1: ContractAddress, fee: u32, zero_for_one: bool
    ) -> Array<felt252> {
        let mut swap_callback_data: Array<felt252> = ArrayTrait::new();
        let swap_callback_data_struct = SwapCallbackData {
            token0: token0, token1: token1, fee: fee, zero_for_one: zero_for_one
        };
        Serde::<SwapCallbackData>::serialize(@swap_callback_data_struct, ref swap_callback_data);

        swap_callback_data
    }

    fn get_global_account(self: @ContractState, key: StrategyKey,) -> GlobalAccount {
        let mut hash_data = array![];
        Serde::serialize(@key.pool, ref hash_data);
        Serde::serialize(@key.tick_lower, ref hash_data);
        Serde::serialize(@key.tick_upper, ref hash_data);
        let key_hash = poseidon_hash_span(hash_data.span());

        self.strategyGlobalFees.read(key_hash)
    }

    fn set_global_account(ref self: ContractState, key: StrategyKey, account: GlobalAccount) {
        let mut hash_data = array![];
        Serde::serialize(@key.pool, ref hash_data);
        Serde::serialize(@key.tick_lower, ref hash_data);
        Serde::serialize(@key.tick_upper, ref hash_data);
        let key_hash = poseidon_hash_span(hash_data.span());

        self.strategyGlobalFees.write(key_hash, account);
    }


    fn _get_governance_fee(self: @ContractState, is_private: bool) -> (u256, u256, u256, u256) {
        let governance_fee_handler = IGovernanceFeeHandlerDispatcher {
            contract_address: self.governance_fee_handler_address.read()
        };
        let (
            lp_automation_fee,
            strategy_creation_fee,
            protocol_fee_on_management,
            protocol_fee_on_performance
        ) =
            governance_fee_handler
            .get_governance_fee(is_private);

        (
            lp_automation_fee,
            strategy_creation_fee,
            protocol_fee_on_management,
            protocol_fee_on_performance
        )
    }


    #[abi(embed_v0)]
    impl CLTBaseImpl of super::ICLTBase<ContractState> {
        fn get_Owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }


        fn create_strategy(
            ref self: ContractState,
            key: StrategyKey,
            actions: PositionActions,
            management_fee: u256,
            performance_fee: u256,
            is_compound: bool,
            is_private: bool,
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

            // let governance_handler: IGovernanceFeeHandlerDispatcher =
            //     IGovernanceFeeHandlerDispatcher {
            //     contract_address: self.governance_fee_handler_address.read()
            // };

            // deduct strategy creation fee here
            // let (_, strategy_creation_fee_amount, _, _) = governance_handler
            //     .get_governance_fee(is_private);

            // transfer fee amount
            self.emit(StrategyCreated { strategy_id });
        }


        fn deposit(ref self: ContractState, params: DepositParams,) -> (u256, u256, u256, u256) {
            // Ensure the strategy exists and authorized for deposits
            authorization_of_strategy(@self, params.strategy_id);

            let (
                mut share,
                mut amount0,
                mut amount1,
                mut fee_growth_inside0_last_x128,
                mut fee_growth_inside1_last_x128
            ) =
                _deposit(
                ref self,
                params.strategy_id,
                params.amount0_desired,
                params.amount1_desired,
                params.amount0_min,
                params.amount1_min,
            );

            // mint token id here
            let token_id = self._shares_Id.read();
            self.erc721_storage._mint(get_caller_address(), token_id);
            self._shares_Id.write(token_id + 1);

            self
                .positions
                .write(
                    token_id,
                    Data {
                        strategy_id: params.strategy_id,
                        liquidity_share: share,
                        fee_growth_inside0_last_x128,
                        fee_growth_inside1_last_x128,
                        tokens_owed0: 0,
                        tokens_owed1: 0,
                    }
                );

            // Emit the Deposit event
            self
                .emit(
                    Deposited { token_id, recipient: params.recipient, share, amount0, amount1, }
                );

            (token_id, share, amount0, amount1)
        }


        fn withdraw(ref self: ContractState, params: WithdrawParams,) -> (u256, u256) {
            let mut amount0: u256 = 0.into();
            let mut amount1: u256 = 0.into();

            // Retrieve position and strategy data
            let mut position = self.positions.read(params.token_id);
            let mut strategy = self.strategies.read(position.strategy_id);

            // Update global strategy fees
            let mut global = _update_globals(ref self, ref strategy, position.strategy_id);

            // Validate liquidity and position requirements
            assert(params.liquidity != 0.into(), Errors::INVALID_SHARE_AMOUNT);
            assert(position.liquidity_share != 0.into(), Errors::ZERO_LIQUIDITY);
            assert(position.liquidity_share >= params.liquidity, Errors::INVALID_SHARE_AMOUNT);

            // Create an Account struct for holding intermediary calculations
            let mut vars = Account {
                fee0: 0.into(),
                fee1: 0.into(),
                balance0: 0.into(),
                balance1: 0.into(),
                total_shares: strategy.account.total_shares,
                jediswap_liquidity: 0,
                fee_growth_inside0_last_x128: strategy.account.fee_growth_inside0_last_x128,
                fee_growth_inside1_last_x128: strategy.account.fee_growth_inside1_last_x128,
                fee_growth_outside0_last_x128: strategy.account.fee_growth_outside0_last_x128,
                fee_growth_outside1_last_x128: strategy.account.fee_growth_outside1_last_x128,
            };

            // Calculate liquidity burn and update values
            let (burned_liquidity, amt0, amt1, _, _) = PoolActions::burn_user_liquidity(
                strategy.key,
                strategy.account.jediswap_liquidity,
                (params.liquidity * Constants::ONE.into() / strategy.account.total_shares)
            );

            amount0 += amt0;
            amount1 += amt1;
            vars.jediswap_liquidity = burned_liquidity;

            // Claim user fees for compounders and non-compounders
            // if !strategy.is_compound {
            let (fee0, fee1) = UserPositions::claim_fee_for_non_compounders(
                ref position, ref strategy
            );
            vars.fee0 += fee0.into();
            vars.fee1 += fee1.into();
            // } else {
            //     let (fee0, fee1) = UserPositions.claim_fee_for_compounders(ref strategy);
            //     vars.fee0 += fee0;
            //     vars.fee1 += fee1;
            // }
            // Calculate protocol fees
            let (_, _, protocol_fee_on_management, protocol_fee_on_performance) =
                _get_governance_fee(
                @self, strategy.is_private
            );
            let mut protocol_management_fee = protocol_fee_on_management;
            let mut protocol_performance_fee = protocol_fee_on_performance;

            // Deduct fees if required
            let (fee_balance0, fee_balance1) = CLTPayments::transfer_fee(
                strategy.key,
                protocol_performance_fee,
                strategy.performance_fee,
                vars.fee0,
                vars.fee1,
                self.owner.read(),
                strategy.owner,
            );

            vars.fee0 -= fee_balance0;
            vars.fee1 -= fee_balance1;

            let (mgmt_fee_balance0, mgmt_fee_balance1) = CLTPayments::transfer_fee(
                strategy.key,
                protocol_management_fee,
                strategy.management_fee,
                amount0,
                amount1,
                self.owner.read(),
                strategy.owner,
            );

            amount0 -= mgmt_fee_balance0;
            amount1 -= mgmt_fee_balance1;

            // Calculate user share amounts
            let user_share0 = (strategy.account.balance0 * params.liquidity)
                / strategy.account.total_shares;
            let user_share1 = (strategy.account.balance1 * params.liquidity)
                / strategy.account.total_shares;

            amount0 += user_share0 + vars.fee0;
            amount1 += user_share1 + vars.fee1;

            // Update strategy balances
            strategy.account.balance0 -= user_share0;
            strategy.account.balance1 -= user_share1;

            // Reset owed tokens for non-compounders
            // if !strategy.is_compound {
            position.tokens_owed0 = 0;
            position.tokens_owed1 = 0;
            // }

            // Validate minimum amounts
            assert(amount0 >= params.amount0_min, Errors::MIN_AMOUNT_EXCEEDED);
            assert(amount1 >= params.amount1_min, Errors::MIN_AMOUNT_EXCEEDED);

            // Transfer funds to the recipient
            // need to look into weth and ETH support

            let pool_Dispatcher = IJediSwapV2PoolDispatcher { contract_address: strategy.key.pool };

            if amount0 > 0.into() {
                CLTPayments::transfer_funds(
                    false, params.recipient, pool_Dispatcher.get_token0(), amount0
                );
            }
            if amount1 > 0.into() {
                CLTPayments::transfer_funds(
                    false, params.recipient, pool_Dispatcher.get_token1(), amount1
                );
            }

            // Update global liquidity if needed
            // if !strategy.get_hodl_status() {
            global.total_liquidity -= params.liquidity;
            // }

            // Update position and strategy liquidity shares
            position.liquidity_share -= params.liquidity;
            strategy.account.total_shares -= params.liquidity;
            strategy.account.jediswap_liquidity -= vars.jediswap_liquidity;
            // Emit withdraw event
            self
                .emit(
                    Withdraw {
                        token_id: params.token_id,
                        recipient: params.recipient,
                        liquidity: params.liquidity,
                        amount0,
                        amount1,
                        fee0: vars.fee0,
                        fee1: vars.fee1,
                    }
                );

            (amount0, amount1)
        }
    }
}

