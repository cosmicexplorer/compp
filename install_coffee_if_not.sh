#!/bin/sh

if ! hash coffee 2>/dev/null; then
  echo "coffeescript is not installed on your system." 1>&2
  echo "Please run \"npm install -g coffee-script\"." 1>&2
  exit -1
fi
