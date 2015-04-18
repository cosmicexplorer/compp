# native modules
fs = require 'fs'
path = require 'path'
stream = require 'stream'
# local modules
ConcatBackslashNewlinesStream = require './concat-backslash-newline-stream'

# regexes
directiveRegex = /^\s*#\s*[a-z_]+/g
tokenRegex = /\b[a-zA-Z_0-9]+\b/g
numberRegex = /[0-9]+/g
backslashNewlineRegex = /\\\n/g
stringInQuotes = /".*"/g
# matches all preprocessor conditionals
condRegex = /(if|else)/g
notWhitespaceRegex = /[^\s]/g
leadingWhitespaceRegex = /^\s+/g
trailingWhitespaceRegex = /\s+$/g
whitespaceRegex = /\s/g
hashRegex = /#/g
# matches //-style comments until backslash-newline
C99CommentBackslashRegex = /\/\/.*\\\n/g
# matches //-style comments until end of line
C99CommentNoBackslashRegex = /\/\/.*/g
# matches beginning of /*-style comments
slashStarBeginRegex = /\/\*/g
slashStarEndRegex = /\*\//g
# matches within parentheses
parentheticalExprRegex = /\([^\)]*\)/g
parenCommaWhitespaceRegex = /[\(\),\s]/g
argumentRegex = /[^,]+[,\)]/g
charInQuotesRegex = /'(.)'/g
fileTokenRegex = /\b__FILE__\b/g
lineTokenRegex = /\b__LINE__\b/g
systemHeaderRegex = /^\s*<.+>/g
localHeaderRegex = /^\s*".+"/g
stripSideCaratsRegex = /[<>]/g
stripQuotesRegex = /"/g
allowedConditionalChars = /[^0-9\(\)!%\^&\*\-\+\|\/=~<>\\\s]/g

# constants
defineErrorCol = 2

# SUPER MEGA HACK TO GET INCLUDE DIRECTORIES

# include directories
sysIncludeDirs = [
  "/usr/local/include"
  "/usr/include"
  "/usr/include/linux"
  "/usr/include/sys"
  ]
localIncludeDirs = []

try
  res = fs.statSync "/usr/lib/gcc"
  if not res.isDirectory()
    throw "gcc is not a folder for some reason"
catch err
  throw new Error "gcc not installed or something, idk: #{err}"
# now assuming gcc dirs exist
# gcc version dirs
gccVersionDirs = (fs.readdirSync "/usr/lib/gcc").map((inode) ->
  path.join "/usr/lib/gcc", inode)
  .filter((inode) ->
    try   # in case it doesn't exist (even though the previous line checks that)
      (fs.statSync inode).isDirectory()
    catch err
      return false)
# actual include directories
for dir in gccVersionDirs
  # we're not going to check that they still exist here (race condition)
  sysIncludeDirs.push (path.join dir, "include")
  sysIncludeDirs.push (path.join dir, "include-fixed")

# utility functions
# throw error at file, line, col and exit "gracefully"
throwError = (file, line, line_num, col, err) ->
  console.error "#{file}:#{line_num}:#{col}: error: #{err}"
  process.stderr.write line
  # add the cute little carat showing you where your problem is
  for i in [1..(col - 1)] by 1
    process.stderr.write " "
  process.stderr.write "^~~\n"
  process.exit -1

getBackslashNewlinesBeforeToken = (str, tok) ->
  ind = str.indexOf(tok)
  if ind is null or ind is -1
    return 0
  prevChar = ""
  num = 0
  for i in [0..(ind-1)] by 1
    if str.charAt(i) is "\n" and prevChar is "\\"
      ++num
    prevChar = str.charAt(i)
  return num

applyFunctionDefine =
(fnDefn, args, token, str, defines, macrosExpanded, opts, line) ->
  tokenIndex = str.indexOf token
  if args.length isnt fnDefn.args.length
    throwError opts.file, str, opts.line, tokenIndex,
      "Incorrect number of arguments passed to function-like macro: should " +
      "be #{fnDefn.args.length}, not #{args.length}"
  curStr = fnDefn.text
  for i in [0..(args.length - 1)] by 1
    # arguments to function-like macros take precedence over previous defines,
    # but those arguments might themselves be macros
    curStr = curStr.replace(new RegExp("\\b#{fnDefn.args[i]}\\b"),
      applyDefines(args[i], defines, opts, macrosExpanded))
  return applyDefines((str.substr(0, tokenIndex) +
    curStr +
    str.substr(tokenIndex + token.length)), defines, opts, macrosExpanded)

