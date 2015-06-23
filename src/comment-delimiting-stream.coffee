# takes in stream of text and returns objects, formatted as:
# {
#   string: "<text>"
#   type: "(string|lineComment|blockComment|text)"
# }
# the concatenation of all the "string" portions is the same as the input text
# this splits up c and c++ comments alike since c99
#
# this might have been doable using a standard parsing tool, but i'm not sure
# how to transfer the c preprocessor syntax (given that it sits on top of the
# actual c language syntax) to a normal parser generator, so i decided to just
# roll it by hand

utils = require './utilities'
Transform = require 'transform-stream-extensions'

module.exports =
class CommentDelimitingStream extends Transform
  constructor: (opts = {}) ->
    opts.readableObjectMode = yes
    super opts

    @curBlock = ""

    # "text", "string", "blockComment", or "lineComment"; start off reading file
    # in plain text state
    @state = "text"

  @NonTextTokenMap:
    '//': 'lineComment'
    '/*': 'blockComment'
    '"': 'string'

  @TerminatingTokenMap:
    'blockComment': '*/'
    'string': '"'
    'lineComment': '\n'

  getTermFromInitTok: (tok) ->
    @constructor.TerminatingTokenMap[@constructor.NonTextTokenMap[tok]]

  indexAndNextState: (str, tok) ->
    [
      @indexOfStringWithoutBackslash(tok, str),
      @constructor.NonTextTokenMap[tok]
    ]

  # get occurrences of next non-text tokens, sort, return closest or -1
  getNextNonText: (str) ->
    res = Object.keys(@constructor.NonTextTokenMap).map((tok) =>
      @indexAndNextState str, tok).filter((pair) ->
      pair[0] isnt -1).sort((pair1, pair2) ->
      pair1[0] - pair2[0])
    if res?.length > 0
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

  minusOneOrAdd: (num, addition) -> if num is -1 then -1 else num + addition

  mapState: (state, block) ->
    # these just make sure the right characters are plucked from each section,
    # like adding the quote characters to "string" sections, or /* */ to
    # blockComment, etc
    startPast = @tokenFromState(state)?.length
    endTok = @constructor.TerminatingTokenMap[state]
    endPast = startPast + endTok?.length
    if state is "text"
      @getNextNonText block
    else
      [
        @minusOneOrAdd(@indexOfStringWithoutBackslash(
          endTok,block[(startPast)..]), endPast),
        "text"
      ]

  pushNextSection: ->
    [endIndex, nextState] = @mapState @state, @curBlock
    if endIndex isnt -1
      nextString = @curBlock.substr 0, endIndex
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
