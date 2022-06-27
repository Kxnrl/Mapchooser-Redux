#!/bin/bash

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
COMMITS=$COUNT
FILE=MapChooser-Redux-git$COUNT-$2.zip

wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -q -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

wget "https://github.com/Kxnrl/Store/raw/master/include/store.inc" -q -O include/store.inc
wget "https://github.com/Kxnrl/SourceMod-Shop/raw/master/SourcePawn/include/shop.inc" -q -O include/shop.inc
wget "https://github.com/Kxnrl/sourcemod-utils/raw/master/smutils.inc" -q -O include/smutils.inc

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
cp maplister_redux.sp addons/sourcemod/scripting/
cp forcemapend_redux.sp addons/sourcemod/scripting/

cp include/* addons/sourcemod/scripting/include

for file in addons/sourcemod/scripting/*_redux.sp
do
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

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

if [ ! -f "maplister_redux.smx" ]; then
    echo "Compile maplister_redux failed!"
    exit 1;
fi

if [ ! -f "forcemapend_redux.smx" ]; then
    echo "Compile forcemapend_redux failed!"
    exit 1;
fi

mkdir plugins
mkdir scripts

mv *.sp scripts
mv include scripts
mv *.smx plugins

7z a $FILE -t7z -mx9 scripts plugins translations LICENSE README.md >nul

echo "Upload file RSYNC ..."
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./$FILE $RSYNC_USER@$RSYNC_HOST::TravisCI/MapChooser-Redux/$1/

if [ "$1" = "1.11" ]; then
    echo "Upload RAW RSYNC ..."
    RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./plugins/*.smx $RSYNC_USER@$RSYNC_HOST::TravisCI/_Raw/
    RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./translations/com.kxnrl.mcr.translations.txt $RSYNC_USER@$RSYNC_HOST::TravisCI/_Raw/translations/
fi
