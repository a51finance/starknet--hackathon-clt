use cltbase::CLT_Base::{CLTBase, ICLTBaseDispatcher, ICLTBaseDispatcherTrait};
use starknet::{ContractAddress, contract_address_try_from_felt252};
use openzeppelin::access::ownable::{
    OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait}
};

use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy,
    EventFetcher, Event, EventAssertions
};
use openzeppelin::security::interface::{IPausableDispatcher, IPausableDispatcherTrait};
use super::utils::{owner, new_owner, token0, token1};

fn setup_contracts() -> ICLTBaseDispatcher {
    // Declare and deploy
    let base_contract = declare("CLTBase");
    let owner = owner();
    let mut base_contract_constructor_calldata = Default::default();
    Serde::serialize(@owner, ref base_contract_constructor_calldata);
    let base_contract_address = base_contract.deploy(@base_contract_constructor_calldata).unwrap();
    // Return the dispatcher.
    // The dispatcher allows to interact with the contract based on its interface.
    ICLTBaseDispatcher { contract_address: base_contract_address }
}

#[test]
fn test_owner_on_deployment() {
    let base_contract: ICLTBaseDispatcher = setup_contracts();
    assert(base_contract.get_Owner() == owner(), 'Invalid owner');
}
