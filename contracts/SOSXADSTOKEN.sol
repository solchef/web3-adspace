// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract MICMANAGER is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint256;
    using SafeMath for uint8;

    //---------------------------------------------------------------------
    //-------------------------- STRUCTS -----------------------------------
    //---------------------------------------------------------------------
    struct Purchase {
        uint256 purchase_amount;
        uint256 purchaseTime;
        uint256 purchaseAction; // 0 -no-action 1-Activate RedCrystal for referrer 2-Activate Blue Crystal for referrer
    }

    struct Account {
        address referral;
        uint256 referralPurchaseTime;
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

    event Transfer(address sender, address receiver, uint256 amount);

    /**
     *   @dev Emitted when a new purchase is made
     */
    event NewPurchase(uint256 depositAmount, address from);

    /**
     *   @dev Emitted when a new Deposit is withdrawed
     */

    /**
     *   @dev Emitted when an crystals reward is sent
     */

    event redCrystalRewardSent(address account, uint256 reward);
    event blueCrystalRewardSent(address account, uint256 reward);

    /**
     *   @dev Emitted when an user  withdraws their reward
     */

    /**
     *   @dev Emitted when the machine is stopped by the admin.
     */
    event machineStopped();

    //--------------------------------------------------------------------
    //-------------------------- GLOBALS -----------------------------------
    //--------------------------------------------------------------------

    // mapping(address => Pool[]) private Pool; /// @dev Map that contains account's stakes
    mapping(address => Purchase[]) private purchase;

    address private redCrystalAddress;
    address private blueCrystalAddress;
    address private micTokenAddress;
    address payable ethVaultAddress;

    ERC20 private ERC20InterfaceMic;
    ERC20 private ERC20InterfaceRedCryStal;
    ERC20 private ERC20InterfaceBlueCrystal;

    uint256 private redCrystalPool; //The pool where adredCrystalPools Tokens are taken
    uint256 private blueCrystalPool; //The pool where ads blueCrystalPool are taken
    uint256 private micTokenPool; //The pool  where micTokenPool Tokens are taken

    uint256 private pauseTime; //Time when the machine paused
    uint256 private stopTime; //Time when the machine stopped

    uint256 private micEthPrice;

    mapping(address => address[]) private referral; //Store account that was used for the referral

    mapping(address => Account) private account_referral; //Store the setted account referral

    address[] private activeAccounts; //Store both user account and referral

    uint256 private constant _DECIMALS = 18;

    uint256 private constant _MIN_PURCHASE_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_PURCHASE_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_TOKEN_SUPPLY_LIMIT = 25000 * (10**_DECIMALS);

    uint256 private constant _MIDTERM_TOKEN_SUPPLY_LIMIT = 25000 * (10**_DECIMALS);

    constructor() {
        redCrystalPool = 0;
        blueCrystalPool = 0;
        micTokenPool = 0;
        // amount_supplied = _MAX_TOKEN_SUPPLY_LIMIT; //The total amount of token released

        micTokenAddress = address(0);
        redCrystalAddress = address(0);
        blueCrystalAddress = address(0);
    }

    //--------------------------------------------------------------------
    //--------------------------OWNER FUNCTIONS -----------------------------------
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

    function setEthVaultAddress(address payable _ethVaultAddress) external onlyOwner {
        ethVaultAddress = _ethVaultAddress;
    }

    function setmicEthPrice(uint256 _micPrice) external onlyOwner {
        micEthPrice = _micPrice;
    }

    function isTokenSet() external view returns (bool) {
        if (micTokenAddress == address(0)) return false;
        if (redCrystalAddress == address(0)) return false;
        if (blueCrystalAddress == address(0)) return false;

        return true;
    }

    function getMicEthPrice() external view returns (uint256) {
        return micEthPrice;
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

    function topUpMicToken(uint256 _amount) external onlyOwner nonReentrant {
        require(micTokenAddress != address(0), "The Mic Token Contract is not specified");

        if (ERC20InterfaceMic.transferFrom(msg.sender, address(this), _amount)) {
            //Emit the event to update the UI
            micTokenPool = micTokenPool.add(_amount);
            emit micTokenPoolUpdated(micTokenPool);
        } else {
            revert("Unable to tranfer funds");
        }
    }

    function topUpRedCrystal(uint256 _amount) external onlyOwner nonReentrant {
        require(redCrystalAddress != address(0), "The redCrystal  Token Contract is not specified");

        if (ERC20InterfaceRedCryStal.transferFrom(msg.sender, address(this), _amount)) {
            //Emit the event to update the UI
            redCrystalPool = redCrystalPool.add(_amount);
            emit redCrystalPoolUpdated(redCrystalPool);
        } else {
            revert("Unable to tranfer funds");
        }
    }

    function topUpBlueCrystal(uint256 _amount) external onlyOwner nonReentrant {
        require(blueCrystalAddress != address(0), "The BlueCrystal  Token Contract is not specified");

        if (ERC20InterfaceBlueCrystal.transferFrom(msg.sender, address(this), _amount)) {
            blueCrystalPool = blueCrystalPool.add(_amount);
            //Emit the event to update the UI
            emit blueCrystalPoolUpdated(blueCrystalPool);
        } else {
            revert("Unable to tranfer funds");
        }
    }

    function finalShutdown() external onlyOwner nonReentrant {
        uint256 micAmount = getMICBalance();
        uint256 redCrystalAmount = getRedCrystalBalance();
        uint256 blueCrystalAmount = getBlueCrystalBalance();

        ERC20InterfaceMic.transfer(owner(), micAmount);
        ERC20InterfaceRedCryStal.transfer(owner(), redCrystalAmount);
        ERC20InterfaceBlueCrystal.transfer(owner(), blueCrystalAmount);
    }

    //--------------------------------------------------------------------
    //--------------------------PUBLIC FUNCTIONS -------------------------
    //--------------------------------------------------------------------

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

    function getMICBalance() internal view returns (uint256) {
        return ERC20InterfaceMic.balanceOf(address(this));
    }

    function getRedCrystalBalance() internal view returns (uint256) {
        return ERC20InterfaceRedCryStal.balanceOf(address(this));
    }

    function getBlueCrystalBalance() internal view returns (uint256) {
        return ERC20InterfaceBlueCrystal.balanceOf(address(this));
    }

    function getMachineState() external view returns (uint256) {
        return micTokenPool;
    }

    //--------------------------------------------------------------------
    //--------------------------USER -----------------------------------
    //--------------------------------------------------------------------

    function purchaseMICToken(address _referralAddress) public payable {
        require(micTokenAddress != address(0), "No contract set");

        require(ERC20InterfaceMic.balanceOf(msg.sender) < 1 * (10**_DECIMALS), "You can only hold one MIC token");

        require(msg.sender.balance >= micEthPrice, "You need to have enough ETH amount to purchase MIC");

        uint256 referrerCrystal = 0;

        uint256 _amount = 1000000000000000000;

        if (!hasReferral()) {
            // /User was referred to buy MIC token lets set and also set count for crystal token check.
            if (ERC20InterfaceMic.balanceOf(_referralAddress) > 0) {
                setReferral(_referralAddress);
                uint256 referralCount = referral[_referralAddress].length;
                if (referralCount == 1) {
                    referrerCrystal = 1;
                } else if (referralCount == 2) {
                    referrerCrystal = 2;
                } else {
                    // has received both crystals
                    referrerCrystal = 0;
                }
            } else {
                // user cannot receive referral crystals since they dont hold MIC token
            }
        }

        address buyer = msg.sender;

        Purchase memory newPurchase;
        newPurchase.purchase_amount = _amount;
        newPurchase.purchaseTime = block.timestamp;
        newPurchase.purchaseAction = referrerCrystal;
        purchase[buyer].push(newPurchase);
        activeAccounts.push(msg.sender);
        emit Transfer(msg.sender, ethVaultAddress, micEthPrice);
        // Transfer 1 MIC touser
        ERC20InterfaceMic.transfer(msg.sender, _amount);
        micTokenPool = micTokenPool.add(_amount);
        //here I am performing the transfer of the crystal to your referrer based on your count.
        if (referrerCrystal == 1) {
            ERC20InterfaceRedCryStal.transfer(_referralAddress, _amount);
        } else if (referrerCrystal == 2) {
            ERC20InterfaceBlueCrystal.transfer(_referralAddress, _amount);
        }
        emit NewPurchase(_amount, _referralAddress);
    }

    function getCurrentPurchaseAmount(uint256 _purchaseId) external view returns (uint256) {
        require(micTokenAddress != address(0), "No contract set");

        return purchase[msg.sender][_purchaseId].purchase_amount;
    }

    function getPurchaseInfo(uint256 _purchaseId)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            address
        )
    {
        Purchase memory selectedPurchase = purchase[msg.sender][_purchaseId];

        address myReferral = getMyReferral();

        return (
            selectedPurchase.purchase_amount,
            selectedPurchase.purchaseAction,
            selectedPurchase.purchaseTime,
            myReferral
        );
    }

    function getTotalPurchaseAmount() external view returns (uint256) {
        require(micTokenAddress != address(0), "No contract set");

        Purchase[] memory currentPurchase = purchase[msg.sender];
        uint256 numberOfPurchase = purchase[msg.sender].length;
        uint256 totalPurchase = 0;
        uint256 tmp;
        for (uint256 i = 0; i < numberOfPurchase; i++) {
            tmp = currentPurchase[i].purchase_amount;
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
        account.referralPurchaseTime = block.timestamp;
        account.referralRewarded = 0;
        account_referral[msg.sender] = account;

        activeAccounts.push(referer);
    }

    function getReferralCount() external view returns (uint256) {
        return referral[msg.sender].length;
    }

    function getAccountReferral() external view returns (address[] memory) {
        return referral[msg.sender];
    }

    function getMyReferral() public view returns (address) {
        Account memory myAccount = account_referral[msg.sender];
        return myAccount.referral;
    }

    function getCurrentReferrals() external view returns (address[] memory) {
        return referral[msg.sender];
    }
}
