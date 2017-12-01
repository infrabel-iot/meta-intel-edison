#!/bin/bash

# Copyright(c) 2013 Intel Corporation. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# fabien.chereau@intel.com

set -e

# Branch and Tag to fetch from the yoctoproject.org upstream repository.
yocto_branch="pyro"
yocto_tag="pyro"

# The conf directory get's cleaned out with 'make setup' which deletes your changes
# Instead we make a link to conf files in the the top repo dir. 
# To make your changes permanent, # edit the file in the top repo dir and commit.
# To make temporary changes delete the link and cp the file to conf, then edit the conf.
# To restore, delete the changed file, then run 'make update'
do_local_conf () {
if [ ! -f $yocto_conf_dir/local.conf ]; then
  ln -s $top_repo_dir/meta-intel-edison/local.conf $yocto_conf_dir/local.conf
fi
}

do_initramfs_conf () {
if [ ! -f $yocto_conf_dir/initramfs.conf ]; then
  ln -s $top_repo_dir/meta-intel-edison/initramfs.conf $yocto_conf_dir/initramfs.conf
fi
}

do_u-boot_conf () {
if [ ! -f $yocto_conf_dir/u-boot.conf ]; then
  ln -s $top_repo_dir/meta-intel-edison/u-boot.conf $yocto_conf_dir/u-boot.conf
fi
}


do_append_layer (){
  if [[ $extra_layers == \\ ]]; then
    extra_layers="$1 \\"
  else
    extra_layers+=$'\n'
    extra_layers+="  $1 \\"
  fi
}

extra_layers="\\"

do_bblayers_conf () {
  cat > $yocto_conf_dir/bblayers.conf <<EOF
# LAYER_CONF_VERSION is increased each time build/conf/bblayers.conf
# changes incompatibly
LCONF_VERSION = "6"

BBPATH = "\${TOPDIR}"
BBFILES ?= ""
BBLAYERS ?= " \\
  $poky_dir/meta \\
  $poky_dir/meta-poky \\
  $poky_dir/meta-yocto-bsp \\
  $poky_dir/meta-openembedded/meta-oe \\
  $poky_dir/meta-openembedded/meta-python \\
  $poky_dir/meta-openembedded/meta-networking \\
  $poky_dir/meta-nodejs \\
  $top_repo_dir/meta-intel-edison/meta-intel-edison-bsp \\
  $top_repo_dir/meta-intel-edison/meta-intel-edison-distro \\
  $top_repo_dir/meta-intel-edison/meta-intel-iot-middleware \\
  $extra_layers
  "
BBLAYERS_NON_REMOVABLE ?= " \\
  $poky_dir/meta \\
  $poky_dir/meta-poky \\
  "
EOF
# we might want to add these back later
#  $top_repo_dir/meta-intel-edison/meta-intel-arduino \\
#  $top_repo_dir/meta-arduino \\
}

function check_path()
{
  if [ "${VALUE:0:1}" = "~" ]; then
    echo "ERROR: '~' not allowed in directory path"
    usage
    exit 1
  fi
  if [ ! -d "$VALUE" ]; then
    echo "ERROR: '$VALUE' directory does not exist"
    usage
    exit 1
  fi
}

function usage()
{
  echo "Setup build environment for building the Edison Device Software"
  echo ""
  echo "./setup.sh"
  echo -e "\t-h --help\t\t\tdisplay this help and exit"
  echo -e "\t--dl_dir=$my_dl_dir\tdefine the directory (absolute path) where bitbake places downloaded files"
  echo -e "\t--sstate_dir=$my_sstate_dir\tdefine the directory (absolute path) where bitbake places shared-state files"
  echo -e "\t--bb_number_thread=$my_bb_number_thread\t\tdefine how many tasks bitbake should run in parallel"
  echo -e "\t--parallel_make=$my_parallel_make\t\tdefine how many processes make should run in parallel when running compile tasks"
  echo -e "\t--build_name=$my_build_name\t\tdefines custom build name which can then be retrieved on a running linux in /etc/version"
  echo -e "\t--sdk_host=$my_sdk_host\t\tchoose host machine on which the generated SDK and cross compiler will be run. Must be one of [$all_sdk_hosts]"
  echo -e "\t-l --list_sdk_hosts\t\tlist availables sdk host supported machines"
  echo -e "\t--create_src_archive\t\twhen set, copies sources of all deployed packages into build/tmp/deploy/sources"
  echo -e "\t--ipk_packages\t\twhen set, use .ipk package format instead of .deb"
  echo ""
}

