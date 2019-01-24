/* global artifacts, contract, it, web3, beforeEach */
/* eslint-disable no-unused-expressions */

const Retailer = artifacts.require('Retailer')
const SmartMeters = artifacts.require('SmartMeters')

const chai = require('chai')
const chaiAsPromised = require('chai-as-promised')

chai.use(chaiAsPromised)

const eth = web3.utils.toWei('1', 'ether')

contract('Retailer', (accounts) => {
  beforeEach(async () => {
    this.smartMeter = await SmartMeters.new()
    this.retailer = await Retailer.new(this.smartMeter.address, 3, 3, 4, 5, 1500, eth)
  })

  const meter = accounts[1]
  const user = accounts[2]

  it('should subscribe a user', async () => {
    await this.smartMeter.registerMeter(meter)
    await this.retailer.subscribeUser(meter, { from: user, value: eth })
  })

  it('should declare a consumption', async () => {
    await this.smartMeter.registerMeter(meter)
    await this.retailer.subscribeUser(meter, { from: user, value: eth })
    await this.retailer.declarePeriod(user, 10, { from: meter })
  })

  it('should pay', async () => {
    await this.smartMeter.registerMeter(meter)
    await this.retailer.subscribeUser(meter, { from: user, value: eth })
    await this.retailer.declarePeriod(user, 10, { from: meter })
    await this.retailer.paymentPeriod({ from: user })
  })

  it('should finalize', async () => {
    await this.smartMeter.registerMeter(meter)
    await this.retailer.subscribeUser(meter, { from: user, value: eth })
    await this.retailer.declarePeriod(user, 10, { from: meter })
    await this.retailer.paymentPeriod({ from: user })
    await this.retailer.finalize()
  })

})
