pragma solidity >=0.4.25 <0.6.0;

contract smartMeters {
  address owner;
  struct meter {
    bool isSubscribed;
    // other relevant parameters
  }
  address[] metersArr;
  mapping (address => meter) meters;

  event deployMeterService(address meterProvider, address meterContract);

  constructor () public {
    owner = msg.sender;
    emit deployMeterService(msg.sender, address(this));
  }

  function insertMeter(address meter_) public onlyOwner {
    require(!meters[meter_].isSubscribed, "Meter already subscribed.");
    meters[meter_].isSubscribed = true;
    metersArr.push(meter_);
  }

  function isValidMeter(address meter_) public view returns (bool) {
    return meters[meter_].isSubscribed;
  }

  modifier onlyOwner {
    require(msg.sender == owner, "Only retailer can modify!");
    _;
  }
}