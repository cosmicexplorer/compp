spawnSync = require('child_process').spawnSync
utils = require './utilities'
path = require 'path'

compilers =
  c: ['gcc', 'clang']
  "c++": ['g++', 'clang++']
headerArgs = ['-v', '/dev/null', '-fsyntax-only']

# looks like a hack, but this is standard syntax for gcc and clang
includeStart = "#include <...> search starts here:"
includeEnd = "End of search list."

parseAndSplit = (str) ->
  return [] if str is ""
  str.substring(str.indexOf(includeStart) + includeStart.length,
    str.indexOf(includeEnd))
    .split('\n').filter((str) -> str isnt "") # first and last line are empty
    # each line has an initial space
    .map (str) ->
      path.resolve str.substr 1

module.exports = (lang) ->
  if not compilers[lang]
    throw new Error "language #{lang} not recognized"
  utils.uniquify(compilers[lang].map((compiler) ->
    parseAndSplit(((proc) ->
      if proc.status is 0
        proc.stderr.toString()
      else "")(spawnSync(compiler, ['-x', lang].concat headerArgs))))
    .reduce((arr1, arr2) -> arr1.concat arr2))
