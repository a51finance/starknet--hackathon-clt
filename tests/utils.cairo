use starknet::{
    ContractAddress, ClassHash, contract_address_try_from_felt252, contract_address_to_felt252
};
use snforge_std::{declare, start_prank, stop_prank, ContractClass, ContractClassTrait, CheatTarget};
use jediswap_v2_core::libraries::math_utils::pow;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

fn user1() -> ContractAddress {
    contract_address_try_from_felt252('user1').unwrap()
}

fn user2() -> ContractAddress {
    contract_address_try_from_felt252('user2').unwrap()
}

fn owner() -> ContractAddress {
    contract_address_try_from_felt252('owner').unwrap()
}

fn new_owner() -> ContractAddress {
    contract_address_try_from_felt252('new_owner').unwrap()
}

fn token0() -> ContractAddress {
    contract_address_try_from_felt252('token0').unwrap()
}

fn token1() -> ContractAddress {
    contract_address_try_from_felt252('token1').unwrap()
}

