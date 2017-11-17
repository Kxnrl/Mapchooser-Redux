#!/bin/bash

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
COMMITS=$COUNT
FTP_HOST=$2
FTP_USER=$3
FTP_PSWD=$4
FILE=MCERedux-$COUNT-$1.zip

wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -q -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

wget "https://github.com/Kxnrl/Core/raw/master/include/cg_core.inc" -q -O include/cg_core.inc
wget "https://github.com/Kxnrl/Store/raw/master/include/store.inc" -q -O include/store.inc

chmod +x addons/sourcemod/scripting/spcomp

for file in include/mapchooser_redux.inc
do
  sed -i "s/<commits>/$COMMITS/g" $file > output.txt
  rm output.txt
done

cp mapchooser_redux.sp addons/sourcemod/scripting/
cp maptimelimit_redux.sp addons/sourcemod/scripting/
cp nominations_redux.sp addons/sourcemod/scripting/
cp rockthevote_redux.sp addons/sourcemod/scripting/

cp include/* addons/sourcemod/scripting/include

for file in addons/sourcemod/scripting/*_redux.sp
do
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

echo " \n "

if [ ! -f "mapchooser_redux.smx" ]; then
    echo "Compile mapchooser_redux failed!"
    exit 1;
fi

if [ ! -f "maptimelimit_redux.smx" ]; then
    echo "Compile maptimelimit_redux failed!"
    exit 1;
fi

if [ ! -f "nominations_redux.smx" ]; then
    echo "Compile nominations_redux failed!"
    exit 1;
fi

if [ ! -f "rockthevote_redux.smx" ]; then
    echo "Compile rockthevote_redux failed!"
    exit 1;
fi

mkdir plugins
mkdir scripts

mv *.sp scripts
mv include scripts
mv *.smx plugins

zip -9rq $FILE scripts plugins LICENSE README.md

lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O MCR/build/ $FILE"

if [ "$1" = "1.8" ]; then
    echo "Upload RAW..."
    cd plugins
    lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O MCR/Raw/ mapchooser_redux.smx"
    lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O MCR/Raw/ maptimelimit_redux.smx"
    lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O MCR/Raw/ nominations_redux.smx"
    lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O MCR/Raw/ rockthevote_redux.smx"
fi