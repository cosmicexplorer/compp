###
transform stream that performs a C preprocessing of the input
note: this stream requires all piped input to be given in lines of text;
backslash-newlines should be in the same input chunk as the rest of the line.
e.g. the quote-delimited string:
'int a = \
      3;
'
should be an entire chunk fed into the stream. the neighboring file
./concat-backslash-newline-stream.coffee implements a transform stream which
will perform this transformation appropriately. if this precondition is not met,
PreprocessStream will likely error out or produce incorrect output!

Also, this is meant to be piped into. There are two ways to approach this; if
you must manually write into this, you can use a PassThrough stream to hold your
writes, and pipe that into this stream. Alternatively, two events are emitted
when the input stream is supposed to stop and restart writing to this stream:
'pause-input-stream' and 'resume-input-stream'. You can use these to manage when
you are and are not allowed to write to the stream.
###

# native modules
fs = require 'fs'
path = require 'path'
Transform = require('stream').Transform

# local modules
ConcatBackslashNewlinesStream = require './concat-backslash-newline-stream'

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
    # text of the line currently being processed; set in _transform
    @curLine = ""

    # emit 'error' and track input pipe
    @src = null
    cbError = (err) =>
      @emit 'error', err
    @on 'pipe', (src) =>
      src.on 'error', cbError
      @src = src
    @on 'unpipe', (src) =>
      src.removeListener 'error', cbError
      @src = null

  throwError: (colNum, errText) ->
    errStr = "#{@file}:#{@line}:#{colNum}: error: #{errText}\n"
    errStr += @curLine
    for i in [1..(colNum - 1)] by 1
      errStr += " "
    errStr += "^~~\n"
    @emit 'error', new Error(errStr)

  applyDefines: (str, macrosExpanded) ->
    str = str.replace @constructor.backslashNewlineRegex, ""
    for defineStr, defineVal of @defines
      defineObjectRegexStr = "\\b#{defineStr}\\b"
      defineFunctionRegexStr = "\\b#{defineStr}\\([^\\)]*\\)"
      if ((not macrosExpanded) or
         (macrosExpanded.indexOf(defineStr) is -1))
        if macrosExpanded
          definesToSend = macrosExpanded
        else
          definesToSend = []
        ###
        this regex construction is safe because valid tokens for #defines
        will only contain [a-zA-z0-9_], as shown above in tokenRegex.
        if there were hyphens, backslashes, or other such weird things, we
        would have to perform the appropriate escaping.
        ###
        if defineVal.type is "object" and
           str.match(new RegExp(defineObjectRegexStr, "g"))
          definesToSend.push defineStr
          replaceString = applyDefines defineVal.text, definesToSend
          str = str.replace(new RegExp(defineObjectRegexStr, "g"),
            replaceString)
        else if defineVal.type is "function" and
                str.match(new RegExp(defineFunctionRegexStr, "g"))
          definesToSend.push defineStr
          # the bottom two strings are guaranteed to exist by the regex above,
          # so we don't check if they're null or whatever

          # array of tokens with parens attached
          tokensWithArgs = str.match(new RegExp(defineFunctionRegexStr, "g"))
          # array of just the parens portion of each token instance
          argsInParens = tkwArgs
              .match(parentheticalExprRegex)[0] for tkwArgs in tokensWithArgs
          # array of arrays of args for each function call; because of this
          # structure's complexity, we cannot use a comprehension as easily
          argsArr = []
          for argInP in argsInParens
            res = ((argInP.match argumentRegex).map (s) ->
              s.replace parenCommaWhitespaceRegex, "")
            res = [] if res.length is 1 and res[0] is ""
            argsArr.push res
          if tokensWithArgs.length isnt argsArr.length
            throw new Error "lengths should be the same here!\n" +
            "(this is a bug; #{tokensWithArgs.length} and #{argsArr.length})"
          for i in [0..(tokensWithArgs.length - 1)] by 1
            str = applyFunctionDefine defineVal, argsArr[i], tokensWithArgs[i],
              str, defines, definesToSend, opts, line
    # __FILE__ and __LINE__ are constantly changed by the preprocessor, so we
    # will special-case them here instead of inserting them as normal macros
    return str.replace(fileTokenRegex, @filename).replace(lineTokenRegex, @line)

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
    headerStream.on 'error', (err) =>
      @emit 'error', err
    headerStream.on 'data', (chunk) =>
      @push chunk
    headerStream.on 'end', =>
      # restart chunks from this stream's input stream
      @src?.resume()
      @emit 'resume-input-stream'
    # stop chunks from this stream's input stream
    @emit 'pause-input-stream'
    @src?.pause()
    fs.createReadStream(filePath).pipe(headerStream)

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
      throwError @constructor.defineErrorCol, "#include without header"
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
      catch
      if found
        break
    if not found
      throwError @constructor.defineErrorCol,
      "Include file #{headerFilename} not found."




  ###
  constants and regexes
  ###
  # constants
  @defineErrorCol: 2

  # regexes
  @directiveRegex : /^\s*#\s*[a-z_]+/g
  @tokenRegex : /\b[a-zA-Z_][a-zA-Z0-9_]{0,31}\b/g
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
