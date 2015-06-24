fs = require 'fs'
byline = require 'byline'
PreprocessStream = require '../../../src/new-preprocess-stream'
Transform = require 'transform-stream-extensions'
TestUtils = require '../../test-utils'

infile = process.argv[2]

ParseLineStream = TestUtils.makeTransformStream "both", JSON.parse

StringifyStream = TestUtils.makeTransformStream "write", (obj) ->
  JSON.stringify(obj) + '\n'

byline(fs.createReadStream(infile))
  .pipe(new ParseLineStream)    # bounce to object
  .pipe(new PreprocessStream infile, "c")
  .pipe(new StringifyStream)    # bounce back to string
  .pipe(process.stdout)
