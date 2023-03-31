# /bin/bash
# Description: Build static python

set -e
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
SETUP_SRC=$WORK_DIR/Setup-ssl
SETUP_DES=$PYTHON_DIR/Modules/Setup

# dependencies
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    dpkg-dev \
    gcc \
    llvm \
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

# install custom openssl
CUSTOM_SSL=$WORK_DIR/custom-openssl
if [ ! -d $CUSTOM_SSL ]; then
    mkdir -p $CUSTOM_SSL
    # cd parent dir of $CUSTOM_SSL
    cd $CUSTOM_SSL/..
    wget -O openssl-1.1.1t.tar.gz https://www.openssl.org/source/openssl-1.1.1t.tar.gz
    tar -xf openssl-1.1.1t.tar.gz
    cd openssl-1.1.1t
    ./config --prefix=$CUSTOM_SSL --openssldir=$CUSTOM_SSL
    make -j
    make install
fi

# download python
wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"
tar --extract --directory $PYTHON_DIR --strip-components=1 --file python.tar.xz
rm python.tar.xz

# static build python
cd $PYTHON_DIR
cp $SETUP_SRC $SETUP_DES
# gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
./configure \
    --prefix=$PY_PREFIX \
    --disable-shared \
    --enable-optimizations \
    --with-openssl=$CUSTOM_SSL \
    LDFLAGS="-static" CFLAGS="-static" CPPFLAGS="-static" 
# --build="$gnuArch" 
# --with-openssl-rpath=auto 
nproc="$(nproc)"
EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"
LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"
make -j $nproc LDFLAGS="-static" LINKFORSHARED=" "
