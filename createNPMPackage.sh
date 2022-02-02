#!/bin/bash
set -e
set -x

ROOT=$(pwd)

unset CI

versions=("0.67.2" "0.66.3" "0.65.1" "0.64.2" "0.63.3")
rnv8_versions=("0.67.2-patch.0" "0.66.3-patch.1" "v0.65.2-patch.1" "0.64.2-patch.1" "0.63.3-patch.0" )
version_name=("67" "66" "65" "64" "63")

for index in {0..2}
do
  yarn add react-native@"${versions[$index]}"
  for js_runtime in "hermes" "jsc" "v8"
  do
    echo "js_runtime=${js_runtime}"

    if [ "${js_runtime}" == "v8" ]; then
      yarn add react-native-v8@"${rnv8_versions[$index]}"
      cp -Rf node_modules/react-native-v8/src/v8runtime node_modules/react-native/ReactCommon/jsi/jsi/
    fi

    cd android

    echo "APPLY PATCH"
    versionNumber=${version_name[$index]}
    cd ./rnVersionPatch/$versionNumber
    rm -rf ../backup/*
    cp -r . ../backup
    if [ "$(find . | grep 'java')" ];
    then
      fileList=$(find . | grep -i 'java')
      for file in $fileList; do
        echo "COPY: $file"
        cp ../../src/main/java/com/swmansion/reanimated/$file ../backup/$file
        cp $file ../../src/main/java/com/swmansion/reanimated/$file
      done
    else
    pwd
      echo "NO PATCH";
    fi
    cd ../..

    ./gradlew clean

    JS_RUNTIME=${js_runtime} ./gradlew :assembleDebug

    cd ./rnVersionPatch/$versionNumber
    if [ $(find . | grep 'java') ];
    then
      echo "RESTORE BACKUP"
      for file in $fileList; do
        echo "BACKUP: $file"
        cp ../backup/$file ../../src/main/java/com/swmansion/reanimated/$file
      done
      echo "CLEAR BACKUP"
      rm -rf ../backup/*
    fi
    cd ../..

    cd $ROOT

    rm -rf android-npm/react-native-reanimated-"${version_name[$index]}-${js_runtime}".aar
    cp android/build/outputs/aar/*.aar android-npm/react-native-reanimated-"${version_name[$index]}-${js_runtime}".aar

    if [ "${js_runtime}" == "v8" ]; then
      yarn remove react-native-v8
    fi
  done
done

rm -rf libSo
mkdir libSo
cd libSo
mkdir fbjni
cd fbjni
wget https://repo1.maven.org/maven2/com/facebook/fbjni/fbjni/0.2.2/fbjni-0.2.2.aar
unzip fbjni-0.2.2.aar
rm -r $(find . ! -name '.' ! -name 'jni' -maxdepth 1)
rm $(find . -name '*libc++_shared.so')
cd ../..

yarn add react-native@0.67.2 --dev

mv android android-temp
mv android-npm android

yarn run type:generate

npm pack

mv android android-npm
mv android-temp android

rm -rf ./libSo
rm -rf ./lib
rm -rf ./android/rnVersionPatch/backup/*
touch ./android/rnVersionPatch/backup/.gitkeep

echo "Done!"
