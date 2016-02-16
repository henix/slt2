#!/bin/bash
for t in tests/* ; do
  echo "## ${t#tests/}"

  OPTS=()
  if [ -f "$t/def.lua" ] ; then
    OPTS+=(-d "$t/def.lua")
  fi

  if [ -f "$t/ans" ]; then
    # normal test
    colordiff -U3 <(${LUA:-lua} ./runslt2.lua "${OPTS[@]}" -t "$t/tmpl" < "$t/data.lua") "$t/ans"
  elif [ -f "$t/err" ]; then
    # error test
    errout=$(mktemp)
    ${LUA:-lua} ./runslt2.lua "${OPTS[@]}" -t "$t/tmpl" < "$t/data.lua" >/dev/null 2>"$errout"
    if ! eval "$(< "$t/err")" < "$errout" ; then
      cat "$errout"
    fi
    rm -f "$errout"
  else
    echo "ans or err must exists in $t"
  fi
done
