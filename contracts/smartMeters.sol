pragma solidity >=0.4.25 <0.6.0;

contract smartMeters {
  address owner;
  struct meter {
    bool isSubscribed;
    // other parameters
  }
  address[] metersArr;
  mapping (address => meter) meters;

  constructor () public {
    owner = msg.sender;

  }

  function insertMeter(address meter) public onlyOwner {
    require(!meters[meter].isSubscribed, "Meter already subscribed.");
    meters[meter].isSubscribed = true;
    metersArr.push(meter);
  }

  modifier onlyOwner {
    require(msg.sender == owner, "Only retailer can modify!");
    _;
  }

}