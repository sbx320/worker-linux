FROM buildpack-deps:zesty
ADD . /compat

RUN apt-get update && apt-get install -y \
	software-properties-common \
	wget

# add toolchain repo
RUN add-apt-repository ppa:ubuntu-toolchain-r/test

# add clang repo 
RUN echo deb http://apt.llvm.org/zesty/ llvm-toolchain-zesty-4.0 main > /etc/apt/sources.list.d/llvm.list && \
	wget -O - http://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add

# install compilation dependencies
RUN apt-get update && apt-get install -y \
	gcc \
	g++ \
	clang-4.0 \
	clang++-4.0 \
	clang-tidy-4.0 \
	make \
	zsh \
	libssl-dev \
	libprotobuf-dev && \
	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Setup compilers
ENV CXX="clang++-4.0 -fPIC -std=c++1z 
ENV CC="clang-4.0 -fPIC 
ENV CPP="clang-4.0 -E"
ENV LINK="clang++-4.0"

# Force clang 
RUN ln -sf /usr/bin/clang-4.0 /usr/bin/cc && \
	ln -sf /usr/bin/clang++-4.0 /usr/bin/cpp
