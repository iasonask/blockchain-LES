/* global artifacts, contract, it, beforeEach */
/* eslint-disable no-unused-expressions */

const SmartMeters = artifacts.require('SmartMeters')

const chai = require('chai')
const chaiAsPromised = require('chai-as-promised')
const shouldFail = require('./shouldFail')

chai.use(chaiAsPromised)
const expect = chai.expect

contract('SmartMeters', (accounts) => {
  beforeEach(async () => {
    this.smartMeter = await SmartMeters.new()
  })

  it('should register a meter', async () => {
    await this.smartMeter.registerMeter(accounts[1])
    expect(await this.smartMeter.isValidMeter(accounts[1])).to.be.true
  })

  it('should unregister a meter', async () => {
    await this.smartMeter.registerMeter(accounts[1])
    await this.smartMeter.unregisterMeter(accounts[1])
    expect(await this.smartMeter.isValidMeter(accounts[1])).to.be.false
  })

  it('only owner should register a meter', async () => {
    shouldFail.reverting(this.smartMeter.registerMeter(accounts[1], { from: accounts[2] }))
  })

  it('only owner should unregister a meter', async () => {
    await this.smartMeter.registerMeter(accounts[1])
    shouldFail.reverting(this.smartMeter.unregisterMeter(accounts[1], { from: accounts[2] }))
  })

  it('should not register an already registered meter', async () => {
    await this.smartMeter.registerMeter(accounts[1])
    shouldFail.reverting(this.smartMeter.registerMeter(accounts[1]))
  })

  it('should not unregister an unregistered meter', async () => {
    shouldFail.reverting(this.smartMeter.registerMeter(accounts[1]))
  })
})
