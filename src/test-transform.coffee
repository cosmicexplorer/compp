Transform = require('stream').Transform

module.exports =
class TestTransform extends Transform
  constructor: ->
    Transform.call @, readableObjectMode: true
    @buffer = ""

  pushLines: ->
    newlineIndex = @buffer.indexOf "\n"
    while newlineIndex isnt -1
      @push @buffer.substr(0, newlineIndex + 1)
      @emit 'line', @buffer.substr(0, newlineIndex + 1)
      @buffer = @buffer.substr(newlineIndex + 1)
      newlineIndex = @buffer.indexOf "\n"

  _transform: (chunk, enc, cb) ->
    @buffer = @buffer + chunk.toString()
    @pushLines()
    cb?()

  _flush: (cb) ->
    @pushLines()
    @buffer += "\n"             # ending newline
    @push @buffer
    @emit 'line', @buffer       # push last line
    @buffer = ""
    cb?()
