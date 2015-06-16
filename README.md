compp
======

![A compost thresher.](http://cd.indiabizclub.com/uploads05/34/0/amar_412694906.jpg)

A preprocessor for [composter](https://github.com/cosmicexplorer/composter), the trashy C compiler.

# Explanation:

This is going to be a full C/C++ preprocessor when it's finished. However, I've currently become distracted with another project, [gxr](https://github.com/cosmicexplorer/gxr), and since libclang has no preprocessing support, I'm gutting this project to provide that for C and C++ source. Fear not! The previous attempt at making a standalone preprocessor (which was almost complete, lol) can be viewed and downloaded at the [standalone branch](https://github.com/cosmicexplorer/compp/tree/standalone), and I'll get back to this quite soon.

## How compliant is this preprocessor?

I intend for compp to match GCC's preprocessor semantics exactly; the (somewhat formatted) output of GCC's preprocessor is used to test compp.

## How fast is it?

Probably not as fast as gcc's, since that's written in C. However, [node streams](https://nodejs.org/api/stream.html) are pretty well-documented and optimized, so I expect compp should be able to at least avoid getting lapped.

## Why are you doing this?

As part of [composter](https://github.com/cosmicexplorer/composter), a C compiler project written in coffeescript. Feel free to join me! This preprocessor is just over a thousand lines, the rest won't take too much effort.

## How do I make it and test it?

- build: ```make```
- test: ```make check```

## License

GPL v3
