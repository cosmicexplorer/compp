# native modules
path = require 'path'
stream = require 'stream'
# local modules
ConcatBackslashNewlinesStream = require './concat-backslash-newline-stream'

# regexes
directiveRegex = /^#[a-z_]+/g
tokenRegex = /\b[a-zA-Z_0-9]+\b/g
numberRegex = /[0-9]+/g
backslashNewlineRegex = /\\\n/g
stringInQuotes = /".*"/g
# matches all preprocessor conditionals
condRegex = /(if|else)/g
notWhitespaceRegex = /[^\s]/g
leadingWhitespaceRegex = /^\s+/g
trailingWhitespaceRegex = /\s+$/g
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

# utility functions
# throw error at file, line, col and exit "gracefully"
throwError = (file, line, line_num, col, err) ->
  console.error "#{file}:#{line_num}:#{col}: error: #{err}"
  process.stderr.write line
  # add the cute little carat showing you where your problem is
  for i in [1..(col)] by 1
    process.stderr.write " "
  process.stderr.write "^\n"
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
(fnDefn, args, token, str, defines, macrosExpanded, opts) ->
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
applyDefines = (str, defines, opts, macrosExpanded) ->
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
          definesToSend
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
          res = [] if res.length is 1 and res[0] == ""
          argsArr.push res
        if tokensWithArgs.length isnt argsArr.length
          throw new Error "lengths should be the same here!\n" +
          "(this is a bug; #{tokensWithArgs.length} and #{argsArr.length})"
        for i in [0..(tokensWithArgs.length - 1)] by 1
          str = applyFunctionDefine defineVal, argsArr[i], tokensWithArgs[i],
            str, defines, definesToSend, opts
  return str

# process preprocessor line functions
insertInclude = (directive, restOfLine, outStream, opts, dirname) ->
  # TODO: write this (do this part last)
  outStream.write "#include#{restOfLine}"
  matches = restOfLine.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

addFunctionMacro = (defineToken, lineAfterToken, opts) ->
  args = lineAfterToken.match(parentheticalExprRegex)?[0]
  if not args
    throwError opts.file, "\#define #{defineToken}#{lineAfterToken}",
    opts.line, 2, "Function-like macro construction has no closing paren."
  # apparently macros can have 0 arguments lol
  argsArr = (args.match argumentRegex or []).map (s) ->
    s.replace parenCommaWhitespaceRegex, ""
  # this simplifies the case of no arguments
  argsArr = [] if argsArr.length is 1 and argsArr[0] == ""
  opts.defines[defineToken] =
    text: lineAfterToken.substr(lineAfterToken.indexOf(args) +
      args.length).replace(leadingWhitespaceRegex, "").replace(
        trailingWhitespaceRegex, "")
    type: "function"
    args: argsArr

addObjectMacro = (defineToken, lineAfterToken, opts) ->
  replaceToken = lineAfterToken.replace(backslashNewlineRegex, "").replace(
    leadingWhitespaceRegex, "").replace(trailingWhitespaceRegex, "")
  opts.defines[defineToken] =
    text: replaceToken
    type: "object"

addDefine = (directive, restOfLine, outStream, opts) ->
  defineToken = restOfLine.match(tokenRegex)?[0]
  if not defineToken
    throwError opts.file, "#{directive}#{restOfLine}", opts.line, 2,
    "No token given to \#define."
  lineAfterToken = restOfLine.substr(
    restOfLine.indexOf(defineToken) + defineToken.length)
  if lineAfterToken.charAt(0) == "("
    addFunctionMacro defineToken, lineAfterToken, opts
  else
    addObjectMacro defineToken, lineAfterToken, opts
  matches = restOfLine.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

removeDefine = (directive, restOfLine, outStream, opts) ->
  undefToken = restOfLine.match(tokenRegex)?[0]
  if undefToken
    throwError opts.file, opts.line, directive.length,
    "No token given to \#undef."
  delete opts.defines[undefToken]
  matches = restOfLine.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

