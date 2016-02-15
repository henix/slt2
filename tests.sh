#!/bin/bash
for t in tests/* ; do
  echo "## $t"
  colordiff -U3 <(./runslt2.lua -d "$t/def.lua" -t "$t/tmpl" < "$t/data.lua") "$t/ans"
done
