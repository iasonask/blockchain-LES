pragma solidity >=0.4.25 <0.6.0;

contract doubleAuction {
  address owner;

  // bidders data
  struct seller {
    address seller_;
    bytes32 bidValue;
    uint256 energy;
    address meter;
    uint256 deposit;
    bool isSubscribed;
  }
  mapping(address => seller) sellers;
  address[] sellersArr;
  uint256[] sellBids;
  uint sellVolume = 0; 

  struct buyer {
    address buyer_;
    bytes32 bidValue;
    uint256 energy;
    address meter;
    uint256 deposit;
    bool isSubscribed;
  }
  mapping(address => buyer) buyers;
  address[] buyersArr;
  uint256[] buyBids;
  uint256 buyVolume = 0;

  // UC related parameters
  uint256 t0;
  uint256 t1;
  uint256 t2;
  uint256 t3;
  uint256 deposit;
  uint256 price;
  
  // event to inform smart meters for declaring energy consumption
  event subscription (address meter, address user, uint256 t2, uint256 t3);

  // event to inform consumers for participating in the energy auction
  event deployEnergyAuction (address retailer_con, uint256 t1, uint256 t2, uint256 t3);

  // inform potential buyers and sellers for trading
  event tradeEnergyBuyer(address buyer, uint256 energyVolume);
  event tradeEnergySeller(address seller, uint256 energyVolume);

  constructor (uint256 t1_, uint256 t2_, uint256 t3_, uint256 deposit_) public {
    owner = msg.sender;
    t0 = getBlockNumber();
    t1 = t0 + t1_;
    t2 = t1 + t2_;
    t3 = t2 + t3_;
    deposit = deposit_;
    emit deployEnergyAuction (address(this), t1, t2, t3);
  }

  //make bids
  function bidSeller(bytes32 bid, address meter, uint256 energy) public onlyBidding payable {
    // need to check for negative energy volume?? how?
    require(msg.value >= deposit, "Insufficient deposit.");
    sellers[msg.sender] = seller(msg.sender, bid, energy, meter, msg.value, true);
    sellersArr.push(msg.sender);
  }

  function bidBuyer(bytes32 bid, address meter, uint256 energy) public onlyBidding payable {
    require(msg.value >= deposit, "Insufficient deposit.");
    buyers[msg.sender] = buyer(msg.sender, bid, energy, meter, msg.value, true);
    buyersArr.push(msg.sender);
  }

  // reveal bids
  function revealSeller(bytes32 nonce, uint256 bidValue) public onlyReveal {
    require(sellers[msg.sender].isSubscribed, "Seller has not committed bid.");
    require(makeCommitment(nonce, bidValue) == sellers[msg.sender].bidValue, "Invalid sell bid.");
    sellBids.push(bidValue);
    (sellBids, sellersArr) = bidSortAscenting(sellBids, sellersArr);
    // calculate total energy volume
    uint256 i;
    for (i = 0; i < sellBids.length; i++) {
      sellVolume += sellers[sellersArr[i]].energy;
    }
  }

  function revealBuyer(bytes32 nonce, uint256 bidValue) public onlyReveal {
    require(buyers[msg.sender].isSubscribed, "Buyer has not committed bid.");
    require(makeCommitment(nonce, bidValue) == buyers[msg.sender].bidValue, "Invalid buy bid.");
    buyBids.push(bidValue);
    (buyBids, buyersArr) = bidSortDescenting(buyBids, buyersArr);
    // calculate total energy volume
    uint256 i;
    for (uint i = 0; i < buyBids.length; i++) {
      buyVolume += buyers[buyersArr[i]].energy;
    }
  }

  // clear the market
  function clearMarket() public onlyMatching {

    // construct demand and supply curves
    uint256 maxVol = max(buyVolume, sellVolume);
    uint i;

    uint256[] memory buyPrices = new uint[](maxVol);
    uint256 j_buy = 0;
    for (i = 0; i < buyBids.length; i++) {
      uint256 tempVol = buyers[buyersArr[i]].energy;
      while (tempVol > 0) {
        buyPrices[j_buy] = buyBids[i];
        tempVol--;
        j_buy++;
      }
    }
    
    uint256[] memory sellPrices = new uint[](maxVol);
    uint256 j_sell = 0;
    for (i = 0; i < sellBids.length; i++) {
      uint256 tempVol = sellers[sellersArr[i]].energy;
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
        // Eligible buy bid
        buyVolume += buyers[buyersArr[i]].energy;
      }
    }

    // find eligible sell bids
    sellVolume = 0;
    for (i = 0; i < sellBids.length; i++) {
      if (sellBids[i] <= price) {
        // Eligible sell bid
        sellVolume += sellers[sellersArr[i]].energy;
      }
    }

    // volume that will be traded
    uint256 vol = min(buyVolume, sellVolume);
    // trade: find matching buy bids
    i = 0;
    uint256 tempVol = vol;
    while (tempVol > 0) {
      if (buyers[buyersArr[i]].energy <= tempVol) {
        //Matching buyer and Quantity
        tempVol -= buyers[buyersArr[i]].energy;
        emit tradeEnergyBuyer(buyersArr[i], buyers[buyersArr[i]].energy);
        i++;
      } else {
        //Matching buyer and Quantity
        emit tradeEnergyBuyer(buyersArr[i], tempVol);
        break;
      }
    }

    // trade: find matching selling bids
    i = 0;
    tempVol = vol;
    while (tempVol > 0) {
      if (sellers[sellersArr[i]].energy <= tempVol) {
        // Matching seller and Quantity
        tempVol -= sellers[sellersArr[i]].energy;
        emit tradeEnergySeller(sellersArr[i], sellers[sellersArr[i]].energy);
        i++;
      } else {
        // Matching seller and Quantity
        emit tradeEnergySeller(sellersArr[i], tempVol);
        break;
      }
    }

  }

  function getPrice() public view returns (uint256) {
    return price;
  }

  // Commitment utility
  function makeCommitment(bytes32 nonce, uint256 bidValue) public pure returns(bytes32) {
    return keccak256(abi.encodePacked(nonce, bidValue));
  }

  function finalize() public onlyOwner {
    require(getBlockNumber() >= t3, "Finalization period has not yet arrived.");
    selfdestruct(msg.sender);
  }

  // sort bids as they are revealed
  function bidSortAscenting(uint[] memory arr, address[] memory bidders) internal pure returns (uint[] memory, address[] memory) { 
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

  function bidSortDescenting(uint[] memory arr, address[] memory bidders) internal pure returns (uint[] memory, address[] memory) { 
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
  function isBiddingPeriod() public view returns (bool) {
    return (getBlockNumber() < t1) && (getBlockNumber() >= t0);
  }

  function isRevealPeriod() public view returns (bool) {
    return (getBlockNumber() < t3) && (getBlockNumber() >= t2);
  }

  function isMatchingPeriod() public view returns (bool) {
    return (getBlockNumber() >= t3);
  }

  function getBlockNumber() public view returns (uint256) {
    return block.number;
  }

  //modifiers
  modifier onlyBidding {
    require(isBiddingPeriod(), "Bidding period has not started or has already ended.");
    _;
  }

  modifier onlyReveal {
    require(isRevealPeriod(), "Declaration period has not started or has already ended.");
    _;
  }

  modifier onlyMatching {
    require(isMatchingPeriod(), "Matching period has not started or has already ended.");
    _;
  }

  modifier onlyOwner {
    require(msg.sender == owner, "Only retailer can modify!");
    _;
  }
  
}