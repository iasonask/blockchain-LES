pragma solidity ^0.5.0;

contract doubleAuction {
  address owner;

  constructor () public {
    owner = msg.sender;
  }
  
}