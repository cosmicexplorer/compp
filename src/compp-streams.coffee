PreprocessStream = require './preprocess-stream'

###
example usage:

    inStream
      .pipe(new comppStreams.ConcatBackslashNewlinesStream
        filename: filename)
      .pipe(new comppStreams.PreprocessStream(
        filename, opts.includes, defines))
      .pipe(new comppStreams.CFormatStream({
        numNewlinesToPreserve: 0,
        indentationString: "  "}))
      .pipe(outStream)

The appropriate specification for arguments for PreprocessStream can be found in
preprocess-stream.coffee; the same goes for CFormatStream and the
c-format-stream npm module and associated github
(https://github.com/cosmicexplorer/c-format-stream).
###

module.exports =
  # do preprocessing
  PreprocessStream: PreprocessStream
