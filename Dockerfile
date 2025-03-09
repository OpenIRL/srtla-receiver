# Builder Stage
FROM alpine:3.20 AS builder

ENV LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib64
WORKDIR /tmp

# Install required packages
RUN apk update \
    && apk add --no-cache linux-headers alpine-sdk cmake tcl openssl-dev zlib-dev spdlog spdlog-dev \
    && rm -rf /var/cache/apk/*

# Clone, build and install belabox-patched SRT
RUN git clone https://github.com/onsmith/srt.git srt \
    && cd srt \
    && ./configure \
    && make -j${nproc} \
    && make install

# Clone and build SRT Live Server
RUN git clone https://github.com/OpenIRL/srt-live-server.git srt-live-server \
    && cd srt-live-server \
    && make -j8

# Clone and build SRTla
RUN git clone -b next https://github.com/OpenIRL/srtla.git srtla \
    && cd srtla \
    && git submodule update --init --recursive \
    && cmake . \
    && make -j${nproc}

# Final Stage
FROM alpine:3.20

ENV LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib64

RUN apk update \
    && apk add --no-cache openssl libstdc++ supervisor coreutils spdlog perl \
    && rm -rf /var/cache/apk/*

# Copy binaries from the builder stage
COPY --from=builder /tmp/srt-live-server/bin /usr/local/bin
COPY --from=builder /tmp/srtla/srtla_rec /usr/local/bin
COPY --from=builder /usr/local/bin/srt-* /usr/local/bin
COPY --from=builder /usr/local/lib/libsrt* /usr/local/lib

# copy configuration files
COPY conf/sls.conf /etc/sls/sls.conf
COPY conf/supervisord.conf /etc/supervisord.conf

# copy bin files
COPY --chmod=755 bin/logprefix /bin/logprefix

# Expose ports
EXPOSE 5000/udp 4001/udp 8080/tcp

# Start supervisor
CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]