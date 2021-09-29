
/*
 * I would like to ensure that this code is correct.
 * I explain above each function what I would like it to do.
 * Anyone familiar with RocketPool please help :)
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RocketPool_TEST is Ownable {

  using SafeMath for uint;
  RocketStorageInterface rocketStorage = RocketStorageInterface(0);
  uint public totalEthStaked = 0;

  constructor(address _rocketStorageAddress) {
    rocketStorage = RocketStorageInterface(_rocketStorageAddress);
  }



  /*
   * When someone calls this function I want the msg.value to be deposited (staked) into RocketPool.
   * And I want the rETH minted to belong to this contract address.
   */
  function depositToPool() external payable {
    require(msg.value > 0.01, "Invalid deposit amount");

    // Load Rocket contracts
    address rocketDepositPoolAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketDepositPool")));
    RocketDepositPoolInterface rocketDepositPool = RocketDepositPoolInterface(rocketDepositPoolAddress);
    address rocketETHTokenAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketETHToken")));
    RocketETHTokenInterface rocketETHToken = RocketETHTokenInterface(rocketETHTokenAddress);

    // Forward deposit to RocketPool & get amount of rETH minted
    uint256 rethBalance1 = rocketETHToken.balanceOf(address(this));
    rocketDepositPool.deposit{value: msg.value}();
    uint256 rethBalance2 = rocketETHToken.balanceOf(address(this));
    require(rethBalance2 > rethBalance1, "No rETH was minted");
    uint256 rethMinted = rethBalance2 - rethBalance1;

    // Now we keep track of the total ETH that has been staked.
    totalEthStaked = totalEthStaked.add(msg.value);
  }



  /*
   * I want this function to tell me how much rewards are claimable without withdrawing the totalEthStaked deposits.
   * This should return the rewards amounts in terms of rETH and ETH eqivalent
   */
  function checkRewards() external onlyOwner returns (uint, uint) {
    // Load Rocket contracts
    address rocketETHTokenAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketETHToken")));
    RocketETHTokenInterface rocketETHToken = RocketETHTokenInterface(rocketETHTokenAddress);

    // Get rewards amounts
    uint rEthBalance = rocketETHToken.balanceOf(address(this));
    uint256 rEthRewards = rEthBalance.sub(RocketTokenREthInterface().getREthAmount(totalEthStaked));
    uint256 ethRewards = RocketTokenREthInterface().getEthValue(rEthRewards);

    return (rEthReward, ethRewards);
  }



  /*
   * I want this function to send to the owner() of this contract the rewards claimable in ETH
   * without withdrawing the totalEthStaked deposits.
   */
  function claimRewardsETH() external onlyOwner {
    // Load Rocket contracts
    address rocketETHTokenAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketETHToken")));
    RocketETHTokenInterface rocketETHToken = RocketETHTokenInterface(rocketETHTokenAddress);

    // Get rewards amounts
    uint rEthBalance = rocketETHToken.balanceOf(address(this));
    uint rEthRewards = rEthBalance.sub(RocketTokenREthInterface().getREthAmount(totalEthStaked));

    // Burn rETH to ETH
    uint ethBalanceBefore = address(this).balance;
    rocketETHToken.burn(rEthRewards);

    // Send ETH to msg.sender
    payable(msg.sender).send{value: (address(this).balance - ethBalanceBefore)}();
  }



  /*
   * I want this function to send to the owner() of this contract the rewards claimable in rETH
   * without withdrawing the totalEthStaked deposits.
   * This is in case the RocketPool does not have enough liquidity to do the conversion from rETH to ETH.
   */
  function claimRewardsRETH() external onlyOwner {
    // Load Rocket contracts
    address rocketETHTokenAddress = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketETHToken")));
    RocketETHTokenInterface rocketETHToken = RocketETHTokenInterface(rocketETHTokenAddress);

    // Get rewards amounts
    uint rEthBalance = rocketETHToken.balanceOf(address(this));
    uint rEthRewards = rEthBalance.sub(RocketTokenREthInterface().getREthAmount(totalEthStaked));

    // Transfer rETH to msg.sender
    require(rocketETHToken.transfer(msg.sender, rEthRewards), "rETH rewards was not claimed");
  }


}
