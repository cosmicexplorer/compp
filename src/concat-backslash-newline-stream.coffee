# simple transform stream which emits a 'line' event on each consumed input line
# in addition, whenever "\\\n" appears in the string (a backslash immediately
# followed by a newline), it will transform "\\\n" -> " " and continue onwards
# as if a new line had not been encountered. to be used in a c preprocessor and
# applications with similar needs

Transform = require('stream').Transform

module.exports =
class ConcatBackslashNewlinesStream extends Transform
  constructor: ->
    if not @ instanceof ConcatBackslashNewlinesStream
      return new ConcatBackslashNewlinesStream
    else
      Transform.call @, readableObjectMode: true
      @heldLines = []
      @prevChar = ""

    # emit 'end' on end of input
    cbEnd = =>
      @emit 'end'
    # same for 'error'
    cbError = (err) =>
      @emit 'error'
    @on 'pipe', (src) =>
      src.on 'end', cbEnd
      src.on 'error', cbError
    @on 'unpipe', (src) =>
      src.removeListener 'end', cbEnd
      src.removeListener 'error', cbError

  baseTransformFunc: (str) ->
    for c in str
      @heldLines.push c
      if c is "\n" and @prevChar isnt "\\"
        @emit 'line', @heldLines.join("")
        @push @heldLines.join("")
        @heldLines = []
      @prevChar = c

  _transform: (chunk, enc, cb) ->
    str = chunk.toString()
    @baseTransformFunc str
    cb?()

  _flush: (cb) ->
    finalStr = @heldLines.join("")
    if finalStr.charAt(finalStr.length - 1) isnt "\n"
      finalStr += "\n"
    @emit 'line', finalStr
    @push finalStr
    cb?()
