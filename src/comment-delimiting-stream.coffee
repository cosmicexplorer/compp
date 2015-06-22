# takes in stream of text and returns objects, formatted as:
# {
#   string: "<text>"
#   isComment: <boolean>
# }
# the concatenation of all the "string" portions is the same as the input text
# this splits up c and c++ comments alike since c99

Transform = require 'transform-stream-extensions'

module.exports =
class CommentDelimitingStream extends Transform
  constructor: (opts = {}) ->
    opts.readableObjectMode = yes
    super opts

    @curBlock = ""

    # no, "blockComment", or "lineComment"
    @state = no

  minimum: (a, b) ->
    switch
      when a < b and a isnt -1 then [a, 0]
      else [b, 1]

  mapState: (state, block) ->
    nextIndex =
      switch state
        when "blockComment" then block.indexOf("*/") + 2
        when "lineComment" then block.indexOf("\n") + 1
        else @minimum block.indexOf("//"), block.indexOf("/*")
    nextState =
      switch state
        when "blockComment" then no
        when "lineComment" then no
        else
          if nextIndex[1] is 0
            "lineComment"
          else
            "blockComment"
    nextIndex = nextIndex[0] if nextIndex.length
    [nextIndex, nextState]

  pushNextSection: ->
    [endIndex, nextState] = @mapState @state, @curBlock
    if endIndex isnt -1
      nextString = @curBlock.substr 0, endIndex
      if nextString.length isnt 0
        @push
          string: nextString
          isComment: @state isnt no
      @state = nextState
      @curBlock = @curBlock.substr endIndex
    endIndex

  keepPushingUntilDone: ->
    res = @pushNextSection()
    while res isnt -1
      res = @pushNextSection()

  _transform: (chunk, enc, cb) ->
    @curBlock += chunk.toString()
    @keepPushingUntilDone()
    cb?()

  _flush: (cb) ->
    @keepPushingUntilDone()
    if @curBlock.length isnt 0
      @push
        string: @curBlock
        isComment: @state isnt no
    cb?()
