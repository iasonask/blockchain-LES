/* global artifacts, contract, it, web3, beforeEach */
/* eslint-disable no-unused-expressions */

const SmartMeters = artifacts.require('SmartMeters')
const DoubleAuction = artifacts.require('DoubleAuction')

const chai = require('chai')
const chaiAsPromised = require('chai-as-promised')

const { getRandomInt } = require('./helpers')

chai.use(chaiAsPromised)

const eth = web3.utils.toWei('10', 'ether')

const number_of_participants = 10 //*2

const addParticipants = async (smartMeter, auction, buyers, sellers) => {
  for (let buyer of buyers) {
    await smartMeter.registerMeter(buyer.meter)
    await auction.bidBuyer(await this.doubleAuction.makeCommitment(web3.utils.toHex(buyer.nonce), web3.utils.toHex(buyer.price)), buyer.meter, buyer.volume, { from: buyer.address, value: eth })
  }

  for (let seller of sellers) {
    await smartMeter.registerMeter(seller.meter)
    await auction.bidSeller(await this.doubleAuction.makeCommitment(web3.utils.toHex(seller.nonce), web3.utils.toHex(seller.price)), seller.meter, seller.volume, { from: seller.address, value: eth })
  }
}

const revealBids = async (auction, buyers, sellers) => {
  for (let buyer of buyers) {
    await auction.revealBuyer(web3.utils.toHex(buyer.nonce), web3.utils.toHex(buyer.price), { from: buyer.address })
  }

  for (let seller of sellers) {
    await auction.revealSeller(web3.utils.toHex(seller.nonce), web3.utils.toHex(seller.price), { from: seller.address })
  }
}
const declareEnergy = async (auction, buyers, sellers) => {
  for (let buyer of buyers) {
    await auction.energyDeclarationsBuyers(buyer.address, getRandomInt(1, 7), { from: buyer.address })
  }

  for (let seller of sellers) {
    await auction.energyDeclarationsSellers(seller.address, getRandomInt(1, 7), { from: seller.address })
  }
}

const sendReceivePayments = async (auction, buyers, sellers) => {
  for (let buyer of buyers) {
    await auction.sendPayment({ from: buyer.address })
  }

  for (let seller of sellers) {
    await auction.receivePayment({ from: seller.address })
  }
}

contract('Double Auction', (accounts) => {
  beforeEach(async () => {
    this.smartMeter = await SmartMeters.new()
    this.doubleAuction = await DoubleAuction.new(this.smartMeter.address, 9, 13, 24, 16, 6, 7, 2000, eth)
  })

  const buyers = []
  const sellers = []

  for (let i = 1; i < number_of_participants + 1; i++) {
    buyers.push({ address: accounts[i], meter: accounts[i], price: getRandomInt(800, 2000), volume: getRandomInt(1, 7), nonce: i })
  }

  for (let i = number_of_participants + 1; i < 2 * number_of_participants + 1; i++) {
    sellers.push({ address: accounts[i], meter: accounts[i], price: getRandomInt(800, 2000), volume: getRandomInt(1, 7), nonce: i })
  }

  // it('Add bidders', async () => {
  //   await addParticipants(this.smartMeter, this.doubleAuction, buyers, sellers)
  // })

  // it('Reveal bids', async () => {
  //   await addParticipants(this.smartMeter, this.doubleAuction, buyers, sellers)
  //   await revealBids(this.doubleAuction, buyers, sellers)
  // })

  it('Clear', async () => {
    await addParticipants(this.smartMeter, this.doubleAuction, buyers, sellers)
    await revealBids(this.doubleAuction, buyers, sellers)
    await this.doubleAuction.clearMarket()
    // console.log(await this.doubleAuction.getPrice())
    await declareEnergy(this.doubleAuction, buyers, sellers)
    await sendReceivePayments(this.doubleAuction, buyers, sellers)
    await this.doubleAuction.finalize()
  })
})
