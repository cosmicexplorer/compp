# native modules
fs = require 'fs'
path = require 'path'
stream = require 'stream'
# local modules
ConcatBackslashNewlinesStream = require './ConcatBackslashNewlinesStream'

# regexes
directiveRegex = /^#[a-z_]+/g
tokenRegex = /\b[a-zA-Z_0-9]+\b/g
numberRegex = /[0-9]+/g
backslashNewlineRegex = /\\\n/g
stringInQuotes = /".*"/g
# matches all preprocessor conditionals
condRegex = /(if|else)/g

# utility functions
# throw error at file and line
throwError = (file, line, col, err) ->
  console.error "#{file}:#{line}:#{col}: #{err}"
  process.exit -1

getBackslashNewlinesBeforeToken = (str, tok) ->
  ind = str.indexOf(tok)
  if ind is null or ind is -1
    return 0
  prevChar = ""
  num = 0
  for i in [0..(ind-1)]
    if str.charAt(i) is "\n" and prevChar is "\\"
      ++num
    prevChar = str.charAt(i)
  return num

# apply all macro expansions to the given string
applyDefines = (str, defines, curDefines) ->
  for define in opts.defines
    if curDefines?.indexOf define is -1
      replaceString = ""
      if opts.defines[define] isnt null
        definesToSend = []
        if curDefines
          definesToSend = curDefines
        definesToSend.push define
        replaceString = applyDefines opts.defines[define], opts, defines
      line.replace(new RegExp("\b#{opt}\b", "g"), replaceString)

# process preprocessor line functions
insertInclude = (directive, restOfLine, outStream, opts, dirname) ->
  outStream.write "#include#{restOfLine}"
  # TODO: write this
  # console.error "insertInclude not implemented!"
  # process.exit -1

addDefine = (directive, restOfLine, outStream, opts) ->
  outStream.write "#define#{restOfLine}"
  # TODO: write this
  # console.error "addDefine not implemented!"
  # process.exit -1

removeDefine = (directive, restOfLine, outStream, opts) ->
  # TODO: write this
  console.error "removeDefine not implemented!"
  process.exit -1

processError = (directive, restOfLine, ifStack) ->
  # TODO: write this
  console.error "processError not implemented!"
  process.exit -1

processPragma = (directive, restOfLine, outStream, opts) ->
  # TODO: write this
  console.error "processPragma not implemented!"
  process.exit -1

processLineDirective = (directive, restOfLine, outStream, opts) ->
  # TODO: report better column numbers
  # TODO: show line of interest, with carat pointing up at column
  toLine = restOfLine.match(tokenRegex)?[0] # get first token
  backslashesBeforeToLine =
    getBackslashNewlinesBeforeToken restOfLine, toLine
  if not toLine                             # if line just "#line \n"
    throwError opts.file, opts.line, directive.length,
    "No line number given in #{directive} directive."
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
  outStream.write(applyDefines line, opts.defines)

# this one does all the heavy lifting; given an input line, output stream, and
# list of current defines, it will read in preprocessor directives and modify
# opts as appropriate, finally outputting the correct output to outStream
# we chose to leave the concatenation of backslash-newlines to each processLine
# function so that they can give the appropriate lines and columns on each error
processLine = (line, outStream, opts, ifStack, dirname) ->
  directive = line.match(directiveRegex)?[0]
  restOfLine = line.substr directive?.length
  if ifStack.length isnt 0 and ifStack[ifStack.length - 1].isCurrentlyTrue
    switch directive
      when "\#include"
      then insertInclude directive, restOfLine, outStream, opts, dirname
      when "\#define"
      then addDefine directive, restOfLine, outStream, opts
      when "\#undef"
      then removeDefine directive, restOfLine, outStream, opts
      when "\#error"
      then processError directive, restOfLine, ifStack
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
         if ifStack.length is 0 or ifStack[ifStack.length - 1].isCurrentlyTrue
           processSourceLine line, outStream, opts
  else
    if directive.match condRegex
      processIf directive, restOfLine, outStream, opts, ifStack, dirname
    else
      # gotta keep those lines in place
      opts.line += (directive + restOfLine?).match(backslashNewlineRegex).length

# this function sets up input and processing streams and calls processLine to
# write the appropriate output to outStream; exposed to the frontend
# e.g.,
# opts: {
#  defines: { define1: null, define2: 2 },
#  includes: ['/mnt/usr/include']
# }
analyzeLines = (file, opts) ->
  # initialize opts
  opts.line = 1
  opts.file = file
  # get pwd of file
  dirname = path.dirname file
  # initialize streams
  fileStream = fs.createReadStream file
  formatStream = new ConcatBackslashNewlinesStream
  lineStream = fileStream.pipe(formatStream)
  outStream = new stream.PassThrough()
  # stack of #if directives
  # each element is laid out as:
  # {
  #   type: "if",
  #   hasBeenTrue: true
  #   isCurrentlyTrue: false
  # }
  # hasBeenTrue is true so we know whether to process "else" statements
  # isCurrentlyTrue tells us whether we're processing the current branch of if
  ifStack = []
  fileStream.on 'error', (err) ->
    console.error "Error in reading input file: #{file}."
    throw err
  lineStream.on 'line', (line) ->
    processLine line, outStream, opts, ifStack, dirname
  return outStream

module.exports = analyzeLines
