# Highly-Optimized Docker Image of pyLoad (ubuntu variant)
# AUTHOR: vuolter
#      ____________
#   _ /       |    \ ___________ _ _______________ _ ___ _______________
#  /  |    ___/    |   _ __ _  _| |   ___  __ _ __| |   \\    ___  ___ _\
# /   \___/  ______/  | '_ \ || | |__/ _ \/ _` / _` |    \\  / _ \/ _ `/ \
# \       |   o|      | .__/\_, |____\___/\__,_\__,_|    // /_//_/\_, /  /
#  \______\    /______|_|___|__/________________________//______ /___/__/
#          \  /
#           \/

FROM lsiobase/ubuntu as builder

ARG APT_TEMPS = "/tmp/* /var/lib/apt/lists/* /var/tmp/*"
ARG APT_INSTALL_OPTIONS = "--no-install-recommends --yes"
ARG PIP_INSTALL_OPTIONS = "--no-cache-dir --no-compile --upgrade"

RUN \
echo "**** update sources list ****" && \
add-apt-repository {universe,restricted,multiverse} && apt-get update -y && \
\
echo "**** install Python ****" && \
apt-get install $APT_INSTALL_OPTIONS python3 openssl && \
\
echo "**** upgrade PIP ****" && \
pip install $PIP_INSTALL_OPTIONS pip && \
\
echo "**** cleanup ****" && \
apt-get clean && rm -rf $APT_TEMPS




FROM builder as wheels_builder

COPY setup.cfg /source/setup.cfg
WORKDIR /wheels

RUN \
echo "**** build pyLoad dependencies ****" && \
python -c "import configparser as cp; c = cp.ConfigParser(); c.read('/source/setup.cfg'); print(c['options']['install_requires'] + c['options.extras_require']['extra'])" | \
xargs pip wheel --wheel-dir=.




FROM builder as source_builder

COPY . /source
WORKDIR /source

ARG PIP_PACKAGES="Babel Jinja2"

RUN \
echo "**** build pyLoad locales ****" && \
pip install $PIP_INSTALL_OPTIONS $PIP_PACKAGES && python setup.py build_locale




FROM builder as package_builder

COPY --from=wheels_builder /wheels /wheels
COPY --from=source_builder /source /source
WORKDIR /package

RUN \
echo "**** build pyLoad package ****" && \
pip install $PIP_INSTALL_OPTIONS --find-links=/wheels --no-index --prefix=. /source[extra]




FROM builder

LABEL \
version="1.0" \
description="The free and open-source Download Manager written in pure Python" \
maintainer="vuolter@gmail.com"

ENV PYTHONUNBUFFERED=1

ARG APT_PACKAGES="sqlite tesseract-ocr unrar"
ARG PYLOAD_OPTIONS="--userdir /config --storagedir /downloads"

RUN \
echo "**** install missing packages ****" && \
apt-get install $APT_INSTALL_OPTIONS $APT_PACKAGES && \
\
echo "**** create s6 fix-attr script ****" && \
echo "
/config true abc:abc 0644 0755
/downloads false abc:abc 0644 0755
" >> /etc/fix-attrs.d/10-run && \
\
echo "**** create s6 service script ****" && \
RUN echo "
#!/usr/bin/with-contenv bash
umask 022
exec s6-setuidgid abc pyload $PYLOAD_OPTIONS
" >> /etc/services.d/pyload/run && \
\
echo "**** cleanup ****" && \
apt-get clean && rm -rf $APT_TEMPS && \
\
echo "**** finalize pyLoad ****"

COPY --from=package_installer /package /usr/local

EXPOSE 8001 9666
VOLUME /config /downloads