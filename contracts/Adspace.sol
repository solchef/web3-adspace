// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract AdSpace is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint256;
    using SafeMath for uint8;

    //---------------------------------------------------------------------
    //-------------------------- STRUCTS -----------------------------------
    //---------------------------------------------------------------------
    struct Pool {
        uint256 deposit_amount; //Deposited Amount
        uint256 Deposit_creation_time; //The time when the Ad creation was made
        bool returned; //Specifies if the funds were withdrawed
        uint256 alreadyWithdrawedAmount;
        // string adIpfsUrl;
    }

    struct Account {
        address referral;
    }

    //---------------------------------------------------------------------
    //-------------------------- EVENTS -----------------------------------
    //---------------------------------------------------------------------

    /**
     *   @dev Emitted when the pool value changes
     */
    event adsPoolUpdated(uint256 newAdpool);

    /**
     *   @dev Emitted when a user tries to send an amount
     *       of token greater than the one in the pool
     */

    event adsPoolExhausted();

    /**
     *   @dev Emitted when a new Deposit is issued
     */
    event NewDeposit(uint256 depositAmount, address from);

    /**
     *   @dev Emitted when a new Deposit is withdrawed
     */

    event PoolWithDraw(uint256 depositID, uint256 amount);

    /**
     *   @dev Emitted when an Adspace reward is sent
     */

    event AdRewardSent(address account, uint256 reward);

    /**
     *   @dev Emitted when an user  withdraws their reward
     */

    event rewardWithdrawed(address account);

    /**
     *   @dev Emitted when the machine is stopped (500.000 tokens)
     */
    event machineStopped();

    /**
     *   @dev Emitted when the subscription is stopped (400.000 tokens)
     */
    event subscriptionStopped();

    //--------------------------------------------------------------------
    //-------------------------- GLOBALS -----------------------------------
    //--------------------------------------------------------------------

    mapping(address => Pool[]) private Pool; /// @dev Map that contains account's stakes

    address private redCrystalAddress;
    address private blueCrystalAddress;
    address private micTokenAddress;

    ERC20 private ERC20Interface;

    uint256 private redCrystalPool; //The pool where adredCrystalPools Tokens are taken
    uint256 private blueCrystalPool; //The pool where ads blueCrystalPool are taken
    uint256 private micTokenPool; //The pool  where micTokenPool Tokens are taken

    uint256 private pauseTime; //Time when the machine paused
    uint256 private stopTime; //Time when the machine stopped

    address[] private activeAccounts; //Store both Buter account and referral

    uint256 private constant _DECIMALS = 18;

    uint256 private constant _MIN_Deposit_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_Deposit_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_TOKEN_SUPPLY_LIMIT = 25000 * (10**_DECIMALS);
    uint256 private constant _MIDTERM_TOKEN_SUPPLY_LIMIT = 25000 * (10**_DECIMALS);

    constructor() public {
        redCrystalPool = 0;
        blueCrystalPool = 0;
        micTokenPool = 0;
        amount_supplied = _MAX_TOKEN_SUPPLY_LIMIT; //The total amount of token released

        micTokenAddress = address(0);
        redCrystalAddress = address(1);
        blueCrystalAddress = address(2);
    }

    //--------------------------------------------------------------------
    //-------------------------- FUNCTIONS -----------------------------------
    //--------------------------------------------------------------------

    function setTokenAddress(address _micTokenAddress,address _redCrystalAddress, address _blueCrystalAddress ) external onlyOwner {
        require(Address.isContract(_micTokenAddress), "The mictoken address does not point to a contract");
        require(Address.isContract(_redCrystalAddress), "The red crystal address does not point to a contract");
        require(Address.isContract(_blueCrystalAddress), "The bluecrystal address does not point to a contract");

        micTokenAddress = _micTokenAddress,
        redCrystalAddress = _redCrystalAddress;
        blueCrystalAddress = _blueCrystalAddress;

        ERC20Interface = ERC20(tokenAddress);
    }

    function isTokenSet() external view returns (bool) {
        if (micTokenAddress == address(0)) return false;
        if (redCrystalAddress == address(1)) return false;
        if (blueCrystalAddress == address(2)) return false;
        return true;
    }

    function getMicTokenAddress() external view returns (address) {
        return micTokenAddress;
    }

    function getblueCrystalTokenAddress() external view returns (address) {
        return redCrystalAddress;
    }

    function getredCrystalTokenAddress() external view returns (address) {
        return blueCrystalAddress;
    }

    function topUpRedCrystal(uint256 _amount) external onlyOwner nonReentrant {
        require(redCrystalAddress != address(1), "The redCrystal  Token Contract is not specified");

        blueCrystalPool = blueCrystalPool.add(_amount);

        if (ERC20Interface.transferFrom(msg.sender, address(this), _amount)) {
            //Emit the event to update the UI
            emit blueCrystalPoolUpdated(blueCrystalPool);
        } else {
            revert("Unable to tranfer funds");
        }
    }


     function topUpBlueCrystal(uint256 _amount) external onlyOwner nonReentrant {
        require(redCrystalAddress != address(2), "The redCrystal  Token Contract is not specified");

        blueCrystalPool = blueCrystalPool.add(_amount);

        if (ERC20Interface.transferFrom(msg.sender, address(this), _amount)) {
            //Emit the event to update the UI
            emit blueCrystalPoolUpdated(blueCrystalPool);
        } else {
            revert("Unable to tranfer funds");
        }
    }


    function getAllAccount() external view returns (address[] memory) {
        return activeAccounts;
    }

    function finalShutdown() external onlyOwner nonReentrant {
        uint256 machineAmount = getMachineBalance();

        if (!ERC20Interface.transfer(owner(), machineAmount)) {
            revert("Unable to transfer funds");
        }
    }
