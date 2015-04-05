# my own version of getopt which support typical cpp syntax
# WORKING ON THIS LATER

displayHelp = (optionMap) ->
  outStr =
    "Usage: compp [OPTION...] FILE\n\n"
  for opt in optionArr
    outStr += "\t-#{opt[0]}, --#{opt[1]},\t#{opt[2]}\n"

parseArgsFromArr = (argArr, optionMap) ->
  exec = argArr.shift()
  help = false
  version = false
  for arg in argArr
    if

parseArgv = (argv, optionMap) ->
  argv_zero = argv.match(/^.*\s/g)[0]
  argArr = argv.match /\s+.*\s+/g
  argArr.unshift argv_zero
  for arg in argArr
    arg.replace /\s/g, ""
  parseArgsFromArr argArr, optionMap

module.exports =
  displayHelp: displayHelp
  parseArgv: parseArgv
