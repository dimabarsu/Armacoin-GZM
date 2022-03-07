//const BEP20TokenImplementation = artifacts.require("BEP20TokenImplementation");
const BEP20ArmacoinImplementation = artifacts.require("BEP20ArmacoinImplementation");
const BEP20ArmacoinImplementationV1 = artifacts.require("BEP20ArmacoinImplementationV1");
const ApproveAndCallFallBackTest = artifacts.require("ApproveAndCallFallBackTest");
const BEP20TokenFactory = artifacts.require("BEP20TokenFactory");

const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const fs = require('fs');

module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    await deployer.deploy(BEP20ArmacoinImplementation);
    await deployer.deploy(BEP20ArmacoinImplementationV1);
    await deployer.deploy(ApproveAndCallFallBackTest);
    await deployer.deploy(BEP20TokenFactory, BEP20ArmacoinImplementation.address);
  });
};
