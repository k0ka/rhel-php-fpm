FROM rockylinux:8

ENV USER_ID=900 \
	GROUP_ID=900 \
	PHP_VERSION="7.4" \
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

RUN	dnf -y clean all && \
    dnf -y --nodoc --setopt=install_weak_deps=false update && \
    dnf -y erase acl bind-export-libs cpio dhcp-client dhcp-common dhcp-libs \
        ethtool findutils hostname ipcalc iproute iputils kexec-tools \
        lzo pkgconf pkgconf-m4 shadow-utils snappy squashfs-tools xz && \
	dnf -y autoremove && \
	dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
	dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm && \
	dnf -y update && \
	dnf -y module reset php && \
	dnf -y module enable php:remi-${PHP_VERSION} && \
	dnf -y install --setopt=tsflags=nodocs php php-fpm php-pecl-redis5 php-pecl-memcached-3.1.5-13.el8.remi.7.4 php-mysqlnd php-intl \
		php-bcmath php-gd php-mbstring php-pecl-apcu php-pecl-imagick php-pecl-sphinx php-process php-xml php-pecl-zip php-pecl-xdebug \
		ImageMagick cronie vim-enhanced && \
	dnf -y install --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm \
		https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm && \
	dnf -y install 'dnf-command(config-manager)' && \
	dnf -y config-manager --enable powertools && \
	dnf -y install --setopt=tsflags=nodocs ffmpeg

RUN	dnf -y clean all 

COPY ./php-fpm.conf /etc/php-fpm.conf
COPY ./global.conf /etc/php-fpm.d/global.conf
COPY ./www.conf /etc/php-fpm.d/www.conf

RUN chown php-fpm:php-fpm /var/lib/php/session/
	
EXPOSE 9000/tcp

USER php-fpm 

CMD ["/usr/sbin/php-fpm", "-F"]
