
pragma ton-solidity >= 0.35.0;

abstract contract HasConstructorWithPubKey {
    constructor(uint256 pubkey) public {}
}
