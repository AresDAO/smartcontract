// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";

contract ARDPreSale is Ownable, ReentrancyGuard {

    struct RoundSale {  
        uint256 price;
        uint256 minSpend;
        uint256 maxSpend;
        uint256 startingTimeStamp;
    }
    // ARD token
    IERC20 public ARD;
    // BuyingToken token
    IERC20 public BuyingToken;

    uint256 public constant ARD_ALLOCATION = 50000000000000000000000;       // hardcap 50k ARD
    // Set round active 1 pre, 2 public
    uint256 public roundActive = 1;
    // Store detail earch round
    mapping(uint256 => RoundSale) public rounds;
    // Whitelisting list
    mapping(address => bool) public whiteListed;
    // Total ARD user buy
    mapping(address => uint256) public tokenBoughtTotal;
    // Total BuyingToken spend for limits earch user
    mapping(uint256 => mapping(address => uint256)) public totalBuyingTokenSpend;
    // Total ARD sold
    uint256 public totalTokenSold = 0;
    // Claim token
    uint256[] public claimableTimestamp;
    mapping(uint256 => uint256) public claimablePercents;
    mapping(address => uint256) public claimCounts;

    event TokenBuy(address user, uint256 tokens);
    event TokenClaim(address user, uint256 tokens);

    constructor(
        address _ARD,
        address _BuyingToken
    ) {
        ARD = IERC20(_ARD);
        BuyingToken = IERC20(_BuyingToken);
    }

    /* User methods */
    function buy(uint256 _amount) public nonReentrant {
        require(roundActive == 1 || roundActive == 2, "No open sale rounds found");
        RoundSale storage roundCurrent = rounds[roundActive];
        require(
            block.timestamp >= roundCurrent.startingTimeStamp,
            "Presale has not started"
        );
        require(
            roundActive != 1 || whiteListed[_msgSender()] == true,
            'Not whitelisted'
        );
        require(
            totalBuyingTokenSpend[roundActive][_msgSender()] + _amount >= roundCurrent.minSpend,
            "Below minimum amount"
        );
        require(
            totalBuyingTokenSpend[roundActive][_msgSender()] + _amount <= roundCurrent.maxSpend,
            "You have reached maximum spend amount per user"
        );

        uint256 tokens = _amount / roundCurrent.price * 1000;

        require(
            totalTokenSold + tokens <= ARD_ALLOCATION,
            "Token presale hardcap reached"
        );

        BuyingToken.transferFrom(_msgSender(), address(this), _amount);

 		tokenBoughtTotal[_msgSender()] += tokens;
        totalBuyingTokenSpend[roundActive][_msgSender()] += _amount;

        totalTokenSold += tokens;
        emit TokenBuy(_msgSender(), tokens);
    }

    
    function claim() external nonReentrant {
        uint256 userBought = tokenBoughtTotal[_msgSender()];
        require(userBought > 0, "Nothing to claim");
        require(claimableTimestamp.length > 0, "Can not claim at this time");
        require(_now() >= claimableTimestamp[0], "Can not claim at this time");

        uint256 startIndex = claimCounts[_msgSender()];
        require(startIndex < claimableTimestamp.length, "You have claimed all token");

        uint256 tokenQuantity = 0;
        for(uint256 index = startIndex; index < claimableTimestamp.length; index++){
            uint256 timestamp = claimableTimestamp[index];
            if(_now() >= timestamp){
                tokenQuantity += userBought * claimablePercents[timestamp] / 100;
                claimCounts[_msgSender()]++;
            }else{
                break;
            }
        }

        require(tokenQuantity > 0, "Token quantity is not enough to claim");
        require(ARD.transfer(_msgSender(), tokenQuantity), "Can not transfer ARD");

        emit TokenClaim(_msgSender(), tokenQuantity);
    }

    function getTokenBought(address _buyer) public view returns(uint256){
        require(_buyer != address(0), "Zero address");
        return tokenBoughtTotal[_buyer];
    }

    function getRoundActive() public view returns(uint256){
        return roundActive;
    }

    /* Admin methods */

    function setActiveRound(uint256 _roundId) external onlyOwner{
        require(_roundId == 1 || _roundId == 2, "Round ID invalid");
        roundActive = _roundId;
    }

    function setRoundSale(
        uint256 _roundId,
        uint256 _price,
        uint256 _minSpend,
        uint256 _maxSpend,
        uint256 _startingTimeStamp) external onlyOwner{
        require(_roundId == 1 || _roundId == 2, "Round ID invalid");
        require(_minSpend < _maxSpend, "Spend invalid");

        rounds[_roundId] = RoundSale({
            price: _price,
            minSpend: _minSpend,
            maxSpend: _maxSpend,
            startingTimeStamp: _startingTimeStamp
        });
    }

    function setClaimableBlocks(uint256[] memory _timestamp) external onlyOwner{
        require(_timestamp.length > 0, "Empty input");
        claimableTimestamp = _timestamp;
    }

    function setClaimablePercents(uint256[] memory _timestamps, uint256[] memory _percents) external onlyOwner{
        require(_timestamps.length > 0, "Empty input");
        require(_timestamps.length == _percents.length, "Empty input");
        for(uint256 index = 0; index < _timestamps.length; index++){
            claimablePercents[_timestamps[index]] = _percents[index];
        }
    }

    function setUsdcToken(address _newAddress) external onlyOwner{
        require(_newAddress != address(0), "Zero address");
        BuyingToken = IERC20(_newAddress);
    }

    function setArdToken(address _newAddress) external onlyOwner{
        require(_newAddress != address(0), "Zero address");
        ARD = IERC20(_newAddress);
    }

    function addToWhiteList(address[] memory _accounts) external onlyOwner {
        require(_accounts.length > 0, "Invalid input");
        for (uint256 i; i < _accounts.length; i++) {
            whiteListed[_accounts[i]] = true;
        }
    }

    function removeFromWhiteList(address[] memory _accounts) external onlyOwner{
        require(_accounts.length > 0, "Invalid input");
        for(uint256 index = 0; index < _accounts.length; index++){
            whiteListed[_accounts[index]] = false;
        }
    }

    function withdrawFunds() external onlyOwner {
        BuyingToken.transfer(_msgSender(), BuyingToken.balanceOf(address(this)));
    }

    function withdrawUnsold() external onlyOwner {
        uint256 amount = ARD.balanceOf(address(this)) - totalTokenSold;
        ARD.transfer(_msgSender(), amount);
    }
}