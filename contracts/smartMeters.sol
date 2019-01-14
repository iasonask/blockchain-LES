pragma solidity >=0.4.25 <0.6.0;

contract smartMeters {

  address owner;

  struct meter {
    bool isSubscribed;
    // other relevant parameters
  }
  mapping (address => meter) meters;

  event deployMeterService(address meterProvider, address meterContract);

  constructor () public {
    owner = msg.sender;
    emit deployMeterService(msg.sender, address(this));
  }

  function insertMeter(address meter_) public onlyOwner {
    require(!meters[meter_].isSubscribed, "Meter already subscribed.");
    meters[meter_].isSubscribed = true;
  }

  function removeMeter(address meter_) public onlyOwner {
    require(meters[meter_].isSubscribed, "Meter isn't subscribed.");
    meters[meter_].isSubscribed = false;
  }

  function isValidMeter(address meter_) public view returns (bool) {
    return meters[meter_].isSubscribed;
  }

  function destroy() public onlyOwner {
    selfdestruct(msg.sender);
  }

  modifier onlyOwner {
    require(msg.sender == owner, "Only Meter Provider can modify!");
    _;
  }
}