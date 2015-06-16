# node standard modules
fs = require 'fs'
path = require 'path'
# local modules
comppGetOpt = require "#{__dirname}/compp-getopt"
comppStreams = require "#{__dirname}/compp-streams"

# frontend and argument processor for compp
# calls to analyzeLines to do all the heavy lifting
module.exports =
  # all the streams used for compp; use this to access
  # concat-backslash-newline-stream and preprocess-stream (and c-format-stream
  # if you want it all in one package)
  streams: comppStreams
  # inStream and outStream are optional arguments, made so that compp could be
  # more easily used by other javascript processes
  run : (argv) ->
    language = argv[2]
    infile = argv[3]

    # 'node compp.js <language> <infile>'
    if argv.length isnt 4
      console.log '''
        Usage: compp language infile
        'language' can be specified as either 'c' or 'c++'. Output prints to
        stdout.
        '''
      process.exit 1

    # all the streams used here propagate errors, so an uncaught error will
    # continue onward into the CFormatStream, and if uncaught, will blow up
    cbns = new comppStreams.ConcatBackslashNewlinesStream
       filename: infile
    pps = new comppStreams.PreprocessStream(
      infile, opts.includes, defines)
    cfs = new comppStreams.CFormatStream
      numNewlinesToPreserve: 0
      indentationString: "  "
    # TODO: add better error management, taking care of all the errors that each
    # transform stream throws
    if errorCallback
      cfs.on 'error', errorCallback
    else
      cfs.on 'error', (err) ->
        if err.isWarning
          if err.sourceStream
            console.error "From #{err.sourceStream}:"
          else
            console.error "No source stream specified:"
          console.error err.message
          if err.isTrigraph
            console.error "Use -t to enable."
        else
          if err.sourceStream
            console.error err.message
          else if err.code is 'ENOENT' # probably isn't stdin; assume path works
            console.error "Input file #{err.path} not found."
          else if err.code is 'EISDIR'
            console.error "Input file #{err.path} is a directory."
          else                    # unrecognized error
              console.error err.stack
          process.exit 1

    inStream
      .pipe(cbns)
      .pipe(pps)
      .pipe(cfs)
      # errors on output stream don't propagate to input streams, and errors on
      # input/transform streams don't propagate to output stream (since we
      # didn't write fs.createWriteStream), so we deal with this error case
      # separately
      .pipe(outStream).on 'error', (err) ->
        if err.code is 'EISDIR'
          console.error "Output file #{err.path} is a directory."
        else                    # unrecognized error
          console.error err.stack
        process.exit 1
