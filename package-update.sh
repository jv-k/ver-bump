#!/bin/bash

MODULE_DIR="$(dirname "$(realpath "$0")")"
source $MODULE_DIR/lib/helper.sh

FLAG_JSON=true
V_USR_INPUT="1.12.2" 

JSON_FILES=("test.jsown")

# Change `version:` value in JSON files, like packager.json, composer.json, etc
bump-json-files() {
  if [ "$FLAG_JSON" != true ]; then return; fi
  
  JSON_PROCESSED=( ) # holds filenames after they've been changed

  for FILE in "${JSON_FILES[@]}"; do
    if [ -f $FILE ]; then
      # Get the existing version number
      V_OLD=$( sed -n 's/.*"version":.*"\(.*\)"\(,\)\{0,1\}/\1/p' $FILE )

      if [ "$V_OLD" = "$V_USR_INPUT" ]; then
        echo -e "\n${S_WARN}File <${S_NORM}$FILE${S_WARN}> already contains version: ${S_NORM}$V_OLD"
      else
        # Write to output file
        FILE_MSG=`sed -i .temp "s/\"version\":\(.*\)\"$V_OLD\"/\"version\":\1\"$V_USR_INPUT\"/g" $FILE 2>&1`

        if [ "$?" -eq 0 ]; then
          echo -e "\n${I_OK} ${S_NOTICE}Updated file: <${S_NOTICE}$FILE${S_LIGHT}> from ${S_NORM}$V_OLD -> $V_USR_INPUT"
          rm -f ${FILE}.temp          
          # Add file change to commit message:
          GIT_MSG+="Updated $FILE, "
        else
          echo -e "\n${I_STOP} ${S_ERROR}Error\n$PUSH_MSG\n"
        fi
      fi

      JSON_PROCESSED+=($FILE)
    else
      echo -e "\n${S_WARN}File <${S_NORM}$FILE${S_WARN}> not found."
    fi
  done
  # Stage files that were changed:
}

bump-json-files