fs = require 'fs'
byline = require 'byline'
PreprocessStream = require '../../../src/new-preprocess-stream'
Transform = require 'transform-stream-extensions'
TestUtils = require '../../test-utils'

infile = process.argv[2]

ParseLineStream = TestUtils.makeTransformStream "both", JSON.parse

byline(fs.createReadStream(infile))
  .pipe(new ParseLineStream)
  .pipe(new PreprocessStream infile, "c").on 'data', (obj) ->
    console.log obj
