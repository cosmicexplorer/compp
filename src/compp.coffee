# node standard modules
fs = require 'fs'
path = require 'path'
# local modules
comppGetOpt = require "#{__dirname}/compp-getopt"
comppStreams = require "#{__dirname}/compp-streams"

# frontend and argument processor for compp
# calls to analyzeLines to do all the heavy lifting
module.exports =
  run : ->
    ###
    accepts -D, -U, -I, -h, -v, and -o arguments
    note: undefs take precedence over defines, and later defines take precedence
    over earlier defines ("earlier" -> earlier in argument list (closer to
    left))

    process.argv[0] will be "node", and process.argv[1] will be the compiled
    version of this script, due to the way these are compiled to js before
    execution, and the way this is called from "compp" (an auxiliary script in
    the repo's base directory). this is done because invoking the script through
    the coffeescript interpreter "coffee compp.coffee ..." automatically splits
    process.argv according to the argument parsing done in the coffeescript
    frontend, making the traditional "-DDEFINE" cpp syntax fail. the only
    resolution to this issue (calling this with "/usr/bin/env coffee --")
    doesn't actually work. we will explicitly shift it and change to "coffee"
    here to avoid confusion.
    ###
    process.argv.shift()
    process.argv[0] = "coffee"

    # parse and sanitize inputs
    opts = comppGetOpt.parseArgsFromArr process.argv

    if opts.help
      comppGetOpt.displayHelp()
      process.exit -1
    if opts.version
      comppGetOpt.displayVersion()
      process.exit 0

    if not (0 < opts.argv.length <= 2)
      console.error "Please input at least one and at most two file(s) " +
      "for preprocessing."
      process.exit -1

    if opts.output.length > 1 or
       (opts.output.length is 1 and opts.argv.length is 2)
      console.error "Please input at most one file for output."
      process.exit -1

    if opts.output.length is 0 and opts.argv.length is 2
      opts.output = [opts.argv[1]]

    defines = {}
    for defStr in opts.defines
      hasFoundEqualsSign = no
      for i in [0..(defStr.length - 1)] by 1
        if defStr.charAt(i) is "="
          defines[defStr.substr(0, i)] =
            text: defStr.substr(i + 1)
            type: "object"
          hasFoundEqualsSign = yes
          break
      if not hasFoundEqualsSign
        defines[defStr] =
          text: ""
          type: "object"

    # if any -D options exist, and any -U options
    if opts.defines and opts.undefs
      for undefStr in opts.undefs
        # use 'in' for arrays, 'of' for hashes
        for defineStr of defines
          if undefStr is defineStr
            delete defines[defineStr]

    # let's include files in our own directory!
    if opts.argv[0] is "-"
      opts.includes.push path.resolve(__dirname)
    else
      opts.includes.push path.resolve(path.dirname(opts.argv[0]))

    if opts.argv[0] is "-"
      inStream = process.stdin
    else
      inStream = fs.createReadStream(opts.argv[0])

    if opts.output[0]
      outStream = fs.createWriteStream(opts.output[0])
    else
      outStream = process.stdout

    # all the streams used here propagate errors, so an uncaught error will
    # continue onward into the CFormatStream.
    cbns = new comppStreams.ConcatBackslashNewlinesStream
    pps = new comppStreams.PreprocessStream(
      opts.argv[0], opts.includes, defines)
    cfs = new comppStreams.CFormatStream
      numNewlinesToPreserve: 0
      indentationString: "  "
    # TODO: add better error management, taking care of all the errors that each
    # transform stream throws
    cfs.on 'error', (err) ->
      if err.code is 'ENOENT'   # probably isn't stdin
        console.error "Input file #{err.path} not found."
      else if err.code is 'EISDIR'
        console.error "Input file #{err.path} is a directory."
      else                      # for errors from our transform streams
        if err.sourceStream
          console.error "From #{err.sourceStream}:"
          console.error err.message
        else
          console.error err.stack
      process.exit -1

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
        else
          console.error err
        process.exit -1