# do_update_cache function: update git yoctoproject repository or clone it if
# it does not exist.
# $1: name of the repository to clone.
#
# 1- test if there is a git repo in cache
# if yes
# 2- update it
# if no
# 2b- clone it from upstream
#
do_update_cache () {
  # save local path
  my_position=$(pwd)
  if [ ! -d "${my_dl_dir}" ]; then
    # directory does not exist, create it
    mkdir -p ${my_dl_dir}
  fi

  cd $my_dl_dir
  if [ -d "$1-mirror.git" ]; then
    cd $1-mirror.git
    # Verify we are in a git repository
    # $? == 0 if git repo
    # $? != 0 if not git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1 ; then
      echo "Error: ${my_dl_dir}/$1-mirror.git is not a git repository!"
      echo "You can remove it manually with:"
      echo "rm -rf ${my_dl_dir}/$1-mirror.git"
      echo "Exiting..."
      exit 1
    fi
    # The repo already exists. Just pull.
    git remote update
  else
    # The repo does not exist. Clone it.
    git clone --mirror $2/$1.git $1-mirror.git
  fi
  cd $my_position

}

main() {
  top_repo_dir=$(dirname $(dirname $(readlink -f $0)))
  my_dl_dir="$top_repo_dir/bbcache/downloads"
  my_sstate_dir="$top_repo_dir/bbcache/sstate-cache"
  my_bb_number_thread=4
  my_parallel_make=8
  my_build_name="Custom Edison build by $USER@$HOSTNAME "$(date +"%F %H:%M:%S %Z")
  all_sdk_hosts="linux32 linux64 win32 win64 macosx"
  extra_package_type="package_deb"

  #probe my_sdk_host from uname
  plat=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
    i?86) arch="32" ;;
    x86_64) arch="64" ;;
    *) arch="unknow" ;;
  esac
  my_sdk_host="$plat$arch"

  my_build_dir="$top_repo_dir/out/$my_sdk_host"

  while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
      -h | --help)
        usage
        exit
        ;;
      --create_src_archive)
        extra_archiving="INHERIT += \"archiver\"
