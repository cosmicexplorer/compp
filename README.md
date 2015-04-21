compp
======

![A compost thresher.](http://cd.indiabizclub.com/uploads05/34/0/amar_412694906.jpg)

A preprocessor for [composter](https://github.com/cosmicexplorer/composter), the trashy C compiler.

## TODO:
- better column markings
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
ComppStreams = require('compp');

// this pipeline will preprocess your input stream
preprocessPipeline = getReadableStreamSomehow()
  .pipe(new ComppStreams.ConcatBackslashNewlinesStream({
    filename: filename
  }))
  .pipe(new ComppStreams.PreprocessStream(filename, opts.includes, defines))
  .pipe(new ComppStreams.CFormatStream({ // these parameters can be modified
    numNewlinesToPreserve: 0,            // as described in c-format-stream
    indentationString: "  "
  }));

// fires if there are any errors in the readable stream, or in between.
// example code for how to use errors arising from invalid preprocessor input
// (essentially, compiler errors) can be found in the source
preprocessPipeline.on('error', function(err){
  handleErr(err); // do whatever, man
});

preprocessPipeline.pipe(getWriteableStreamSomehow());
```

All streams in the pipeline can be used separately; there are detailed instructions in the source on how to manually write to the preprocessing stream, for example. However, it is easiest to just use all three at once. All three streams in the pipeline will propagate any `'error'` events, so it is sufficient to simply watch error events that occur at the final stage of the pipeline. Note that [c-format-stream](https://github.com/cosmicexplorer/c-format-stream) has its own repository and associated documentation.

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
