# Debian 11 has an old enough GCC to not complain about libnyquist
FROM debian/eol:bullseye
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y aria2 luajit

ENV PKGS="git build-essential ninja-build \
    libgtk2.0-dev libasound2-dev python3-minimal libavformat-dev libjack-jackd2-dev \
    patchelf cimg-dev \
    libgpgme-dev libgcrypt-dev libcurl4-openssl-dev \
    squashfs-tools desktop-file-utils wget googletest"

COPY apt2ml.lua /usr/bin/apt2ml
RUN chmod +x /usr/bin/apt2ml

RUN apt-get install --print-uris $PKGS | apt2ml > pkglist.meta4

RUN aria2c -m0 -j2 -x4 -s99 -c --min-split-size=10M \
    --enable-http-pipelining -d /var/cache/apt/archives \
    pkglist.meta4 && rm pkglist.meta4

RUN apt install -y $PKGS && rm -f /var/cache/apt/archives/*.deb

# Clone all required git repos

WORKDIR /src/wxwidgets
RUN git clone https://github.com/audacity/wxWidgets . --depth 1 \
    --branch v3.1.3-audacity --recurse-submodules --shallow-submodules

WORKDIR /src/audacity
RUN git clone https://github.com/audacity/audacity . --depth 1 \
    --branch Audacity-2.4.2 --recurse-submodules --shallow-submodules

WORKDIR /src/appimagetool
RUN git clone https://github.com/AppImage/appimagetool . --depth 1 \
    --branch 1.9.0 --recurse-submodules --shallow-submodules

WORKDIR /src/linuxdeploy
RUN git clone https://github.com/linuxdeploy/linuxdeploy . --depth 1 \
    --branch 1-alpha-20250213-2 --recurse-submodules --shallow-submodules

WORKDIR /src/linuxdeploy-plugin-appimage
RUN git clone https://github.com/linuxdeploy/linuxdeploy-plugin-appimage . --depth 1 \
    --branch 1-alpha-20250213-1 --recurse-submodules --shallow-submodules

# CMake is not installed from apt because Debian 11's version
# is too old to build appimagetool

WORKDIR /src/cmake
RUN aria2c -m0 https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-x86_64.sh
RUN chmod +x ./cmake*.sh
RUN ./cmake*.sh --prefix=/usr --skip-license

# Start building stuff

# Build linuxdeploy, plugin, and appimagetool

WORKDIR /src/linuxdeploy/build
RUN cmake -S .. -B . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . -j4
RUN cmake --install .

WORKDIR /src/linuxdeploy-plugin-appimage/build
RUN cmake -S .. -B . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . -j$(nproc)
RUN cmake --install .

WORKDIR /src/appimagetool/build
RUN cmake -S .. -B . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . -j$(nproc)
RUN cmake --install .

# Build WXWidgets
WORKDIR /src/wxwidgets/buildgtk
RUN ../configure --with-cxx=14 --with-gtk
RUN make -j$(nproc)
RUN make install

# Build Audacity
WORKDIR /src/audacity/build
RUN cmake -S .. -B . -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . -j$(nproc)
RUN cmake --install . --prefix ./AppDir/usr

# cache needs to be updated before linuxdeploy will work
RUN ldconfig
# Patch required for linuxdeploy to not complain about not being able to find 'env'
RUN sed -i 's/env UBUNTU_MENUPROXY=0//' ./AppDir/usr/share/applications/audacity.desktop
RUN linuxdeploy --appdir AppDir --output appimage

WORKDIR /root
RUN cp /src/audacity/build/*.AppImage .
RUN rm -rf /src

# ENTRYPOINT ["bash"]
ENTRYPOINT ["bash", "-c", "cp ./*.AppImage /out/ && echo \"Copied appimage to /out\""]