# apply all macro expansions to the given string
# guaranteed that all macro arguments will not expand to
applyDefines = (str, defines, opts, macrosExpanded, line) ->
  str = str.replace backslashNewlineRegex, ""
  for defineStr, defineVal of defines
    defineObjectRegexStr = "\\b#{defineStr}\\b"
    defineFunctionRegexStr = "\\b#{defineStr}\\([^\\)]*\\)"
    if ((not macrosExpanded) or
       (macrosExpanded.indexOf(defineStr) is -1))
      definesToSend = []
      if macrosExpanded
        definesToSend = macrosExpanded
      # expand object-like macros
      if defineVal.type is "object" and
         # this regex construction is safe because valid tokens for #defines
         # will only contain [a-zA-z0-9_], as shown above in tokenRegex.
         # if there were hyphens, backslashes, or other such weird things, we
         # would have to perform the appropriate escaping.
         str.match(new RegExp(defineObjectRegexStr, "g"))
        # recursively expand macros, but only a little
        definesToSend.push defineStr
        replaceString = applyDefines defineVal.text, defines, opts,
          definesToSend, line
        str = str.replace(new RegExp(defineObjectRegexStr, "g"), replaceString)
      else if defineVal.type is "function" and
              str.match(new RegExp(defineFunctionRegexStr, "g"))
        definesToSend.push defineStr
        # the bottom two strings are guaranteed to exist by the regex above, so
        # we don't check if they're null or whatever

        # array of tokens with parens attached
        tokensWithArgs = str.match(new RegExp(defineFunctionRegexStr, "g"))
        # array of just the parens portion of each token instance
        argsInParens =
          tkwArgs.match(parentheticalExprRegex)[0] for tkwArgs in tokensWithArgs
        # array of arrays of args for each function call; because of this
        # structure's complexity, we cannot use a comprehension as easily
        argsArr = []
        res = null
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
  return str
    .replace(fileTokenRegex, opts.file)
    .replace(lineTokenRegex, opts.line)

# process preprocessor line functions
insertInclude = (directive, restOfLine, outStream, opts, dirname, line) ->
  sysHeader = restOfLine.match(systemHeaderRegex)?[0]
  localHeader = restOfLine.match(localHeaderRegex)?[0]
  found = no
  if sysHeader
    sysHeader = sysHeader.replace leadingWhitespaceRegex, ""
    sysHeader = sysHeader.replace stripSideCaratsRegex, ""
    for includeDir in sysIncludeDirs
      try
        filePath = path.join(includeDir, sysHeader)
        res = fs.statSync(filePath) # throws if dne
        # FIXME:
        # while we wish we could just throw in a clone of the current opts as an
        # argument instead of destructively modifying 'opts', we also wish to
        # grab the #defines and #undefs from the header file and apply it to
        # all succeeding files as well; so we must modify opts. however, we do
        # wish to keep the old file and line characteristics, so we save and
        # revert those here. this could be mitigated by having analyzeLines
        # return the modified opts, for example
        console.error "FOUND: #{filePath}"
        prevFile = opts.file
        prevLine = opts.line
        prevInFileStream = opts.inFileStream
        # stop reading this input stream while reading another (the header)
        prevInFileStream.pause()
        analyzeLines(filePath, fs.createReadStream(filePath), opts)
          .pipe(outStream)
          .on 'end', -> # now start again
            prevInFileStream.unpause()
            console.error "RETURN:"
            console.error "FILE: #{opts.file}: NEW: #{prevFile}"
            console.error "LINE: #{opts.line}: NEW: #{prevLine}"
            opts.file = prevFile
            opts.line = prevLine
            opts.inFileStream = prevInFileStream
            matches = restOfLine.match backslashNewlineRegex
            opts.line += matches.length if matches
            ++opts.line
        found = yes
      catch err
        res = null
      if found
        break
    if not found
      opts.inFileStream.close()
      throwError opts.file, line, opts.line, defineErrorCol,
      "Include file <#{sysHeader}> not found."
  # for includeDir in opts.includes
  #   fileStat = fs.statSync path.join includeDir, ""
  # outStream.write line

