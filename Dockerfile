FROM buildbot/buildbot-worker:master
user root
ADD . /compat

RUN apt-get update && apt-get install -y \
	software-properties-common \
	wget

# add toolchain repo
RUN add-apt-repository ppa:ubuntu-toolchain-r/test

# add clang repo 
RUN echo deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-4.0 main > /etc/apt/sources.list.d/llvm.list && \
	wget -O - http://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add

# install compilation dependencies
RUN apt-get update && apt-get install -y \
	gcc-6 \
	g++-6 \
	clang-4.0 \
	clang++-4.0 \
	clang-tidy-4.0 \
	make \
	zsh \
	libssl-dev && \
	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Build static OpenSSL
ENV SSL_VER=1.0.2j \
    PREFIX=/usr/local \
    PATH=/usr/local/bin:$PATH

ENV CC="clang-4.0 -fPIC"

RUN curl -sL http://www.openssl.org/source/openssl-$SSL_VER.tar.gz | tar xz && \
    cd openssl-$SSL_VER && \
    ./Configure no-shared --prefix=$PREFIX --openssldir=$PREFIX/ssl no-zlib linux-x86_64 && \
    make depend 2> /dev/null && make -j$(nproc) && make install && \
    cd .. && rm -rf openssl-$SSL_VER

ENV OPENSSL_LIB_DIR=$PREFIX/lib \
    OPENSSL_INCLUDE_DIR=$PREFIX/include \
    OPENSSL_DIR=$PREFIX \
    OPENSSL_STATIC=1

# Setup compilers
ENV CXX="clang++-4.0 -fPIC -std=c++1z -i/compat/glibc_version.h"
ENV CC="clang-4.0 -fPIC -i/compat/glibc_version.h"
ENV CPP="clang-4.0 -E"
ENV LINK="clang++-4.0 -static-libstdc++ -static-libgcc -L/compat"

# Force clang 
RUN ln -sf /usr/bin/clang-4.0 /usr/bin/cc && \
	ln -sf /usr/bin/clang++-4.0 /usr/bin/cpp

# Prepare static libs 
RUN objcopy --redefine-syms=/compat/glibc_version.redef /usr/lib/gcc/x86_64-linux-gnu/6/libstdc++.a /compat/libstdc++.a
RUN objcopy --redefine-syms=/compat/glibc_version.redef /usr/lib/gcc/x86_64-linux-gnu/6/libstdc++fs.a /compat/libstdc++fs.a
RUN objcopy --redefine-syms=/compat/glibc_version.redef /usr/local/lib/libssl.a /compat/libssl.a
RUN objcopy --redefine-syms=/compat/glibc_version.redef /usr/local/lib/libcrypto.a /compat/libcrypto.a

# Get breakpad symbol dumper 
RUN wget https://github.com/sbx320/binaries/blob/master/dump_syms?raw=true -O /usr/bin/dump_syms && chmod +x /usr/bin/dump_syms

user buildbot 
RUN mkdir ~/.ssh
RUN ssh-keyscan -H gitlab.nanos.io >> ~/.ssh/known_hosts

CMD echo "$ID_RSA" > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa && \
   unset ID_RSA && unset BUILDMASTER && unset BUILDMASTER_PORT && unset WORKERNAME && unset WORKERPASS && \
   rm -rf twistd.pid && \
   /usr/local/bin/dumb-init twistd -ny buildbot.tac

