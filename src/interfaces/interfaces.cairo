mod interfaces {
    use starknet::ContractAddress;


    #[starknet::interface]
    trait IERC20MetadataOld<TContractState> {
        fn name(self: @TContractState) -> felt252;
        fn symbol(self: @TContractState) -> felt252;
    }

    #[starknet::interface]
    trait IERC721<TContractState> {
        fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
        fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
        fn safe_transfer_from(
            ref self: TContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        );
        fn transfer_from(
            ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        );
        fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
        fn set_approval_for_all(
            ref self: TContractState, operator: ContractAddress, approved: bool
        );
        fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
        fn is_approved_for_all(
            self: @TContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool;
    }

    #[starknet::interface]
    trait IERC721CamelOnly<TContractState> {
        fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
        fn ownerOf(self: @TContractState, tokenId: u256) -> ContractAddress;
        fn safeTransferFrom(
            ref self: TContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        );
        fn transferFrom(
            ref self: TContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        );
        fn setApprovalForAll(ref self: TContractState, operator: ContractAddress, approved: bool);
        fn getApproved(self: @TContractState, tokenId: u256) -> ContractAddress;
        fn isApprovedForAll(
            self: @TContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool;
    }


    #[starknet::interface]
    trait IERC721Metadata<TContractState> {
        fn name(self: @TContractState) -> ByteArray;
        fn symbol(self: @TContractState) -> ByteArray;
        fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    }

    #[starknet::interface]
    trait IERC721CamelMetadata<TContractState> {
        fn tokenURI(self: @TContractState, token_id: u256) -> ByteArray;
    }

    #[starknet::interface]
    trait IERC721Enumberable<TContractState> {
        fn get_all_tokens_for_owner(self: @TContractState, owner: ContractAddress) -> Array<u256>;
    }
}
