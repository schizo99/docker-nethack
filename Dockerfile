FROM rust:buster as builder
LABEL maintainer="schizo99@gmail.com"

WORKDIR /build
COPY ./nethack .

RUN RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-gnu

FROM debian as base

RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf bison \
    bsdmainutils flex gcc git groff libncursesw5-dev libsqlite3-dev make \
    ncurses-dev sqlite3 tar locales wget && \
  apt-get clean

RUN locale-gen en_US.UTF-8

RUN mkdir /home/nethack-temp/ && cd /home/nethack-temp/ && \
  wget http://nethack.org/download/3.6.7/nethack-367-src.tgz && \
  tar -xzf nethack-367-src.tgz && cd NetHack-3.6.7

ADD hints /home/nethack-temp/NetHack-3.6.7/hints

RUN cd /home/nethack-temp/NetHack-3.6.7 && \
      sed -i '/enter_explore_mode(VOID_ARGS)/{n;s/{/{ return 0;/}' src/cmd.c && \
      sh sys/unix/setup.sh hints && make all && make install

RUN git clone https://github.com/paxed/dgamelaunch.git && \
  cd dgamelaunch && \
  ./autogen.sh --enable-sqlite --enable-shmem --with-config-file=/home/nethack/etc/dgamelaunch.conf && \
  make && \
  sed -i \
    -e 's/^CHROOT=.*/CHROOT=\"\/home\/nethack\/\"/g' \
    -e 's/^NHSUBDIR=.*/NHSUBDIR=\"\/nh367\/\"/g' \
    -e 's/^NH_VAR_PLAYGROUND=.*/NH_VAR_PLAYGROUND=\"\/nh367\/var\/\"/g' \
    -e 's/^NH_PLAYGROUND_FIXED=.*/NH_PLAYGROUND_FIXED=\"\/home\/nethack-compiled\/nh367\"/g' \
    -e 's/nh343/nh367/g' dgl-create-chroot && \
  ./dgl-create-chroot

RUN mv /home/nethack/nh367/var/ /home/nethack/ && \
  mv -f /nh367 /home/nethack/ && \
  chown -R games:games /home/nethack/nh367
  
RUN sed -i \
  -e 's/^chroot_path =.*/chroot_path = \"\/home\/nethack\/\"/g' \
  -e 's/# menu_max_idle_time/menu_max_idle_time/g' \
  -e '/play_game \"NH343\"/a \        commands\[\"h\"\] = exec \"\/highscore\" \"\"' \
  -e 's/343/367/g' /home/nethack/etc/dgamelaunch.conf

RUN sed -i '/ p)/a \ h) Highscore' /home/nethack/dgl_menu_main_user.txt && \
    sed -i 's/boulder:0/boulder:`/g' /home/nethack/dgl-default-rcfile.nh367

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
# Configure SSH to use the custom script
RUN echo "command=\"/home/nethack/dgamelaunch\" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyQJUz91Q0L9F4EtPpI8VfV5p2VoJYx1qOQ7kTQi0NiP4lRT0i... user@host" >> /root/.ssh/authorized_keys && \
    echo "ForceCommand /home/nethack/dgamelaunch" >> /etc/ssh/sshd_config
EXPOSE 22
# Start the SSH service
CMD ["/usr/sbin/sshd", "-D"]