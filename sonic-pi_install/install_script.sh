#!/bin/bash

#TODO: FIGURE OUT WHERE SUDO IS TRULY NEEDED

#fail script on first error encountered
set -e

#application/library versions built by this script
SP_COMMIT=1cb29cc7157b91de966693aed71cdee746bec157 #commit that work will be done with.
SUPERCOLLIDER_VERSION=3.11.0 #try '3.10.4' if doesn't work
SC_PLUGINS_VERSION=3.10.0
#AUBIO_VERSION= #now included w/ sonic-pi
#OSMID_VERSION= #now included w/ sonic-pi

#internal definitions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#SP_APP_SRC=${SCRIPT_DIR}
SP_ROOT=${SCRIPT_DIR} #script running from project's root directory
#SP_ROOT=${SP_APP_SRC}/../../../../
SP_APP_SRC=${SP_ROOT}/sonic-pi/app/gui/qt/ #script running from project's root directory
#OSMID_DIR=${SP_APP_SRC}/../../server/native/osmid/ #unix-prebuild.sh takes care of this

#TODO: test the distribution for the raspi's and make sure they're up-to-date

sudo apt-get update #-y?
sudo apt-get dist-upgrade #-y?
sudo apt-get install -y sofware-properties-common
sudo apt-get install -y libjack-jackd2-dev cmake erlang-base

#install ruby v2.6.5
cd ${SP_ROOT}
git clone https://github.com/ruby/ruby.git ./ruby-2.6.5
cd ./ruby-2.6.5
git checkout v2_6_5
./configure --prefix='/usr/' #instead of '/usr/local/'; sudo and --prefix='' for root installation?
make #sudo?
make update-gems #needed? sudo?
make extract-gems #needed? sudo?
sudo make install

#TODO: insert bash script check for ruby and gem versions
cd ${SP_ROOT}
sudo gem install ruby-dev
sudo gem install bundler

#not included in current git repo, but will try to install without to test:
#sudo apt-get install -y libasound2-dev libavahi-client-dev libicu-dev libreadline6-dev libudev-dev libqwt-qt5-dev libqt5scintilla2-dev libqt5svg5-dev qt5-qmake qt5-default qttools5-dev qttoold5-dev-tools qtdeclarative5-dev libqt5webkit5-dev qtpositioning5-dev libqt5sensors5-dev qtmultimedia5-dev libqt5opengl5-dev

#download sonic-pi
cd ${SP_ROOT}
git clone https://github.com/samaaron/sonic-pi.git ${SP_ROOT}/sonic-pi/ #use ${SP_ROOT} instead of .?
cd ${SP_ROOT}/sonic-pi/ #use ${SP_ROOT} instead of .?
git checkout ${SP_COMMIT}

#download and build, install supercollider
cd ${SP_ROOT}
git clone https://github.com/supercollider/supercollider.git ${SP_ROOT}/supercollider/
cd ${SP_ROOT}/supercollider/
git checkout Version-${SUPERCOLLIDER_VERSION}
git submodule init && git submodule update
mkdir -p build
cd build
#TODO: test if sudoing next line changes the directory vars its installed to
cmake -DSC_EL=no .. #find flag to change to root directories? maybe just sudo?
make
sudo make install #is there a way to get to install to /usr/ and not /usr/local?
#this should install to /usr/local

#download and build, install sc3-plugins
cd ${SP_ROOT}
git clone https://github.com/supercollider/sc3-plugins.git ${SP_ROOT}/sc3-plugins/
cd ${SP_ROOT}/sc3-plugins/
git checkout Version-${SC_PLUGINS_VERSION}
git submodule init && git submodule update
cp -r external_libraries/nova-simd/* source/VBAPUGens
mkdir -p build
cd build
cmake -DSC_PATH=/usr/local/include/SuperCollider -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release .. #change if got supercollider installed to /usr/ or / instead of /usr/local/
make
sudo make install

#TODO: make changes to interception files and push??
#in /interception/ext/interception.c: '#elif RUBY_19' -> '#elif RUBY_19 || RUBY_26'
#in /interception/ext/extconf.rb: '.../^ruby/ && RUBY_VERSION.to_f < 2.0' ->
#'.../^ruby/', '.../^(1.9)/\nputs("...' -> .../^(1.9)/\n$CFLAGS += " -DRUBY_26" if 
#RUBY_VERSION =~ /^(2.6)/\nputs("...'
#use sed like below to make changes to interception's files?
cd ${SP_APP_SRC}/../../server/ruby/vendors/interception/ext/
mv ./interception.c ./interception_old.c
cp ${SP_ROOT}/interception.txt ./interception.c
mv ./extconf.rb ./extconf_old.rb
cp ${SP_ROOT}/extconf.txt ./extconf.rb

#unix-prebuild.sh now builds aubio w/ arg '--build-aubio', builds gui externals, places osmid files,
#places an aubio .so in /server/native/lib, runs compile_extensions.rb, compiles erlang files (NOTE:
#no longer checks for 'nanosecond' issue / for older erlang version), and the usual tutorial
#translations and docs creation.  should still do the erlang check before calling the script.

cd ${SP_APP_SRC}/../../server/erlang
ERLANG_VERSION=$(./print_erlang_version) #should type script here in case file gets deleted, sudo?
if [[ "${ERLANG_VERSION}" < "19.1" ]]; then
    cp ./osc.erl ./osc.erl.orig
    echo "Found Erlang version < 19.1 (${ERLANG_VERSION})! Updating source code."
    sed -i.orig 's|erlang:system_time(nanosecond)|erlang:system_time(nano_seconds)|' osc.erl
    #rm ./osc.erl.orig
fi

cd ${SP_APP_SRC}
#does /externals/unix_build_externals.sh build the other libs if i don't have them (e.g. boost, opus)?
./unix-prebuild.sh --build-aubio

./unix-config.sh

cd ${SP_APP_SRC}/build
#will this include things needed from /externals/ if you don't have them?
#should you call from SP_APP_SRC? or just call make in SP_APP_SRC?
make

#do you call a 'sudo make install' after this?  would doing this solve privilege issues
#since you would be installing it within superuser?
#sudo make install #???