addFunctionMacro = (defineToken, lineAfterToken, opts, line) ->
  args = lineAfterToken.match(parentheticalExprRegex)?[0]
  if not args
    throwError opts.file, lin,
    opts.line, defineErrorCol, "Function-like macro construction has no closing paren."
  # apparently macros can have 0 arguments lol
  argsArr = (args.match argumentRegex or []).map (s) ->
    s.replace parenCommaWhitespaceRegex, ""
  # this simplifies the case of no arguments
  argsArr = [] if argsArr.length is 1 and argsArr[0] is ""
  opts.defines[defineToken] =
    text: lineAfterToken.substr(lineAfterToken.indexOf(args) +
      args.length).replace(leadingWhitespaceRegex, "").replace(
        trailingWhitespaceRegex, "")
    type: "function"
    args: argsArr

addObjectMacro = (defineToken, lineAfterToken, opts, line) ->
  replaceToken = lineAfterToken.replace(backslashNewlineRegex, "").replace(
    leadingWhitespaceRegex, "").replace(trailingWhitespaceRegex, "")
  opts.defines[defineToken] =
    text: replaceToken
    type: "object"

addDefine = (directive, restOfLine, outStream, opts, line) ->
  defineToken = restOfLine.match(tokenRegex)?[0]
  if not defineToken
    throwError opts.file, line, opts.line, defineErrorCol,
    "No token given to #define."
  lineAfterToken = restOfLine.substr(
    restOfLine.indexOf(defineToken) + defineToken.length)
  if lineAfterToken.charAt(0) == "("
    addFunctionMacro defineToken, lineAfterToken, opts, line
  else
    addObjectMacro defineToken, lineAfterToken, opts, line
  matches = restOfLine.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

removeDefine = (directive, restOfLine, outStream, opts, line) ->
  undefToken = restOfLine.match(tokenRegex)?[0]
  if undefToken
    # FIXME: this should NOT applyDefines to anything
    throwError opts.file, line, opts.line, defineErrorCol,
    "No token given to #undef."
  delete opts.defines[undefToken]
  matches = restOfLine.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

processError = (directive, restOfLine, opts, line) ->
  # the literal 2 here is verbatim from gnu cpp
  throwError opts.file, line, opts.line, defineErrorCol,
    restOfLine.replace(leadingWhitespaceRegex, "")
    .replace(trailingWhitespaceRegex, "")

processPragma = (directive, restOfLine, outStream, opts, line) ->
  # we don't do anything here, but it's left here for clarity
  outStream.write line
  matches = restOfLine.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

processLineDirective = (directive, restOfLine, outStream, opts, line) ->
  toLine = restOfLine.match(tokenRegex)?[0] # get first token
  backslashesBeforeToLine =
    getBackslashNewlinesBeforeToken restOfLine, toLine
  if not toLine                             # if line just "#line \n"
    throwError opts.file, line, opts.line,
    directive.length, "No line number given in #{directive} directive."
  if not toLine.match numberRegex
    throwError opts.file, opts.line + backslashesBeforeToLine, directive.length,
    "Invalid line number given in #{directive} directive."
  toFile = restOfLine.match(tokenRegex)?[1] # get second token, if exists
  backslashesBeforeToFile = getBackslashNewlinesBeforeToken restOfLines, toFile
  if toFile                                 # second token is optional
    if not toFile.match stringInQuotes      # if not in quotes
      throwError opts.file, line, opts.line + backslashesBeforeToFile,
      directive.length,
      "Invalid file name given in #{directive} directive."
    else
      opts.file = toFile
  # set down here because we want to give the correct line number on error
  opts.line = toLine

ifDefinedCallback = (opts, line) ->
  return (str, g1) ->
    tokMatches = g1.match tokenRegex
    if not tokMatches or tokMatches.length > 1
      throwError opts.file, line, opts.line, line.indexOf("defined"),
      "Invalid token provided to 'defined' operator in preprocessor " +
      "conditional."
    else
      tokenMatch = tokMatches[0]
      if opts.defines[g1]
        return ' 1 '
      else
        return ' 0 '

# perform mathematical operations according to c syntax
doIfCondMath = (str, opts, line) ->
  str = str.replace backslashNewlineRegex, ""
  # sanitize input
  # replace character expressions with their ascii values
  str = str.replace charInQuotesRegex, (str, g1) ->
    g1.charCodeAt(0)
  # allowed characters
  res = allowedConditionalChars.exec str
  if res
    throwError opts.file, line, opts.line, defineErrorCol,
    "invalid character in preprocessor conditional: #{res[0]}"
  else
    try
      resVal = eval str
    catch err
      throwError opts.file, line, opts.line, defineErrorCol,
      "invalid expression in preprocessor conditional: #{err}"
    return resVal > 0

