fs = require 'fs'
diff = require 'diff'
NewPreprocessStream = require '../../../src/new-preprocess-stream'
DumpStream = require 'dump-stream'
TestUtils = require '../../test-utils'

infile = process.argv[2]

console.error infile

s = fs.createReadStream(infile)
  .pipe(new NewPreprocessStream infile, "c")
  .pipe(new DumpStream).on 'finish', ->
    res = diff.diffLines(s.dump(),
      fs.readFileSync("#{__dirname}/expected-output").toString())
    if res.length isnt 0
      console.error "FAILED:"
      console.error "DIFF:"
      TestUtils.outputDiffs(res, process.stderr)
      process.exit 1