processError = (directive, restOfLine, opts) ->
  # the literal 2 here is verbatim from gnu cpp
  throwError opts.file, "#{directive}#{restOfLine}", opts.line, 2,
    restOfLine.replace(leadingWhitespaceRegex, "")
    .replace(trailingWhitespaceRegex, "")

processPragma = (directive, restOfLine, outStream, opts) ->
  # we don't do anything here, but it's left here for clarity
  outStream.write "#{directive}#{restOfLine}"
  matches = restOfLine.match backslashNewlineRegex
  opts.line += matches.length if matches
  ++opts.line

processLineDirective = (directive, restOfLine, outStream, opts) ->
  toLine = restOfLine.match(tokenRegex)?[0] # get first token
  backslashesBeforeToLine =
    getBackslashNewlinesBeforeToken restOfLine, toLine
  if not toLine                             # if line just "#line \n"
    throwError opts.file, "#{directive}#{restOfLine}", opts.line,
    directive.length, "No line number given in #{directive} directive."
  if not toLine.match numberRegex
    throwError opts.file, opts.line + backslashesBeforeToLine, directive.length,
    "Invalid line number given in #{directive} directive."
  toFile = restOfLine.match(tokenRegex)?[1] # get second token, if exists
  backslashesBeforeToFile = getBackslashNewlinesBeforeToken restOfLines, toFile
  if toFile                                 # second token is optional
    if not toFile.match stringInQuotes      # if not in quotes
      throwError opts.file, opts.line + backslashesBeforeToFile,
      directive.length,
      "Invalid file name given in #{directive} directive."
    else
      opts.file = toFile
  # set down here because we want to give the correct line number on error
  opts.line = toLine

processIf = (directive, restOfLine, outStream, opts, ifStack, dirname) ->
  # TODO: write this
  console.error "processIf not implemented!"
  process.exit -1

processSourceLine = (line, outStream, opts) ->
  outLine = applyDefines line, opts.defines, opts
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
        opts.isInComment = false
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
processLine = (line, outStream, opts, ifStack, inComment, dirname) ->
  # clobbers opts.isInComment (in a good way)
  line = processComments line, opts

  directive = line.match(directiveRegex)?[0]
  restOfLine = ""
  if not directive
    restOfLine = line
  else
    restOfLine = line.substr directive.length
  if ifStack.length is 0 or ifStack[ifStack.length - 1].isCurrentlyTrue
    switch directive
      when "\#include"
      then insertInclude directive, restOfLine, outStream, opts, dirname
      when "\#define"
      then addDefine directive, restOfLine, outStream, opts
      when "\#undef"
      then removeDefine directive, restOfLine, outStream, opts
      when "\#error"
      then processError directive, restOfLine, opts
      # TODO: not sure if we should do anything here
      when "\#pragma"
      then processPragma directive, restOfLine, outStream, opts
      when "\#line"
      then processLineDirective directive, restOfLine, outStream, opts
      else
        if directive?.match directiveRegex
          # works on #if, #else, #endif, #ifdef, #ifndef, #elif
          processIf directive, restOfLine, outStream, opts, ifStack, dirname
        # just a normal source line
        else
          # output if not within a #if or if within a true #if
          processSourceLine line, outStream, opts
  else
    if directive and directive.match condRegex
      processIf directive, restOfLine, outStream, opts, ifStack, dirname
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
# }
analyzeLines = (file, fileStream, opts) ->
  # initialize opts
  opts.line = 1
  opts.file = file
  opts.isInComment = false
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
  #   isCurrentlyTrue: false
  # }
  # hasBeenTrue is true so we know whether to process "else" statements
  # isCurrentlyTrue tells us whether we're processing the current branch of if
  ifStack = []
  # whether currently in comment
  inComment = false
  fileStream.on 'error', (err) ->
    console.error "Error in reading input file: #{file}."
    throw err
  lineStream.on 'line', (line) ->
    processLine line, outStream, opts, ifStack, inComment, dirname
  return outStream

module.exports = analyzeLines
