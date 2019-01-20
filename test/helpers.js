const advanceTimeAndBlock = async (web3, time) => {
  await advanceTime(time)
  await advanceBlock()

  return Promise.resolve(web3.eth.getBlock('latest'))
}

const advanceTime = (web3, time) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [time],
      id: new Date().getTime()
    }, (err, result) => {
      if (err) { return reject(err) }
      return resolve(result)
    })
  })
}

const advanceBlock = (web3) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_mine',
      id: new Date().getTime()
    }, (err, result) => {
      if (err) { return reject(err) }
      const newBlockHash = web3.eth.getBlock('latest').hash

      return resolve(newBlockHash)
    })
  })
}

const forwardBlocks = async (web3, num) => {
  for (let i = 0; i <= num; i++) {
    await advanceBlock(web3)
  }
}

const getRandomInt = (min, max) => {
  min = Math.ceil(min)
  max = Math.floor(max)
  return Math.floor(Math.random() * (max - min)) + min
}

module.exports = {
  advanceTime,
  advanceBlock,
  advanceTimeAndBlock,
  forwardBlocks,
  getRandomInt
}
