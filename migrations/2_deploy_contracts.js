/* global artifacts */

var Retailer = artifacts.require('../contracts/retailer.sol')
var SmartMeters = artifacts.require('../contracts/smartMeters.sol')
var DoubleAuction = artifacts.require('../contracts/doubleAuction.sol')

module.exports = function (deployer) {
  deployer.deploy(SmartMeters)
    .then((instance) => {
      deployer.deploy(Retailer, SmartMeters.address, 10, 20, 30, 40, 1500, 1000)
      deployer.deploy(DoubleAuction, SmartMeters.address, 10, 20, 30, 40, 50, 60, 1000)
    })
}
