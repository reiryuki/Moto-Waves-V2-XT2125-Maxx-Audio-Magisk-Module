# space
ui_print " "

# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " ID=$MODID"
ui_print " Version=$MODVER"
ui_print " VersionCode=$MODVERCODE"
if [ "$KSU" == true ]; then
  ui_print " KSUVersion=$KSU_VER"
  ui_print " KSUVersionCode=$KSU_VER_CODE"
  ui_print " KSUKernelVersionCode=$KSU_KERNEL_VER_CODE"
else
  ui_print " MagiskVersion=$MAGISK_VER"
  ui_print " MagiskVersionCode=$MAGISK_VER_CODE"
fi
ui_print " "

# huskydg function
get_device() {
PAR="$1"
DEV="`cat /proc/self/mountinfo | awk '{ if ( $5 == "'$PAR'" ) print $3 }' | head -1 | sed 's/:/ /g'`"
}
mount_mirror() {
SRC="$1"
DES="$2"
RAN="`head -c6 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9'`"
while [ -e /dev/$RAN ]; do
  RAN="`head -c6 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9'`"
done
mknod /dev/$RAN b `get_device "$SRC"; echo $DEV`
if mount -t ext4 -o ro /dev/$RAN "$DES"\
|| mount -t erofs -o ro /dev/$RAN "$DES"\
|| mount -t f2fs -o ro /dev/$RAN "$DES"\
|| mount -t ubifs -o ro /dev/$RAN "$DES"; then
  blockdev --setrw /dev/$RAN
  rm -f /dev/$RAN
  return 0
fi
rm -f /dev/$RAN
return 1
}
unmount_mirror() {
DIRS="$MIRROR/system_root $MIRROR/system $MIRROR/vendor
      $MIRROR/product $MIRROR/system_ext $MIRROR/odm
      $MIRROR/my_product $MIRROR"
for DIR in $DIRS; do
  umount $DIR
done
}
mount_partitions_to_mirror() {
unmount_mirror
# mount system
if [ "$SYSTEM_ROOT" == true ]; then
  DIR=/system_root
  ui_print "- Mount $MIRROR$DIR..."
  mkdir -p $MIRROR$DIR
  if mount_mirror / $MIRROR$DIR; then
    ui_print "  $MIRROR$DIR mount success"
    rm -rf $MIRROR/system
    ln -sf $MIRROR$DIR/system $MIRROR
    ls $MIRROR$DIR
  else
    ui_print "  ! $MIRROR$DIR mount failed"
    rm -rf $MIRROR$DIR
  fi
else
  DIR=/system
  ui_print "- Mount $MIRROR$DIR..."
  mkdir -p $MIRROR$DIR
  if mount_mirror $DIR $MIRROR$DIR; then
    ui_print "  $MIRROR$DIR mount success"
    ls $MIRROR$DIR
  else
    ui_print "  ! $MIRROR$DIR mount failed"
    rm -rf $MIRROR$DIR
  fi
fi
ui_print " "
# mount vendor
DIR=/vendor
ui_print "- Mount $MIRROR$DIR..."
mkdir -p $MIRROR$DIR
if mount_mirror $DIR $MIRROR$DIR; then
  ui_print "  $MIRROR$DIR mount success"
  ls $MIRROR$DIR
else
  ui_print "  ! $MIRROR$DIR mount failed"
  rm -rf $MIRROR$DIR
  ln -sf $MIRROR/system$DIR $MIRROR
fi
ui_print " "
# mount product
DIR=/product
ui_print "- Mount $MIRROR$DIR..."
mkdir -p $MIRROR$DIR
if mount_mirror $DIR $MIRROR$DIR; then
  ui_print "  $MIRROR$DIR mount success"
  ls $MIRROR$DIR
else
  ui_print "  ! $MIRROR$DIR mount failed"
  rm -rf $MIRROR$DIR
  ln -sf $MIRROR/system$DIR $MIRROR
fi
ui_print " "
# mount system_ext
DIR=/system_ext
ui_print "- Mount $MIRROR$DIR..."
mkdir -p $MIRROR$DIR
if mount_mirror $DIR $MIRROR$DIR; then
  ui_print "  $MIRROR$DIR mount success"
  ls $MIRROR$DIR
else
  ui_print "  ! $MIRROR$DIR mount failed"
  rm -rf $MIRROR$DIR
  if [ -d $MIRROR/system$DIR ]; then
    ln -sf $MIRROR/system$DIR $MIRROR
  fi
fi
ui_print " "
# mount odm
DIR=/odm
ui_print "- Mount $MIRROR$DIR..."
mkdir -p $MIRROR$DIR
if mount_mirror $DIR $MIRROR$DIR; then
  ui_print "  $MIRROR$DIR mount success"
  ls $MIRROR$DIR
else
  ui_print "  ! $MIRROR$DIR mount failed"
  rm -rf $MIRROR$DIR
  if [ -d $MIRROR/system_root$DIR ]; then
    ln -sf $MIRROR/system_root$DIR $MIRROR
  fi
fi
ui_print " "
# mount my_product
DIR=/my_product
ui_print "- Mount $MIRROR$DIR..."
mkdir -p $MIRROR$DIR
if mount_mirror $DIR $MIRROR$DIR; then
  ui_print "  $MIRROR$DIR mount success"
  ls $MIRROR$DIR
else
  ui_print "  ! $MIRROR$DIR mount failed"
  rm -rf $MIRROR$DIR
  if [ -d $MIRROR/system_root$DIR ]; then
    ln -sf $MIRROR/system_root$DIR $MIRROR
  fi
fi
ui_print " "
}

