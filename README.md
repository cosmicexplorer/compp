compp
======

![A compost thresher.](http://cd.indiabizclub.com/uploads05/34/0/amar_412694906.jpg)

A preprocessor for [composter](https://github.com/cosmicexplorer/composter), the trashy C compiler.

## TODO:
- better column markings
- stop cyclical includes
- digraph/trigraph support
- get actual system-independent include directories

## How compliant will this preprocessor be?

I've been reading through the GNU cpp manual quite a bit recently, and I intend for compp to match its capabilities. I don't intend to pedantically follow ANSI C, and I'll resolve any errors in test inputs as they arise.

## How fast will it be?

Probably not as fast as GNU cpp, since that's written in C. However, [node streams](https://nodejs.org/api/stream.html) are pretty well-documented and optimized, so I expect compp should be able to at least avoid getting lapped.

## How do I make it and test it?

- build: ```make```
- test: ```make check```
