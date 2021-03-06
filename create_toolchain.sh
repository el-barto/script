#!/usr/bin/env bash

# =================================
# Set Variables
# =================================

filtersdir=~/.pandoc/filters # lua filters will go here (user only)
installdir=/usr/local/bin # binaries will go here (system-wide)
tmpdir=/tmp/tmpdir
deb_ver=`cat /etc/debian_version` # find out which Debian are we on
minversion="2.7" #Minimum version for Pandoc
update_pandoc="false" # inizialize variable to default value
red=$(tput setaf 1)
green=$(tput setaf 76)
normal=$(tput sgr0)
bold=$(tput bold)
underline=$(tput sgr 0 1)



# =================================
# Silly functions
# =================================

i_ok() { printf "\n${green}✔${normal} "; }
i_ko() { printf "\n  ${red}✖  ERROR  ✖${normal}\n"; }

function check_i {
  if [ $? -eq 0 ]; then
    i_ok
  else
    i_ko; read
    exit
  fi
}

# =================================
# Preliminary checks
# =================================

# check if root

if [[ $EUID == 0 ]]; then
  i_ko
  printf "
  Sorry, this script ${red} must NOT${normal} be run as root:
  please log in as normal user or avoid using sudo.
  You will be asked to authenticate for sudo, if needed\n"
   exit 1
fi

# Check if Debian

if [ -z $deb_ver ] ; then
  i_ko
  printf "\nThis ain't no Debian-based  -- Aborting\n\n" ; exit 1
fi

# check if sudoer

sudo touch /tmp/test 2> /dev/null

if [ $? != 0 ]
then
  i_ko
  printf "\n  Oh no, you are not a sudoer!
  Make sure your user can sudo.
  or add yourself to sudo group. Go back to root and use:
  # usermod -a -G sudo $USER \n\n"
  exit 1
fi

# =================================
# Actual script
# =================================

# we operate from a temporary directory
mkdir $tmpdir
cd $tmpdir || exit 1 #so if it fails, we dont delete the script's  directory
check_i
rm $tmpdir/* 2>/dev/null # clean slate

# Debian packages:

# check what pandoc version do we have installed and available
pandoc_ver=`apt-cache policy pandoc | egrep "Inst" | awk '{print $2}' | sed 's/-/./g' | awk 'BEGIN { FS = "." } ; {print $1 "." $2}'`
pandoc_cand=`apt-cache policy pandoc | egrep "Cand" | awk '{print $2}' | sed 's/-/./g' | awk 'BEGIN { FS = "." } ; {print $1 "." $2}'`
[[ $pandoc_ver =~ ^.*none.*$ ]] && pandoc_ver=0 # if no version installed, we neee a number

# Install pandoc and only if the version in repositories is not sufficiently recent
# fetch it and install manually

if  [[ "$pandoc_ver" < $minversion ]] ; then
  if  [[ "$pandoc_cand" < $minversion ]] ; then

    wget https://github.com/jgm/pandoc/releases/download/2.7.3/pandoc-2.7.3-1-amd64.deb
    sudo dpkg -i pandoc-2.7.3-1-amd64.deb
    i_ok
    printf "\nwe have installed Pandoc to $minversion from github (not repositories)"
  else
    update_pandoc="true"
  fi
else
i_ok
printf "Pandoc is already up to the needed version \n"
update_pandoc="false"
fi

# check if apt cache is sufficiently recent or has it been ever updated, else, skip

[ -f /var/cache/apt/pkgcache.bin ] && last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin) || last_update=0
now=$(date +%s)
[ -f /var/cache/apt/pkgcache.bin ] && actualsize=$(du -k /var/cache/apt/pkgcache.bin | cut -f 1) || actualsize=0 # if size too small, need to force update: check size

if [ $((now - last_update)) -gt 3600 ] || [ ! $actualsize -ge 3000 ] ; then
  update_apt="true" ; else
  update_apt="false"
fi

# If we need to install or update pandoc from repository, we do it now

if [ $update_pandoc = "true" ] ; then
 [ $update_apt = "true" ] && sudo apt update && update_apt="false" ; sudo apt install pandoc
fi

# test if mustache is installed, if not, install ruby-mustache from repository

which mustache 1>/dev/null  || ( [ $update_apt = "true" ] && sudo apt update ; sudo apt install -y ruby-mustache )

# Now we donwload a bunch of filters and stuff if missing

[ -f $filtersdir/crossref-ordered-list.lua ] || wget --directory-prefix=$filtersdir https://raw.githubusercontent.com/alpianon/howdyadoc/dev-legal/legal/pandoc-lua-filters/crossref-ordered-list.lua
[ -f $filtersdir/inline-headers.lua ] || wget --directory-prefix=$filtersdir https://raw.githubusercontent.com/alpianon/howdyadoc/dev-legal/legal/pandoc-lua-filters/inline-headers.lua
[ -f $filtersdir/secgroups.lua ] || wget --directory-prefix=$filtersdir https://raw.githubusercontent.com/alpianon/howdyadoc/dev-legal/legal/pandoc-lua-filters/secgroups.lua

[ -f $installdir/convert-html2docx-comments.pl ] || sudo wget --directory-prefix=$installdir https://raw.githubusercontent.com/alpianon/howdyadoc/dev-legal/legal/scripts/convert-html2docx-comments.pl
[ -f $installdir/howdyadoc-legal-convert ] || sudo wget --directory-prefix=$installdir https://raw.githubusercontent.com/alpianon/howdyadoc/dev-legal/legal/scripts/howdyadoc-legal-convert
[ -f $installdir/howdyadoc-legal-preview ] || sudo wget --directory-prefix=$installdir https://raw.githubusercontent.com/alpianon/howdyadoc/dev-legal/legal/scripts/howdyadoc-legal-preview
[ -f $installdir/pp-include.pl ] || sudo wget --directory-prefix=$installdir https://raw.githubusercontent.com/alpianon/howdyadoc/dev-legal/legal/scripts/pp-include.pl


[ -f $installdir/pandoc-crossref ] || \
( wget --directory-prefix=$tmpdir https://github.com/lierdakil/pandoc-crossref/releases/download/v0.3.4.1a/linux-pandoc_2_7_3.tar.gz && \
tar -xf $tmpdir/linux-pandoc_2_7_3.tar.gz && sudo mv $tmpdir/pandoc-crossref $installdir ) || \
printf "something went wrong with pandoc-crossref"


# make stuff executable in the install directory

sudo chmod +x $installdir/*


# cleanup temp directory:

rm -rf $tmpdir

i_ok

printf "******************************************
congratulations, your ${green}Debian${normal} $deb_ver
or Debian based distro can do it!
********************************************
"
