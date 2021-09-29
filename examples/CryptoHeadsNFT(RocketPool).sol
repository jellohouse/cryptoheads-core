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




contract CryptoHeadsNFT is ERC721, ERC721Enumerable, Pausable, Ownable, ReentrancyGuard {

  using SafeMath for uint;


  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - State Variables - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  //RocketStorageInterface rocketStorage = RocketStorageInterface(0);
  uint public constant TOKEN_LIMIT = 10000;

  uint public constant mintersRate = 5;           // in %
  uint public poolRate = 3;                // in %

  uint public totalEthStaked = 0;
  uint public ethToStake = 0;

  string public baseURI = 'ipfs://QmcmZ6Y7G9oWJ2SP5oHpRB2zs5S3RFGKPNf8YgobAsLDSK/';

  struct CryptoHeadState {
    string status;  // owned, auction, direct
    uint value;     // keeps the last price at which it was bought (WEI)
    uint minValue;  // min price to pay - also represents the highest bid (WEI)
    address highestBidder;
    uint expiration;    // expiration of an aution
    uint plRate;
  }

  mapping (uint => CryptoHeadState) public tokenState;  // Mapping from tokenID to CryptoHeadState
  mapping (address => uint) public ethBalance;    // Mapping from address to balance
  mapping (uint => address) public minters;    // Mapping from tokenID to address




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
  constructor(address _rocketStorageAddress)
    ERC721("CryptoHeads", unicode"Ӝ")
  {
    //rocketStorage = RocketStorageInterface(_rocketStorageAddress);
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
    return string(abi.encodePacked(baseURI, toString(tokenID), '.json'));
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
  //- - - - - - - - - - - - - RocketPool Functions - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function addToPool() public onlyOwner {
    // Check deposit amount
    require(ethToStake > 0, "Invalid deposit amount");

    // Load contracts
    address rocketDepositPoolAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketDepositPool")));
    RocketDepositPoolInterface rocketDepositPool = RocketDepositPoolInterface(rocketDepositPoolAddress);
    address rocketETHTokenAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketETHToken")));
    RocketETHTokenInterface rocketETHToken = RocketETHTokenInterface(rocketETHTokenAddress);

    // Forward deposit to RocketPool & get amount of rETH minted
    uint256 rethBalance1 = rocketETHToken.balanceOf(address(this));
    rocketDepositPool.deposit{value: ethToStake}();
    uint256 rethBalance2 = rocketETHToken.balanceOf(address(this));
    require(rethBalance2 > rethBalance1, "No rETH was minted");
    uint256 rethMinted = rethBalance2 - rethBalance1;

    // Transfer rETH to caller (this contract)
    require(rocketETHToken.transfer(address(this), rethMinted), "rETH was not transferred to CryptoHead contract");

    totalEthStaked = totalEthStaked.add(ethToStake);
    ethToStake = 0;
  }


  function checkRewards() public onlyOwner returns (uint, uint) {
    uint rEthBalance = rocketETHToken.balanceOf(address(this));
    uint256 rEthReward = rEthBalance.sub(RocketTokenREthInterface().getREthAmount(totalEthStaked));
    return (rEthReward, RocketTokenREthInterface().getEthValue(rEthReward));
  }

  function claimRewardsEth() public onlyOwner {
    uint rEthBalance = rocketETHToken.balanceOf(address(this));

    uint256 rEthRewards = rEthBalance.sub(RocketTokenREthInterface().getREthAmount(totalEthStaked));

    uint256 ethEquivalent = RocketTokenREthInterface().getEthValue(rEthRewards);

    RocketTokenREthInterface().burn(rEthRewards);

    payable(msg.sender).send{value: ethEquivalent}
  }

  function claimRewardsReth() public onlyOwner {
    uint rEthBalance = rocketETHToken.balanceOf(address(this));

    uint256 rEthRewards = rEthBalance.sub(RocketTokenREthInterface().getREthAmount(totalEthStaked));

    require(rocketETHToken.transfer(owner(), rEthRewards), "rETH rewards was not claimed");

    //payable(msg.sender).send{value: ethEquivalent}
  }




  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - ADMIN Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function setBaseURI(string memory _baseURI) public onlyOwner {
    baseURI = _baseURI;
  }

  function setPoolRate(uint newRate) external onlyOwner {
    poolRate = newRate;
  }

  function devMint(uint quantity, address recipient) external onlyOwner {
    require(totalSupply().add(quantity) <= TOKEN_LIMIT, "Exceeds CryptoHeads limit");
    for(uint i = 0; i < quantity; i++) {
      uint tokenID = totalSupply().add(1);
      require(!_exists(tokenID), "This CryptoHead already exists");
      _safeMint(recipient, tokenID);
      CryptoHeadState memory newCryptoHeadState = CryptoHeadState('owned', getMintPrice(), 0, address(0x0), poolRate);
      tokenState[tokenID] = newCryptoHeadState;
      minters[tokenID] = recipient;
    }
  }



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - Public Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function withdraw(uint _amount) external nonReentrant {
    require(_amount <= ethBalance[msg.sender], 'Insufficient balance');
    ethBalance[msg.sender] = ethBalance[msg.sender].sub(_amount);
    (bool success, ) = msg.sender.call{value: _amount}("");
    require(success);
    emit E_Withdraw(msg.sender, _amount);
  }

  function getTokenState(uint tokenID) public view returns(string memory, uint, uint, address, uint) {
    CryptoHeadState memory c = tokenState[tokenID];
    if (!_exists(tokenID)) c.minValue = getMintPrice();
    return (
      c.status,
      c.value,
      c.minValue,
      c.highestBidder,
      c.plRate
    );
  }


  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - Mint CryptoHead - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function getMintPrice() returns (uint) {
    if (totalSupply() <= 2000) {  // Pre-sale
      return 0.05 ether;
    } else {
      return 0.08 ether;
    }
  }


  function mintCryptoHead(uint quantity) public payable nonReentrant {
    require(totalSupply().add(quantity) <= TOKEN_LIMIT, "Exceeds CryptoHeads limit minted");
    require(balanceOf(msg.sender)+quantity <= 10, "You can only mint 10 CryptoHeads");
    require(msg.value >= (getMintPrice()*quantity), "You must pay minimum minting cost");

    for(uint i = 0; i < quantity; i++) {
      uint tokenID = totalSupply().add(1);
      require(!_exists(tokenID), "This CryptoHead already exists");
      _safeMint(msg.sender, tokenID);
      CryptoHeadState memory newCryptoHeadState = CryptoHeadState(msg.sender, 'owned', getMintPrice(), 0, address(0x0), poolRate);
      tokenState[tokenID] = newCryptoHeadState;
      minters[tokenID] = msg.sender;
    }

    // 5% goes to dev
    uint devCut = (msg.value).mul(mintersRate).div(100);
    ethBalance[owner()] = ethBalance[owner()].add(devCut);
    // rest goes to pool
    ethToStake = ethToStake.add((msg.value).sub(devCut));
  }






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - MARKETPLACE - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //


  function createOffer(uint tokenID, uint minValue, string memory offerType) public {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(compareStrings(tokenState[tokenID].status, "owned"), "Your CryptoHead must not be for sale or auction");
    require((compareStrings(offerType, 'auction') || compareStrings(offerType, 'direct')), "Only auction or direct");
    require(minValue > 0.0001 ether, "The minimum sale price is 0.001 ETH");

    tokenState[tokenID].status = offerType;
    tokenState[tokenID].minValue = minValue;
    tokenState[tokenID].plRate = poolRate;
    tokenState[tokenID].highestBidder = address(0x0);
    tokenState[tokenID].expiration = 0;

    emit E_NewOffer(msg.sender, tokenID, offerType, minValue);
  }



  function cancelOffer(uint tokenID) public {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require((compareStrings(tokenState[tokenID].status, 'auction') || compareStrings(tokenState[tokenID].status, 'direct')), "This is not on auction or directly for sale");

    if (compareStrings(tokenState[tokenID].status, 'auction')) {
      // Pay back the highest bidder
      if (tokenState[tokenID].highestBidder != address(0x0)) {
        ethBalance[tokenState[tokenID].highestBidder] = ethBalance[tokenState[tokenID].highestBidder].add(tokenState[tokenID].minValue);
      }
    }

    tokenState[tokenID].status = "owned";
    tokenState[tokenID].highestBidder = address(0x0);
    tokenState[tokenID].expiration = 0;
    tokenState[tokenID].minValue = 0;
  }



  function buyDirectly(uint tokenID, bool useBalance, uint useAmt) payable nonReentrant whenNotPaused public {
    require(compareStrings(tokenState[tokenID].status, "direct"), "This CryptoHead is not for sale");
    require(msg.sender != ownerOf(tokenID), "Cannot buy your own CryptoHead");
    if (useBalance) {
      require((ethBalance[msg.sender] >= useAmt && (msg.value + useAmt) >= tokenState[tokenID].minValue), "You must pay min price");
    } else {
      require((msg.value >= tokenState[tokenID].minValue), "You must pay min price");
    }

    address seller = ownerOf(tokenID);
    uint soldPrice = msg.value;

    if (useBalance) {
      ethBalance[msg.sender] = ethBalance[msg.sender].sub(useAmt);
      soldPrice = soldPrice.add(useAmt);
    }

    // Pay the people
    uint amountMinter = (soldPrice.mul(mintersRate)).div(100);
    uint amountPool = (soldPrice.mul(tokenState[tokenID].plRate)).div(100);
    //addToPool(amountPool);
    ethToStake = ethToStake.add(amountPool);
    ethBalance[minters[tokenID]] = ethBalance[minters[tokenID]].add(amountMinter);
    ethBalance[seller] = ethBalance[seller].add((soldPrice.sub(amountPool)).sub(amountMinter));

    // Transfer Token
    _transfer(seller, msg.sender, tokenID);

    tokenState[tokenID].status = "owned";
    tokenState[tokenID].value = soldPrice;

    emit E_NewTrade(msg.sender, seller, tokenID, soldPrice);
  }



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - AUCTIONS - - - - - - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function bidAuction(uint tokenID, bool useBalance, uint useAmt) payable nonReentrant whenNotPaused public {
    require(compareStrings(tokenState[tokenID].status, "auction"), "This CryptoHead is not set for auction.");
    require(msg.sender != ownerOf(tokenID), "Cannot bid on your own auction");
    if (useBalance) {
      require((ethBalance[msg.sender] >= useAmt && (msg.value + useAmt) > tokenState[tokenID].minValue), "You must bid higher");
    } else {
      require((msg.value > tokenState[tokenID].minValue), "You must bid higher");
    }
    if (tokenState[tokenID].expiration) {
      require(now < tokenState[tokenID].expiration, "Auction expired");
    } else {
      // First bidder
      tokenState[tokenID].expiration = now.add(1 weeks);
    }
    // Bid in the last hour - add 1 day
    if ((tokenState[tokenID].expiration.sub(now)) <= 1 hours) {
      tokenState[tokenID].expiration = now.add(1 days);
    }

    // Pay back the previous highest bidder
    if (tokenState[tokenID].highestBidder != address(0x0)) {
      ethBalance[tokenState[tokenID].highestBidder] = ethBalance[tokenState[tokenID].highestBidder].add(tokenState[tokenID].minValue);
    }
    // Bid
    tokenState[tokenID].highestBidder = msg.sender;
    if (useBalance) {
      tokenState[tokenID].minValue = tokenState[tokenID].minValue.add(msg.value).add(useAmt);
      ethBalance[msg.sender] = ethBalance[msg.sender].sub(useAmt);
    } else {
      tokenState[tokenID].minValue = msg.value;
    }

    emit E_NewBid(tokenID, msg.value, msg.sender);
  }


  function acceptBid(uint tokenID) public nonReentrant {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(tokenState[tokenID].highestBidder != address(0x0), "There is no bidder on this auction");
    require(compareStrings(tokenState[tokenID].status, "auction"), "This auction does not exist");

    uint soldPrice = tokenState[tokenID].minValue;
    address buyer = tokenState[tokenID].highestBidder;
    address seller = ownerOf(tokenID);

    // - - - - - Pay the people - - - -//
    uint amountMinter = (soldPrice.mul(mintersRate)).div(100);
    uint amountPool = (soldPrice.mul(tokenState[tokenID].plRate)).div(100);

    //addToPool(amountPool);
    ethToStake = ethToStake.add(amountPool);
    ethBalance[minters[tokenID]] = ethBalance[minters[tokenID]].add(amountMinter);
    ethBalance[seller] = ethBalance[seller].add((soldPrice.sub(amountPool)).sub(amountMinter));

    _transfer(msg.sender, buyer, tokenID);

    tokenState[tokenID].status = "owned";
    tokenState[tokenID].minValue = 0;
    tokenState[tokenID].value = soldPrice;
    tokenState[tokenID].highestBidder = address(0x0);

    emit E_NewTrade(buyer, seller, tokenID, soldPrice);
  }


  // In case someone never accepts highest bid on expired auction
  function expiredAuction(uint tokenID) public nonReentrant {
    require(compareStrings(tokenState[tokenID].status, "auction"), "This CryptoHead is not set for auction.");
    require(msg.sender == tokenState[tokenID].highestBidder, "You are not highestBidder");
    require(now > (tokenState[tokenID].expiration + 4 weeks), "Cannot revoke bid yet");
    ethBalance[msg.sender] = ethBalance[msg.sender].add(tokenState[tokenID].minValue);
    tokenState[tokenID].highestBidder = address(0x0);
    tokenState[tokenID].expiration = 0;
    //min bid value will stay the highest bid we had
  }

}
