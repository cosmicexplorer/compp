# native modules
fs = require 'fs'
path = require 'path'
stream = require 'stream'
# local modules
ConcatBackslashNewlinesStream = require './ConcatBackslashNewlinesStream'

# constants
directiveRegex = /^#[a-z_]+/

# process preprocessor line
insertInclude = (restOfLine, outStream, opts, dirname) ->
  outStream.write "#include#{restOfLine}"
  # TODO: write this
  # console.error "insertInclude not implemented!"
  # process.exit -1

addDefine = (restOfLine, outStream, opts) ->
  outStream.write "#define#{restOfLine}"
  # TODO: write this
  # console.error "addDefine not implemented!"
  # process.exit -1

removeDefine = (restOfLine, outStream, opts) ->
  # TODO: write this
  console.error "removeDefine not implemented!"
  process.exit -1

processError = (restOfLine, ifStack) ->
  # TODO: write this
  console.error "processError not implemented!"
  process.exit -1

processPragma = (restOfLine, outStream, opts) ->
  # TODO: write this
  console.error "processPragma not implemented!"
  process.exit -1

processLineDirective = (restOfLine, outStream, opts) ->
  # TODO: write this
  console.error "processLineDirective not implemented!"
  process.exit -1

processIf = (directive, restOfLine, outStream, opts, ifStack, dirname) ->
  # TODO: write this
  console.error "processIf not implemented!"
  process.exit -1

processSourceLine = (line, outStream, opts) ->
  # TODO: write this
  outStream.write line

# this one does all the heavy lifting; given an input line, output stream, and
# list of current defines, it will read in preprocessor directives and modify
# opts as appropriate, finally outputting the correct output to outStream
processLine = (line, outStream, opts, ifStack, dirname) ->
  directive = line.match(directiveRegex)?[0]
  restOfLine = line.replace directiveRegex, ""
  switch directive
    when "\#include" then insertInclude restOfLine, outStream, opts, dirname
    when "\#define" then addDefine restOfLine, outStream, opts
    when "\#undef" then removeDefine restOfLine, outStream, opts
    when "\#error" then processError restOfLine, ifStack
    # TODO: not sure if we do anything here
    when "\#pragma" then processPragma restOfLine, outStream, opts
    when "\#line" then processLineDirective restOfLine, outStream, opts
    else
      if directive?.match directiveRegex
        # works on #if, #else, #endif, #ifdef, #ifndef, #elif
        processIf directive, restOfLine, outStream, opts, ifStack, dirname
      # just a normal source line
      else
        # output if not within a #if or if within a true #if
        if ifStack.length is 0 or ifStack[ifStack.length - 1].isCurrentlyTrue
          processSourceLine line, outStream, opts

# this function sets up input and processing streams and calls processLine to
# write the appropriate output to outStream; exposed to the frontend
#
# opts: {
#  defines: ['define1', 'define2=2'],
#  undefines: ['define3']
#  include: ['/mnt/usr/include']
# }
analyzeLines = (file, opts) ->
  # initialize opts
  opts.line = 1
  opts.filename = file
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
