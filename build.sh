#!/bin/bash

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
COMMITS=$COUNT
FTP_HOST=$2
FTP_USER=$3
FTP_PSWD=$4
FILE=MCER_$COUNT.zip

wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

chmod +x addons/sourcemod/scripting/spcomp

for file in include/mapchooser_extended.inc
do
  sed -i "s/<commits>/$COMMITS/g" $file > output.txt
  rm output.txt
done

mv mapchooser_extended.sp addons/sourcemod/scripting/
mv maptimelimit_extended.sp addons/sourcemod/scripting/
mv nominations_extended.sp addons/sourcemod/scripting/
mv rockthevote_extended.sp addons/sourcemod/scripting/

mv include/* addons/sourcemod/scripting/include

for file in addons/sourcemod/scripting/*_extended.sp
do
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

zip -9rq $FILE mapchooser_extended.smx maptimelimit_extended.smx nominations_extended.smx rockthevote_extended.smx 

lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O MCER/ $FILE"