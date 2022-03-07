// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './BEP20UpgradeableProxy.sol';
import './IProxyInitialize.sol';
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract BEP20TokenFactory is Ownable{

    address public logicImplement;

    event TokenCreated(address indexed token);

    constructor(address _logicImplement) public {
        logicImplement = _logicImplement;
    }

    function createBEP20Token(string calldata name, string calldata symbol, uint8 decimals, uint256 amount, uint256 maxSupply, bool mintable, bool mineable, address bep20Owner, address proxyAdmin) external onlyOwner returns (address) {
        BEP20UpgradeableProxy proxyToken = new BEP20UpgradeableProxy(logicImplement, proxyAdmin, "");

        IProxyInitialize token = IProxyInitialize(address(proxyToken));
        token.initialize(name, symbol, decimals, amount, maxSupply, mintable, mineable, bep20Owner);
        emit TokenCreated(address(token));
        return address(token);
    }
}