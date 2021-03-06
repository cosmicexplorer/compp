# node standard modules
fs = require 'fs'
path = require 'path'
# local modules
comppGetOpt = require "./compp-getopt"
comppStreams = require "./compp-streams"

# frontend and argument processor for compp
# calls to analyzeLines to do all the heavy lifting
module.exports =
  streams: comppStreams
  run : (argv) ->
    language = argv[2]
    infile = argv[3]

    # 'node compp.js <language> <infile>'
    if argv.length isnt 4
      console.log '''
        Usage: compp language infile
        'language' can be specified as either 'c' or 'cpp'. Output prints to
        stdout.
        '''
      process.exit 1

    cbns = new comppStreams.ConcatBackslashNewlinesStream
       filename: infile
    pps = new comppStreams.PreprocessStream(
      infile, opts.includes, defines)

    pps.on 'error', (err) ->
      if err.isWarning
        if err.sourceStream
          console.error "From #{err.sourceStream}:"
        else
          console.error "No source stream specified:"
        console.error err.message
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

    inStream.pipe(cbns).pipe(pps).pipe(process.stdout)
