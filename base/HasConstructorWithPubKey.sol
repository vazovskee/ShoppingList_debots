
pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;

abstract contract HasConstructorWithPubKey {
    constructor(uint256 pubkey) public {}
}
