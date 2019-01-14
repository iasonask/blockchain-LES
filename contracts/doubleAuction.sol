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
    require(bidValue >= 0, "Negative sell bid.");
    sellBids.push(bidValue);
    (sellBids, sellersArr) = bidSortAscenting(sellBids, sellersArr);
  }

  function revealBuyer(bytes32 nonce, uint256 bidValue) public onlyReveal {
    require(buyers[msg.sender].isSubscribed, "Buyer has not committed bid.");
    require(makeCommitment(nonce, bidValue) == buyers[msg.sender].bidValue, "Invalid buy bid.");
    require(bidValue >= 0, "Negative buy bid.");
    buyBids.push(bidValue);
    (buyBids, buyersArr) = bidSortDescenting(buyBids, buyersArr);
  }

  // clear the market
  function determinePrice() public onlyMatching {
    uint256 energy = 0;
    for (uint256 i = 0; i < buyBids.length; i++) {
      if (buyers[buyersArr[i]].energy >= sellers[sellersArr[i]].energy) {
        energy += buyers[buyersArr[i]].energy;
      } else {
        energy += sellers[sellersArr[i]].energy;
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
      i--;
      key = arr[i];
      temp = bidders[i];
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
      i--;
      key = arr[i];
      temp = bidders[i];
    }
    return (arr, bidders);
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