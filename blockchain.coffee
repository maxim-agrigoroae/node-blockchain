fs = require 'fs'
path = require 'path'
crypto = require 'crypto'

blocksDir = process.env.BLOCKCHAIN_DIR or './blocks/'
blockChainSecret = process.env.BLOCKCHAIN_SECRET or 'silence-is-gold'

blockChainDir = path.normalize path.join __dirname, blocksDir

# Creates block chain folder.
exists = fs.existsSync blockChainDir

if not exists
  fs.mkdirSync blockChainDir

hash = (data) ->
  crypto.createHmac 'sha256', blockChainSecret
    .update data
    .digest 'hex'

createBlock = (blockName, data, prevHash = '') ->
  return new Promise((resolve, reject) ->
    data.prevHash = prevHash
    data.timestamp = new Date()

    file = path.join blockChainDir, blockName

    fs.writeFile file, JSON.stringify(data), (err) ->
      if err
        reject err

      console.log "Created block #{blockName} to block chain"

      resolve blockName
  )

addBlock = (data) ->
  return new Promise((resolve, reject) ->
    fs.readdir blockChainDir, (err, files) ->
      if err
        reject err

      blockName = files.length + 1
      blockName = blockName.toString()

      if not files.length
        return createBlock blockName, data
          .then (created) -> resolve created

      prevBlock = files.length.toString()

      getBlock prevBlock
        .then (block) ->
          prevHash = hash block

          console.log prevHash

          createBlock blockName, data, prevHash
            .then (created) -> resolve created
  )

getBlock = (blockName) ->
  return new Promise((resolve, reject) ->
    file = path.join blockChainDir, blockName
    fs.access file, fs.F_OK, (err) ->
      if err
        resolve null

      fs.readFile file, { encoding: 'utf-8' }, (err, block) ->
        if err
          reject err

        if block
          resolve block
        else
          resolve null
  )

checkBlock = (blockName) ->
  return new Promise((resolve, reject) ->
    blockId = parseInt blockName
    nxtBlockName = blockId + 1
    nxtBlockName = nxtBlockName.toString()

    Promise.all [
      getBlock(blockName),
      getBlock(nxtBlockName),
    ]
      .catch (e) -> console.log e
      .then (result) ->
        block = result[0]
        nextBlock = result[1]


        if not nextBlock
          console.log "#{blockName} is the last block in chain"
          resolve true

        blockHash = hash block
        block = JSON.parse block

        if not Object.hasOwnProperty.call block, 'prevHash'
          reject new Error('Invalid block')

        if not Object.hasOwnProperty.call block, 'timestamp'
          reject new Error('Invalid block')

        if not block.prevHash
          console.log "#{blockName} is genesis block"
          resolve true

        nextBlock = JSON.parse nextBlock

        resolve blockHash is nextBlock.prevHash
  )


# addBlock({
#   sender: 'Max',
#   receiver: 'Vanya',
#   amount: 10
# })
#   .catch (e) -> console.log e
#   .then (block) ->
#     console.log "#{block} added"
#     addBlock {
#       sender: 'Kostya',
#       receiver: 'Max',
#       amount: 20
#     }
#       .catch (e) -> console.log e
#       .then (block) ->
#         console.log "#{block} added"

checkBlock(process.argv[2])
  .catch (e) ->
    console.log e
  .then (res) ->
    if res
      console.log 'OK'
    else
      console.log 'CORRUPTED'
