FROM lambci/lambda:build-provided

LABEL maintainer="Development Seed <info@developmentseed.org>"
LABEL authors="Matthew Hanson  <matt.a.hanson@gmail.com>"

# install system libraries
RUN \
    yum makecache fast; \
    yum install -y wget libpng-devel nasm; \
    yum install -y bash-completion --enablerepo=epel; \
    yum clean all; \
    yum autoremove

# versions of packages
ENV \
    GDAL_VERSION=3.0.1 \
    PROJ_VERSION=6.2.0 \
    NGHTTP2_VERSION=1.39.2 \
    CURL_VERSION=7.66.0 \
    PKGCONFIG_VERSION=0.29.2 \
    OPENSSL_VERSION=1.0.2

# Paths to things
ENV \
    BUILD=/build \
    NPROC=4 \
    PREFIX=/usr/local \
    GDAL_CONFIG=/usr/local/bin/gdal-config \
    LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64 \
    PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:/usr/lib64/pkgconfig \
    GDAL_DATA=${PREFIX}/share/gdal \
    PROJ_LIB=${PREFIX}/share/proj

# switch to a build directory
WORKDIR /build

# pkg-config - version > 2.5 required for GDAL 2.3+
RUN \
    mkdir pkg-config; \
    wget -qO- https://pkg-config.freedesktop.org/releases/pkg-config-$PKGCONFIG_VERSION.tar.gz \
        | tar xvz -C pkg-config --strip-components=1; cd pkg-config; \
    ./configure --prefix=$PREFIX CFLAGS="-O2 -Os"; \
    make -j ${NPROC} install; \
    cd ../; rm -rf pkg-config

# proj
RUN \
    mkdir proj; \
    wget -qO- http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz | tar xvz -C proj --strip-components=1; cd proj; \
    ./configure --prefix=$PREFIX; \
    make -j ${NPROC} install; \
    cd ..; rm -rf proj

# nghttp2
RUN \
    mkdir nghttp2; \
    wget -qO- https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.gz \
        | tar xvz -C nghttp2 --strip-components=1; cd nghttp2; \
    ./configure --enable-lib-only --prefix=${PREFIX}; \
    make -j ${NPROC} install; \
    cd ..; rm -rf nghttp2

# curl
RUN \
    mkdir curl; \
    wget -qO- https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz \
        | tar xvz -C curl --strip-components=1; cd curl; \
    ./configure --prefix=${PREFIX} --disable-manual --disable-cookies --with-nghttp2=${PREFIX}; \
    make -j ${NPROC} install; \
    cd ..; rm -rf curl

# GDAL
RUN \
    mkdir gdal; \
    wget -qO- http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz \
        | tar xvz -C gdal --strip-components=1; cd gdal; \
    ./configure \
        --disable-debug \
        --disable-static \
        --prefix=${PREFIX} \
        --with-threads=yes \
        --with-curl=${PREFIX}/bin/curl-config \
        --without-python \
        --without-libtool \
        --with-hide-internal-symbols=yes \
        CFLAGS="-O2 -Os" CXXFLAGS="-O2 -Os" \
        LDFLAGS="-Wl,-rpath,'\$\$ORIGIN'"; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf gdal

# Open SSL is needed for building Python so it's included here for ease
RUN \
    mkdir openssl; \
    wget -qO- https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
        | tar xvz -C openssl --strip-components=1; cd openssl; \
    ./config shared --prefix=${PREFIX}/openssl --openssldir=${PREFIX}/openssl; \
    make depend; make install; cd ..; rm -rf openssl


# Copy shell scripts and config files over
COPY bin/* /usr/local/bin/

WORKDIR /home/geolambda
