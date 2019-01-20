/* global artifacts, contract, it, web3, beforeEach */
/* eslint-disable no-unused-expressions */

const SmartMeters = artifacts.require('SmartMeters')
const DoubleAuction = artifacts.require('DoubleAuction')

const chai = require('chai')
const chaiAsPromised = require('chai-as-promised')

const { getRandomInt } = require('./helpers')

chai.use(chaiAsPromised)

const eth = web3.toWei('1', 'ether')

const addParticipants = async (smartMeter, auction, buyers, sellers) => {
  for (let buyer of buyers) {
    await smartMeter.registerMeter(buyer.meter)
    await auction.bidBuyer(await this.doubleAuction.makeCommitment(buyer.nonce, buyer.price), buyer.meter, buyer.volume, { from: buyer.address, value: eth })
  }

  for (let seller of sellers) {
    await smartMeter.registerMeter(seller.meter)
    await auction.bidSeller(await this.doubleAuction.makeCommitment(seller.nonce, seller.price), seller.meter, seller.volume, { from: seller.address, value: eth })
  }
}

const revealBids = async (auction, buyers, sellers) => {
  for (let buyer of buyers) {
    await auction.revealBuyer(buyer.nonce, buyer.price, { from: buyer.address })
  }

  for (let seller of sellers) {
    await auction.revealSeller(seller.nonce, seller.price, { from: seller.address })
  }
}
contract('Double Auction', (accounts) => {
  beforeEach(async () => {
    this.smartMeter = await SmartMeters.new()
    this.doubleAuction = await DoubleAuction.new(this.smartMeter.address, 9, 13, 24, 16, 6, 7, eth)
  })

  const buyers = []
  const sellers = []

  for (let i = 0; i < 45; i++) {
    buyers.push({ address: accounts[i], meter: accounts[i + 1], price: getRandomInt(800, 2000), volume: getRandomInt(1, 7), nonce: i })
  }

  for (let i = 45; i < 95; i++) {
    sellers.push({ address: accounts[i], meter: accounts[i + 1], price: getRandomInt(800, 2000), volume: getRandomInt(1, 7), nonce: i })
  }

  it('Add bidders', async () => {
    await addParticipants(this.smartMeter, this.doubleAuction, buyers, sellers)
  })

  it('Reveal bids', async () => {
    await addParticipants(this.smartMeter, this.doubleAuction, buyers, sellers)
    await revealBids(this.doubleAuction, buyers, sellers)
  })

  it('Clear', async () => {
    await addParticipants(this.smartMeter, this.doubleAuction, buyers, sellers)
    await revealBids(this.doubleAuction, buyers, sellers)
    await this.doubleAuction.clearMarket()
  })
})