# magisk
MAGISKPATH=`magisk --path`
if [ "$BOOTMODE" == true ]; then
  if [ "$MAGISKPATH" ]; then
    MAGISKTMP=$MAGISKPATH/.magisk
    MIRROR=$MAGISKTMP/mirror
  else
    MAGISKTMP=/mnt
    MIRROR=$MAGISKTMP/mirror
    mount_partitions_to_mirror
  fi
fi

# path
SYSTEM=`realpath $MIRROR/system`
PRODUCT=`realpath $MIRROR/product`
VENDOR=`realpath $MIRROR/vendor`
SYSTEM_EXT=`realpath $MIRROR/system_ext`
if [ -d $MIRROR/odm ]; then
  ODM=`realpath $MIRROR/odm`
else
  ODM=`realpath /odm`
fi
if [ -d $MIRROR/my_product ]; then
  MY_PRODUCT=`realpath $MIRROR/my_product`
else
  MY_PRODUCT=`realpath /my_product`
fi

# optionals
OPTIONALS=/sdcard/optionals.prop
if [ ! -f $OPTIONALS ]; then
  touch $OPTIONALS
fi

# architecture
if [ "$ARCH" == arm64 ] || [ "$ARCH" == arm ]; then
  ui_print "- Architecture $ARCH"
  ui_print " "
else
  ui_print "! Unsupported architecture $ARCH. This module is only for"
  ui_print "  arm64 or arm architecture."
  abort
fi

# bit
if [ "$IS64BIT" != true ]; then
  rm -rf `find $MODPATH/system -type d -name *64`
fi

# sdk
NUM=30
NUM2=31
if [ "$API" -lt $NUM ]; then
  ui_print "! Unsupported SDK $API. You have to upgrade your Android"
  ui_print "  version at least SDK API $NUM to use this module."
  ui_print "  Use Moto Waves G 5G Plus instead!"
  abort
