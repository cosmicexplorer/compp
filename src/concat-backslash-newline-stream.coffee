# simple transform stream which emits a 'line' event on each consumed input line
# in addition, whenever "\\\n" appears in the string (a backslash immediately
# followed by a newline), it will transform "\\\n" -> " " and continue onwards
# as if a new line had not been encountered. to be used in a c preprocessor and
# applications with similar needs

Transform = require('stream').Transform

module.exports =
class ConcatBackslashNewlinesStream extends Transform
  constructor: (opts) ->
    if not opts
      opts = {}
    opts.readableObjectMode = yes
    if not @ instanceof ConcatBackslashNewlinesStream
      return new ConcatBackslashNewlinesStream
    else
      Transform.call @, opts

    @heldLines = ""
    @prevChar = ""
    if opts.filename
      @filename = opts.filename
    # else
    #   @filename = "NO_FILE"
    @curLine = 1
    @curCol = 0
    @allowTrigraphs = opts.allowTrigraphs

    cbError = (err) =>
      @emit 'error', err
    @on 'pipe', (src) =>
      src.on 'error', cbError
    @on 'unpipe', (src) =>
      src.removeListener 'error', cbError

  # trigraph regexes
  # MUST be done in here instead of preprocess-stream, since these are handled
  # before tokenization
  @hashTrigraphRegex: /\?\?=/g
  @backslashTrigraphRegex: /\?\?\//g
  @caratTrigraphRegex: /\?\?'/g
  @leftBracketTrigraphRegex: /\?\?\(/g
  @rightBracketTrigraphRegex: /\?\?\)/g
  @pipeTrigraphRegex: /\?\?!/g
  @leftBraceTrigraphRegex: /\?\?</g
  @rightBraceTrigraphRegex: /\?\?>/g
  @tildeTrigraphRegex: /\?\?\-/g

  transformTrigraphs: (str) ->
    if str.match(/\?\?./g) and not @allowTrigraphs
      matchText = str.match(/\?\?./g)[0]
      errText = "trigraph #{matchText} ignored"
      errStr = "#{@filename}:#{@curLine}:#{@curCol}: warning: #{errText}"
      errObj = new Error(errStr)
      errObj.sourceStream = @constructor.name
      errObj.isWarning = yes
      errObj.isTrigraph = yes
      @emit 'error', errObj
      return str
    else if str.match /\?\?/g
      return str
        .replace(@constructor.hashTrigraphRegex, "#")
        .replace(@constructor.backslashTrigraphRegex, "\\")
        .replace(@constructor.caratTrigraphRegex, "^")
        .replace(@constructor.leftBracketTrigraphRegex, "[")
        .replace(@constructor.rightBracketTrigraphRegex, "]")
        .replace(@constructor.pipeTrigraphRegex, "|")
        .replace(@constructor.tildeTrigraphRegex, "~")
    else
      return str

  baseTransformFunc: (str) ->
    @heldLines += str
    @heldLines = @transformTrigraphs(@heldLines)
    outStr = ""
    for c in @heldLines
      outStr += c
      ++@curCol
      if c is "\n" and @prevChar isnt "\\"
        @emit 'line', outStr
        @push outStr
        outStr = ""
        ++@curLine
        @curCol = 0
      @prevChar = c
    @heldLines = outStr

  _transform: (chunk, enc, cb) ->
    # continuously emitting error because otherwise the receiving stream
    # literally may not get it in time
    if not @filename
      @emit 'error',
      new Error "error: no filename given to #{@constructor.name}!"
    str = chunk.toString()
    @baseTransformFunc str
    cb?()

  _flush: (cb) ->
    if @heldLines.charAt(@heldLines.length - 1) isnt "\n"
      @heldLines += "\n"
    @emit 'line', @heldLines
    @push @heldLines
    cb?()
