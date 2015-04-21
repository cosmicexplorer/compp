compp
======

![A compost thresher.](http://cd.indiabizclub.com/uploads05/34/0/amar_412694906.jpg)

A preprocessor for [composter](https://github.com/cosmicexplorer/composter), the trashy C compiler.

## TODO:
- better column markings
- function-like macros on the command line
- get system and compiler-independent include directories
- actually evaluate conditional ifs

# Usage:
## Executable
```bash
$ compp -h

    Usage: compp [-Dmacro[=defn]...] [-Umacro]
                 [-Idir] [-o outfile] [-t]
                 infile [outfile]
```
Use `"-"` for stdin or stdout instead of naming a file. `outfile` defaults to stdout. Use the `-t` option to turn on trigraphs.

## Node Module
```javascript
Compp = require('compp');

args = {
  defines: ['__cplusplus', 'ASDF=3'],
  includes: ['/usr/include']
};

Compp.run(args, getReadableStreamSomehow(), getWriteableStreamSomehow(),
  function(err){
    handleError(err); // do whatever you want, man
  }
);

```

All streams in the pipeline can be used separately; there are detailed instructions in the source on how to manually use each one. However, it is easiest to just use all three at once with the provided run function. All three streams in the pipeline will propagate any `'error'` events, so it is sufficient to simply watch error events that occur at the final stage of the pipeline. Note that [c-format-stream](https://github.com/cosmicexplorer/c-format-stream) has its own repository and associated documentation.

## How compliant is this preprocessor?

I've been reading through the GNU cpp manual quite a bit recently, and I intend for compp to match its capabilities. I don't intend to pedantically follow ANSI C, and I'll resolve any errors in test inputs as they arise.

However, as of now, it's definitely not fully compliant. See the TODO in this file and the tests for examples where it diverges.

## How fast is it?

Probably not as fast as GNU cpp, since that's written in C. However, [node streams](https://nodejs.org/api/stream.html) are pretty well-documented and optimized, so I expect compp should be able to at least avoid getting lapped.

## Why are you doing this?

As part of [composter](https://github.com/cosmicexplorer/composter), a C compiler project written in coffeescript. Feel free to join me! This preprocessor is just over a thousand lines, the rest won't take too much effort.

## How do I make it and test it?

- build: ```make```
- test: ```make check```

## License

GPL v3