else
  if [ "$API" -gt $NUM2 ]; then
    ui_print "! Unsupported SDK $API. This module is only for SDK API"
    ui_print "  $NUM2 and $NUM."
  else
    ui_print "- SDK $API"
  fi
  if [ "$API" -ge $NUM2 ]; then
    cp -rf $MODPATH/system_12/* $MODPATH/system
  fi
fi
ui_print " "
rm -rf $MODPATH/system_12

# mount
if [ "$BOOTMODE" != true ]; then
  if [ -e /dev/block/bootdevice/by-name/vendor ]; then
    mount -o rw -t auto /dev/block/bootdevice/by-name/vendor /vendor
  else
    mount -o rw -t auto /dev/block/bootdevice/by-name/cust /vendor
  fi
  mount -o rw -t auto /dev/block/bootdevice/by-name/persist /persist
  mount -o rw -t auto /dev/block/bootdevice/by-name/metadata /metadata
fi

# sepolicy
FILE=$MODPATH/sepolicy.rule
DES=$MODPATH/sepolicy.pfsd
if [ "`grep_prop sepolicy.sh $OPTIONALS`" == 1 ]\
&& [ -f $FILE ]; then
  mv -f $FILE $DES
fi

# motocore
if [ ! -d /data/adb/modules_update/MotoCore ]\
&& [ ! -d /data/adb/modules/MotoCore ]; then
  ui_print "- This module requires Moto Core Magisk Module installed"
  ui_print "  except you are in Motorola ROM."
  ui_print "  Please read the installation guide!"
  ui_print " "
else
  rm -f /data/adb/modules/MotoCore/remove
  rm -f /data/adb/modules/MotoCore/disable
fi

# .aml.sh
mv -f $MODPATH/aml.sh $MODPATH/.aml.sh

# function
extract_lib() {
for APPS in $APP; do
  FILE=`find $MODPATH/system -type f -name $APPS.apk`
  if [ -f `dirname $FILE`/extract ]; then
    rm -f `dirname $FILE`/extract
    ui_print "- Extracting..."
    DIR=`dirname $FILE`/lib/$ARCH
    mkdir -p $DIR
    rm -rf $TMPDIR/*
    DES=lib/"$ABI"/*
    unzip -d $TMPDIR -o $FILE $DES
    cp -f $TMPDIR/$DES $DIR
    ui_print " "
  fi
done
}

# extract
APP=MotoWavesV2
extract_lib

# extract
APP=WavesServiceV2
ABI=armeabi-v7a
ARCH=arm
extract_lib

# function
check_function() {
ui_print "- Checking"
ui_print "$NAME"
ui_print "  function at"
ui_print "$FILE"
ui_print "  Please wait..."
if ! grep -Eq $NAME $FILE; then
  ui_print "! Function not found. Use Moto Waves G 5G Plus instead!"
  abort
fi
ui_print " "
}

# check
NAME=_ZN7android23sp_report_stack_pointerEv
if [ "$API" -ge 31 ]; then
  TARGET=libandroidaudioeffect_Android12.so
else
  TARGET=libandroidaudioeffect_Android11Plus.so
fi
LISTS=`strings $MODPATH/system/priv-app/WavesServiceV2/lib/arm/$TARGET | grep ^lib | grep .so | sed "s/$TARGET//" | sed 's/libc++_shared.so//'`
FILE=`for LIST in $LISTS; do echo $SYSTEM/lib/$LIST; done`
check_function

# config
if [ "`grep_prop waves.config $OPTIONALS`" == pstar ]; then
  ui_print "- Using Moto Waves Edge 30 Pro (pstar) config"
  cp -rf $MODPATH/system_pstar/* $MODPATH/system
  ui_print " "
elif [ "`grep_prop waves.config $OPTIONALS`" == nairo ]; then
  ui_print "- Using Moto Waves G 5G Plus (nairo) config"
  cp -rf $MODPATH/system_nairo/* $MODPATH/system
  ui_print " "
elif [ "`grep_prop waves.config $OPTIONALS`" == racer ]; then
  ui_print "- Using Moto Waves Edge (racer) config"
  cp -rf $MODPATH/system_racer/* $MODPATH/system
  ui_print " "
fi
rm -rf $MODPATH/system_pstar
rm -rf $MODPATH/system_nairo
rm -rf $MODPATH/system_racer

# mod ui
if [ "`grep_prop mod.ui $OPTIONALS`" == 1 ]; then
  APP=MotoWavesV2
  FILE=/sdcard/$APP.apk
  DIR=`find $MODPATH/system -type d -name $APP`
  ui_print "- Using modified UI apk..."
  if [ -f $FILE ]; then
    cp -f $FILE $DIR
    chmod 0644 $DIR/$APP.apk
    ui_print "  Applied"
  else
    ui_print "  ! There is no $FILE file."
    ui_print "    Please place the apk to your internal storage first"
    ui_print "    and reflash!"
  fi
  ui_print " "
fi

# cleaning
ui_print "- Cleaning..."
PKG=`cat $MODPATH/package.txt`
if [ "$BOOTMODE" == true ]; then
  for PKGS in $PKG; do
    RES=`pm uninstall $PKGS 2>/dev/null`
  done
fi
rm -rf /metadata/magisk/$MODID
rm -rf /mnt/vendor/persist/magisk/$MODID
rm -rf /persist/magisk/$MODID
rm -rf /data/unencrypted/magisk/$MODID
rm -rf /cache/magisk/$MODID
ui_print " "

# power save
FILE=$MODPATH/system/etc/sysconfig/*
if [ "`grep_prop power.save $OPTIONALS`" == 1 ]; then
  ui_print "- $MODNAME will not be allowed in power save."
  ui_print "  It may save your battery but decreasing $MODNAME performance."
  for PKGS in $PKG; do
    sed -i "s/<allow-in-power-save package=\"$PKGS\"\/>//g" $FILE
    sed -i "s/<allow-in-power-save package=\"$PKGS\" \/>//g" $FILE
  done
  ui_print " "
fi

# function
cleanup() {
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
DIR=/data/adb/modules_update/$MODID
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
}

# cleanup
DIR=/data/adb/modules/$MODID
FILE=$DIR/module.prop
if [ "`grep_prop data.cleanup $OPTIONALS`" == 1 ]; then
  sed -i 's/^data.cleanup=1/data.cleanup=0/' $OPTIONALS
  ui_print "- Cleaning-up $MODID data..."
  cleanup
  ui_print " "
elif [ -d $DIR ] && ! grep -Eq "$MODNAME" $FILE; then
  ui_print "- Different version detected"
  ui_print "  Cleaning-up $MODID data..."
  cleanup
  ui_print " "
fi

# function
permissive_2() {
sed -i '1i\
SELINUX=`getenforce`\
if [ "$SELINUX" == Enforcing ]; then\
  magiskpolicy --live "permissive *"\
fi\' $MODPATH/post-fs-data.sh
}
permissive() {
SELINUX=`getenforce`
if [ "$SELINUX" == Enforcing ]; then
  setenforce 0
  SELINUX=`getenforce`
  if [ "$SELINUX" == Enforcing ]; then
    ui_print "  Your device can't be turned to Permissive state."
    ui_print "  Using Magisk Permissive mode instead."
    permissive_2
  else
    setenforce 1
    sed -i '1i\
SELINUX=`getenforce`\
if [ "$SELINUX" == Enforcing ]; then\
  setenforce 0\
fi\' $MODPATH/post-fs-data.sh
  fi
fi
}

# permissive
if [ "`grep_prop permissive.mode $OPTIONALS`" == 1 ]; then
  ui_print "- Using device Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive
  ui_print " "
elif [ "`grep_prop permissive.mode $OPTIONALS`" == 2 ]; then
  ui_print "- Using Magisk Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive_2
  ui_print " "
fi

# function
hide_oat() {
for APPS in $APP; do
  export REPLACE="$REPLACE
  `find $MODPATH/system -type d -name $APPS | sed "s|$MODPATH||"`/oat"
done
}
replace_dir() {
if [ -d $DIR ]; then
  export REPLACE="$REPLACE
  $MODDIR"
fi
}
hide_app() {
DIR=$SYSTEM/app/$APPS
MODDIR=/system/app/$APPS
replace_dir
DIR=$SYSTEM/priv-app/$APPS
MODDIR=/system/priv-app/$APPS
replace_dir
DIR=$PRODUCT/app/$APPS
MODDIR=/system/product/app/$APPS
replace_dir
DIR=$PRODUCT/priv-app/$APPS
MODDIR=/system/product/priv-app/$APPS
replace_dir
DIR=$MY_PRODUCT/app/$APPS
MODDIR=/system/product/app/$APPS
replace_dir
DIR=$MY_PRODUCT/priv-app/$APPS
MODDIR=/system/product/priv-app/$APPS
replace_dir
DIR=$PRODUCT/preinstall/$APPS
MODDIR=/system/product/preinstall/$APPS
replace_dir
DIR=$SYSTEM_EXT/app/$APPS
MODDIR=/system/system_ext/app/$APPS
replace_dir
DIR=$SYSTEM_EXT/priv-app/$APPS
MODDIR=/system/system_ext/priv-app/$APPS
replace_dir
DIR=$VENDOR/app/$APPS
MODDIR=/system/vendor/app/$APPS
replace_dir
DIR=$VENDOR/euclid/product/app/$APPS
MODDIR=/system/vendor/euclid/product/app/$APPS
replace_dir
}

# hide
APP="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
hide_oat
APP="MusicFX MotoWaves WavesService"
for APPS in $APP; do
  hide_app
done

# stream mode
FILE=$MODPATH/.aml.sh
PROP=`grep_prop stream.mode $OPTIONALS`
if echo "$PROP" | grep -Eq m; then
  ui_print "- Activating music stream..."
  sed -i 's/#m//g' $FILE
  sed -i 's/musicstream=/musicstream=true/g' $MODPATH/acdb.conf
  ui_print " "
else
  APP=AudioFX
  for APPS in $APP; do
    hide_app
  done
fi
if echo "$PROP" | grep -Eq r; then
  ui_print "- Activating ring stream..."
  sed -i 's/#r//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq a; then
  ui_print "- Activating alarm stream..."
  sed -i 's/#a//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq s; then
  ui_print "- Activating system stream..."
  sed -i 's/#s//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq v; then
  ui_print "- Activating voice_call stream..."
  sed -i 's/#v//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq n; then
  ui_print "- Activating notification stream..."
  sed -i 's/#n//g' $FILE
  ui_print " "
fi

# check
NAME=libadspd.so
APP=MotoWavesV2
DIR=`find $MODPATH/system -type d -name $APP`/lib/arm
cp -f $SYSTEM/lib/$NAME $DIR
cp -f $VENDOR/lib/$NAME $DIR
cp -f $ODM/lib/$NAME $DIR
if [ "$IS64BIT" == true ]; then
  DIR=`find $MODPATH/system -type d -name $APP`/lib/arm64
  cp -f $SYSTEM/lib64/$NAME $DIR
  cp -f $VENDOR/lib64/$NAME $DIR
  cp -f $ODM/lib64/$NAME $DIR
fi

# check
NAME=libc++_shared.so
for NAMES in $NAME; do
  FILE=$VENDOR/lib/$NAMES
  if [ -f $FILE ]; then
    ui_print "- Detected $NAMES"
    ui_print " "
    rm -f $MODPATH/system/vendor/lib/$NAMES
  fi
done

# audio rotation
FILE=$MODPATH/service.sh
if [ "`grep_prop audio.rotation $OPTIONALS`" == 1 ]; then
  ui_print "- Activating ro.audio.monitorRotation=true"
  sed -i '1i\
resetprop ro.audio.monitorRotation true' $FILE
  ui_print " "
fi

# raw
FILE=$MODPATH/.aml.sh
if [ "`grep_prop disable.raw $OPTIONALS`" == 0 ]; then
  ui_print "- Not disabling Ultra Low Latency playback (RAW)"
  ui_print " "
else
  sed -i 's/#u//g' $FILE
fi

# permission
ui_print "- Setting permission..."
DIR=`find $MODPATH/system/vendor -type d`
for DIRS in $DIR; do
  chown 0.2000 $DIRS
done
ui_print " "

# unmount
if [ "$BOOTMODE" == true ] && [ ! "$MAGISKPATH" ]; then
  unmount_mirror
fi
















