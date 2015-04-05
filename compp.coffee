#!/usr/bin/env coffee

# frontend and argument processor for compp
# calls to analyzeLines to do all the heavy lifting

# node standard modules
fs = require 'fs'
path = require 'path'
# local modules
analyzeLines = require './analyzeLines'

addDefineStr = 'add-define'
removeDefineStr = 'remove-define'
includeStr = 'include-dir'
outputStr = 'output'

getOpt = new (require('node-getopt'))([
  # -D HELLO for #define HELLO,
  # -D HELLO=3 for #define HELLO 3
  ['D', "#{addDefineStr}=ARG+", 'Add cpp define.'],
  # -U HELLO for #undef HELLO
  ['U', "#{removeDefineStr}=ARG+", 'Remove cpp define.'],
  # -I dir adds to include dirs
  ['I', "#{includeStr}=ARG+", 'Include directory for header files.'],
  # -o file
  ['o', "#{outputStr}=ARG", 'Define file to output to.'],
  ['h', 'help', 'Display this help.'],
  ['v', 'version', 'Display version number.']])

getOpt.setHelp(
  "Usage: compp [OPTION..] FILE\n\n" +
  "[[OPTIONS]]\n"
)

# this should error out appropriately if any incorrect options are given
opts = getOpt.bindHelp().parseSystem()

if 1 != opts.argv.length
  console.error "Please input a single file for preprocessing."
  process.exit -1

# TODO: sanitize defines, define values, undefines, and includes
console.warn opts.defines

# read from file
fs.exists opts.argv[0], (exists) ->
  if not exists
    console.error "Input file not found."
    process.exit -1

  processedStream =
    analyzeLines(opts.argv[0], {
      defines : opts.options[addDefineStr],
      undefines: opts.options[removeDefineStr],
      includes: opts.options[includeStr]
      })

  if opts.options[outputStr]
    fs.exists path.dirname(opts.options[outputStr]), (exists) ->
      if not exists
        console.error "Directory for output file not found."
        process.exit -1
      fs.stat opts.options[outputStr], (err, stats) ->
        # don't care if file doesn't exist since we're writing to it
        if err and err.code isnt 'ENOENT'
          throw err
        if not err and stats.isDirectory()
          console.error "Output file should be file, not directory."
          process.exit -1
        else
          outStream = fs.createWriteStream(opts.options[outputStr])
          processedStream.pipe outStream
          outStream.on 'error', (err) ->
            console.error "Error in writing to output file: " +
              "#{opts.options[outputStr]}"
            throw err
  else
    processedStream.pipe process.stdout
