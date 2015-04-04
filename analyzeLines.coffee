# native modules
fs = require 'fs'
stream = require 'stream'
# local modules
ConcatBackslashNewlinesStream = require './ConcatBackslashNewlinesStream'

# opts: {
#  defines: ['define1', 'define2=2'],
#  undefines: ['define3']
#  include: ['/mnt/usr/include']
# }
analyzeLines = (file, opts) ->
  fileStream = fs.createReadStream file
  formatStream = new ConcatBackslashNewlinesStream
  lineStream = fileStream.pipe(formatStream)
  outStream = new stream.PassThrough()
  fileStream.on 'error', (err) ->
    console.error "Error in reading input file: #{file}."
    throw err
  lineStream.on 'line', (line) ->
    if line.charAt(0) == "#"
      outStream.write "comment line!\n"
  return outStream

module.exports = analyzeLines
