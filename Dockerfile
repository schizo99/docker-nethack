FROM rust:buster as builder
LABEL maintainer="schizo99@gmail.com"

WORKDIR /build
COPY ./nethack .

RUN RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-gnu

FROM debian as base

# Set the Nethack version
ENV NH_SHORT_VERSION=367
ENV NH_VERSION=3.6.7
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf bison \
    bsdmainutils flex gcc git groff libncursesw5-dev libsqlite3-dev make \
    ncurses-dev sqlite3 tar locales wget && \
  apt-get clean

RUN locale-gen en_US.UTF-8

RUN mkdir /home/nethack-temp/ && cd /home/nethack-temp/ && \
  wget http://nethack.org/download/$NH_VERSION/nethack-$NH_SHORT_VERSION-src.tgz && \
  tar -xzf nethack-$NH_SHORT_VERSION-src.tgz && cd NetHack-$NH_VERSION

ADD hints /home/nethack-temp/NetHack-$NH_VERSION/hints
ADD games.txt /games.txt
RUN cd /home/nethack-temp/NetHack-$NH_VERSION && \
      sed -i '/enter_explore_mode(VOID_ARGS)/{n;s/{/{ return 0;/}' src/cmd.c && \
      sh sys/unix/setup.sh hints && make all && make install

RUN git clone https://github.com/paxed/dgamelaunch.git && \
  cp /games.txt dgamelaunch/games.txt && \
  cd dgamelaunch && \
  sed -i '/loggedin = 1/a \
    time_t rawtime; \
    struct tm *timeinfo; \
    char time_buffer[20]; \
    time(&rawtime); \
    timeinfo = localtime(&rawtime); \
    strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%d %H:%M:%S", timeinfo); \
    fprintf(stderr, "[%s] Welcome, %s!\\n", time_buffer, me->username); \
    fflush(stderr);' dgamelaunch.c && \
  ./autogen.sh --enable-sqlite --enable-shmem --with-config-file=/home/nethack/etc/dgamelaunch.conf && \
  make && \
  sed -i \
    -e 's/^CHROOT=.*/CHROOT=\"\/home\/nethack\/\"/g' \
    -e "s/^NHSUBDIR=.*/NHSUBDIR=\"\/nh$NH_SHORT_VERSION\/\"/g" \
    -e "s/^NH_VAR_PLAYGROUND=.*/NH_VAR_PLAYGROUND=\"\/nh$NH_SHORT_VERSION\/var\/\"/g" \
    -e "s/^NH_PLAYGROUND_FIXED=.*/NH_PLAYGROUND_FIXED=\"\/home\/nethack-compiled\/nh$NH_SHORT_VERSION\"/g" \
    -e "s/nh343/nh$NH_SHORT_VERSION/g" dgl-create-chroot && \
  ./dgl-create-chroot

RUN mv /home/nethack/nh$NH_SHORT_VERSION/var/ /home/nethack/ && \
  mv -f /nh$NH_SHORT_VERSION /home/nethack/ && \
  chown -R games:games /home/nethack/nh$NH_SHORT_VERSION

RUN sed -i \
  -e 's/^chroot_path =.*/chroot_path = \"\/home\/nethack\/\"/g' \
  -e 's/# menu_max_idle_time/menu_max_idle_time/g' \
  -e '/play_game \"NH343\"/a \        commands\[\"r\"\] = play_game \"\ROBOTS\"' \
  -e '/play_game \"NH343\"/a \        commands\[\"y\"\] = play_game \"\HYPERTYPER\"' \
  -e '/play_game \"NH343\"/a \        commands\[\"h\"\] = exec \"\/highscore\" \"\"' \
  -e '/play_game \"NH343\"/a \        commands\[\"t\"\] = play_game \"ROBOTS_HIGHSCORE\"' \
  -e '/play_game \"NH343\"/a \        commands\[\"u\"\] = play_game \"HYPERTYPER_HIGHSCORE\"' \
  -e '/# third game/ r games.txt' \
  -e "s/NetHack 3.4.3/NetHack $NH_VERSION/g" \
  -e "s/343/$NH_SHORT_VERSION/g" /home/nethack/etc/dgamelaunch.conf

RUN sed -i \
    -e '/ p)/a \ r) Play Robots' \
    -e '/ p)/a \ y) Play Hypertyper' \
    -e '/ p)/a \ h) Nethack highscore' \
    -e '/ p)/a \ t) Robots highscore' \
    -e '/ p)/a \ u) Hypertyper highscore' \
    -e "s/NetHack 3.4.3/NetHack $NH_VERSION/g" /home/nethack/dgl_menu_main_user.txt && \
    sed -i 's/boulder:0/boulder:`/g' /home/nethack/dgl-default-rcfile.nh$NH_SHORT_VERSION

RUN mkdir /home/nethack/dgldir/inprogress-robots && chown games:games /home/nethack/dgldir/inprogress-robots && \
    mkdir /home/nethack/dgldir/inprogress-hypertyper && chown games:games /home/nethack/dgldir/inprogress-hypertyper

RUN cp /usr/lib/x86_64-linux-gnu/libncurses.so.6 /home/nethack/lib && cp /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 /home/nethack/lib

FROM debian:bookworm-slim

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ssh sqlite3

COPY --from=base /home/nethack /home/nethack
# Create the SSH directory and set the appropriate permissions
RUN mkdir /var/run/sshd && mknod /home/nethack/dev/null c 1 3

# Set root password (change it to a strong password)
RUN echo 'root:härskaspelas' | chpasswd

# Allow root login via SSH (this is generally not recommended for production)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Ensure the SSH daemon listens on port 22

COPY --from=builder /build/target/x86_64-unknown-linux-gnu/release/nethack /home/nethack/highscore
COPY robots /home/nethack/robots
COPY hypertyper /home/nethack/

# Configure SSH to use the custom script
RUN echo "command=\"/home/nethack/dgamelaunch\" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyQJUz91Q0L9F4EtPpI8VfV5p2VoJYx1qOQ7kTQi0NiP4lRT0i... user@host" >> /root/.ssh/authorized_keys && \
    echo "ForceCommand /home/nethack/dgamelaunch 2>> /home/nethack/dgldir/login.log" >> /etc/ssh/sshd_config
EXPOSE 22
# Start the SSH service
CMD ["/usr/sbin/sshd", "-D"]
