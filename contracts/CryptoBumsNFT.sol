// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";


contract CryptoHeads is ERC721URIStorage {

  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - State Variables - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  address private adminAddress;
  address private bankAddress;

  uint constant bankTradeCut = 5;         // in %
  uint constant firstOwnerTradeCut = 5;   // in %

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIDsCounter;

  mapping (uint256 => address) public firstOwners;    // Mapping from tokenID to owner

  struct Bid {
    bool exists;
    address bidder;
    uint tokenID;
    uint value;
  }

  struct Auction {
    bool exists;
    uint tokenID;
    address seller;
    uint minValue;          // in ether
    uint highestBid;
    address highestBidder;
    mapping (address => Bid) auctionBids;
  }

  mapping (uint256 => Auction) public cryptoHeadAuctions;  //tokenID -> auction
  //mapping (uint256 => Bid) public cryptoHeadBids;  //tokenID -> Bid

  struct DirectSell {
    bool exists;
    uint tokenID;
    address seller;
    uint value;
  }

  mapping (uint256 => DirectSell) public cryptoHeadDirectSells; //tokenID -> DirectSell




  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - EVENTS - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  event E_claimedTokens(uint256 amount);

  event E_CryptoHeadTransfer(uint256 tokenID, address from, address to);

  event E_NewCryptoHeadDirectSell(uint256 tokenID, uint256 value);
  event E_RemovedCryptoHeadDirectSell(uint256 tokenID);
  event E_CryptoHeadDriectBought(uint256 tokenID, uint256 value, address from, address to);

  event E_NewCryptoHeadAuction(uint256 tokenID, uint256 minValue);
  event E_RemovedCryptoHeadAuction(uint256 tokenID);
  event E_NewCryptoHeadBid(uint256 tokenID, uint256 value, address from);
  event E_CryptoHeadBidAccepted(uint256 tokenID, uint256 value, address from, address to);





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - CONSTRUCTOR - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  constructor() ERC721("CryptoHeads", "NFT") {
    adminAddress = msg.sender;
    bankAddress = msg.sender;
  }




  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - ADMIN Functions - - - - - - - - - - - //
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function setAdminAddress(address newAdminAddress) external {
    require(msg.sender == adminAddress, "Only the admin can call this function");
    adminAddress = newAdminAddress;
  }


  function setBankAddress(address newBankAddress) external {
    require(msg.sender == adminAddress, "Only the admin can call this function");
    bankAddress = newBankAddress;
  }

  /*
  function _baseURI() internal view override returns (string memory) {
    return 'localhost:3000/'
  }*/






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - Claim an initial CryptoHead - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function claimFirst(string memory tokenURI) public returns (uint256) {
    require(_tokenIDsCounter.current() <= 10000, "All CryptoHead tokens are already claimed");
    require(balanceOf(msg.sender) == 0, "You can only be the first owner of one CryptoHead NFT");

    _tokenIDsCounter.increment();

    uint256 newTokenID = _tokenIDsCounter.current();
    _safeMint(msg.sender, newTokenID);
    _setTokenURI(newTokenID, tokenURI);
    firstOwners[newTokenID] = msg.sender;

    emit E_claimedTokens(_tokenIDsCounter.current());

    return newTokenID;
  }





  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - Transfer a CryptoHead to someone without payment - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function transferCryptoHead(address to, uint256 tokenID) public {
    require(_exists(tokenID), "This CryptoHead tokenID does not exist");
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    _transfer(msg.sender, to, tokenID);

    if (cryptoHeadAuctions[tokenID].exists) {
      cryptoHeadAuctions[tokenID].seller = to;  //If it was set for auction keep the auction change the seller
      if (cryptoHeadAuctions[tokenID].auctionBids[to].exists) {  //If reciever had a bid on it, give back his money.
        payable(to).transfer(cryptoHeadAuctions[tokenID].auctionBids[to].value);
        delete cryptoHeadAuctions[tokenID].auctionBids[to];
      }
    }
    if (cryptoHeadDirectSells[tokenID].exists) {
      cryptoHeadDirectSells[tokenID].seller = to;  //If it was set for direct sell, change the seller to to
    }

    emit E_CryptoHeadTransfer(tokenID, msg.sender, to);
  }






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - Directly sell your cryptoHead (without an auction) - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function createDirectSell(uint256 tokenID, uint256 value) external {
    require(_exists(tokenID), "This CryptoHead tokenID does not exist");
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(!cryptoHeadDirectSells[tokenID].exists, "This CryptoHead is already set up for DirectSell");
    require(!cryptoHeadAuctions[tokenID].exists, "This CryptoHead is already set up for Auction");
    //require(value > 0.01, "The minimum sale price is 0.01 ETH");

    DirectSell storage newForSale = cryptoHeadDirectSells[tokenID];
    newForSale.exists = true;
    newForSale.tokenID = tokenID;
    newForSale.seller = msg.sender;
    newForSale.value = value;

    emit E_NewCryptoHeadDirectSell(tokenID, value);
  }


  function removeDirectSell(uint256 tokenID) public {
    require(_exists(tokenID), "This CryptoHead tokenID does not exist");
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(msg.sender == cryptoHeadDirectSells[tokenID].seller, "The direct sell does not belong to you");

    delete cryptoHeadDirectSells[tokenID];

    emit E_RemovedCryptoHeadDirectSell(tokenID);
  }


  function buyDirectSell(uint256 tokenID) payable external {
    require(_exists(tokenID), "This CryptoHead tokenID does not exist");
    require(cryptoHeadDirectSells[tokenID].exists, "This CryptoHead is not for dierct sell");
    require(msg.sender != cryptoHeadDirectSells[tokenID].seller, "You cannot buy your own CryptoHead");
    require(msg.value >= cryptoHeadDirectSells[tokenID].value, "You must enter a value >= to price required to buy");

    uint256 soldPrice = msg.value;
    address seller = cryptoHeadDirectSells[tokenID].seller;
    address buyer = msg.sender;

    // - - - - - Pay the people - - - -//
    uint256 amountFirstOwnerCut = (soldPrice * firstOwnerTradeCut) / 100;
    uint256 amountBankCut = (soldPrice * bankTradeCut) / 100;
    uint256 amountSellerCut = soldPrice - amountFirstOwnerCut - amountBankCut;

    payable(firstOwners[tokenID]).transfer(amountFirstOwnerCut);
    payable(bankAddress).transfer(amountBankCut);
    payable(seller).transfer(amountSellerCut);

    _transfer(seller, buyer, tokenID);

    //delete cryptoHeadDirectSells[tokenID];
    removeDirectSell(tokenID);

    emit E_CryptoHeadDriectBought(tokenID, soldPrice, seller, msg.sender);
  }






  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  //- - - - - - - - - - - - - - AUCTIONS - - - - - - - - - - - - - -//
  //- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  function createAuction(uint256 tokenID, uint256 minSalePrice) external {
      require(_exists(tokenID), "This CryptoHead tokenID does not exist");
      require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
      require(!cryptoHeadAuctions[tokenID].exists, "This CryptoHead is already set up for Auction");
      require(!cryptoHeadDirectSells[tokenID].exists, "This CryptoHead is already set up for DirectSell");
      //require(minSalePrice > 0.01, "The minimum sale price is 0.01 ETH");

      Auction storage newAuction = cryptoHeadAuctions[tokenID];
      newAuction.exists = true;
      newAuction.tokenID = tokenID;
      newAuction.seller = msg.sender;
      newAuction.minValue = minSalePrice;
      newAuction.highestBid = 0;

      emit E_NewCryptoHeadAuction(tokenID, minSalePrice);
  }



  function removeAuction(uint256 tokenID) public {
    require(msg.sender == cryptoHeadAuctions[tokenID].seller, "This CryptoHead auction does not belong to you");

    //pay back all the bidders:
    /*foreach cryptoHeadAuctions[tokenID].auctionBids(function (bid) {
      payable(bid.bidder).transfer(bid.value);
      delete cryptoHeadAuctions[tokenID].auctionBids[bid.bidder];
    });*/

    // Delete auciton from the mapping
    delete cryptoHeadAuctions[tokenID];

    emit E_RemovedCryptoHeadAuction(tokenID);
  }



  function offerBid(uint256 tokenID) payable external {
    require(_exists(tokenID), "This CryptoHead tokenID does not exist");
    require(ownerOf(tokenID) != msg.sender, "You cannot offer a bid on your own CryptoHead");
    require(msg.value >= cryptoHeadAuctions[tokenID].minValue, "You must offer at least the minimum bid required");
    require(msg.value > cryptoHeadAuctions[tokenID].highestBid, "You must offer a bid greater than the current");

    Bid storage newBid = cryptoHeadAuctions[tokenID].auctionBids[msg.sender];
    newBid.exists = true;
    newBid.tokenID = tokenID;
    newBid.bidder = msg.sender;
    newBid.value = msg.value;

    cryptoHeadAuctions[tokenID].highestBid = msg.value;
    cryptoHeadAuctions[tokenID].highestBidder = msg.sender;

    emit E_NewCryptoHeadBid(tokenID, msg.value, msg.sender);
  }



  function acceptBid(uint256 tokenID) external {
    require(_exists(tokenID), "This CryptoHead tokenID does not exist");
    require(msg.sender == ownerOf(tokenID), "This CryptoHead does not belong to you");
    require(msg.sender == cryptoHeadAuctions[tokenID].seller, "This auction does not belong to you");
    require(cryptoHeadAuctions[tokenID].exists, "This auction does not exist");
    require(cryptoHeadAuctions[tokenID].exists, "There is no bid on this auction");
    require(cryptoHeadAuctions[tokenID].highestBid > 0, "The bid on this auction is not valid");

    uint256 soldPrice = cryptoHeadAuctions[tokenID].highestBid;
    address buyer = cryptoHeadAuctions[tokenID].highestBidder;

    // - - - - - Pay the people - - - -//
    uint256 amountFirstOwnerCut = (soldPrice * firstOwnerTradeCut) / 100;
    if (msg.sender == firstOwners[tokenID]) { //aka this is the first owner selling his CryptoHead for the first time
      amountFirstOwnerCut = 0;
    }
    uint256 amountBankCut = (soldPrice * bankTradeCut) / 100;
    uint256 amountSellerCut = soldPrice - amountFirstOwnerCut - amountBankCut;

    if (amountFirstOwnerCut > 0) {
      payable(firstOwners[tokenID]).transfer(amountFirstOwnerCut);
    }
    payable(bankAddress).transfer(amountBankCut);
    payable(cryptoHeadAuctions[tokenID].seller).transfer(amountSellerCut);

    //delete cryptoHeadAuctions[tokenID];
    //Delete the auction. First delete the bidder from the auctionBids Since we don't want to refund him
    delete cryptoHeadAuctions[tokenID].auctionBids[buyer];
    removeAuction(tokenID);

    // - - - Transfer the CryptoHead NFT to new Owner - - - //
    _transfer(msg.sender, buyer, tokenID);

    emit E_CryptoHeadBidAccepted(tokenID, soldPrice, msg.sender, buyer);
  }



}
