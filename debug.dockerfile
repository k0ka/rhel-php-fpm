FROM rockylinux:8 AS builder

RUN rpm -ivh https://rpms.remirepo.net/SRPMS/libmemcached-awesome-1.1.3-1.remi.src.rpm \
    && cd /root/rpmbuild \
    && dnf -y install wget rpm-build bison cmake cyrus-sasl-devel flex gcc gcc-c++ libevent-devel memcached openssl-devel systemtap-sdt-devel \
    && dnf -y install 'dnf-command(config-manager)' \
    && dnf -y config-manager --enable powertools \
    && dnf -y install python3-sphinx \
    && wget https://github.com/awesomized/libmemcached/commit/48dcc61a.patch -O SOURCES/libmemcached-awesome-revert.patch \
    && sed -i "s/Source0.*/&\n\nPatch0:    %{projname}-revert.patch/" SPECS/libmemcached-awesome.spec \
    && sed -i "s/%setup.*/&\n%patch0 -p1/" SPECS/libmemcached-awesome.spec \
    && sed -i 's/Release:   1%/Release:   2%/' SPECS/libmemcached-awesome.spec \
    && rpmbuild -ba --define 'vendeur remi' SPECS/libmemcached-awesome.spec

FROM rockylinux:8

# php version should be like "7.4"
ARG PHP_VERSION

ENV USER_ID=900 \
	GROUP_ID=900 \
	SUMMARY="Platform for running Remi's php-fpm ${PHP_VERSION} on Rocky Linux 8 (RHEL Compatible)" \
	DESCRIPTION="PHP-FPM (FastCGI Process Manager) is an alternative PHP FastCGI \
		implementation with some additional features useful for sites of any size, \
		especially busier sites."

LABEL maintainer="admin@idwrx.com" \
	summary="${SUMMARY}" \
	description="${DESCRIPTION}" \
	name="k0ka/rhel-php-fpm"

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r -g $GROUP_ID php-fpm && useradd -r -g php-fpm -u $USER_ID php-fpm

# remove cache
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

COPY --from=builder /root/rpmbuild/RPMS/x86_64/* /root/

RUN	dnf -y clean all  \
    && dnf -y --nodoc --setopt=install_weak_deps=false update  \
    && dnf -y erase acl bind-export-libs cpio dhcp-client dhcp-common dhcp-libs \
        ethtool findutils hostname ipcalc iproute iputils kexec-tools \
        lzo pkgconf pkgconf-m4 shadow-utils snappy squashfs-tools xz  \
    && dnf -y autoremove \
    && dnf -y install /root/remi-libmemcached-awesome-1.1.3-2.el8.x86_64.rpm  \
      /root/remi-libmemcached-awesome-debuginfo-1.1.3-2.el8.x86_64.rpm \
      /root/remi-libmemcached-awesome-debugsource-1.1.3-2.el8.x86_64.rpm \
    && dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm  \
    && dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm  \
    && dnf -y update  \
    && dnf -y module reset php  \
    && dnf -y module enable php:remi-${PHP_VERSION}  \
    && dnf -y install gdb gdb-gdbserver procps tcpdump \
    && dnf -y install --setopt=tsflags=nodocs php php-fpm php-pecl-redis5 php-pecl-memcache php-pecl-memcached php-mysqlnd php-intl \
		php-bcmath php-gd php-mbstring php-pecl-apcu php-pecl-imagick php-process php-xml php-pecl-zip php-pecl-xdebug \
		ImageMagick cronie vim-enhanced  \
    && dnf -y install --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm \
		https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm  \
    && dnf -y install 'dnf-command(config-manager)'  \
    && dnf -y config-manager --enable powertools  \
    && dnf -y install --setopt=tsflags=nodocs ffmpeg

RUN	dnf -y clean all

COPY ./php-fpm.conf /etc/php-fpm.conf
COPY ./global.conf /etc/php-fpm.d/global.conf
COPY ./www.conf /etc/php-fpm.d/www.conf

RUN chown php-fpm:php-fpm /var/lib/php/session/
	
EXPOSE 9000/tcp

USER php-fpm 

CMD ["/usr/sbin/php-fpm", "-F"]
