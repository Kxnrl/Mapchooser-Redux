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

cp mapchooser_extended.sp addons/sourcemod/scripting/
cp maptimelimit_extended.sp addons/sourcemod/scripting/
cp nominations_extended.sp addons/sourcemod/scripting/
cp rockthevote_extended.sp addons/sourcemod/scripting/

cp include/* addons/sourcemod/scripting/include

for file in addons/sourcemod/scripting/*_extended.sp
do
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

mkdir plugins
mkdir scripts

mv *.sp scripts
mv include scripts
mv *.smx plugins

zip -9rq $FILE scripts plugins

lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O MCER/ $FILE"