pragma solidity >=0.4.25 <0.6.0;

import "./smartMeters.sol";

contract doubleAuction {
  address owner;
  uint256 constant INITIAL_DEPOSIT = 0;

  // sellers data
  struct seller {
    bytes32 bidValue;
    uint256 energy;
    address meter;
    uint256 deposit;
    bool isSubscribed;
    bool isTrading;
    uint256 volToTrade;
    uint256 measuredVol;
    bool hasDeclared;
    bool hasBeenPayed;
  }
  mapping(address => seller) sellers;
  address[] sellersArr;
  uint256[] sellBids;
  uint256 sellVolume = 0; 

  // buyers data
  struct buyer {
    bytes32 bidValue;
    uint256 energy;
    address meter;
    uint256 deposit;
    bool isSubscribed;
    bool isTrading;
    uint256 volToTrade;
    uint256 measuredVol;
    bool hasDeclared;
    bool hasPayed;
  }
  mapping(address => buyer) buyers;
  address[] buyersArr;
  uint256[] buyBids;
  uint256 buyVolume = 0;

  // smart meters
  smartMeters smartMeterContract;

  // UC related parameters
  uint256 t0;
  uint256 t1;
  uint256 t2;
  uint256 t3;
  uint256 t4;
  uint256 t5;
  uint256 t6;
  uint256 deposit;
  uint256 public price;
  
  // event to inform smart meters for declaring energy consumption
  event subscriptionBuyer(address meter, address user, uint256 t3, uint256 t4,  uint256 t5);
  event subscriptionSeller(address meter, address user, uint256 t3, uint256 t4,  uint256 t5);

  // inform potential buyers and sellers for trading
  event tradeEnergyBuyer(address buyer, uint256 energyVolume);
  event tradeEnergySeller(address seller, uint256 energyVolume);

  constructor (address meterProvider, uint256 t1_, uint256 t2_, 
  uint256 t3_,  uint256 t4_, uint256 t5_,  uint256 t6_, 
  uint256 deposit_) public payable {
    require(msg.value >= INITIAL_DEPOSIT, "Contract instantiation requires INITIAL_DEPOSIT.");
    owner = msg.sender;
    t0 = getBlockNumber();
    t1 = t0 + t1_;
    t2 = t0 + t2_;
    t3 = t0 + t3_;
    t4 = t0 + t4_;
    t5 = t0 + t5_;
    t6 = t0 + t6_;
    deposit = deposit_;
    smartMeterContract = smartMeters(meterProvider);
  }

  //make bids
  function bidSeller(bytes32 bid, address meter, uint256 energy) public onlyBidding payable {
    require(msg.value >= deposit, "Insufficient deposit.");
    require(isValidMeter(meter), "Meter not valid.");
    sellers[msg.sender] = seller(bid, energy, meter, msg.value, true, false, 0, 0, false, false);
    sellersArr.push(msg.sender);
  }

  function bidBuyer(bytes32 bid, address meter, uint256 energy) public onlyBidding payable {
    require(msg.value >= deposit, "Insufficient deposit.");
    require(isValidMeter(meter), "Meter not valid.");
    buyers[msg.sender] = buyer(bid, energy, meter, msg.value, true, false, 0, 0, false, false);
    buyersArr.push(msg.sender);
  }

  // reveal bids
  function revealSeller(bytes32 nonce, uint256 bidValue) public onlyReveal {
    require(sellers[msg.sender].isSubscribed, "Seller has not committed bid.");
    require(makeCommitment(nonce, bidValue) == sellers[msg.sender].bidValue, "Invalid sell bid.");
    sellBids.push(bidValue);
    (sellBids, sellersArr) = bidSortAscenting(sellBids, sellersArr);
    // calculate total energy volume
    sellVolume += sellers[msg.sender].energy;
  }

  function revealBuyer(bytes32 nonce, uint256 bidValue) public onlyReveal {
    require(buyers[msg.sender].isSubscribed, "Buyer has not committed bid.");
    require(makeCommitment(nonce, bidValue) == buyers[msg.sender].bidValue, "Invalid buy bid.");
    buyBids.push(bidValue);
    (buyBids, buyersArr) = bidSortDescenting(buyBids, buyersArr);
    // calculate total energy volume
    buyVolume += buyers[msg.sender].energy;
  }

  // clear the market
  function clearMarket() public onlyMatching {

    // construct demand and supply curves
    uint256 maxVol = max(buyVolume, sellVolume);
    uint256 i;
    uint256 tempVol;

    uint256[] memory buyPrices = new uint[](maxVol);
    uint256 j_buy = 0;
    for (i = 0; i < buyBids.length; i++) {
      tempVol = buyers[buyersArr[i]].energy;
      while (tempVol > 0) {
        buyPrices[j_buy] = buyBids[i];
        tempVol--;
        j_buy++;
      }
    }
    
    uint256[] memory sellPrices = new uint[](maxVol);
    uint256 j_sell = 0;
    for (i = 0; i < sellBids.length; i++) {
      tempVol = sellers[sellersArr[i]].energy;
      while (tempVol > 0) {
        sellPrices[j_sell] = sellBids[i];
        tempVol--;
        j_sell++;
      }
    }

    // calculate the market clearing price
    for (i = 0; i < buyPrices.length; i++) {
      if (buyPrices[i] < sellPrices[i]) {
        price = (buyPrices[i-1] + sellPrices[i-1])/2;
        break;
      } else if (buyPrices[i] == sellPrices[i]) {
        price = buyPrices[i];
      }
    }

    // find eligible buy bids
    buyVolume = 0;
    for (i = 0; i < buyBids.length; i++) {
      if (buyBids[i] >= price) {
        buyVolume += buyers[buyersArr[i]].energy;
      }
    }

    // find eligible sell bids
    sellVolume = 0;
    for (i = 0; i < sellBids.length; i++) {
      if (sellBids[i] <= price) {
        sellVolume += sellers[sellersArr[i]].energy;
      }
    }

    // volume that will be traded
    uint256 vol = min(buyVolume, sellVolume);

    // trade: find matching buy bids
    i = 0;
    tempVol = vol;
    while (tempVol > 0) {
      if (buyers[buyersArr[i]].energy <= tempVol) {
        tempVol -= buyers[buyersArr[i]].energy;
        buyers[buyersArr[i]].isTrading = true;
        buyers[buyersArr[i]].volToTrade = buyers[buyersArr[i]].energy;
        emit tradeEnergyBuyer(buyersArr[i], buyers[buyersArr[i]].energy);
        emit subscriptionBuyer(buyers[buyersArr[i]].meter, buyersArr[i], t3, t4, t5);
        i++;
      } else {
        buyers[buyersArr[i]].isTrading = true;
        buyers[buyersArr[i]].volToTrade = buyers[buyersArr[i]].energy;
        emit tradeEnergyBuyer(buyersArr[i], tempVol);
        emit subscriptionBuyer(buyers[buyersArr[i]].meter, buyersArr[i], t3, t4, t5);
        break;
      }
    }

    // trade: find matching selling bids
    i = 0;
    tempVol = vol;
    while (tempVol > 0) {
      if (sellers[sellersArr[i]].energy <= tempVol) {
        tempVol -= sellers[sellersArr[i]].energy;
        sellers[sellersArr[i]].isTrading = true;
        sellers[sellersArr[i]].volToTrade = sellers[sellersArr[i]].energy;
        emit tradeEnergySeller(sellersArr[i], sellers[sellersArr[i]].energy);
        emit subscriptionSeller(sellers[sellersArr[i]].meter, sellersArr[i], t3, t4, t5);
        i++;
      } else {
        sellers[sellersArr[i]].isTrading = true;
        sellers[sellersArr[i]].volToTrade = tempVol;
        emit tradeEnergySeller(sellersArr[i], tempVol);
        emit subscriptionSeller(sellers[sellersArr[i]].meter, sellersArr[i], t3, t4, t5);
        break;
      }
    }
  }

  function energyDeclarationsBuyers(address buyer_, uint256 volume) public onlyDeclare {
    require(!buyers[buyer_].hasDeclared, "Buyer has already declared.");
    require(isValidMeter(msg.sender), "Not a valid smart meter");
    require(buyers[buyer_].meter == msg.sender, "Address of meter is different than the one initialy declared.");
    buyers[buyer_].measuredVol = volume;
  }

  function energyDeclarationsSellers(address seller_, uint256 volume) public onlyDeclare {
    require(!sellers[seller_].hasDeclared, "Seller has already declared.");
    require(isValidMeter(msg.sender), "Not a valid smart meter");
    require(sellers[seller_].meter == msg.sender, "Address of meter is different than the one initialy declared.");
    sellers[seller_].measuredVol = volume;
  }

  // buyers send their payments
  function sendPayment() public onlyPay payable {
    require(buyers[msg.sender].isSubscribed, "Buyer is not subscribed!");
    require(!buyers[msg.sender].hasPayed, "Buyer has payed.");
    // require(msg.value >= price*buyers[msg.sender].volToTrade, "Not enough funds.");
    if (buyers[msg.sender].isTrading) {
      // refund user. What if the user consumes less or more than the initial bidding?
      if (msg.value > price * buyers[msg.sender].volToTrade) {
        msg.sender.transfer(msg.value - price*buyers[msg.sender].volToTrade);
      }  
    }
    
    // return initial deposit
    msg.sender.transfer(buyers[msg.sender].deposit);
    buyers[msg.sender].hasPayed = true;    
  }

  function receivePayment() public onlyPay {
    require(sellers[msg.sender].isSubscribed, "Seller is not subscribed!");
    require(!sellers[msg.sender].hasBeenPayed, "Seller has been payed.");
    if (sellers[msg.sender].isTrading) {
      // refund seller according to its actual production
      uint256 refund = price*min(sellers[msg.sender].measuredVol, sellers[msg.sender].volToTrade);
      msg.sender.transfer(refund);
    }
    
    // return also initial deposit
    msg.sender.transfer(sellers[msg.sender].deposit);
    sellers[msg.sender].hasBeenPayed = true;
  }

  function getPrice() public view returns (uint256) {
    return price;
  }

  // Commitment utility
  function makeCommitment(bytes32 nonce, uint256 bidValue) public pure returns(bytes32) {
    return keccak256(abi.encodePacked(nonce, bidValue));
  }

  function isValidMeter(address meter) public view returns(bool) {
    return smartMeterContract.isValidMeter(meter);
  }

  // detroy contract
  function finalize() public onlyOwner {
    // require(isFinalizationPeriod(), "Finalization period has not yet arrived.");
    selfdestruct(msg.sender);
  }

  // sort bids as they are being revealed
  function bidSortAscenting(uint[] memory arr, address[] memory bidders) private pure returns (uint[] memory, address[] memory) { 
    uint256 n = arr.length;
    uint256 i = n-1;
    uint256 key = arr[i];
    address temp = bidders[i];

    while (i > 0 && arr[i-1] > key) {
      arr[i] = arr[i-1];
      arr[i-1] = key;
      // sort bidders array accordingly
      bidders[i] = bidders[i-1];
      bidders[i-1] = temp;
      key = arr[i];
      temp = bidders[i];
      i--;
    }
    return (arr, bidders);
  }

  function bidSortDescenting(uint[] memory arr, address[] memory bidders) private pure returns (uint[] memory, address[] memory) {
    uint256 n = arr.length;
    uint256 i = n-1;
    uint256 key = arr[i];
    address temp = bidders[i];

    while (i > 0 && arr[i-1] < key) {
      arr[i] = arr[i-1];
      arr[i-1] = key;
      // sort bidders array accordingly
      bidders[i] = bidders[i-1];
      bidders[i-1] = temp;
      key = arr[i];
      temp = bidders[i];
      i--;
    }
    return (arr, bidders);
  }

  function max(uint a, uint b) private pure returns (uint) {
    return a > b ? a : b;
  }

  function min(uint a, uint b) private pure returns (uint) {
    return a > b ? b : a;
  }

  // boolean functions for checking the differnt time periods
  function isBiddingPeriod() private view returns (bool) {
    return (getBlockNumber() < t1) && (getBlockNumber() >= t0);
  }

  function isRevealPeriod() private view returns (bool) {
    return (getBlockNumber() < t2) && (getBlockNumber() >= t1);
  }

  function isMatchingPeriod() private view returns (bool) {
    return  (getBlockNumber() < t3) && (getBlockNumber() >= t2);
  }

  function isDeclarationPeriod() private view returns (bool) {
    return (getBlockNumber() < t5) && (getBlockNumber() >= t4);
  }

  function isPaymentPeriod() private view returns (bool) {
    return (getBlockNumber() < t6) && (getBlockNumber() >= t5);
  }

  function isFinalizationPeriod() private view returns (bool) {
    return (getBlockNumber() >= t6);
  }

  function getBlockNumber() private view returns (uint256) {
    return block.number;
  }

  // cansel modifiers  for simplified testing
  modifier onlyBidding {
    // require(isBiddingPeriod(), "Bidding period has not started or has already ended.");
    _;
  }

  modifier onlyReveal {
    // require(isRevealPeriod(), "Reveal period has not started or has already ended.");
    _;
  }

  modifier onlyMatching {
    // require(isMatchingPeriod(), "Matching period has not started or has already ended.");
    _;
  }

  modifier onlyDeclare {
    // require(isDeclarationPeriod(), "Declaration period has not started or has already ended.");
    _;
  }

  modifier onlyPay {
    // require(isPaymentPeriod(), "Payment period has not started or has already ended.");
    _;
  }

  modifier onlyOwner {
    require(msg.sender == owner, "Only retailer can modify!");
    _;
  }
  
}