processIfConstExpr = (directive, restOfLine, outStream, opts, dirname, line) ->
  if directive is "elif"        # handle else
    # no 'else' for this if/else if chain, but that's because every branch
    # either quits the process or returns
    if opts.ifStack.length is 0
      throwError opts.file, line, opts.line, defineErrorCol, "#elif without opening #if"
    else if opts.ifStack[opts.ifStack.length - 1].hasBeenTrue
      opts.ifStack[opts.ifStack.length - 1].isCurrentlyTrue = no
      return
    # else
    #   opts.ifStack[opts.ifStack.length - 1].isCurrentlyTrue = yes
    #   opts.ifStack[opts.ifStack.length - 1].hasBeenTrue = yes
  if directive is "if" or "elif"
    # replace "defined(TOKEN)" with whether it is defined (0 or 1)
    restOfLine = restOfLine.replace /\bdefined\s*\(([^\)]*)\)/g,
      ifDefinedCallback(opts, line)
    # now that that's done, replace "defined TOKEN" as well
    # (this does not interact with the previous regex)
    restOfLine = restOfLine.replace /\bdefined\s*(\w+)/g,
      ifDefinedCallback(opts, line)
    # now expand all other macros
    restOfLine = applyDefines restOfLine, opts.defines, opts, [], line
    boolResult = doIfCondMath restOfLine, opts, line
    if directive is "if"        # stick a new one on there
      opts.ifStack.push
        hasBeenTrue: boolResult
        isCurrentlyTrue: boolResult
        ifLine: opts.line
        ifFile: opts.file
        ifText: line
    else                        # replace what's currently on there
      opts.ifStack[opts.ifStack.length - 1] =
        hasBeenTrue: boolResult
        isCurrentlyTrue: boolResult
        ifLine: opts.line
        ifFile: opts.file
        ifText: line
  else
    throwError opts.file, line, opts.line, defineErrorCol,
    "unrecognized preprocessor directive: #{directive}"

processIf = (directive, restOfLine, outStream, opts, dirname, line) ->
  nextToken = restOfLine.match(tokenRegex)?[0]
  retCondStackObj =
    ifLine: opts.line
    ifFile: opts.file
    ifText: line
  if directive is "ifdef"
    if not nextToken
      throwError opts.file, line, opts.line, defineErrorCol,
      "No token given to #ifdef"
    else if opts.defines[nextToken]
      retCondStackObj.isCurrentlyTrue = yes
      retCondStackObj.hasBeenTrue = yes
    else
      retCondStackObj.isCurrentlyTrue = no
      retCondStackObj.hasBeenTrue = no
    opts.ifStack.push retCondStackObj
  else if directive is "ifndef"
    if not nextToken
      throwError opts.file, line, opts.line, defineErrorCol,
      "No token given to #ifndef"
    else if not opts.defines[nextToken]
      retCondStackObj.isCurrentlyTrue = yes
      retCondStackObj.hasBeenTrue = yes
    else
      retCondStackObj.isCurrentlyTrue = no
      retCondStackObj.hasBeenTrue = no
    opts.ifStack.push retCondStackObj
  else if directive is "else"
    if opts.ifStack.length is 0
      throwError opts.file, line, opts.line, defineErrorCol,
      "#else without opening #if"
    else if opts.ifStack[opts.ifStack.length - 1].hasBeenTrue
      opts.ifStack[opts.ifStack.length - 1].isCurrentlyTrue = no
    else
      opts.ifStack[opts.ifStack.length - 1].isCurrentlyTrue = yes
      opts.ifStack[opts.ifStack.length - 1].hasBeenTrue = yes
  else if directive is "endif"
    if opts.ifStack.length is 0
      throwError opts.file, line, opts.line, defineErrorCol,
      "#endif without opening #if"
    else
      opts.ifStack.pop()
  else
    # #if and #elif
    processIfConstExpr directive, restOfLine, outStream, opts, dirname, line
  matches = line.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

processSourceLine = (line, outStream, opts, origLine) ->
  outLine = applyDefines line, opts.defines, opts, origLine
  outStream.write outLine
  matches = line.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

