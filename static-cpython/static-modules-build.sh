# /bin/bash
# Description: Build static python

set -e
# GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D
PYTHON_VERSION=3.11.2
WORK_DIR=$(dirname $(readlink -f $0))
PYTHON_DIR=$WORK_DIR/static-modules-python$PYTHON_VERSION
if [ -d $PYTHON_DIR ]; then
    rm -rf $PYTHON_DIR
fi
mkdir $PYTHON_DIR
PY_PREFIX=$WORK_DIR/static-modules-python
# if $PY_PREFIX is not exist, mkdir it
if [ ! -d $PY_PREFIX ]; then
    mkdir $PY_PREFIX
fi
SETUP_SRC=$WORK_DIR/Setup-nossl
SETUP_DES=$PYTHON_DIR/Modules/Setup

# dependencies
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    dpkg-dev \
    gcc \
    libbz2-dev \
    libc6-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libncurses5-dev \
    make \
    netbase \
    tk-dev \
    uuid-dev \
    xz-utils \
    zlib1g-dev \
    glibc-source

# download python
wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"
tar --extract --directory $PYTHON_DIR --strip-components=1 --file python.tar.xz
rm python.tar.xz

# static build python
cd $PYTHON_DIR
cp $SETUP_SRC $SETUP_DES
gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
./configure \
    --prefix=$PY_PREFIX \
	--build="$gnuArch" \
    --disable-shared \
    --without-ensurepip \
    LDFLAGS="-static" CFLAGS="-static" CPPFLAGS="-static" 
nproc="$(nproc)"
EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"
LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"
make -j $nproc LDFLAGS="-static" LINKFORSHARED=" "

# ldd $PY_PREFIX