# frontend and argument processor for compp
# calls to analyzeLines to do all the heavy lifting

# accepts -D, -U, -I, -h, -v, and -o arguments
# note: undefs take precedence over defines, and later defines take precedence
# over earlier defines ("earlier" -> earlier in argument list (closer to left))

# process.argv[0] will be "node", and process.argv[1] will be the compiled
# version of this script, due to the way these are compiled to js before
# execution, and the way this is called from "compp" (an auxiliary script in the
# repo's base directory). this is done because invoking the script through the
# coffeescript interpreter "coffee compp.coffee ..." automatically splits
# process.argv according to the argument parsing done in the coffeescript
# frontend, making the traditional "-DDEFINE" cpp syntax fail. the only
# resolution to this issue (calling this with "/usr/bin/env coffee --") doesn't
# actually work. we will explicitly shift it and change to "coffee" here to
# avoid confusion.
process.argv.shift()
process.argv[0] = "coffee"

# node standard modules
fs = require 'fs'
path = require 'path'
# local modules
comppGetOpt = require "#{__dirname}/../obj/compp-getopt"
analyzeLines = require "#{__dirname}/../obj/analyzeLines"

# parse and sanitize inputs
opts = comppGetOpt.parseArgsFromArr process.argv

if opts.help
  comppGetOpt.displayHelp()
  process.exit 0
if opts.version
  comppGetOpt.displayVersion()
  process.exit 0

if not (0 < opts.argv.length <= 2)
  console.error "Please input at least one file for preprocessing."
  process.exit -1

if opts.output.length > 1 or (opts.output.length is 1 and opts.argv.length is 2)
  console.error "Please input at most one file for output."
  process.exit -1

if opts.output.length is 0 and opts.argv.length is 2
  opts.output = [opts.argv[1]]

defines = {}
for defStr in opts.defines
  hasFoundEqualsSign = false
  for i in [0..(defStr.length - 1)] by 1
  # 'is' isn't working here, so use == instead
  # not really sure why
    if defStr.charAt(i) == "="
      defines[defStr.substr(0, i)] = defStr.substr(i + 1)
      hasFoundEqualsSign = true
      break
  if not hasFoundEqualsSign
    defines[defStr] = ''

# if any -D options exist, and any -U options
if opts.defines and opts.undefs
  for undefStr in opts.undefs
    # use 'in' for arrays, 'of' for hashes
    for defineStr of defines
      if undefStr is defineStr
        delete defines[defineStr]

processedOpts =
  defines: defines
  includes: opts.includes

# read from file
processedStream = analyzeLines opts.argv[0],
  fs.createReadStream(opts.argv[0]),
  processedOpts

if opts.output[0]
  fs.stat path.dirname(opts.output[0]), (err, stats) ->
    if err and err.code is 'ENOENT'
      console.error "Directory for output file not found."
      process.exit -1
    else if err
      throw err
    fs.stat opts.output[0], (err, stats) ->
    # don't care if file doesn't exist since we're writing to it
      if err and err.code isnt 'ENOENT'
        throw err
      if not err and stats.isDirectory()
        console.error "Output file should be file, not directory."
        process.exit -1
      else
        outStream = fs.createWriteStream(opts.output[0])
        processedStream.pipe outStream
        outStream.on 'error', (err) ->
          console.error "Error in writing to output file: " +
            "#{opts.output[0]}"
          throw err
else
  processedStream.pipe process.stdout