processComments = (line, opts) ->
  # respect the good ol' /**/-style comments
  newLine = []
  prevChar = ""
  for c in line
    newLine.push c if not opts.isInComment
    if not opts.isInComment
      if c is "*" and prevChar is "/"
        opts.isInComment = true
        # remove /*
        newLine.pop()
        newLine.pop()
    else
      if c in "/" and prevChar is "*"
        opts.isInComment = no
      if c is "\n" and prevChar is "\\"
        # keep the \\\n in there! why? figure it out!!!
        newLine.push "\\"
        newLine.push "\n"
    prevChar = c
  newLine = newLine.join ""
  # respect C99 //-style comments
  # MUST run backslash regex first for correct results
  newLine = newLine.replace C99CommentBackslashRegex, "\\\n"
  newLine = newLine.replace C99CommentNoBackslashRegex, ""
  return newLine

# this one does all the heavy lifting; given an input line, output stream, and
# list of current defines, it will read in preprocessor directives and modify
# opts as appropriate, finally outputting the correct output to outStream
# we chose to leave the concatenation of backslash-newlines to each processLine
# function so that they can give the appropriate lines and columns on each error
processLine = (line, outStream, opts, inComment, dirname) ->
  origLine = line
  # clobbers opts.isInComment (in a good way)
  line = processComments line, opts
  directive = line.match(directiveRegex)?[0]
  restOfLine = ""
  if not directive
    restOfLine = line
  else
    restOfLine = line.substr (line.indexOf directive) + directive.length
    directive = directive.replace whitespaceRegex, ""
    directive = directive.replace hashRegex, ""
  if opts.ifStack.length is 0 or
     opts.ifStack[opts.ifStack.length - 1].isCurrentlyTrue
    switch directive
      when "include"
      then insertInclude directive, restOfLine, outStream, opts, dirname,
        origLine
      when "define"
      then addDefine directive, restOfLine, outStream, opts, origLine
      when "undef"
      then removeDefine directive, restOfLine, outStream, opts, origLine
      when "error"
      then processError directive, restOfLine, opts, origLine
      when "pragma"
      then processPragma directive, restOfLine, outStream, opts, origLine
      when "line"
      then processLineDirective directive, restOfLine, outStream, opts, origLine
      else
        if directive
          # works on #if, #else, #endif, #ifdef, #ifndef, #elif
          processIf directive, restOfLine, outStream, opts, dirname, origLine
        # just a normal source line
        else
          # output if not within a #if or if within a true #if
          processSourceLine line, outStream, opts, origLine
  else
    if directive and directive.match condRegex
      processIf directive, restOfLine, outStream, opts, dirname, origLine
    else
      # gotta keep those lines in place
      if directive and restOfLine
        matches = (directive + restOfLine).match backslashNewlineRegex
        if matches isnt null
          opts.line += matches.length
      else if directive
        matches = directive.match backslashNewlineRegex
        if matches isnt null
          opts.line += matches.length
      else
        matches = restOfLine.match backslashNewlineRegex
        if matches isnt null
          opts.line += matches.length
      ++opts.line

# this function sets up input and processing streams and calls processLine to
# write the appropriate output to outStream; exposed to the frontend
# example opts:
# opts: {
#  defines: { define1: null, define2: 2 },
#  includes: ['/mnt/usr/include']
#  line: 3
#  file: "test.c"
#  isInComment: no
# }
analyzeLines = (file, fileStream, opts) ->
  # initialize opts
  opts.line = 1
  opts.file = file
  opts.isInComment = no
  opts.inFileStream = fileStream
  # get pwd of file
  dirname = path.dirname file
  # initialize streams
  formatStream = new ConcatBackslashNewlinesStream
  lineStream = fileStream.pipe(formatStream)
  outStream = new stream.PassThrough()
  # stack of #if directives
  # each element is laid out as:
  # {
  #   hasBeenTrue: true
  #   isCurrentlyTrue: no
  #   ifLine: 342
  #   ifFile: "test.c"
  #   ifText: "#ifdef ASDF"
  # }
  # hasBeenTrue is true so we know whether to process "else" statements
  # isCurrentlyTrue tells us whether we're processing the current branch of if
  if not opts.ifStack
    opts.ifStack = []
  # whether currently in comment
  inComment = no
  fileStream.on 'error', (err) ->
    console.error "Error in reading input file: #{file}."
    throw err
  lineStream.on 'line', (line) ->
    processLine line, outStream, opts, inComment, dirname
  lineStream.on 'end', ->
    cleanupStream outStream, opts
    outStream.emit 'end'
  return outStream

module.exports = analyzeLines