ARCHIVER_MODE[src] = \"original\"
COPYLEFT_LICENSE_INCLUDE = 'GPL* LGPL*'
"
        ;;
      --ipk_packages)
        extra_package_type="package_ipk"
        ;;
      --dl_dir)
        check_path
        my_dl_dir=$(readlink -f "$VALUE")
        ;;
      --sstate_dir)
        check_path
        my_sstate_dir=$(readlink -f "$VALUE")
        ;;
      --bb_number_thread)
        my_bb_number_thread=$VALUE
        ;;
      --parallel_make)
        my_parallel_make=$VALUE
        ;;
      --build_name)
        my_build_name=$VALUE
        ;;
      --build_dir)
        my_build_dir=$VALUE
        ;;
      -l | --list_sdk_hosts)
        echo $all_sdk_hosts
        exit
        ;;
      --sdk_host)
        my_sdk_host=$VALUE
        ;;
      *)
      echo "ERROR: unknown parameter \"$PARAM\""
      usage
      exit 1
      ;;
    esac
    shift
  done

  if [ ! -d $my_build_dir ]; then
    mkdir -p $my_build_dir
  fi

  if [ -d "$top_repo_dir/meta-intel-edison-devtools" ]; then
    echo "Found a development tools layer, adding it to Edison list of layers"
    echo "Note that none of the recipes provided by this layer is compiled by default."
    do_append_layer $top_repo_dir/meta-intel-edison-devtools
  fi

  case $my_sdk_host in
    win32)
      extra_conf="SDKMACHINE = \"i686-mingw32\""
      ;;
    win64)
      extra_conf="SDKMACHINE = \"x86_64-mingw32\""
      ;;
    macosx)
      extra_conf="SDKMACHINE = \"i386-darwin\""
      ;;
    linux32)
      extra_conf="SDKMACHINE = \"i686\""
      ;;
    linux64)
      extra_conf="SDKMACHINE = \"x86_64\""
      ;;
    *)
      echo "Unknow host: $my_sdk_host chooses one in [$all_sdk_hosts]"
      exit
      ;;
  esac

  # Updating local git cache
  do_update_cache "poky" "git://git.yoctoproject.org"
  do_update_cache "meta-openembedded" "https://github.com/openembedded"
  do_update_cache "meta-nodejs" "https://github.com/imyller"
  do_update_cache "meta-mingw" "git://git.yoctoproject.org"
  do_update_cache "meta-darwin" "git://git.yoctoproject.org"

  cd $my_build_dir
  poky_dir=$my_build_dir/poky
  echo "Cloning Poky in the $poky_dir directory"
  rm -rf $poky_dir

  git clone -b ${yocto_branch} ${my_dl_dir}/poky-mirror.git poky
  cd $poky_dir
  git checkout ${yocto_tag}

  mingw_dir=$poky_dir/meta-mingw
  echo "Cloning Mingw layer to ${mingw_dir} directory from local cache"
  git clone -b ${yocto_branch} ${my_dl_dir}/meta-mingw-mirror.git meta-mingw

  darwin_dir=$poky_dir/meta-darwin
  echo "Cloning Darwin layer to ${darwin_dir} directory from local cache"
  git clone ${my_dl_dir}/meta-darwin-mirror.git meta-darwin
  cd ${darwin_dir}
  git checkout 29b5ff31cee24e796f2eb2d2fd1269e3e92c831c
  git apply $top_repo_dir/meta-intel-edison/utils/0001-Update-gcc-patch.patch

  cd $poky_dir
  oe_dir=$poky_dir/meta-openembedded
  echo "Cloning Openembedded layer to ${oe_dir} directory from local cache"
  git clone ${my_dl_dir}/meta-openembedded-mirror.git meta-openembedded
  cd ${oe_dir}
  git checkout pyro
  
  cd $poky_dir
  oe_dir=$poky_dir/meta-nodejs
  echo "Cloning Nodejs layer to ${oe_dir} directory from local cache"
  git clone ${my_dl_dir}/meta-nodejs-mirror.git meta-nodejs
  cd ${oe_dir}
  git checkout master

  cd ${top_repo_dir}
  echo "Cloning meta-arduino layer to ${top_repo_dir} directory from GitHub.com/01org/meta-arduino"
  rm -rf meta-arduino || true
  git clone -b 1.6.x https://github.com/01org/meta-arduino.git
  cd meta-arduino
  git checkout 1.6.x

  # Apply patch on top of it allowing to perform build in external source directory
  echo "Applying patch on poky"
  cd $mingw_dir
  git apply $top_repo_dir/meta-intel-edison/utils/0001-Revert-machine-sdk-mingw32.conf-Disable-SDKTAROPTS.patch
  cd $poky_dir

  if [[ $my_sdk_host == win* ]]
  then
    do_append_layer $mingw_dir
  fi

  if [[ $my_sdk_host == macosx ]]
  then
    do_append_layer $darwin_dir
  fi

  yocto_conf_dir=$my_build_dir/build/conf

  echo "Setting up yocto configuration file (in build/conf/local.conf)"
  do_bblayers_conf
  do_local_conf
  do_initramfs_conf
  do_u-boot_conf

  echo "Initializing yocto build environment"
  source oe-init-build-env $my_build_dir/build > /dev/null

  echo "** Success **"
  echo "SDK will be generated for $my_sdk_host host"
  echo "Now run these two commands to setup and build the flashable image:"
  echo "cd $my_build_dir"
  echo "source poky/oe-init-build-env"
  echo "bitbake -k edison-image"
  echo "*************"
}

main "$@"
