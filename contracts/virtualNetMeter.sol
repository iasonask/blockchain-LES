pragma solidity >=0.4.25 <0.6.0;

contract DateTime {
  function getYear(uint timestamp) public view returns (uint16);
  function getMonth(uint timestamp) public view returns (uint8);
  function getDay(uint timestamp) public view returns (uint8);
  function getHour(uint timestamp) public view returns (uint8);
  function getMinute(uint timestamp) public view returns (uint8);
}

contract virtualNetMeter {
    
  address owner;
  // prosumer data
  struct prosumer {
    address pros;
    uint8 typeOf; //0 load, 1 production, 2 combined
    uint256 activeP;
    uint256 mismatch;
    bool isActive;
    bool isSubscribed;
  }
  address[] users;
  mapping (address => prosumer) prosumers;

  address public dateTimeAddr = 0x8Fc065565E3e44aef229F1D06aac009D6A524e82;
  DateTime dateTime = DateTime(dateTimeAddr);

  // UC related vars
  uint16 constant t0 = 0;
  uint16 constant t1 = 5;
  uint16 constant t2 = 5;
  uint256 productionBalance = 0;
  uint256 consumptionBalance = 0;

  event subscription (address user);

  constructor () public {
    owner = msg.sender;
    // t0 = getBlockNumber();
  }
  
  // subscribe new prosumers
  function subscribeUser (uint8 typeOf) public {
    require(!prosumers[msg.sender].isSubscribed, "User already subscribed!");
    prosumers[msg.sender] = prosumer(msg.sender, typeOf, 0, 0, true, true);
    users.push(msg.sender);
    emit subscription(msg.sender);
  }

  // users declare their production
  function subscribeProduction (uint256 activeP_) public onlyProduction {
    require(prosumers[msg.sender].isSubscribed, "User is not subscribed!");
    require(activeP_ > 0, "Negative Production");
    prosumers[msg.sender].activeP = activeP_;
    productionBalance += activeP_;
  }

  // users declare their consumption
  function subscribeConsumption (uint256 activeP_) public onlyConsumption {
    require(prosumers[msg.sender].isSubscribed, "User is not subscribed!");
    require(activeP_ > 0, "Load should be positive");
    prosumers[msg.sender].activeP = activeP_;
    consumptionBalance += activeP_;
  }

  //dateTime related functions
  function getDay () public view returns (uint256) {
    return dateTime.getDay(now);
  }

  function getHourOfDay () public view returns (uint256) {
    return dateTime.getHour(now);
  }

  function getMinOfHour () public view returns (uint256) {
    return dateTime.getMinute(now);
  }
  
  function getBlockNumber () public view returns (uint256) {
    return block.number;
  }

  function isProductionSession() public view returns (bool) {
    return (getMinOfHour() < t1) && (getMinOfHour() >= t0);
  }
  
  function isConsumptionSession() public view returns (bool) {
    return (getMinOfHour() < t2) && (getMinOfHour() >= t1);
  }

  //modifiers
  modifier onlyProduction {
    require(isProductionSession(), "Production subscription session has not started or has already ended.");
    require((prosumers[msg.sender].typeOf == 1) || (prosumers[msg.sender].typeOf == 2), "User is not producer!");
    _;
  }

  modifier onlyConsumption {
    require(isConsumptionSession(), "Consumption subscription session has not started or has already ended.");
    require(prosumers[msg.sender].typeOf == 0, "User is not consumer!");
    _;
  }

  modifier onlyOwner {
    require(msg.sender == owner, "Only owner can modify!");
    _;
  }

  function destruct() public onlyOwner {
    selfdestruct(msg.sender);
  } 
    
  
}