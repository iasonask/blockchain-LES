pragma solidity >=0.4.25 <0.6.0;

contract doubleAuction {
  address owner;

  constructor () public {
    owner = msg.sender;
  }
  
}