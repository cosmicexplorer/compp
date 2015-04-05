# my own version of getopt which support typical cpp syntax

displayHelp = (optionMap) ->
  outStr =
    "Usage: compp [OPTION...] FILE\n\n"
  for opt in optionArr
    outStr += "\t-#{opt[0]}, --#{opt[1]},\t#{opt[2]}\n"

parseArgv = (argv, optionMap) ->
  argv_zero = argv.match(/^.*\s/g)[0]
  argv_zero.replace /\s/g, ""
  argArr = argv.match /\s+.*\s+/g
  argArr.unshift argv_zero
