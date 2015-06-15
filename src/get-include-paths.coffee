# interestingly enough, this should work on cygwin installs as well

spawnSync = require('child_process').spawnSync
utils = require './utilities'
path = require 'path'

compilers = ['gcc', 'clang']
headerArgs = ['-v', '/dev/null', '-fsyntax-only']

# looks like a hack, but this is standard syntax for gcc and clang
includeStart = "#include <...> search starts here:"
includeEnd = "End of search list."

parseAndSplit = (str) ->
  str.substring(str.indexOf(includeStart) + includeStart.length,
    str.indexOf(includeEnd))
    .split('\n').filter((str) -> str isnt "") # first and last line are empty
    # each line has an initial space
    .map (str) ->
      path.resolve str.substr 1

module.exports = (language) ->
  if language isnt "c" and language isnt "c++"
    throw new Error "c/c++ are the only allowed languages"
  utils.uniquify(compilers.map((compiler) ->
    parseAndSplit(
      spawnSync(compiler, ['-x', language].concat headerArgs)
      .stderr.toString()))
    .reduce((arr1, arr2) -> arr1.concat arr2))
