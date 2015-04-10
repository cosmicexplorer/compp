#!/bin/sh

# look at makefile for test input/output naming scheme
for test_in in $@; do
  test_out="$(echo "$test_in" | sed -e 's/_in\.c$/_out\.c/g')"
  if diff "$test_in" "$test_out"; then
    echo "diff failed: $test_in and $test_out" 1>&2
    exit -1
  fi
done
