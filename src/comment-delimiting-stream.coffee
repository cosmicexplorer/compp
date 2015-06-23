# takes in stream of text and returns objects, formatted as:
# {
#   string: "<text>"
#   type: "(string|comment|text)"
# }
# the concatenation of all the "string" portions is the same as the input text
# this splits up c and c++ comments alike since c99

utils = require './utilities'
Transform = require 'transform-stream-extensions'

module.exports =
class CommentDelimitingStream extends Transform
  constructor: (opts = {}) ->
    opts.readableObjectMode = yes
    super opts

    @curBlock = ""

    # "string", "text", "blockComment", or "lineComment"
    @state = "text"

  @NonTextTokenMap:
    '//': 'lineComment'
    '/*': 'blockComment'
    '"': 'string'

  @TerminatingTokenMap:
    'blockComment': '*/'
    'string': '"'
    'lineComment': '\n'

  nextStateFromText: (tokArr) ->
    [tokArr[0], @constructor.NonTextTokenMap[tokArr[1]]]

  getTermFromInitTok: (tok) ->
    @constructor.TerminatingTokenMap[@constructor.NonTextTokenMap[tok]]

  indexAndNextState: (str, tok) ->
    [
      @indexOfStringWithoutBackslash(tok, str),
      @constructor.NonTextTokenMap[tok]
    ]

  getNextNonText: (str) ->
    res = Object.keys(@constructor.NonTextTokenMap).map((tok) =>
      @indexAndNextState str, tok).filter((pair) ->
      pair[0] isnt -1).sort((pair1, pair2) ->
      pair1[0] - pair2[0])
    if res?.length > 0
      # console.error [str, res]
      res[0]
    else
      [-1, ""]

  # gets index of string within another string, assuming normal backslashing
  indexOfStringWithoutBackslash: (strAsRegex, str) ->
    quotedStr = utils.quoteRegexString strAsRegex
    reg = new RegExp("(^|[^\\\\]|(\\\\\\\\)+)#{quotedStr}", "gm")
    matchObj = reg.exec str
    if matchObj
      matchObj.index + matchObj[1].length
    else -1

  tokenFromState: (state) ->
    Object.keys(@constructor.NonTextTokenMap).filter((key) =>
      @constructor.NonTextTokenMap[key] is state)[0]

  minusOneOrAdd: (num, addition) ->
    if num is -1 then -1 else num + addition

  mapState: (state, block) ->
    startPast = @tokenFromState state
    endPast = startPast + @constructor.TerminatingTokenMap[state]?.length
    switch state
      when "blockComment"
        [
          @minusOneOrAdd(@indexOfStringWithoutBackslash('*/',block[2..]), 4),
          "text"
        ]
      when "string"
        [
          @minusOneOrAdd(@indexOfStringWithoutBackslash('"',block[1..]),2),
          "text"
        ]
      when "lineComment"
        [
          @minusOneOrAdd(@indexOfStringWithoutBackslash('\n',block[2..]), 3),
          "text"
        ]
      when "text"
        @getNextNonText block

  pushNextSection: ->
    [endIndex, nextState] = @mapState @state, @curBlock
    if endIndex isnt -1
      nextString = @curBlock.substr 0, endIndex
      # console.error [endIndex,  nextString, "#{@state}->#{nextState}"]
      if nextString.length isnt 0
        @push
          string: nextString
          type: @state
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
        type: @state
    cb?()
