FROM ubuntu:17.04
ADD . /compat

RUN apt-get update && apt-get install -y \
	software-properties-common \
	ca-certificates \
	git \
	wget

# add toolchain repo
RUN add-apt-repository ppa:ubuntu-toolchain-r/test

# add clang repo 
RUN echo deb http://apt.llvm.org/zesty/ llvm-toolchain-zesty main > /etc/apt/sources.list.d/llvm.list && \
	wget -O - http://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add

# install compilation dependencies
RUN apt-get update && apt-get install -y \
	clang-4.0 \
	clang++-4.0 \
	clang-tidy-4.0 \
	ninja-build \
	make \
	zsh \
	build-essential \
	curl \
	subversion \
	cmake \
	libssl-dev && \
	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Build static OpenSSL
ENV SSL_VER=1.0.2k \
    PREFIX=/usr/local \
    PATH=/usr/local/bin:$PATH

RUN curl -sL http://www.openssl.org/source/openssl-$SSL_VER.tar.gz | tar xz && \
    cd openssl-$SSL_VER && \
    ./Configure no-shared --prefix=$PREFIX --openssldir=$PREFIX/ssl no-zlib linux-x86_64 -fPIC && \
    make depend 2> /dev/null && make -j$(nproc) && make install && \
    cd .. && rm -rf openssl-$SSL_VER
	
ENV OPENSSL_LIB_DIR=$PREFIX/lib \
    OPENSSL_INCLUDE_DIR=$PREFIX/include \
    OPENSSL_DIR=$PREFIX \
    OPENSSL_STATIC=1

# Build libc++
ENV CXX="clang++-4.0 -fPIC -i/compat/glibc_version.h"
ENV CC="clang-4.0 -fPIC -i/compat/glibc_version.h"
ENV CPP="clang-4.0 -E"
ENV LINK="clang++-4.0 -L/compat"

RUN mkdir /libcpp && \
	cd /libcpp && \
	svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm && \
	cd llvm/projects && \
	svn co http://llvm.org/svn/llvm-project/libcxx/trunk libcxx && \
	svn co http://llvm.org/svn/llvm-project/libcxxabi/trunk libcxxabi && \
	cd .. && \
	mkdir build && \
	cd build && \
	cmake -G "Unix Makefiles" \ 
        -DLIBCXX_ENABLE_SHARED=NO \
        -DLIBCXX_INCLUDE_BENCHMARKS=NO \
        -DLIBCXX_ENABLE_STATIC=YES \             
        -DLIBCXXABI_ENABLE_SHARED=NO \             
        -DLIBCXXABI_ENABLE_STATIC=YES \           
		-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
        -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=YES \
		-DCMAKE_INSTALL_PREFIX=/usr/ \
		/libcpp/llvm && \
	make cxx && \
	make install-cxx install-cxxabi && \
	cp /libcpp/llvm/projects/libcxxabi/include/* /usr/include/c++/v1/ && \
	rm -rf /libcpp
	

	
# Force clang 
ENV CXX="clang++-4.0 -I/usr/include/c++/v1 -nostdinc++ -stdlib=libc++ -fPIC -i/compat/glibc_version.h -L/usr/lib/ -lc++ -lc++experimental -lc++abi"
ENV LINK="clang++-4.0 -stdlib=libc++ -static-libstdc++ -static-libgcc -L/compat"
RUN ln -sf /usr/bin/clang-4.0 /usr/bin/cc && \
	ln -sf /usr/bin/clang++-4.0 /usr/bin/cpp && \
	ln -sf /usr/bin/clang++-4.0 /usr/bin/c++

# Prepare static libs 
RUN objcopy --redefine-syms=/compat/glibc_version.redef /usr/local/lib/libssl.a /compat/libssl.a
RUN objcopy --redefine-syms=/compat/glibc_version.redef /usr/local/lib/libcrypto.a /compat/libcrypto.a

# Get breakpad symbol dumper 
RUN wget https://github.com/sbx320/binaries/blob/master/dump_syms?raw=true -O /usr/bin/dump_syms && chmod +x /usr/bin/dump_syms
