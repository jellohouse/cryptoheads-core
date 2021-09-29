// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import  "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import  "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
//import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";



contract CryptoHeadsNFT is ERC721, ERC721Enumerable, Pausable, Ownable, ReentrancyGuard, VRFConsumerBase, KeeperCompatibleInterface {

  using SafeMath for uint;


  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - State Variables - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  //RocketStorageInterface rocketStorage = RocketStorageInterface(0);
  uint public constant mintPrice = 0.08 ether;
  uint public constant TOKEN_LIMIT = 10000;

  uint public exchangeRate = 5;           // in %
  uint public poolRate = 5;                // in %

  uint public constant prizeInterval = 1 weeks;
  uint public lastTimeStamp;

  uint public totalEthStaked = 0;
  uint public prize;

  struct CryptoHeadState {
    bool exists;
    uint tokenID;
    address owner;
    string status;  // owned, auction, direct
    uint value;     // keeps the last price at which it was bought (WEI)
    uint minValue;  // min price to pay - also represents the highest bid (WEI)
    address highestBidder;
    uint exRate;
  }

  mapping (uint => CryptoHeadState) public tokenState;  // Mapping from tokenID to CryptoHeadState
  mapping (address => uint) public ethBalance;    // Mapping from address to balance

  // CHAINLINK
  bytes32 internal keyHash;
  uint internal fee;



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - EVENTS - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  event E_NewBid(uint tokenID, uint value, address from);

  event E_NewWinner(uint tokenID, address winner, uint reward);

  event E_NewTrade(address from, address to, uint tokenID, uint soldPrice);

  event E_NewOffer(address from, uint tokenID, string offerType, uint minValue);

  event E_Withdraw(address from, uint amount);





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - CONSTRUCTOR - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
    // 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9 KOVAN testnet - VRF Coordinator
    // 0xa36085F69e2889c224210F603D836748e7dC0088 KOVAN testnet - LINK Token
  constructor(address _rocketStorageAddress, address _vrfCoordinator, address _link)
    VRFConsumerBase(_vrfCoordinator, _link)
    ERC721("CryptoHeads", unicode"Ӝ")
  {
    //rocketStorage = RocketStorageInterface(_rocketStorageAddress);
    keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    fee = 0.1 * 10**18; // 0.1 LINK
    lastTimeStamp = block.timestamp;
  }




  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - Util Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //


  function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function toString(uint256 value) internal pure returns (string memory) {
    if (value == 0) {
        return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
        digits++;
        temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
        digits -= 1;
        buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
        value /= 10;
    }
    return string(buffer);
  }





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - Overrides - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function tokenURI(uint256 tokenID) public view virtual override returns (string memory) {
    return string(abi.encodePacked('ipfs://QmcmZ6Y7G9oWJ2SP5oHpRB2zs5S3RFGKPNf8YgobAsLDSK/', toString(tokenID), '.json'));
  }

  function pause() public onlyOwner {
      _pause();
  }

  function unpause() public onlyOwner {
      _unpause();
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
      internal
      whenNotPaused
      override(ERC721, ERC721Enumerable)
  {
      super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
      public
      view
      override(ERC721, ERC721Enumerable)
      returns (bool)
  {
      return super.supportsInterface(interfaceId);
  }





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - CHAINLINK CRON - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function checkUpkeep(bytes calldata /* checkData */) external override whenNotPaused returns (bool upkeepNeeded, bytes memory /* performData */) {
    upkeepNeeded = (block.timestamp - lastTimeStamp) > prizeInterval;
    // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
  }

  function performUpkeep(bytes calldata /* performData */) external override {
    lastTimeStamp = block.timestamp;
    _rewardRandomWinner();
  }





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - RocketPool Functions - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function addToPool(uint256 amount) internal {
    // Check deposit amount
    require(amount > 0, "Invalid deposit amount");
    totalEthStaked = totalEthStaked.add(amount);
    // Load contracts
    /* address rocketDepositPoolAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketDepositPool")));
    RocketDepositPoolInterface rocketDepositPool = RocketDepositPoolInterface(rocketDepositPoolAddress);
    address rocketETHTokenAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketETHToken")));
    RocketETHTokenInterface rocketETHToken = RocketETHTokenInterface(rocketETHTokenAddress);
    // Forward deposit to RP & get amount of rETH minted
    uint256 rethBalance1 = rocketETHToken.balanceOf(address(this));
    rocketDepositPool.deposit{value: amount}();
    uint256 rethBalance2 = rocketETHToken.balanceOf(address(this));
    require(rethBalance2 > rethBalance1, "No rETH was minted");
    uint256 rethMinted = rethBalance2 - rethBalance1;
    // Transfer rETH to caller
    require(rocketETHToken.transfer(address(this), rethMinted), "rETH was not transferred to CryptoHead contract"); */
  }


  function _rewardRandomWinner() internal {
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
    bytes32 requestId = requestRandomness(keyHash, fee);
  }

  function fulfillRandomness(bytes32 requestId, uint256 randomNumber) internal override {
    uint winnerTokenID = randomNumber.mod(TOKEN_LIMIT).add(1);

    // rETH to ETH - should be in separate function on demand user rETH balance
    /* uint256 rEthToExchange = rEthUserBalance.sub(RocketTokenREthInterface().getREthAmount(originalEthDepositAmount));

    uint256 ethEquivalent = RocketTokenREthInterface ().getEthValue(rEthToExchange);

    RocketTokenREthInterface().burn(rEthToExchange);

    payable(msg.sender).send{value: ethEquivalent} */
  }






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - ADMIN Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function setExchangeRate(uint newRate) external onlyOwner {
    exchangeRate = newRate;
  }

  function devMint(uint quantity, uint startingID, address recipient) external onlyOwner {
    require((startingID >= 1) && (startingID.add(quantity).sub(1) <= TOKEN_LIMIT));
    for (uint i = startingID; i <= (startingID.add(quantity).sub(1)); i++) {
      if (!_exists(i)) {
        _safeMint(recipient, i);
        CryptoHeadState memory newCryptoHeadState = CryptoHeadState(true, i, recipient, 'owned', mintPrice, 0, address(0x0), exchangeRate);
        tokenState[i] = newCryptoHeadState;
      }
    }
  }



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - USER Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function withdraw(uint _amount) external nonReentrant {
      require(_amount <= ethBalance[msg.sender], 'Insufficient balance');
      ethBalance[msg.sender] = ethBalance[msg.sender].sub(_amount);
      (bool success, ) = msg.sender.call{value: _amount}("");
      require(success);
      emit E_Withdraw(msg.sender, _amount);
  }

  function getTokenState(uint tokenID) public view returns(bool, uint, address, string memory, uint, uint, address, uint) {
    CryptoHeadState memory c = tokenState[tokenID];
    if (!c.exists) c.minValue = mintPrice;
    return (
      c.exists,
      c.tokenID,
      c.owner,
      c.status,
      c.value,
      c.minValue,
      c.highestBidder,
      c.exRate
    );
  }



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - Mint CryptoHead - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function mintCryptoHead(uint tokenID) public payable nonReentrant returns (uint) {
    require(!_exists(tokenID), "This CryptoHead already exists");
    require(totalSupply() < TOKEN_LIMIT, "All CryptoHeads are already minted");
    require(tokenID >= 1 && tokenID <= TOKEN_LIMIT, "This is not a valid token");
    require(balanceOf(msg.sender) < 10, "You can only mint 10 CryptoHeads");
    require(((msg.value >= mintPrice) || (msg.sender == owner())), "You must pay minimum minting cost");

    _safeMint(msg.sender, tokenID);

    CryptoHeadState memory newCryptoHeadState = CryptoHeadState(true, tokenID, msg.sender, 'owned', mintPrice, 0, address(0x0), exchangeRate);
    tokenState[tokenID] = newCryptoHeadState;

    if (msg.value >= mintPrice) {
      ethBalance[owner()] = ethBalance[owner()].add(0.01 ether);
      addToPool((msg.value).sub(0.01 ether));
    }

    return tokenID;
  }






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - MARKETPLACE - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //


  function createOffer(uint tokenID, uint minValue, string memory offerType) external {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(compareStrings(tokenState[tokenID].status, "owned"), "Your CryptoHead must not be for sale or auction");
    require((compareStrings(offerType, 'auction') || compareStrings(offerType, 'direct')), "Only auction or direct");
    require(minValue > 0.0001 ether, "The minimum sale price is 0.001 ETH");

    tokenState[tokenID].status = offerType;
    tokenState[tokenID].minValue = minValue;
    tokenState[tokenID].exRate = exchangeRate;

    emit E_NewOffer(msg.sender, tokenID, offerType, minValue);
  }



  function cancelOffer(uint tokenID) external {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require((compareStrings(tokenState[tokenID].status, 'auction') || compareStrings(tokenState[tokenID].status, 'direct')), "This is not on auction or directly for sale");

    if (compareStrings(tokenState[tokenID].status, 'auction')) {
      // Pay back the highest bidder
      if (tokenState[tokenID].highestBidder != address(0x0)) {
        ethBalance[tokenState[tokenID].highestBidder] = ethBalance[tokenState[tokenID].highestBidder].add(tokenState[tokenID].minValue);
      }
      tokenState[tokenID].highestBidder = address(0x0);
    }

    tokenState[tokenID].status = "owned";
  }



  function buyDirectly(uint tokenID, bool useBalance, uint useAmt) payable nonReentrant whenNotPaused external {
    require(compareStrings(tokenState[tokenID].status, "direct"), "This CryptoHead is not for sale");
    require(msg.sender != ownerOf(tokenID), "Cannot buy your own CryptoHead");
    require((msg.value >= tokenState[tokenID].minValue) ||(useBalance && ethBalance[msg.sender] >= useAmt && (msg.value + useAmt) >= tokenState[tokenID].minValue), "You must enter a value >= to price required to buy");

    address seller = tokenState[tokenID].owner;
    uint soldPrice = msg.value;

    if (useBalance) {
      ethBalance[msg.sender] = ethBalance[msg.sender].sub(useAmt);
      soldPrice = soldPrice.add(useAmt);
    }

    // Pay the people
    uint amountPoolCut = (soldPrice.mul(poolRate)).div(100);
    uint amountBankCut = (soldPrice.mul(tokenState[tokenID].exRate)).div(100);
    addToPool(amountPoolCut);
    ethBalance[owner()] = ethBalance[owner()].add(amountBankCut);
    ethBalance[seller] = ethBalance[seller].add((soldPrice.sub(amountPoolCut)).sub(amountBankCut));

    // Transfer Token
    _transfer(seller, msg.sender, tokenID);

    tokenState[tokenID].owner = msg.sender;
    tokenState[tokenID].status = "owned";
    tokenState[tokenID].value = soldPrice;

    emit E_NewTrade(msg.sender, seller, tokenID, soldPrice);
  }



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - AUCTIONS - - - - - - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function bidAuction(uint tokenID, bool useBalance, uint useAmt) payable nonReentrant whenNotPaused external {
    require(compareStrings(tokenState[tokenID].status, "auction"), "This CryptoHead is not set for auction.");
    require(msg.sender != ownerOf(tokenID), "Cannot bid on your own auction");
    require((msg.value > tokenState[tokenID].minValue) || (useBalance && ethBalance[msg.sender] >= useAmt && (msg.value + useAmt) > tokenState[tokenID].minValue), "You must offer greater then the minimum bid required");

    // Pay back the previous highest bidder
    if (tokenState[tokenID].highestBidder != address(0x0)) {
      ethBalance[tokenState[tokenID].highestBidder] = ethBalance[tokenState[tokenID].highestBidder].add(tokenState[tokenID].minValue);
    }

    tokenState[tokenID].highestBidder = msg.sender;
    if (useBalance) {
      tokenState[tokenID].minValue = tokenState[tokenID].minValue.add((msg.value).add(useAmt));
      ethBalance[msg.sender] = ethBalance[msg.sender].sub(useAmt);
    } else {
      tokenState[tokenID].minValue = msg.value;
    }

    emit E_NewBid(tokenID, msg.value, msg.sender);
  }


  function acceptBid(uint tokenID) external nonReentrant {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(tokenState[tokenID].highestBidder != address(0x0), "There is no bidder on this auction");
    require(compareStrings(tokenState[tokenID].status, "auction"), "This auction does not exist");

    uint soldPrice = tokenState[tokenID].minValue;
    address buyer = tokenState[tokenID].highestBidder;
    address seller = tokenState[tokenID].owner;

    // - - - - - Pay the people - - - -//
    uint amountPoolCut = (soldPrice.mul(poolRate)).div(100);
    uint amountBankCut = (soldPrice.mul(tokenState[tokenID].exRate)).div(100);

    addToPool(amountPoolCut);
    ethBalance[owner()] = ethBalance[owner()].add(amountBankCut);
    ethBalance[seller] = ethBalance[seller].add((soldPrice.sub(amountPoolCut)).sub(amountBankCut));

    _transfer(msg.sender, buyer, tokenID);

    tokenState[tokenID].status = "owned";
    tokenState[tokenID].minValue = 0;
    tokenState[tokenID].owner = buyer;
    tokenState[tokenID].value = soldPrice;
    tokenState[tokenID].highestBidder = address(0x0);

    emit E_NewTrade(buyer, seller, tokenID, soldPrice);
  }


}
