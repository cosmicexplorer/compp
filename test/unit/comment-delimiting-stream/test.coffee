fs = require 'fs'
diff = require 'diff'
CommentDelimitingStream = require '../../../src/comment-delimiting-stream'
DumpStream = require 'dump-stream'
Transform = require 'transform-stream-extensions'
TestUtils = require '../../test-utils'

infile = process.argv[2]
outfile = "#{__dirname}/output"
compare_outfile = "#{__dirname}/expected-output"

StringifierStream = TestUtils.makeTransformStream "write", (chunk) ->
  JSON.stringify(chunk) + '\n'

fs.createReadStream(infile)
  .pipe(new CommentDelimitingStream)
  .pipe(new StringifierStream)
  .pipe(fs.createWriteStream outfile).on 'finish', ->
    res = diff.diffLines(fs.readFileSync(outfile).toString(),
      fs.readFileSync(compare_outfile).toString())
    if res.filter((el) -> el.added or el.removed).length isnt 0
      console.error "FAILED:"
      console.error "DIFF:"
      TestUtils.outputDiffs(res, process.stderr)
      process.exit 1
    checkLengths()

ConcatStringStream = TestUtils.makeTransformStream "write", (chk) -> chk.string

checkLengths = ->
  s = fs.createReadStream(infile)
    .pipe(new CommentDelimitingStream)
    .pipe(new ConcatStringStream)
    .pipe(new DumpStream).on 'finish', ->
      realFile = fs.readFileSync(infile).toString()
      realChars = realFile.length
      realNewlines = (realFile.match(/\n/g) or []).length
      streamFile = s.dump()
      streamChars = streamFile.length
      streamNewlines = (streamFile.match(/\n/g) or []).length
      if realChars isnt streamChars
        console.error "FAILED:"
        console.error "realChars: #{realChars} != #{streamChars} (streamChars)"
        process.exit 1
      if realNewlines isnt streamNewlines
        console.error "FAILED:"
        console.error "realNewlines: #{realNewlines} != #{streamNewlines} " +
          "(streamNewlines)"
        process.exit 1
