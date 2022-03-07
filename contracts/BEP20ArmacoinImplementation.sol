// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./IBEP20.sol";
import "./EIP918Interface.sol";
import "openzeppelin-solidity/contracts/GSN/Context.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/proxy/Initializable.sol";

contract BEP20ArmacoinImplementation is Context, IBEP20, EIP918Interface, Initializable {
    using SafeMath for uint256;
    /**
     * @dev Mapping for storing messages
     */
    mapping(address => string) private _messages; 
    uint256 private _MessageFee;
    event MessageFeeSet(uint256 fee);
    /**
     * @dev Sets initial minining parameters
     */   
    uint256 public latestDifficultyPeriodStarted;
    uint256 public epochCount;//number of 'blocks' mined
    //a little number
    uint256 public  _MINIMUM_TARGET = power(2,16);
    //a big number is easier ; just find a solution that is smaller
    //uint public  _MAXIMUM_TARGET = 2**224;  bitcoin uses 224
    uint256 public  _MAXIMUM_TARGET = power(2,224); //bitcoin uses 224
    uint256 public miningTarget;
    bytes32 public challengeNumber;   //generate a new one when a new reward is minted
    address public lastRewardTo;
    uint256 public lastRewardAmount;
    uint256 public lastRewardEthBlockNumber;
    // a bunch of maps to know where this is going (pun intended)
    uint256 public _MAX_MESSAGE_LENGTH = 360;
    //
    mapping(bytes32 => bytes32) public solutionForChallenge;
    mapping(uint256 => uint256) public targetForEpoch;
    mapping(uint256 => uint256) public timeStampForEpoch;
    /**
     * @dev BEP compliant variables
     */
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private _maxSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    bool private _mintable;
    bool private _mineable;

    constructor() public {
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev sets initials supply, owner, minting and mining opions
     */
    function initialize(string memory name, string memory symbol, uint8 decimals, uint256 amount, uint256 maxSupply, bool mintable, bool mineable, address owner) public initializer {
        _owner = owner;
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _mintable = mintable;
        _maxSupply = uint256(maxSupply).mul(power(10,uint256(decimals)));
        //
        require(amount <= _maxSupply,"The amount should not exceed max supply");
        _mineable = mineable;
        _mint(owner, amount);
        //
        _MessageFee = 0;
        //
        targetForEpoch[epochCount] = _MAXIMUM_TARGET;
        challengeNumber = "GENESIS_BLOCK";
        solutionForChallenge[challengeNumber] = "42"; // ahah yes
        timeStampForEpoch[epochCount] = block.timestamp;
        latestDifficultyPeriodStarted = block.number;
        epochCount = epochCount.add(1);
        targetForEpoch[epochCount] = _MAXIMUM_TARGET;
        miningTarget = _MAXIMUM_TARGET;
    }

    /**
    * @dev Leaves the contract without owner. It will not be possible to call
    * `onlyOwner` functions anymore. Can only be called by the current owner.
    *
    * NOTE: Renouncing ownership will leave the contract without an owner,
    * thereby removing any functionality that is only available to the owner.
    */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     * @dev Returns if the token is mintable or not
     */
    function mintable() external view returns (bool) {
        return _mintable;
    }

    /**
     * @dev Returns if the token is mineable or not
     */
    function mineable() external view returns (bool){
        return _mineable;
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external override view returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external override view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external override view returns (string memory) {
        return _symbol;
    }

    /**
    * @dev Returns the token name.
    */
    function name() external override view returns (string memory) {
        return _name;
    }

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev BEP20 like-maxSupply.
     */
    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) external override view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev See {BEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {BEP20-allowance}.
     */
    function allowance(address owner, address spender) external override view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {BEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     * - `_mintable` must be true
     */
    function mint(uint256 amount) external onlyOwner returns (bool) {
        require(_mintable, "BEP20: This token is not mintable");
        _mint(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Creates tokens by means of POW mining algorithm, increasing 
     * total supply.
     */
    function mine(uint256 nonce, bytes32 challenge_digest) public override returns (bool success){
        require(_mineable, "BEP20: This token is not mineable");
        //the PoW must contain work that includes a recent ethereum (BSC) block hash (challenge number) and the msg.sender's address to prevent MITM attacks
        bytes32 digest =  keccak256(abi.encodePacked(challengeNumber, msg.sender, nonce));
        //the challenge digest must match the expected
        if (digest != challenge_digest) revert();
        //the digest must be smaller than the target
        if(uint256(digest) > miningTarget) revert();
        //only allow one reward for each challenge
        bytes32 solution = solutionForChallenge[challenge_digest];
        solutionForChallenge[challengeNumber] = digest;
        if(solution != 0x0) revert();  //prevent the same answer from awarding twice
        uint256 reward_amount = getMiningReward();
        // minting limit is _maxSupply
        require(_totalSupply.add(reward_amount) <= _maxSupply,"BEP20: Can not mine due to limit of max supply");
        _balances[msg.sender] = _balances[msg.sender].add(reward_amount);
        _totalSupply = _totalSupply.add(reward_amount);
        //set readonly diagnostics data
        lastRewardTo = msg.sender;
        lastRewardAmount = reward_amount;
        lastRewardEthBlockNumber = block.number;
        _startNewMiningEpoch();
        emit Mint(msg.sender, reward_amount, epochCount, challengeNumber);
       return true;
    }

    //a new 'block' to be mined
    function _startNewMiningEpoch() internal {
        timeStampForEpoch[epochCount] = block.timestamp;
        epochCount = epochCount.add(1);
    
      //Difficulty adjustment following the DigiChieldv3 implementation (Tempered-SMA)
      // Allows more thorough protection against multi-pool hash attacks
      // https://github.com/zawy12/difficulty-algorithms/issues/9
        miningTarget = _reAdjustDifficulty(epochCount);
      //make the latest ethereum block hash a part of the next challenge for PoW to prevent pre-mining future blocks
      //do this last since this is a protection mechanism in the mint() function
      challengeNumber = blockhash(block.number.sub(1));
    }

    //https://github.com/zawy12/difficulty-algorithms/issues/21
    //readjust the target via a tempered EMA
    function _reAdjustDifficulty(uint256 _epoch) internal returns (uint256) {
        uint256 timeTarget = 300;  // We want miners to spend 5 minutes to mine each 'block'
        uint256 N = 6180;          //N = 1000*n, ratio between timeTarget and windowTime (31-ish minutes)
                                // (Ethereum doesn't handle floating point numbers very well)
        uint256 elapsedTime = timeStampForEpoch[_epoch.sub(1)].sub(timeStampForEpoch[_epoch.sub(2)]); // will revert if current timestamp is smaller than the previous one
        targetForEpoch[_epoch] = (targetForEpoch[_epoch.sub(1)].mul(10000)).div( N.mul(3920).div(N.sub(1000).add(elapsedTime.mul(1042).div(timeTarget))).add(N));
        //              newTarget   =   Tampered EMA-retarget on the last 6 blocks (a bit more, it's an approximation)
	// 				Also, there's an adjust factor, in order to correct the delays induced by the time it takes for transactions to confirm
	//				Difficulty is adjusted to the time it takes to produce a valid hash. Here, if we set it to take 300 seconds, it will actually take 
	//				300 seconds + TxConfirmTime to validate that block. So, we wad a little % to correct that lag time.
	//				Once Ethereum scales, it will actually make block times go a tad faster. There's no perfect answer to this problem at the moment
        latestDifficultyPeriodStarted = block.number;
        return targetForEpoch[_epoch];
    }

    //this is a recent ethereum block hash, used to prevent pre-mining future blocks
    function getChallengeNumber() public view override returns (bytes32) {
        return challengeNumber;
    }

    //the number of zeroes the digest of the PoW solution requires.  Auto adjusts
     function getMiningDifficulty() public view override returns (uint256) {
        return _MAXIMUM_TARGET.div(targetForEpoch[epochCount]);
    }

    function getMiningTarget() public view override returns (uint256) {
       return targetForEpoch[epochCount];
    }

    function power(uint256 n, uint256 e) internal pure returns (uint256) {
        if (e == 0) {
            return 1;
        } else if (e == 1) {
            return n;
        } else {
            uint256 p = power(n, e.div(2));
            p = p.mul(p);
            if (e.mod(2) == 1) {
                p = p.mul(n);
            }
            return p;
        }
    }

    //There's no limit to the coin supply
    //reward follows more or less the same emmission rate as coins'. 5 minutes per block / 105120 block in one year (roughly)
    function getMiningReward() public view override returns (uint256) {
        bytes32 digest = solutionForChallenge[challengeNumber];
        if(epochCount > 160000) return(uint256(50000).mul(power(10,uint256(_decimals))));
        if(epochCount > 140000) return(uint256(75000).mul(power(10,uint256(_decimals))));
        if(epochCount > 120000) return(uint256(125000).mul(power(10,uint256(_decimals))));
        if(epochCount > 100000) return(uint256(250000).mul(power(10,uint256(_decimals))));
        if(epochCount > 80000)  return(uint256(500000).mul(power(10,uint256(_decimals))));
        if(epochCount > 60000)  return(uint256(1000000).mul(power(10,uint256(_decimals))));
        if(epochCount > 40000)  return((uint256(keccak256(abi.encodePacked(digest))).mod(2500000)).mul(power(10,uint256(_decimals))));   // 360.0 M/day / ~25.0B Tokens in 20'000 blocks (coin supply @ 40'000th block ~  86 Billions)
        if(epochCount > 20000)  return((uint256(keccak256(abi.encodePacked(digest))).mod(3500000)).mul(power(10,uint256(_decimals))));  // 504.0 M/day / ~35.0B Tokens in 20'000 blocks (coin supply @ 20'000th block ~  51 Billions)
        return((uint256(keccak256(abi.encodePacked(digest))).mod(5000000)).mul(power(10,uint256(_decimals))));                  // 720.0 M/day / ~50.0B Tokens in 20'000 blocks 
    }


    //help debug mining software (even though challenge_digest isn't used, this function is constant and helps troubleshooting mining issues)
    function getMintDigest(uint256 _nonce, bytes32 _challenge_number) public view returns (bytes32 digesttest) {
        bytes32 digest = keccak256(abi.encodePacked(_challenge_number,msg.sender,_nonce));
        return digest;
    }

    //help debug mining software
    function checkMintSolution(uint256 _nonce, bytes32 _challenge_digest, bytes32 _challenge_number, uint256 _testTarget) public view returns (bool success) {
      bytes32 digest = keccak256(abi.encodePacked(_challenge_number,msg.sender,_nonce));
      if(uint256(digest) > _testTarget) revert();
      return(digest == _challenge_digest);
    }


    /**
   * @dev Burn `amount` tokens and decreasing the total supply.
   */
    function burn(uint256 amount) public returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "BEP20: mint to the zero address");
        // minting limit is _maxSupply
        require(_totalSupply.add(amount) <= _maxSupply,"BEP20: Can not mint due to limit of maximum supply");
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "BEP20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance"));
    }

    /**
    * @dev BEP20 style wrapper for string storage
    */
    function addMessage(address _advertiser, string memory _newMessage) public returns(bool) {
        _addMessage(_advertiser, _newMessage);
        return(true);
    }

    /**
    * @dev Stores `_newMessage` in `_advertiser's` entry in the messages mapping
    */
    function _addMessage(address _advertiser, string memory _newMessage) internal {
        //bytes memory bs = bytes(_newMessage);
        //require (bs.length <= _MAX_MESSAGE_LENGTH,"Maximum allowed message length exceeded" );
        require (_balances[msg.sender] >= _MessageFee, "The means are not sufficient");
        _balances[msg.sender] = _balances[msg.sender].sub(_MessageFee);
        _balances[_advertiser] = _balances[_advertiser].add(_MessageFee);
        
        _messages[_advertiser] = _newMessage;
        emit Transfer(msg.sender, _advertiser, _MessageFee);
    }

    /**
    * @dev Retrieves messages from `advertiser's` entry
    */
    function getMessage(address _advertiser) external view returns(string memory) {
        require(_advertiser!=address(0x0),"0x0 address exception");
        return (_messages[_advertiser]);
    }

    /***
     * @dev BEP20 style wrapper for setting a fee for messages
     */
    function addMessageFee(uint256 _fee) external onlyOwner returns(bool){
        _addMessageFee(_fee);
        return(true);
    }
    /**
     * @dev Sets `_fee` in ` fee` variable the messages mapping
     */
    function _addMessageFee(uint256 _fee) internal {
        _MessageFee = _fee;
        emit MessageFeeSet(_fee);
    }
    /**
    * @dev Retrieves message price from `MessageFee` variable
    */
    function getMessageFee() external view returns(uint256) {
        return (_MessageFee);
    }
}
