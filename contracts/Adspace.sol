// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract AdSpace is Ownable, ReentrancyGuard {      
    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeMath for uint8;

    //---------------------------------------------------------------------
    //-------------------------- STRUCTS -----------------------------------
    //---------------------------------------------------------------------
    struct Deposit{
        uint deposit_amount;        //Deposited Amount
        uint Deposit_creation_time;   //The time when the Ad creation was made 
        bool returned;              //Specifies if the funds were withdrawed
        uint alreadyWithdrawedAmount;   
        string adIpfsUrl;
    }

    //---------------------------------------------------------------------
    //-------------------------- EVENTS -----------------------------------
    //---------------------------------------------------------------------

    /**
    *   @dev Emitted when the pool value changes
     */
    event AdsPoolUpdated(
        uint newAdpool
    );


    /**
    *   @dev Emitted when a user tries to send an amount
    *       of token greater than the one in the pool
     */

    event adsPoolExhausted(

    );

    /**
    *   @dev Emitted when a new Deposit is issued
     */
    event NewDeposit(
        uint depositAmount,
        address from
    );
    
    /**
    *   @dev Emitted when a new Deposit is withdrawed
     */
     
    event PoolWithDraw(
        uint depositID,
        uint amount
    );

    /**
    *   @dev Emitted when an Adspace reward is sent
     */

    event AdRewardSent(
        address account,
        uint reward
    );

       /**
    *   @dev Emitted when an user  withdraws their reward
     */

    event rewardWithdrawed(
        address account
    );


    /**
    *   @dev Emitted when the machine is stopped (500.000 tokens)
     */
    event machineStopped(

    );

    /**
    *   @dev Emitted when the subscription is stopped (400.000 tokens)
     */
    event subscriptionStopped(

    );

    //--------------------------------------------------------------------
    //-------------------------- GLOBALS -----------------------------------
    //--------------------------------------------------------------------

    mapping (address => Deposits[]) private Deposits; /// @dev Map that contains account's Deposits

    address private tokenAddress;

    ERC20 private ERC20Interface;

    uint private adsPool;    //The adsPool where ads Tokens are taken

    uint256 private amount_supplied;    //Store the remaining token to be supplied

    uint private pauseTime;     //Time when the machine paused
    uint private stopTime;      //Time when the machine stopped

    address[] private activeAccounts;   //Store both Depositer account
    
    uint256 private constant _DECIMALS = 18;

    uint256 private constant _MIN_Deposit_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_Deposit_AMOUNT = 100000 * (10**_DECIMALS);

    uint private constant _REFERALL_REWARD = 333; //0.333% per day

    uint256 private constant _MAX_TOKEN_SUPPLY_LIMIT = 10000000000 * (10**_DECIMALS);
    uint256 private constant _MIDTERM_TOKEN_SUPPLY_LIMIT = 1000000000 * (10**_DECIMALS);




    constructor() public {
        adsPool = 0;
        amount_supplied = _MAX_TOKEN_SUPPLY_LIMIT;    //The total amount of token released
        tokenAddress = address(0);
    }

    //--------------------------------------------------------------------
    //-------------------------- FUNCTIONS -----------------------------------
    //--------------------------------------------------------------------

    function setTokenAddress(address _tokenAddress) external onlyOwner {
        require(Address.isContract(_tokenAddress), "The address does not point to a contract");

        tokenAddress = _tokenAddress;
        ERC20Interface = ERC20(tokenAddress);
    }

    function isTokenSet() external view returns (bool) {
        if(tokenAddress == address(0))
            return false;
        return true;
    }

    function getTokenAddress() external view returns (address){
        return tokenAddress;
    }


    function topUpAdsPool(uint _amount) external onlyOwner nonReentrant {
        require(tokenAddress != address(0), "The Token Contract is not specified");

        adsPool = adsPool.add(_amount);
    
        if(ERC20Interface.transferFrom(msg.sender, address(this), _amount)){
            //Emit the event to update the UI
            emit adsPoolUpdated(adsPool);
        }else{
            revert("Unable to tranfer funds");
        }

    }

   
    
    function withDrawAdsPoolEarnings(uint _amount) external onlyOwner nonReentrant{
        require(tokenAddress != address(0), "The Token Contract is not specified");
        require(adsPool.sub(_amount) >= 0, "Not enough token");
        
        adsPool = adsPool.sub(_amount);

        if(ERC20Interface.transfer(msg.sender, _amount)){
            //Emit the event to update the UI
            emit adsPoolUpdated(adsPool);
        }else{
            revert("Unable to tranfer funds");
        }

    }
  

    function getAllAccount() external view returns (address[] memory){
        return activeAccounts;
    }

  
    function finalShutdown() external onlyOwner nonReentrant{

        uint machineAmount = getMachineBalance();

        if(!ERC20Interface.transfer(owner(), machineAmount)){
            revert("Unable to transfer funds");
        }
    }

    //--------------------------------------------------------------------
    //-------------------------- CLIENTS -----------------------------------
    //--------------------------------------------------------------------

    /**
    *   @dev Deposit token verifying all the contraint
    *   @notice Deposit tokens
    *   @param _amount Amoun to Deposit
     */

    function DepositToAdsPool(uint _amount, string _adIpfsUrl) external nonReentrant {

        require(tokenAddress != address(0), "No contract set");

        require(!isSubscriptionEnded(), "Subscription ended");

        address Depositr = msg.sender;
        Deposit memory newDeposit;

        newDeposit.deposit_amount = _amount;
        newDeposit.returned = false;
        newDeposit.Deposit_creation_time = block.timestamp;
        newDeposit.alreadyWithdrawedAmount = 0;
        newDeposit.adIpfsUrl = _adIpfsUrl;

        Deposit[Depositr].push(newDeposit);

        activeAccounts.push(msg.sender);

        if(ERC20Interface.transferFrom(msg.sender, address(this), _amount)){
            emit NewDeposit(_amount, msg.sender);
        }else{
            revert("Unable to transfer funds");
        }
        
    }

    /**
    *   @dev Return the Depositd tokens, requiring that the Deposit was
    *        not alreay withdrawed and that the staking clasw duration has been reached
    *   @notice Return Depositd token
    *   @param _DepositID The ID of the Deposit to be returned
     */
    function withDrawFromAdsPool(uint _DepositID) external nonReentrant returns (bool){
        Deposit memory selectedDeposit = Deposit[msg.sender][_DepositID];

        //Check if the Deposit were already withdraw
        require(selectedDeposit.returned == false, "Deposit were already returned");
        
        uint deposited_amount = selectedDeposit.deposit_amount;
        //Get the net reward
        //Sum the net reward to the total reward to withdraw
        uint total_amount = deposited_amount;

        //Only set the withdraw flag in order to disable further withdraw
        Deposit[msg.sender][_DepositID].returned = true;

        if(ERC20Interface.transfer(msg.sender, total_amount)){
            emit DepositWithdraw(_DepositID, total_amount);
        }else{
            revert("Unable to transfer funds");
        }

        return true;
    }

    function withdrawReward(uint _DepositID) external nonReentrant returns (bool){
        Deposit memory _Deposit = Deposit[msg.sender][_DepositID];

        uint rewardToWithdraw = calculateRewardToWithdraw(_DepositID);

        require(updateSuppliedToken(rewardToWithdraw), "Supplied limit reached");

        if(rewardToWithdraw > adsPool){
            revert("adsPool exhausted");
        }

        adsPool = adsPool.sub(rewardToWithdraw);

        Deposit[msg.sender][_DepositID].alreadyWithdrawedAmount = _Deposit.alreadyWithdrawedAmount.add(rewardToWithdraw);

        if(ERC20Interface.transfer(msg.sender, rewardToWithdraw)){
            emit rewardWithdrawed(msg.sender);
        }else{
            revert("Unable to transfer funds");
        }

        return true;
    }

    /**
    *   @dev Check if the provided amount is available in the adsPool
    *   If yes, it will update the adsPool value and return true
    *   Otherwise it will emit a adsPoolExhausted event and return false
     */

    function withdrawFromAdsPool(uint _amount) public nonReentrant returns (bool){
        if(_amount > adsPool){
            emit adsPoolExhausted();
            return false;
        }

        //Update the adsPool value

        adsPool = adsPool.sub(_amount);
        return true;

    }
    

    //--------------------------------------------------------------------
    //-------------------------- VIEWS -----------------------------------
    //--------------------------------------------------------------------

    /**
    * @dev Return the amount of token in the provided caller's Deposit
    * @param _DepositID The ID of the Deposit of the caller
     */
    function getCurrentDepositAmount(uint _DepositID) external view returns (uint256)  {
        require(tokenAddress != address(0), "No contract set");

        return Deposit[msg.sender][_DepositID].deposit_amount;
    }



    /**
    * @dev Return sum of all the caller's Deposit amount
    * @return Amount of Deposit
     */
    function getTotalDepositAmount() external view returns (uint256) {
        require(tokenAddress != address(0), "No contract set");

        Deposit[] memory currentDeposit = Deposit[msg.sender];
        uint nummberOfDeposit = Deposit[msg.sender].length;
        uint totalDeposit = 0;
        uint tmp;
        for (uint i = 0; i<nummberOfDeposit; i++){
            tmp = currentDeposit[i].deposit_amount;
            totalDeposit = totalDeposit.add(tmp);
        }

        return totalDeposit;
    }
    
     /**
        * @dev Return sum of all the voter Deposit amount
        * @return Amount of Deposit
     */
     
    function getVoterTotalDepositAmount(address voter) external view returns (uint256) {
        require(tokenAddress != address(0), "No contract set");
        
        Deposit[] memory currentDeposit = Deposit[voter];
        uint nummberOfDeposit = Deposit[voter].length;
        uint totalDeposit = 0;
        uint tmp;

        for (uint i = 0; i<nummberOfDeposit; i++){
            tmp = currentDeposit[i].deposit_amount;
            totalDeposit = totalDeposit.add(tmp);
        }
    
        return totalDeposit;
    }
    

    /**
    *   @dev Return all the available Deposit info
    *   @notice Return Deposit info
    *   @param _DepositID ID of the Deposit which info is returned
    *
    *   @return 1) Amount Deposited
    *   @return 2) Bool value that tells if the Deposit was withdrawed
    *   @return 3) Deposit creation time (Unix timestamp)
    *   @return 4) The eventual referAccountess != address(0), "No contract set");
    *   @return 5) The current amount
    *   @return 6) The penalty of withdraw
    */
    function getDepositInfo(uint _DepositID) external view returns(uint, bool, uint, uint){

        Deposit memory selectedDeposit = Deposit[msg.sender][_DepositID];

        uint amountToWithdraw = calculateRewardToWithdraw(_DepositID);

        return (
            selectedDeposit.deposit_amount,
            selectedDeposit.returned,
            selectedDeposit.Deposit_creation_time,
            amountToWithdraw
        );
    }


    /**
    *  @dev Get the current adsPool value
    *  @return The amount of token in the current adsPool
     */

    function getCurrentadsPool() external view returns (uint){
        return adsPool;
    }


    /**
    * @dev Get the number of active Deposit of the caller
    * @return Number of active Deposit
     */
    function getDepositCount() external view returns (uint){
        return Deposit[msg.sender].length;
    }


    function getActiveDepositCount() external view returns(uint){
        uint DepositCount = Deposit[msg.sender].length;

        uint count = 0;

        for(uint i = 0; i<DepositCount; i++){
            if(!Deposit[msg.sender][i].returned){
                count = count + 1;
            }
        }
        return count;
    }


    function getAlreadyWithdrawedAmount(uint _DepositID) external view returns (uint){
        return Deposit[msg.sender][_DepositID].alreadyWithdrawedAmount;
    }




    //--------------------------------------------------------------------
    //-------------------------- INTERNAL -----------------------------------
    //--------------------------------------------------------------------

    /**
     * @dev Calculate the customer reward based on the provided Deposit
     * param uint _DepositID The Deposit where the reward should be calculated
     * @return The reward value
     */

    function updateSuppliedToken(uint _amount) internal returns (bool){
        
        if(_amount > amount_supplied){
            return false;
        }
        
        amount_supplied = amount_supplied.sub(_amount);
        return true;
    }

    function checkadsPoolBalance(uint _amount) internal view returns (bool){
        if(adsPool >= _amount){
            return true;
        }
        return false;
    }


    function getMachineBalance() internal view returns (uint){
        return ERC20Interface.balanceOf(address(this));
    }

    function getMachineState() external view returns (uint){
        return amount_supplied;
    }

    function isSubscriptionEnded() public view returns (bool){
        if(amount_supplied >= _MAX_TOKEN_SUPPLY_LIMIT - _MIDTERM_TOKEN_SUPPLY_LIMIT){
            return false;
        }else{
            return true;
        }
    }

    function isMachineStopped() public view returns (bool){
        if(amount_supplied > 0){
            return true;
        }else{
            return false;
        }
    }

    function getOwner() external view returns (address){
        return owner();
    }

}