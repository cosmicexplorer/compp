###
transform stream that performs a C preprocessing of the input

This stream is supposed to receive each chunk sent into _transform delimited by
newline, except when backslash-newlines are used. e.g.:
'int a = \
     3;
'
would be an appropriate 'line' input into this stream. Unless you are trying
some strange experiment, you will want to write not into this stream directly,
but into an instance of ConcatBackslashNewlinesStream, in this same
directory. The file 'compp-streams' provides the helper method
PreprocessorPipelineFactory to make everything simple and fun (although if you
don't want to format the output then you can just manually pipe the input only).

Also, this is meant to be piped into. There are two ways to approach this; if
you must manually write into this instead of piping another stream, you can use
a PassThrough stream to hold your writes, and pipe that into this
stream. Alternatively, two events are emitted when the input stream is supposed
to stop and restart writing to this stream: 'pause-input-stream' and
'resume-input-stream'. You can use these to manage when you are and are not
allowed to write to the stream.

Bottom line, just use the ConcatBackslashNewlinesStream and everything is
easy. If not, you will have a rough time, but it is grudgingly allowed.
###

# native modules
fs = require 'fs'
path = require 'path'
Transform = require('stream').Transform

# local/npm modules
ConcatBackslashNewlinesStream = require './concat-backslash-newline-stream'
CFormatStream = require 'c-format-stream'

###
This sets up the include directories available on the system. It's run once per
call to 'require', and since require is only callable once, it is therefore run
once per program invocation. It scans the system for gcc's include directories
and makes them available to the stream by the array sysIncludeDirs.

TODO: fix this borked broken scheme and find something system-independent.
###
sysIncludeDirs = [
  "/usr/local/include"
  "/usr/include"
  "/usr/include/linux"
  "/usr/include/sys"
  ]
gccArchDirs = fs.readdirSync("/usr/lib/gcc").map((inode) ->
  path.join "/usr/lib/gcc", inode)
  .filter((inode) ->
    fs.statSync(inode).isDirectory())
# now get each version of gcc
gccVersionDirs =
  (fs.readdirSync gccADir for gccADir in gccArchDirs).map((verDirArr) ->
    path.join gccADir, verDir for verDir in verDirArr).reduce((arr1, arr2) ->
    arr1.concat arr2)
# finally, add to system includes
sysIncludeDirs = (path.join dir, "include" for dir in gccVersionDirs)
  .concat sysIncludeDirs

module.exports =
class PreprocessStream extends Transform
  ###
  example inputs:

  ps = new PreprocessStream "hello.c", ['/mnt/usr/include'],
    objLikeDefine:
      text: '(2 + 3)'
      type: 'object'
    funcLikeDefine:
      text: 'do { printf("hey"); x; } while(0);'
      type: 'function'
      args: ['x']

  ###
  constructor: (@filename, @includeDirs, @defines, opts = {}) ->
    if not @ instanceof PreprocessStream
      return new PreprocessStream
    else
      Transform.call @, opts

    @line = 1
    @isInComment = no
    # text of the line currently being processed; set in _transform
    @curLine = ""

    # emit 'error' and track input stream
    @src = null
    cbError = (err) =>
      @emit 'error', err
    @on 'pipe', (src) =>
      src.on 'error', cbError
      @src = src
    @on 'unpipe', (src) =>
      src.removeListener 'error', cbError
      @src = null

    ###
    stack of #if directives
    each element is laid out as:
    {
      hasBeenTrue: true
      isCurrentlyTrue: no
      ifLine: 342
      ifFile: "test.c"
      ifText: "#ifdef ASDF"
    }
    hasBeenTrue is true so we know whether to process "else" statements
    isCurrentlyTrue tells us whether we're processing the current branch of if
    ###
    @ifStack = []

  throwError: (colNum, errText) ->
    errStr = "#{@filename}:#{@line}:#{colNum}: error: #{errText}\n"
    errStr += @curLine
    for i in [1..(colNum - 1)] by 1
      errStr += " "
    errStr += "^~~\n"
    @emit 'error', new Error(errStr)

  applyObjectDefine: (str, definesToSend, defineStr, defineVal) ->
    ###
    this regex construction is safe because valid tokens for #defines
    will only contain [a-zA-z0-9_], as shown above in tokenRegex.
    if there were hyphens, backslashes, or other such weird things, we
    would have to perform the appropriate escaping.

    this applies to applyFunctionDefine too
    ###
    defineObjectRegexStr = "\\b#{defineStr}\\b"
    if defineVal.type is "object" and
       str.match(new RegExp(defineObjectRegexStr, "g"))
      definesToSend.push defineStr
      replaceString = @applyDefines defineVal.text, definesToSend
      return str.replace(new RegExp(defineObjectRegexStr, "g"),
        replaceString)
    else
      return str

  applyFunctionDefine: (str, definesToSend, defineStr, defineVal) ->
    defineFunctionRegexStr = "\\b#{defineStr}\\([^\\)]*\\)"
    if defineVal.type is "function" and
       str.match(new RegExp(defineFunctionRegexStr, "g"))
      definesToSend.push defineStr
      # the bottom two strings are guaranteed to exist by the regex above,
      # so we don't check if they're null or whatever
      # array of tokens with parens attached
      tokensWithArgs = str.match(new RegExp(defineFunctionRegexStr, "g"))
      # array of just the parens portion of each token instance
      argsInParens = tkArgs
          .match(
            @constructor.parentheticalExprRegex)[0] for tkArgs in tokensWithArgs
      # array of arrays of args for each function call; because of this
      # structure's complexity, we cannot use a comprehension as easily
      argsArr = []
      for argInP in argsInParens
        res = (argInP.match(@constructor.argumentRegex)?.map (s) ->
          s.replace parenCommaWhitespaceRegex, "")
        if not res or
           (res.length is 1 and res[0] is "")
          res = []
        argsArr.push res
      if tokensWithArgs.length isnt argsArr.length
        throw new Error "lengths should be the same here!\n" +
        "(this is a bug; #{tokensWithArgs.length} and #{argsArr.length})"
      for i in [0..(tokensWithArgs.length - 1)] by 1
        return applyFunctionDefine defineVal, argsArr[i], tokensWithArgs[i],
          str, defines, definesToSend, opts, line
    else
      return str

  applyDefines: (str, macrosExpanded) ->
    str = str.replace @constructor.backslashNewlineRegex, ""
    for defineStr, defineVal of @defines
      if ((not macrosExpanded) or
         (macrosExpanded.indexOf(defineStr) is -1))
        if macrosExpanded
          definesToSend = macrosExpanded
        else
          definesToSend = []
        str = @applyObjectDefine str, definesToSend, defineStr, defineVal
        str = @applyFunctionDefine str, definesToSend, defineStr, defineVal
    # __FILE__ and __LINE__ are constantly changed by the preprocessor, so we
    # will special-case them here instead of inserting them as normal macros
    return str
      .replace(@constructor.fileTokenRegex, @filename)
      .replace(@constructor.lineTokenRegex, @line)

  pipeIncludeHeader: (filePath) ->
    headerStream = new PreprocessStream(filePath, @includeDirs, @defines)
    # propagate these all the way down
    headerStream.on 'add-define', (defineObj) =>
      @emit 'add-define', defineObj
      for defineStr, defineVal of defineObj
        @defines[defineStr] = defineVal # overwrite as required
    headerStream.on 'remove-define', (undefStr) =>
      @emit 'remove-define', undefStr
      delete @defines[undefStr] # die
    outStream = (new ConcatBackslashNewlinesStream)
      .pipe(headerStream)
      .pipe(new CFormatStream
        numNewlinesToPreserve: 0
        indentationString: "  ")
    # errors and data propagate, which is why this works
    outStream.on 'error', (err) =>
      @emit 'error', err
    outStream.on 'data', (chunk) =>
      @push chunk
    outStream.on 'end', =>
      # restart chunks from this stream's input stream
      @src?.resume()
      @emit 'resume-input-stream'
    # stop chunks from this stream's input stream
    @emit 'pause-input-stream'
    @src?.pause()
    fs.createReadStream(filePath).pipe(outStream)

  insertInclude: (directive, restOfLine) ->
    sysHeader = restOfLine.match(@constructor.systemHeaderRegex)?[0]
    localHeader = restOfLine.match(@constructor.localHeaderRegex)?[0]
    found = no
    if sysHeader
      headerFilename = sysHeader.replace(@constructor.stripSideCaratsRegex, "")
      headerArr = sysIncludeDirs
    else if localHeader
      headerFilename = localHeader.replace(@constructor.stripQuotesRegex, "")
      headerArr = @includeDirs
    else
      @throwError @constructor.defineErrorCol, "#include without header"
    headerFilename = headerFilename
      .replace(@constructor.leadingWhitespaceRegex, "")
      .replace(@constructor.trailingWhitespaceRegex, "")
    for includeDir in headerArr
      try
        filePath = path.join includeDir, headerFilename
        fs.statSync filePath    # throws if dne
        found = yes
        # TODO: make sure a file can only be included x times, and if included
        # more than x times, then error out with cyclical include error
        @pipeIncludeHeader filePath
      catch
      if found
        break
    if not found
      @throwError @constructor.defineErrorCol,
      "Include file #{headerFilename} not found."

  addFunctionMacro: (defineToken, lineAfterToken) ->
    args = lineAfterToken.match(@constructor.parentheticalExprRegex)?[0]
    if not args
      @throwError @constructor.defineErrorCol,
      "Function-like macro construction has no closing paren."
    argsArr = (args.match @constructor.argumentRegex or []).map (s) ->
      s.replace @constructor.parenCommaWhitespaceRegex, ""
    argsArr = [] if argsArr.length is 1 and argsArr[0] is ""
    replaceText = lineAfterToken
      .substr(lineAfterToken.indexOf(args) + args.length)
      .replace(@constructor.backslashNewlineRegex, "")
      .replace(@constructor.leadingWhitespaceRegex, "")
      .replace(@constructor.trailingWhitespaceRegex, "")
    addDefineObj =
      text: replaceText
      type: "function"
      args: argsArr
    @defines[defineToken] = addDefineObj
    emitDefineObj = {}
    emitDefineObj[defineToken] = addDefineObj
    @emit 'add-define', emitDefineObj

  addObjectMacro: (defineToken, lineAfterToken) ->
    replaceToken = lineAfterToken
      .replace(@constructor.backslashNewlineRegex, "")
      .replace(@constructor.leadingWhitespaceRegex, "")
      .replace(@constructor.trailingWhitespaceRegex, "")
    addDefineObj =
      text: replaceToken
      type: "object"
    @defines[defineToken] = addDefineObj
    emitDefineObj = {}
    emitDefineObj[defineToken] = addDefineObj
    @emit 'add-define', emitDefineObj

  addDefine: (directive, restOfLine) ->
    defineToken = restOfLine.match(@constructor.tokenRegex)?[0]
    if not defineToken
      @throwError @constructor.defineErrorCol, "No token given to #define."
    lineAfterToken = restOfLine.substr(
      restOfLine.indexOf(defineToken) + defineToken.length)
    if lineAfterToken.charAt(0) is "("
      @addFunctionMacro defineToken, lineAfterToken
    else
      @addObjectMacro defineToken, lineAfterToken
    matches = @curLine.match @constructor.backslashNewlineRegex
    @line += matches.length if matches
    ++@line

  removeDefine: (directive, restOfLine) ->
    undefToken = restOfLine.match(@constructor.tokenRegex)?[0]
    if not undefToken
      @throwError @constructor.defineErrorCol, "No token given to #undef."
    delete @defines[undefToken]
    @emit 'remove-define', undefToken
    matches = @curLine.match @constructor.backslashNewlineRegex
    @line += matches.length if matches
    ++@line

  processError: (directive, restOfLine) ->
    @throwError @constructor.defineErrorCol,
      restOfLine
      .replace(@constructor.leadingWhitespaceRegex, "")
      .replace(@constructor.trailingWhitespaceRegex, "")

  processPragma: ->
    # the compiler sees these, not us, so we just push it
    @push @curLine.replace(@constructor.backslashNewlineRegex, "")
    matches = @curLine.match @constructor.backslashNewlineRegex, ""
    @line += matches.length if matches
    ++@line

  processLineDirective: (directive, restOfLine) ->
    toLine = restOfLine.match(@constructor.numberTokenRegex)?[0]
    if not toLine
      @throwError directive.length,
      "No line number given in #{directive} directive."
    lineAfterToLine = restOfLine.substr(
      restOfLine.indexOf(toLine) + toLine.length)
    # TODO: process error columns in other functions the way they're processed
    # in this one, and report the error line as @line + backslashesBeforeXXX
    # backslashesBeforeToLine = getBackslashNewlinesBeforeToken restOfLine,
    #   toLine
    toFile = lineAfterToLine.match(@constructor.tokenRegex)?[0]
    # backslashesBeforeToFile = getBackslashNewlinesBeforeToken restOfLines,
    #   toFile
    if toFile
      if not toFile.match @constructor.stringInQuotes
        @throwError @constructor.defineErrorCol,
        "Invalid file name given in #{directive} directive."
      else
        @filename = toFile
    @line = toLine

  ifDefinedCallback: ->
    return (str, g1) =>
      tokMatches = g1.match @constructor.tokenRegex
      if not tokMatches or tokMatches.length > 1
        @throwError @curLine.indexOf("defined"),
        "Invalid token provided to 'defined' operator in preprocessor " +
        "conditional."
      else
        tokenMatch = tokMatches[0]
        if @defines[g1]
          return ' 1 '
        else
          return ' 0 '

  # perform mathematical operations according to c syntax
  doIfCondMath: (str) ->
    # first expand all macros
    str = @applyDefines(str).replace @constructor.backslashNewlineRegex, ""
    # now sanitize input
    # replace character expressions with their ascii values
    str = str.replace @constructor.charInQuotesRegex, (str, g1) ->
      g1.charCodeAt(0)
    # allowed characters (for safety lol)
    res = str.match @constructor.disallowedConditionalChars or
          # after applyDefines, there should be no tokens left
          str.match @constructor.tokenRegex
    if res
      # FIXME: remove!
      if str.match /BSD/g
        return no
      else
        return yes
      outStr = str.match(@constructor.disallowedConditionalChars)?[0] or
               str.match(@constructor.tokenRegex)[0]
      outExpansion = str
        .replace(@constructor.multipleWhitespaceRegex, "")
        .replace(@constructor.leadingWhitespaceRegex, "")
        .replace(@constructor.trailingWhitespaceRegex, "")
      @throwError @constructor.defineErrorCol,
      "Invalid token in preprocessor conditional: '#{outStr}' in expansion:\n" +
      "'#{outExpansion}'"
    else
      try
        resVal = eval str
      catch err
        @throwError @constructor.defineErrorCol
        "Invalid expression in preprocessor conditional: #{err}"
      return resVal > 0

  processIfConstExpr: (directive, restOfLine) ->
    # handle the 'else' part
    if directive is "elif"
      if @ifStack.length is 0
        @throwError @constructor.defineErrorCol, "#elif without opening #if."
      else if @ifStack[@ifStack.length - 1].hasBeenTrue
        @ifStack[@ifStack - 1].isCurrentlyTrue = no
        return
    if directive is "if" or directive is "elif"
      # replace "defined(TOKEN)" with whether it is defined (0 or 1)
      restOfLine = restOfLine.replace @constructor.definedParensRegex,
        @ifDefinedCallback
      # replace "defined TOKEN" as well (this does not interact with above)
      restOfLine = restOfLine.replace @constructor.definedSpaceRegex,
        @ifDefinedCallback
      boolResult = @doIfCondMath restOfLine
      if directive is "if"
        @ifStack.push
          hasBeenTrue: boolResult
          isCurrentlyTrue: boolResult
          ifLine: @line
          ifFile: @filename
          ifText: @curLine
      else
        @ifStack[@ifStack.length - 1] =
          hasBeenTrue: boolResult
          isCurrentlyTrue: boolResult
          ifLine: @line
          ifFile: @filename
          ifText: @curLine
    else
      @throwError @constructor.defineErrorCol,
      "Unrecognized preprocessor directive: #{directive}."

  processIfdef: (directive, restOfLine) ->
    nextToken = restOfLine.match(@constructor.tokenRegex)?[0]
    retCondStackObj =
      ifLine: @line
      ifFile: @filename
      ifText: @curLine
    if directive is "ifdef"
      if not nextToken
        @throwError @constructor.defineErrorCol,
        "No token given to #ifdef"
      else if @defines[nextToken]
        retCondStackObj.isCurrentlyTrue = yes
        retCondStackObj.hasBeenTrue = yes
      else
        retCondStackObj.isCurrentlyTrue = no
        retCondStackObj.hasBeenTrue = no
      @ifStack.push retCondStackObj
    else if directive is "ifndef"
      if not nextToken
        @throwError @constructor.defineErrorCol,
        "No token given to #ifndef"
      else if not @defines[nextToken]
        retCondStackObj.isCurrentlyTrue = yes
        retCondStackObj.hasBeenTrue = yes
      else
        retCondStackObj.isCurrentlyTrue = no
        retCondStackObj.hasBeenTrue = no
      @ifStack.push retCondStackObj

  processElse: (restOfLine) ->
    if @ifStack.length is 0
      @throwError @constructor.defineErrorCol, "#else without opening #if"
    else if @ifStack[@ifStack.length - 1].hasBeenTrue
      @ifStack[@ifStack.length - 1].isCurrentlyTrue = no
    else
      @ifStack[@ifStack.length - 1].isCurrentlyTrue = yes
      @ifStack[@ifStack.length - 1].hasBeenTrue = yes

  processIf: (directive, restOfLine) ->
    if directive is "ifdef" or directive is "ifndef"
      @processIfdef directive, restOfLine
    else if directive is "else"
      @processElse restOfLine
    else if directive is "endif"
      if @ifStack.length is 0
        @throwError @constructor.defineErrorCol, "#endif without opening #if"
      else
        @ifStack.pop()
    else
      @processIfConstExpr directive, restOfLine
    matches = @curLine.match @constructor.backslashNewlineRegex
    @line += matches.length if matches
    ++@line

  processSourceLine: (line) ->
    outLine = @applyDefines line
    @push outLine
    matches = @curLine.match @constructor.backslashNewlineRegex
    @line += matches.length if matches
    ++@line

  processComments: (line) ->
    newLine = []
    prevChar = ""
    for c in line
      newLine.push c if not @isInComment
      if not @isInComment
        if c is "*" and prevChar is "/"
          @isInComment = yes
          # remove /*
          newLine.pop()
          newLine.pop()
      else
        if c is "/" and prevChar is "*"
          @isInComment = no
        if c is "\n" and prevChar is "\\"
          newLine.push "\\"
          newLine.push "\n"
      prevChar = c
    newLine = newLine.join ""
    # respect C99 //-style comments
    # MUST run backslash regex first for correct results
    return newLine
      .replace(@constructor.C99CommentBackslashRegex, "\\\n")
      .replace(@constructor.C99CommentNoBackslashRegex, "")

  processDirectiveLine: (directive, restOfLine, uncommentedLine) ->
    switch directive
      when "include"
      then @insertInclude directive, restOfLine
      when "define"
      then @addDefine directive, restOfLine
      when "undef"
      then @removeDefine directive, restOfLine
      when "error"
      then @processError directive, restOfLine
      when "pragma"
      then @processPragma()
      when "line"
      then @processLineDirective directive, restOfLine
      else
        if directive
          @processIf directive, restOfLine
        else
          @processSourceLine uncommentedLine

  processLine: (line) ->
    uncommentedLine = @processComments line
    # TODO: add digraph/trigraph support
    directive = uncommentedLine.match(@constructor.directiveRegex)?[0]
    restOfLine = ""
    if not directive
      restOfLine = uncommentedLine
    else
      restOfLine = uncommentedLine
        .substr(uncommentedLine.indexOf(directive) + directive.length)
      directive = directive
        .replace(@constructor.whitespaceRegex, "")
        .replace(@constructor.hashRegex, "")
    if @ifStack.length is 0 or
       @ifStack[@ifStack.length - 1].isCurrentlyTrue
      @processDirectiveLine directive, restOfLine, uncommentedLine
    else
      if directive and directive.match @constructor.condRegex
        @processIf directive, restOfLine
      else
        matches = @curline.match @constructor.backslashNewlineRegex
        @line += matches.length if matches
        ++@line

  _transform: (chunk, enc, cb) ->
    str = chunk.toString()
    console.error ">-#{str}-<"
    @curLine = str
    @processLine(@curLine)
    cb?()

  ###
  constants and regexes
  ###
  # constants
  @defineErrorCol: 2

  # regexes
  @directiveRegex : /^\s*#\s*[a-z_]+/g
  @tokenRegex : /\b[a-zA-Z_][a-zA-Z0-9_]{0,31}\b/g
  @numberTokenRegex : /\b[0-9]+\b/g
  @numberRegex : /[0-9]+/g
  @backslashNewlineRegex : /\\\n/g
  @stringInQuotes : /".*"/g
  # matches all preprocessor conditionals
  @condRegex : /(if|else)/g
  @notWhitespaceRegex : /[^\s]/g
  @leadingWhitespaceRegex : /^\s+/g
  @trailingWhitespaceRegex : /\s+$/g
  @whitespaceRegex : /\s/g
  @multipleWhitespaceRegex : /\s+/g
  @hashRegex : /#/g
  # matches //-style comments until backslash-newline
  @C99CommentBackslashRegex : /\/\/.*\\\n/g
  # matches //-style comments until end of line
  @C99CommentNoBackslashRegex : /\/\/.*/g
  # matches beginning of /*-style comments
  @slashStarBeginRegex : /\/\*/g
  @slashStarEndRegex : /\*\//g
  # matches within parentheses
  @parentheticalExprRegex : /\([^\)]*\)/g
  @parenCommaWhitespaceRegex : /[\(\),\s]/g
  @argumentRegex : /[^,]+[,\)]/g
  @charInQuotesRegex : /'(.)'/g
  @fileTokenRegex : /\b__FILE__\b/g
  @lineTokenRegex : /\b__LINE__\b/g
  @systemHeaderRegex : /^\s*<.+>/g
  @localHeaderRegex : /^\s*".+"/g
  @stripSideCaratsRegex : /[<>]/g
  @stripQuotesRegex : /"/g
  @disallowedConditionalChars : /[^0-9\(\)!%\^&\*\-\+\|\/=~<>\\\s]/g
  @definedParensRegex : /\bdefined\s*\(([^\)]*)\)/g
  @definedSpaceRegex : /\bdefined\s*(\w+)/g
