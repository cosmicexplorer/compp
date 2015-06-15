# run as "coffee test-concat.coffee file"

DumpStream = require 'dump-stream'
CBStream = require './concat-backslash-newline-stream'

fs = require 'fs'

concatLines = 0
concatChars = 0
concatBackslashLines = 0

bylineLines = 0
bylineBackslashLines = 0
allChars = 0

getAllChars = (filename) ->
  fs.createReadStream(filename).pipe(new DumpStream)

getConcatLinesAndChars = (filename) ->
  fs.createReadStream(filename).pipe(new CBStream).on 'data', (obj) ->
    ++concatBackslashLines
    concatLines += (obj.match(/\n/g) or []).length
    concatChars += obj.length
    process.stdout.write "<!>" + obj + "<?>"

getConcatLinesAndChars(process.argv[2]).on 'end', ->
  s = getAllChars(process.argv[2])
  s.on 'finish', ->
    str = s.dump()
    allChars = str.length
    str.replace(/(.)\n/g, (str, g1) ->
      if g1 is "\\"
        ++bylineBackslashLines)
    bylineLines = str.match(/\n/g or []).length
    if bylineLines != concatLines
      throw new Error "bylineLines #{bylineLines} != concatLines #{concatLines}"
    if allChars != concatChars
      throw new Error "allChars #{allChars} != concatChars #{concatChars}"
    if concatBackslashLines != bylineBackslashLines
      throw new Error "concatBackslashLines #{concatBackslashLines} != " +
        "bylineBackslashLines #{bylineBackslashLines}"
