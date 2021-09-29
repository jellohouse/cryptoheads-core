// contracts/CryptoHeadsNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";



contract CryptoHeadsNFT is ERC721URIStorage {


  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - State Variables - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  address public admin;

  uint public exchangeRate = 5;                   // in %
  uint constant public firstOwnerTradeCut = 5;    // in %

  uint public numClaimedTokens;

  struct CryptoHeadToken {
    bool exists;
    uint tokenID;
    address owner;
    string status;  // unclaimed, owned, auction, Buy it!
    uint value;     // keeps the last price at which it was bought (WEI)
    uint minValue;  // min price to pay - also represents the highest bid (WEI)
    address highestBidder;
    uint exRate;
  }

  mapping (uint => CryptoHeadToken) public cryptoHeadTokens;  // Mapping from tokenID to CryptoHeadToken
  mapping (uint => address) public firstOwners;    // Mapping from tokenID to owner
  mapping (address => uint) public balances;    // Mapping from tokenID to owner





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - CONSTRUCTOR - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  constructor() ERC721("CryptoHeads", "NFT") {
    admin = msg.sender;
    numClaimedTokens = 0;
  }

  /* function _baseURI() internal view virtual override returns (string memory) {
    return 'ipfs://asdfasdfasdfasdfasdfasdfasfdasdfasdf/';
  } */





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - EVENTS - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  event E_NewCryptoHeadBid(uint tokenID, uint value, address from);






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - Util Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //


  function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }


  function releaseFunds() public {
      require(balances[msg.sender] > 0, "You have no money to release");
      payable(msg.sender).transfer(balances[msg.sender]);
      balances[msg.sender] = 0;
  }


  function getTokenData(uint tokenID) public view returns(bool, uint, address, string memory, uint, uint, address, uint) {
    CryptoHeadToken memory c = cryptoHeadTokens[tokenID];
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
  //- - - - - - - - - - - - - ADMIN Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function setAdminAddress(address newAdminAddress) external {
    require(msg.sender == admin, "Only the admin can call this function");
    admin = newAdminAddress;
  }

  function setExchangeRate(uint newRate) external {
    require(msg.sender == admin, "Only the admin can call this function");
    exchangeRate = newRate;
  }





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - Claim an initial CryptoHead - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function claimFirst(string memory tokenURI, uint tokenID) public returns (uint) {
    require(!_exists(tokenID), "This CryptoHead tokenID already exists");
    require(numClaimedTokens <= 10000, "All CryptoHead tokens are already claimed");
    require(tokenID >= 1 && tokenID <= 10000, "This is not a valid token to claim");
    require(balanceOf(msg.sender) <= 1 || (msg.sender == admin), "You can only be the first owner of 2 CryptoHeads");

    _safeMint(msg.sender, tokenID);
    _setTokenURI(tokenID, tokenURI);

    firstOwners[tokenID] = msg.sender;
    numClaimedTokens += 1;

    CryptoHeadToken storage newCryptoHeadToken = cryptoHeadTokens[tokenID];
    newCryptoHeadToken.exists = true;
    newCryptoHeadToken.tokenID = tokenID;
    newCryptoHeadToken.owner = msg.sender;
    newCryptoHeadToken.status = "owned";
    newCryptoHeadToken.value = 0;
    newCryptoHeadToken.minValue = 0;
    newCryptoHeadToken.highestBidder = address(0x0);

    return tokenID;
  }







  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - Directly sell your CryptoHead  - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //


  function createDirectSell(uint tokenID, uint minValue) external {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(compareStrings(cryptoHeadTokens[tokenID].status, "owned"), "Your CryptoHead must be not for sale or auction");
    require(minValue > 1000, "The minimum sale price is 1000 WEI");

    cryptoHeadTokens[tokenID].status = "Buy it!";
    cryptoHeadTokens[tokenID].minValue = minValue;
    cryptoHeadTokens[tokenID].exRate = exchangeRate;
  }



  function removeDirectSell(uint tokenID) public {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(compareStrings(cryptoHeadTokens[tokenID].status, "Buy it!"), "This CryptoHead is not for Sale");

    cryptoHeadTokens[tokenID].status = "owned";
  }



  function buyDirectSell(uint tokenID, bool useBalance, uint useAmt) payable external {
    require(compareStrings(cryptoHeadTokens[tokenID].status, "Buy it!"), "This CryptoHead is not for sale");
    require((msg.value >= cryptoHeadTokens[tokenID].minValue) ||(useBalance && balances[msg.sender] >= useAmt && (msg.value + useAmt) >= cryptoHeadTokens[tokenID].minValue), "You must enter a value >= to price required to buy");

    uint soldPrice = msg.value;
    if (useBalance) {
      balances[msg.sender] -= useAmt;
      soldPrice += useAmt;
    }

    // - - - - - Pay the people - - - -//
    uint amountFirstOwnerCut = (soldPrice * firstOwnerTradeCut) / 100;
    uint amountBankCut = (soldPrice * cryptoHeadTokens[tokenID].exRate) / 100;
    balances[firstOwners[tokenID]] += amountFirstOwnerCut;
    balances[admin] += amountBankCut;
    balances[cryptoHeadTokens[tokenID].owner] += (soldPrice - amountFirstOwnerCut - amountBankCut);

    _transfer(cryptoHeadTokens[tokenID].owner, msg.sender, tokenID);

    cryptoHeadTokens[tokenID].owner = msg.sender;
    cryptoHeadTokens[tokenID].status = "owned";
    cryptoHeadTokens[tokenID].value = soldPrice;
  }







  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - AUCTIONS - - - - - - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //


  function createAuction(uint tokenID, uint minValue) external {
      require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
      require(compareStrings(cryptoHeadTokens[tokenID].status, "owned"), "This CryptoHead must be owned (not for Sale or Auction)");
      require(minValue > 1000 wei, "The minimum bid price is 1000 WEI");

      cryptoHeadTokens[tokenID].status = "auction";
      cryptoHeadTokens[tokenID].minValue = minValue;
      cryptoHeadTokens[tokenID].exRate = exchangeRate;
  }



  function removeAuction(uint tokenID) public {
    require(msg.sender == cryptoHeadTokens[tokenID].owner, "This CryptoHead auction does not belong to you");
    require(compareStrings(cryptoHeadTokens[tokenID].status, "auction"), "This CryptoHead is not set for Auction");

    // Pay back the highest bidder
    if (cryptoHeadTokens[tokenID].highestBidder != address(0x0)) balances[cryptoHeadTokens[tokenID].highestBidder] += cryptoHeadTokens[tokenID].minValue;

    cryptoHeadTokens[tokenID].status = "owned";
    cryptoHeadTokens[tokenID].minValue = 0;
    cryptoHeadTokens[tokenID].highestBidder = address(0x0);
  }



  function offerBid(uint tokenID, bool useBalance, uint useAmt) payable external {
    require(compareStrings(cryptoHeadTokens[tokenID].status, "auction"), "This CryptoHead is not set for auction.");
    require((msg.value > cryptoHeadTokens[tokenID].minValue) || (useBalance && balances[msg.sender] >= useAmt && (msg.value + useAmt) > cryptoHeadTokens[tokenID].minValue), "You must offer greater then the minimum bid required");

    // Pay back the previous highest bidder
    if (cryptoHeadTokens[tokenID].highestBidder !=  address(0x0)) balances[cryptoHeadTokens[tokenID].highestBidder] += cryptoHeadTokens[tokenID].minValue;

    cryptoHeadTokens[tokenID].highestBidder = msg.sender;
    if (useBalance) {
      cryptoHeadTokens[tokenID].minValue = msg.value + useAmt;
      balances[msg.sender] -= useAmt;
    } else {
      cryptoHeadTokens[tokenID].minValue = msg.value;
    }

    emit E_NewCryptoHeadBid(tokenID, msg.value, msg.sender);
  }



  function acceptBid(uint tokenID) external {
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(cryptoHeadTokens[tokenID].highestBidder != address(0x0), "There is no bidder on this auction");
    require(compareStrings(cryptoHeadTokens[tokenID].status, "auction"), "This auction does not exist");

    uint soldPrice = cryptoHeadTokens[tokenID].minValue;
    address buyer = cryptoHeadTokens[tokenID].highestBidder;

    // - - - - - Pay the people - - - -//
    uint amountFirstOwnerCut = (soldPrice * firstOwnerTradeCut) / 100;
    uint amountBankCut = (soldPrice * cryptoHeadTokens[tokenID].exRate) / 100;
    balances[firstOwners[tokenID]] += amountFirstOwnerCut;
    balances[admin] += amountBankCut;
    balances[cryptoHeadTokens[tokenID].owner] += (soldPrice - amountFirstOwnerCut - amountBankCut);

    _transfer(msg.sender, buyer, tokenID);

    cryptoHeadTokens[tokenID].status = "owned";
    cryptoHeadTokens[tokenID].minValue = 0;
    cryptoHeadTokens[tokenID].owner = buyer;
    cryptoHeadTokens[tokenID].value = soldPrice;
    cryptoHeadTokens[tokenID].highestBidder = address(0x0);
  }



}
