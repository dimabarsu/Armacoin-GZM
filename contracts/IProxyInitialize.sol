// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IProxyInitialize {
    function initialize(string calldata name, string calldata symbol, uint8 decimals, uint256 amount, uint256 maxSupply, bool mintable, bool mineable, address owner) external;
}