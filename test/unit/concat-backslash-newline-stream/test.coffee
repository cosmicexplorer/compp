DumpStream = require 'dump-stream'
CBStream = require '../../../src/concat-backslash-newline-stream'

fs = require 'fs'

concatLines = 0
concatChars = 0
concatBackslashLines = 0

bylineLines = 0
bylineBackslashLines = 0
allChars = 0

getAllCharsStream = (filename) ->
  fs.createReadStream(filename).pipe(new DumpStream)

getConcatLinesAndChars = (filename) ->
  fs.createReadStream(filename).pipe(new CBStream).on 'data', (buf) ->
    obj = buf.toString()
    ++concatBackslashLines
    concatLines += (obj.match(/\n/g) or []).length
    concatChars += obj.length
    process.stdout.write "<!>" + obj + "<?>"

infile = process.argv[2]

# run it
getConcatLinesAndChars(infile).on 'end', ->
  s = getAllCharsStream(infile)
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
