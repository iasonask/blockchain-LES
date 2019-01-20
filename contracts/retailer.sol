pragma solidity >=0.4.25 <0.6.0;

import "./smartMeters.sol";

contract retailer {
  
  //retailer address
  address owner;

  // consumer data
  struct consumer {
    address consumer_;
    uint256 activeConsumption;
    address meter;
    uint256 deposit;
    bool isSubscribed;
    bool hasDeclared;
    bool hasPayed;
  }
  address[] users; ///
  mapping (address => consumer) consumers;

  // UC related parameters
  uint256 t0;
  uint256 t1;
  uint256 t2;
  uint256 t3;
  uint256 t4;
  uint256 price;
  uint256 deposit;

  // smart meters
  smartMeters smartMeterContract;

  // event to inform smart meters for declaring energy consumption
  event subscription(address meter, address user, uint256 t2, uint256 t3);

  //retailer deploys contract and defines the various time parameters
  constructor (address meterProvider, uint256 t1_, uint256 t2_, uint256 t3_, uint256 t4_, uint256 price_, uint256 deposit_) public {
    owner = msg.sender;
    t0 = getBlockNumber();
    t1 = t0 + t1_;
    t2 = t0 + t2_;
    t3 = t0 + t3_;
    t4 = t0 + t4_;
    price = price_;
    deposit = deposit_;
    smartMeterContract = smartMeters(meterProvider);
  }
  
  // subscribe new users only in timeframe between t0 and t1
  function subscribeUser (address meterID_) public onlySubscription payable {
    require(msg.value >= deposit, "Insufficient deposit.");
    require(isValidMeter(meterID_), "Meter not valid.");
    consumers[msg.sender] = consumer(msg.sender, 0, meterID_, msg.value, true, false, false);
    emit subscription(meterID_, msg.sender, t2, t3);
  }

  // smart meters declare autonomously their consumption
  function declarePeriod (address user, uint256 activeP_) public onlyDeclare {
    require(!consumers[user].hasDeclared, "Meter has already declared.");
    require(consumers[user].meter == msg.sender, "Address of meter is different from the one initialy declared.");
    consumers[user].activeConsumption = activeP_;
    consumers[user].hasDeclared = true;
  }

  // users pay correct amount in order to receive their initial deposits
  function paymentPeriod () public onlyPayment {
    require(!consumers[msg.sender].hasPayed, "User has already payed.");
    require(consumers[msg.sender].deposit >= consumers[msg.sender].activeConsumption * price, "Consumer consumption larger than initial deposit.");
    consumers[msg.sender].hasPayed = true;
    //return deposit to user
    msg.sender.transfer(consumers[msg.sender].deposit - consumers[msg.sender].activeConsumption * price);
  }

  // the retailer can acquire the users payments after t4 and destruct the contract
  function finalize() public onlyOwner {
    require(getBlockNumber() >= t4, "Period for finalization has not been reached yer.");
    selfdestruct(msg.sender);
  }

  function isValidMeter(address meter) internal view returns(bool) {
    return smartMeterContract.isValidMeter(meter);
  }

  // boolean functions for checking the differnt time periods
  function isSubscriptionPeriod() internal view returns (bool) {
    return (getBlockNumber() < t1) && (getBlockNumber() >= t0);
  }

  function isDeclarationPeriod() internal view returns (bool) {
    return (getBlockNumber() < t3) && (getBlockNumber() >= t2);
  }

  function isPaymentPeriod() internal view returns (bool) {
    return (getBlockNumber() < t4) && (getBlockNumber() >= t3);
  }

  function getBlockNumber() internal view returns (uint256) {
    return block.number;
  }

  //modifiers
  modifier onlySubscription {
    require(isSubscriptionPeriod(), "Subscription period has not started or has already ended.");
    require(!consumers[msg.sender].isSubscribed, "User already subscribed!");
    _;
  }

  modifier onlyDeclare {
    require(isDeclarationPeriod(), "Declaration period has not started or has already ended.");
    require(isValidMeter(msg.sender), "Not a valid smart meter");
    _;
  }

  modifier onlyPayment {
    require(isPaymentPeriod(), "Payment period has not started or has already ended.");
    require(consumers[msg.sender].isSubscribed, "User is not subscribed!");
    _;
  }

  modifier onlyOwner {
    require(msg.sender == owner, "Only retailer can modify!");
    _;
  }
}