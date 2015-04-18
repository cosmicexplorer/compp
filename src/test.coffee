fs = require 'fs'

TestTransform = require './test-transform'

inStream = new TestTransform

fs.createReadStream("./test.coffee").pipe(inStream)

inStream.on 'line', (line) ->
  process.stdout.write "-->"
  if line.match /line\.match/g
    process.stdout.write line
    console.error "PAUSE"
    inStream.pause()
    fs.createReadStream("./test.coffee").pipe(process.stdout).on 'end', ->
      console.error "UNPAUSE"
      inStream.resume()
  else
    process.stdout.write line
