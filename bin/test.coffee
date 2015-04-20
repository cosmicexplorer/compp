fs = require 'fs'

CBNS = require '../lib/compp/concat-backslash-newline-stream'

fs.createReadStream("out.c")
  # .pipe(new CBNS(filename: "out.c"))
  .pipe(new CBNS)
  .pipe(process.stdout)
