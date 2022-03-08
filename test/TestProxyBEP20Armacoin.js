const truffleAssert = require('truffle-assertions');

const BEP20ArmacoinImplementation = artifacts.require("BEP20ArmacoinImplementation");
const BEP20TokenFactory = artifacts.require("BEP20TokenFactory");

const BEP20ArmacoinImplementationV1 = artifacts.require("BEP20ArmacoinImplementationV1");
const ApproveAndCallFallBackTest = artifacts.require("ApproveAndCallFallBackTest");

const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const fs = require('fs');

require('chai')
.use(require('chai-as-promised'))
.should()

let bep20ArmacoinTokenAddress;

contract('Upgradeable BEP20 Armacoin token', (accounts) => {
    it('Create Token', async () => {
        const BEP20TokenFactoryInstance = await BEP20TokenFactory.deployed();
        bep20FactoryOwner = accounts[0];
        bep20Owner = accounts[1];
        proxyAdmin = accounts[0];
        // Create mineable token
        // FAILURE: amount exceeds max supply
        await await BEP20TokenFactoryInstance.createBEP20Token("Arma Coin", "GZM", 8, web3.utils.toBN(1e9), web3.utils.toBN(1), true, true, bep20Owner, proxyAdmin, {from: bep20FactoryOwner}).should.be.rejected;
        // SUCCESS: token creates
        const tx = await BEP20TokenFactoryInstance.createBEP20Token("Arma Coin", "GZM", 8, 500000000000000, web3.utils.toBN(1000000000), true, true, bep20Owner, proxyAdmin, {from: bep20FactoryOwner});
        truffleAssert.eventEmitted(tx, "TokenCreated",(ev) => {
            bep20ArmacoinTokenAddress = ev.token;
            return true;
        });
    });
    it('Test bep20 query methods', async () => {
        const jsonFile = "test/abi/BEP20ArmacoinImplementation.json";
        const abi = JSON.parse(fs.readFileSync(jsonFile));

        bep20Owner = accounts[1];

        const bep20 = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);

        const name = await bep20.methods.name().call({from: bep20Owner});
        assert.equal(name, "Arma Coin", "wrong token name");

        const symbol = await bep20.methods.symbol().call({from: bep20Owner});
        assert.equal(symbol, "GZM", "wrong token symbol");

        const decimals = await bep20.methods.decimals().call({from: bep20Owner});
        assert.equal(decimals, 8, "wrong token decimals");

        const totalSupply = await bep20.methods.totalSupply().call({from: bep20Owner});
        assert.equal(totalSupply, 500000000000000, "wrong totalSupply");
       
        const maxSupply = await bep20.methods.maxSupply().call({from: bep20Owner});
        assert.equal(maxSupply, 100000000000000000, "wrong maxSupply");

        const bep20OwnerBalance = await bep20.methods.balanceOf(bep20Owner).call({from: bep20Owner});
        assert.equal(bep20OwnerBalance, 500000000000000, "wrong balance");

        const owner = await bep20.methods.getOwner().call({from: bep20Owner});
        assert.equal(owner, bep20Owner, "wrong owner");
    });
    it('Test bep20 transaction methods', async () => {
        const jsonFile = "test/abi/IBEP20.json";
        const abi = JSON.parse(fs.readFileSync(jsonFile));

        bep20Owner = accounts[1];

        const bep20 = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);

        const balanceOld = await bep20.methods.balanceOf(accounts[2]).call({from: bep20Owner});
        assert.equal(balanceOld, web3.utils.toBN(0), "wrong balance");
        // SUCCESS
        await bep20.methods.transfer(accounts[2], 100000000000000).send({from: bep20Owner});
        // FAILURE: transfer amount exceeds total supply
        await await bep20.methods.transfer(accounts[2], web3.utils.toBN(1e17)).send({from: bep20Owner}).should.be.rejected;
        // Check the balance of account[2]
        const balanceNew = await bep20.methods.balanceOf(accounts[2]).call({from: bep20Owner});
        assert.equal(balanceNew, web3.utils.toBN(100000000000000), "wrong balance");
        // Check the balance of account[1]
        const balanceAcc1AfterTrnsfr = await bep20.methods.balanceOf(accounts[1]).call({from: bep20Owner});
        assert.equal(balanceAcc1AfterTrnsfr, web3.utils.toBN(400000000000000), "wrong balance");
        // Check the approved transfer and allowance
        await bep20.methods.approve(accounts[3], web3.utils.toBN(1e8)).send({from: bep20Owner});
        let allowance = await bep20.methods.allowance(bep20Owner, accounts[3]).call({from: accounts[3]});
        assert.equal(allowance, web3.utils.toBN(1e8), "wrong allowance");
        // FAILURE: amount exceeds alowance, transfer will be rejected
        await await bep20.methods.transferFrom(bep20Owner, accounts[4], web3.utils.toBN(2e8)).send({from: accounts[3]}).should.be.rejected;
        // SUCCESS: transfer will not be rejected
        await bep20.methods.transferFrom(bep20Owner, accounts[4], web3.utils.toBN(1e8)).send({from: accounts[3]});
        const balance = await bep20.methods.balanceOf(accounts[4]).call({from: accounts[4]});
        assert.equal(balance, web3.utils.toBN(1e8), "wrong balance");
        // Check unaproved alowance
        allowance = await bep20.methods.allowance(bep20Owner, accounts[3]).call({from: accounts[3]});
        assert.equal(allowance, web3.utils.toBN(0), "wrong allowance");
        // Balance of Account[1] after all transfers
        const balanceAcc1AfterSecondTrnsfr = await bep20.methods.balanceOf(accounts[1]).call({from: bep20Owner});
        assert.equal(balanceAcc1AfterSecondTrnsfr, web3.utils.toBN(399999900000000), "wrong balance");
    });
    it('Test mint and burn', async () => {
        const jsonFile = "test/abi/BEP20ArmacoinImplementation.json";
        const abi = JSON.parse(fs.readFileSync(jsonFile));

        bep20Owner = accounts[1];

        const bep20 = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);

        let totalSupply = await bep20.methods.totalSupply().call({from: bep20Owner});
        assert.equal(totalSupply, 500000000000000, "wrong totalSupply");
        // Balance before mint
        const balanceBeforeMint = await bep20.methods.balanceOf(accounts[1]).call({from: bep20Owner});
        assert.equal(balanceBeforeMint, 399999900000000, "wrong balance");
        // SUCCESS: mint 500000000000000 GZM
        await bep20.methods.mint(500000000000000).send({from: bep20Owner});
        const balanceAfterMint = await bep20.methods.balanceOf(accounts[1]).call({from: bep20Owner});
        assert.equal(balanceAfterMint, 899999900000000, "wrong balance");
        // FAILURE: amount exceeds max supply
        await await bep20.methods.mint(web3.utils.toBN(9e18)).send({from: bep20Owner}).should.be.rejected;
        // FAILURE: only owner can mint GZM
        await await bep20.methods.mint(500000000000000).send({from: accounts[2]}).should.be.rejected;
        // Check new total supply after minting
        totalSupply = await bep20.methods.totalSupply().call({from: bep20Owner});
        assert.equal(totalSupply, 1000000000000000, "wrong totalSupply");
        // Check the burn function
        await bep20.methods.transfer(accounts[5], 99999900000000).send({from: bep20Owner});
        await bep20.methods.burn(99999900000000).send({from: accounts[5]});
        // Check total supply after burn
        totalSupply = await bep20.methods.totalSupply().call({from: accounts[5]});
        assert.equal(totalSupply, 900000100000000, "wrong totalSupply"); 
    });
    it('Test message fee setup', async () => {
        const jsonFile = "test/abi/BEP20ArmacoinImplementation.json";
        const abi = JSON.parse(fs.readFileSync(jsonFile));

        bep20Owner = accounts[1];

        const bep20 = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);

        // Check the message fee: should be 0
        let messageFee = await bep20.methods.getMessageFee().call({from: accounts[5]});
        assert.equal(messageFee, 0,"should be 0");

        // Setup message fee as 100000000: success
        let messageFeeSet = await bep20.methods.addMessageFee(100000000).send({from: bep20Owner});
        let messageFeeAfter = await bep20.methods.getMessageFee().call({from: accounts[5]});
        assert.equal(messageFeeAfter, 100000000, 'is correct');
        // Setup message fee as 100000000: failure
        await await bep20.methods.addMessageFee(100000000).send({from: accounts[3]}).should.be.rejected;
    });
    it('Test message storage', async () => {
        const jsonFile = "test/abi/BEP20ArmacoinImplementation.json";
        const abi = JSON.parse(fs.readFileSync(jsonFile));

        bep20Owner = accounts[1];

        const bep20 = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);
        // Check the ballance of Accounts[5]
        const ballAcc5 = await bep20.methods.balanceOf(accounts[5]).call({from: accounts[5]});
        assert.equal(ballAcc5, 0, "should be zero");

        await bep20.methods.addMessage(accounts[5], "Test message").send({from: bep20Owner});

        let message = await bep20.methods.getMessage(accounts[5]).call({from: bep20Owner});
        assert.equal(message, 'Test message', "wrong message");
        // Check the balance of Accounts[5] after message added
        const ballAcc5new = await bep20.methods.balanceOf(accounts[5]).call({from: accounts[5]});
        assert.equal(ballAcc5new, 100000000, "should be 100000000");
    });
    it('Test mining setup', async () => {
        const jsonFile = "test/abi/BEP20ArmacoinImplementation.json";
        const abi = JSON.parse(fs.readFileSync(jsonFile));

        bep20Owner = accounts[1];

        const bep20 = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);
        //is mineable
        let mineable = await bep20.methods.mineable().call({from: bep20Owner});
        assert.equal(mineable, true, "true is correct");

        let ec = await bep20.methods.epochCount().call({from: bep20Owner});
        //console.log(ec);
        assert.equal(ec, 1, "correct");
        //reward is accessible
        let reward = await bep20.methods.getMiningReward().call({from: accounts[2]});
        //console.log(reward);
        assert.equal(reward, 188997300000000, "correct");
    });
    it('Test ApproveAndCallFallBack', async () => {
        proxyAdmin = accounts[0];
        bep20Owner = accounts[1];

        let jsonFile = "test/abi/UpgradeProxy.json";
        let abi = JSON.parse(fs.readFileSync(jsonFile));

        const bep20Proxy = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);
        let newVer = await bep20Proxy.methods.upgradeTo(BEP20ArmacoinImplementationV1.address).send({from: proxyAdmin});
        assert.equal(newVer.events.Upgraded.event, 'Upgraded', "should be upgraded");

        jsonFile = "test/abi/BEP20ArmacoinImplementationV1.json";
        abi = JSON.parse(fs.readFileSync(jsonFile));

        const bep20 = new web3.eth.Contract(abi, bep20ArmacoinTokenAddress);
        let messageFee = await bep20.methods.getMessageFee().call({from: bep20Owner});
        await bep20.methods.approveAndCall(ApproveAndCallFallBackTest.address, web3.utils.toBN(1e18),web3.utils.hexToBytes("0x")).send({from: bep20Owner});
    });
    
});
