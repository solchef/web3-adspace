// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract MICPRESALE is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint256;
    using SafeMath for uint8;

    //---------------------------------------------------------------------
    //-------------------------- STRUCTS -----------------------------------
    //---------------------------------------------------------------------
    struct Purchase {
        uint256 purchase_amount;
        uint256 purchaseTime;
        uint256 purchaseAction; // 0-no-action 1-Activate RedCrystal for referrer 2-Activate Blue Crystal for referrer
    }

    struct Account {
        address referral;
        uint256 referralRewarded;
    }

    //---------------------------------------------------------------------
    //-------------------------- EVENTS -----------------------------------
    //---------------------------------------------------------------------

    /**
     *   @dev Emitted when the pool value changes
     */
    event micTokenPoolUpdated(uint256 newMicPool);
    event redCrystalPoolUpdated(uint256 newRedCrystal);
    event blueCrystalPoolUpdated(uint256 newBlueCrystal);

    /**
     *   @dev Emitted when a user tries to send an amount
     *       of token greater than the one in the pool
     */

    event redCrystalExhausted();
    event blueCrystalPoolExhausted();

    /**
     *   @dev Emitted when a new purchase is made
     */
    event NewPurchase(uint256 depositAmount, address from);

    /**
     *   @dev Emitted when a new Deposit is withdrawed
     */

    event PoolWithDraw(uint256 depositID, uint256 amount);

    /**
     *   @dev Emitted when an crystals reward is sent
     */

    event redCrystalRewardSent(address account, uint256 reward);
    event blueCrystalRewardSent(address account, uint256 reward);

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

    // mapping(address => Pool[]) private Pool; /// @dev Map that contains account's stakes
    mapping(address => Purchase[]) private purchase;

    address private redCrystalAddress;
    address private blueCrystalAddress;
    address private micTokenAddress;

    ERC20 private ERC20InterfaceMic;
    ERC20 private ERC20InterfaceRedCryStal;
    ERC20 private ERC20InterfaceBlueCrystal;

    uint256 private redCrystalPool; //The pool where adredCrystalPools Tokens are taken
    uint256 private blueCrystalPool; //The pool where ads blueCrystalPool are taken
    uint256 private micTokenPool; //The pool  where micTokenPool Tokens are taken

    uint256 private pauseTime; //Time when the machine paused
    uint256 private stopTime; //Time when the machine stopped

    mapping(address => address[]) private referral; //Store account that used the referral
    mapping(address => Account) private account_referral; //Store the setted account referral

    address[] private activeAccounts; //Store both Buter account and referral

    uint256 private constant _DECIMALS = 18;

    uint256 private constant _MIN_DEPOSIT_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_DEPOSIT_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_TOKEN_SUPPLY_LIMIT = 25000 * (10**_DECIMALS);
    uint256 private constant _MIDTERM_TOKEN_SUPPLY_LIMIT = 25000 * (10**_DECIMALS);

    constructor() public {
        redCrystalPool = 0;
        blueCrystalPool = 0;
        micTokenPool = 0;
        // amount_supplied = _MAX_TOKEN_SUPPLY_LIMIT; //The total amount of token released

        micTokenAddress = address(0);
        redCrystalAddress = address(1);
        blueCrystalAddress = address(2);
    }

    //--------------------------------------------------------------------
    //-------------------------- FUNCTIONS -----------------------------------
    //--------------------------------------------------------------------

    function setTokenAddress(
        address _micTokenAddress,
        address _redCrystalAddress,
        address _blueCrystalAddress
    ) external onlyOwner {
        require(Address.isContract(_micTokenAddress), "The mictoken address does not point to a contract");
        require(Address.isContract(_redCrystalAddress), "The red crystal address does not point to a contract");
        require(Address.isContract(_blueCrystalAddress), "The bluecrystal address does not point to a contract");

        micTokenAddress = _micTokenAddress;
        redCrystalAddress = _redCrystalAddress;
        blueCrystalAddress = _blueCrystalAddress;

        ERC20InterfaceMic = ERC20(micTokenAddress);
        ERC20InterfaceRedCryStal = ERC20(redCrystalAddress);
        ERC20InterfaceBlueCrystal = ERC20(blueCrystalAddress);
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

    function getBlueCrystalTokenAddress() external view returns (address) {
        return redCrystalAddress;
    }

    function getRedCrystalTokenAddress() external view returns (address) {
        return blueCrystalAddress;
    }

    function topUpRedCrystal(uint256 _amount) external onlyOwner nonReentrant {
        require(redCrystalAddress != address(1), "The redCrystal  Token Contract is not specified");

        if (ERC20InterfaceRedCryStal.transferFrom(msg.sender, address(this), _amount)) {
            //Emit the event to update the UI
            redCrystalPool = redCrystalPool.add(_amount);
            emit redCrystalPoolUpdated(redCrystalPool);
        } else {
            revert("Unable to tranfer funds");
        }
    }

    function topUpBlueCrystal(uint256 _amount) external onlyOwner nonReentrant {
        require(blueCrystalAddress != address(2), "The redCrystal  Token Contract is not specified");

        if (ERC20InterfaceBlueCrystal.transferFrom(msg.sender, address(this), _amount)) {
            blueCrystalPool = blueCrystalPool.add(_amount);
            //Emit the event to update the UI
            emit blueCrystalPoolUpdated(blueCrystalPool);
        } else {
            revert("Unable to tranfer funds");
        }
    }

    function getAllAccount() external view returns (address[] memory) {
        return activeAccounts;
    }

    function getCurrentMicToken() external view returns (uint256) {
        return micTokenPool;
    }

    function getCurrentRedCrystalPool() external view returns (uint256) {
        return redCrystalPool;
    }

    function getCurrentBlueCrystalPool() external view returns (uint256) {
        return blueCrystalPool;
    }

    // function finalShutdown() external onlyOwner nonReentrant {
    //     // uint256 machineAmount = getMachineBalance();

    //     if (!ERC20Interface.transfer(owner(), machineAmount)) {
    //         revert("Unable to transfer funds");
    //     }
    // }

    function purchaseMicToken(
        uint256 _amount,
        address _referralAddress,
        uint256 _purchaseAction
    ) external nonReentrant {
        require(micTokenAddress != address(0), "No contract set");

        require(_amount >= _MIN_DEPOSIT_AMOUNT, "You must purchase at least 1 tokens");

        require(_amount <= _MAX_DEPOSIT_AMOUNT, "You must piurchase at maximum 1 tokens");

        // require(!isSubscriptionEnded(), "Subscription ended");

        address buyer = msg.sender;

        Purchase memory newPurchase;

        newPurchase.purchase_amount = _amount;
        newPurchase.purchaseTime = block.timestamp;
        newPurchase.purchaseAction = _purchaseAction;

        purchase[buyer].push(newPurchase);

        if (!hasReferral()) {
            setReferral(_referralAddress);
        }

        activeAccounts.push(msg.sender);

        if (ERC20InterfaceMic.transferFrom(msg.sender, address(this), _amount)) {
            micTokenPool = micTokenPool.add(_amount);
            //here I am performing the transfer of the crystal to your referrer based on your count.

            emit NewPurchase(_amount, _referralAddress);
        } else {
            revert("Unable to transfer funds");
        }
    }

    function getCurrentPurchaseAmount(uint256 _purchaseId) external view returns (uint256) {
        require(micTokenAddress != address(0), "No contract set");

        // return Purchase[msg.sender][_purchaseId].purchase_amount;
        return 1;
    }

    function getPurchaseInfo(uint256 _stakeID)
        external
        view
        returns (
            uint256,
            int256,
            uint256,
            address
        )
    {
        Purchase memory selectedPurchase = stake[msg.sender][_stakeID];

        address myReferral = getMyReferral();

        return (
            selectedPurchase.deposit_amount,
            selectedPurchase.purchaseAction,
            selectedPurchase.purchaseTime,
            myReferral
        );
    }

    function getTotalPurchaseAmount() external view returns (uint256) {
        require(tokenAddress != address(0), "No contract set");

        Purchase[] memory currentPurchase = purchase[msg.sender];
        uint256 numberOfPurchase = purchase[msg.sender].length;
        uint256 totalPurchase = 0;
        uint256 tmp;
        for (uint256 i = 0; i < numberOfPurchase; i++) {
            tmp = currentPurchase[i].deposit_amount;
            totalPurchase = totalPurchase.add(tmp);
        }

        return totalPurchase;
    }

    function hasReferral() public view returns (bool) {
        Account memory myAccount = account_referral[msg.sender];

        if (
            myAccount.referral == address(0) ||
            myAccount.referral == address(0x0000000000000000000000000000000000000001)
        ) {
            //If I have no referral...
            // assert(myAccount.referralAlreadyWithdrawed == 0);
            return false;
        }

        return true;
    }

    function setReferral(address referer) internal {
        require(referer != address(0), "Invalid address");
        require(!hasReferral(), "Referral already set");

        if (referer == address(0x0000000000000000000000000000000000000001)) {
            return; //This means no referer
        }

        if (referer == msg.sender) {
            revert("Referral is the same as the sender, forbidden");
        }

        referral[referer].push(msg.sender);

        Account memory account;

        account.referral = referer;
        account.referralRewarded = 0;

        account_referral[msg.sender] = account;

        activeAccounts.push(referer);
    }

    function getReferralCount() external view returns (uint256) {
        return referral[msg.sender].length;
    }

    function getAccountReferral() external view returns (address[] memory) {
        referral[msg.sender];
        return referral[msg.sender];
    }

    function getMyReferral() public view returns (address) {
        Account memory myAccount = account_referral[msg.sender];

        return myAccount.referral;
    }

    function getCurrentReferrals() external view returns (address[] memory) {
        return referral[msg.sender];
    }

    function getMICBalance() internal view returns (uint256) {
        return ERC20InterfaceMic.balanceOf(address(this));
    }

    function getMachineState() external view returns (uint256) {
        return amount_supplied;
    }
}
