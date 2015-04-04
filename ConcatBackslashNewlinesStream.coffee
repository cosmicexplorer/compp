# simple transform stream which emits a 'line' event on each consumed input line
# in addition, whenever "\\\n" appears in the string (a backslash immediately
# followed by a newline), it will transform "\\\n" -> " " and continue onwards
# as if a new line had not been encountered. to be used in a c preprocessor and
# applications with similar needs

# native modules
util = require 'util'
Transform = require('stream').Transform

ConcatBackslashNewlinesStream = ->
  if not @ instanceof ConcatBackslashNewlinesStream
    return new ConcatBackslashNewlinesStream
  else
    Transform.call @, readableObjectMode: true
    @heldLines = []
    @prevChar = ""

    cb = =>
      @emit 'end'
    @on 'pipe', (src) =>
      src.on 'end', cb
    @on 'unpipe', (src) =>
      src.removeListener 'end', cb

util.inherits ConcatBackslashNewlinesStream, Transform

ConcatBackslashNewlinesStream.prototype.transformProto =
  (chunk, encoding, callback) ->
    str = chunk.toString()
    for c in str
      @heldLines.push c
      if c is "\n" and @prevChar isnt "\\"
        @emit 'line', @heldLines.join("")
        @heldLines = []
      else if c is "\n" and @prevChar is "\\"
        @heldLines.pop()        # remove newline
        @heldLines.pop()        # remove backslash
        @heldLines.push " "     # add space; i think this is correct
      @prevChar = c
    @push(chunk)                # allow for piping (lol)
    callback?()

# leave out _flush for now, doesn't seem to be useful
# TODO: is _flush useful for this input?
ConcatBackslashNewlinesStream.prototype._transform =
  ConcatBackslashNewlinesStream.prototype.transformProto

module.exports = ConcatBackslashNewlinesStream
