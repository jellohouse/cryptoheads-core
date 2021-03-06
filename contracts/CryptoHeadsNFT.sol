// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import  "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import  "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


import './ERC2981PerTokenRoyalties.sol';


contract CryptoHeadsNFT is ERC721, ERC721Enumerable, Pausable, Ownable, ReentrancyGuard {


  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - State Variables - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  uint public constant TOKEN_LIMIT = 10000;
  uint public constant maxMints = 20;

  uint public constant mintersRate = 500;           // 500 / 10000 = 5%
  uint public exchangeRate = 100;                   // 100 / 10000 = 1%

  string public baseURI;

  struct CryptoHeadState {
    string status;  // owned, auction, direct
    uint value;     // keeps the last price at which it was bought (WEI)
    uint minValue;  // min price to pay - also represents the highest bid (WEI)
    address highestBidder;
    uint expiration;    // expiration date of an aution
    uint exRate;
  }

  mapping (uint => CryptoHeadState) public tokenState;  // Mapping from tokenID to CryptoHeadState
  mapping (address => uint) public ethBalance;    // Mapping from address to balance





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - EVENTS - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  event E_NewOffer(address from, uint tokenID, string offerType, uint minValue);

  event E_NewBid(uint tokenID, uint value, address from);

  event E_Trade(address from, address to, uint tokenID, uint soldPrice);







  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - CONSTRUCTOR - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  constructor(string memory _baseURI) ERC721("CryptoHeads", unicode"??") {
    setBaseURI(_baseURI);
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
    require(1 <= tokenID && tokenID <= TOKEN_LIMIT, 'Invalid Token ID');
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
    override(ERC721, ERC721Enumerable, ERC2981PerTokenRoyalties)
    returns (bool)
  {
    //return super.supportsInterface(interfaceId);
    return super.supportsInterface(interfaceId) || ERC2981PerTokenRoyalties.supportsInterface(interfaceId);
  }






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - ADMIN Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function setBaseURI(string memory _baseURI) public onlyOwner {
    baseURI = _baseURI;
  }

  function setExchangeRate(uint newRate) external onlyOwner {
    exchangeRate = newRate;
  }

  function devMint(uint quantity, address recipient) external onlyOwner {
    require(totalSupply() + quantity <= TOKEN_LIMIT, "Exceeds CryptoHeads limit");
    for(uint i = 0; i < quantity; i++) {
      uint tokenID = totalSupply() + 1;
      require(!_exists(tokenID), "This CryptoHead already exists");
      _safeMint(recipient, tokenID);
      CryptoHeadState memory newCryptoHeadState = CryptoHeadState('owned', getMintPrice(), 0, address(0x0), 0);
      tokenState[tokenID] = newCryptoHeadState;
      _setTokenRoyalty(tokenID, recipient, mintersRate);
    }
  }



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - Public Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function withdraw(uint _amount) external nonReentrant {
    require(_amount <= ethBalance[msg.sender], 'Insufficient balance');
    ethBalance[msg.sender] -= _amount;
    (bool success, ) = msg.sender.call{value: _amount}("");
    require(success);
  }

  function getTokenState(uint tokenID) public view returns(string memory, uint, uint, address, uint) {
    CryptoHeadState memory c = tokenState[tokenID];
    if (!_exists(tokenID)) c.minValue = getMintPrice();
    return (
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

  function getMintPrice() returns (uint) {
    if (totalSupply() <= 2000) {  // Pre-sale
      return 0.05 ether;
    } else {
      return 0.08 ether;
    }
  }


  function mintCryptoHead(uint quantity) external payable nonReentrant {
    require(totalSupply() + quantity <= TOKEN_LIMIT, "Exceeds CryptoHeads limit minted");
    require(balanceOf(msg.sender) + quantity <= maxMints, "You can only mint 20 CryptoHeads");
    require(msg.value >= getMintPrice() * quantity, "You must pay minimum minting cost");

    for(uint i = 0; i < quantity; i++) {
      uint tokenID = totalSupply() + 1;
      require(!_exists(tokenID), "This CryptoHead already exists");
      _safeMint(msg.sender, tokenID);
      CryptoHeadState memory newCryptoHeadState = CryptoHeadState(msg.sender, 'owned', getMintPrice(), 0, address(0x0), 0);
      tokenState[tokenID] = newCryptoHeadState;
      setTokenRoyalty(tokenId, msg.sender, mintersRate);
    }

    ethBalance[owner()] += msg.value;
  }






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - MARKETPLACE - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //


  function createOffer(uint tokenID, uint minValue, string memory offerType) external {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(compareStrings(tokenState[tokenID].status, "owned"), "Your CryptoHead must not be for sale or auction");
    require((compareStrings(offerType, 'auction') || compareStrings(offerType, 'direct')), "Only auction or direct");
    require(minValue > 0.0001 ether, "The minimum sale price is 0.0001 ETH");

    tokenState[tokenID].status = offerType;
    tokenState[tokenID].minValue = minValue;
    tokenState[tokenID].exRate = exchangeRate;
    tokenState[tokenID].highestBidder = address(0x0);
    tokenState[tokenID].expiration = 0;

    emit E_NewOffer(msg.sender, tokenID, offerType, minValue);
  }



  function cancelOffer(uint tokenID) external {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require((compareStrings(tokenState[tokenID].status, 'auction') || compareStrings(tokenState[tokenID].status, 'direct')), "This is not on auction or directly for sale");

    if (compareStrings(tokenState[tokenID].status, 'auction')) {
      // Pay back the highest bidder
      if (tokenState[tokenID].highestBidder != address(0x0)) {
        ethBalance[tokenState[tokenID].highestBidder] += tokenState[tokenID].minValue;
      }
    }

    tokenState[tokenID].status = "owned";
    tokenState[tokenID].highestBidder = address(0x0);
    tokenState[tokenID].expiration = 0;
    tokenState[tokenID].minValue = 0;
  }



  function buyDirectly(uint tokenID, bool useBalance, uint useAmt) payable nonReentrant whenNotPaused external {
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
      ethBalance[msg.sender] -= useAmt;
      soldPrice += useAmt;
    }

    // - - - - - Pay the people - - - - //
    (address minter, uint256 royaltyMinter) = royaltyInfo(tokenID, soldPrice);
    uint exAmount = (soldPrice * tokenState[tokenID].exRate) / 10000;
    ethBalance[minter] += royaltyMinter;
    ethBalance[owner()] += exAmount;
    ethBalance[seller] += (soldPrice - amountEx - royaltyMinter);

    // - - - - - Tranfer Token - - - - //
    safeTransferFrom(seller, msg.sender, tokenID);
    tokenState[tokenID].status = "owned";
    tokenState[tokenID].value = soldPrice;

    emit E_Trade(msg.sender, seller, tokenID, soldPrice);
  }



  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - AUCTIONS - - - - - - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function bidAuction(uint tokenID, bool useBalance, uint useAmt) payable nonReentrant whenNotPaused external {
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
      // This is the first bidder
      tokenState[tokenID].expiration = now + (1 weeks);
    }
    if ((tokenState[tokenID].expiration - now) <= 1 hours) {
      // Someone bid in the last hour, add 1 day
      tokenState[tokenID].expiration = now + (1 days);
    }

    // Pay back the previous highest bidder
    if (tokenState[tokenID].highestBidder != address(0x0)) {
      ethBalance[tokenState[tokenID].highestBidder] += tokenState[tokenID].minValue;
    }

    // New Highest Bidder
    tokenState[tokenID].highestBidder = msg.sender;
    if (useBalance) {
      tokenState[tokenID].minValue += (msg.value + useAmt);
      ethBalance[msg.sender] -= useAmt;
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
    address seller = ownerOf(tokenID);

    // - - - - - Pay the people - - - - //
    (address minter, uint256 royaltyMinter) = royaltyInfo(tokenID, soldPrice);
    uint exAmount = (soldPrice * tokenState[tokenID].exRate) / 10000;
    ethBalance[minter] += royaltyMinter;
    ethBalance[owner()] += exAmount;
    ethBalance[seller] += (soldPrice - exAmount - royaltyMinter);

    // - - - - - Tranfer Token - - - - //
    safeTransferFrom(msg.sender, buyer, tokenID);
    tokenState[tokenID].status = "owned";
    tokenState[tokenID].minValue = 0;
    tokenState[tokenID].value = soldPrice;
    tokenState[tokenID].highestBidder = address(0x0);

    emit E_Trade(buyer, seller, tokenID, soldPrice);
  }


  // In case someone never accepts highest bid on expired auction
  function expiredAuction(uint tokenID) external nonReentrant {
    require(compareStrings(tokenState[tokenID].status, "auction"), "This CryptoHead is not set for auction.");
    require(msg.sender == tokenState[tokenID].highestBidder, "You are not highestBidder");
    require(now > (tokenState[tokenID].expiration + 4 weeks), "Cannot revoke bid yet");
    ethBalance[msg.sender] += tokenState[tokenID].minValue;
    tokenState[tokenID].highestBidder = address(0x0);
    tokenState[tokenID].expiration = 0;
    //min bid value will stay the highest bid we had
  }


  // This function allows minters to change the address which recieves royalties (becomes minter)
  function changeRoyaltyAddress(uint tokenID, address newRoyaltyAddress) external {
    (address minter, uint256 royaltyMinter) = royaltyInfo(tokenID, 0);
    require(msg.sender == minter, 'Only the minter can change this address');
    _setTokenRoyalty(tokenID, newRoyaltyAddress, mintersRate);
  }

}
