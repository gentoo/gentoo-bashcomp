# NOTE: this Makefile is mainly for developer use, as there isn't really
# anything to build.

distapp = gentoo-bashcomp
distver := $(shell date --iso | sed -e 's~-~~g')
distpkg := $(distapp)-$(distver)

PREFIX = ${HOME}/.bash_completion.d

install:
	cp gentoo "$(PREFIX)"

dist:
	mkdir -p "$(distpkg)"
	$(MAKE) PREFIX="$(distpkg)" install
	cp ChangeLog AUTHORS TODO COPYING "$(distpkg)/"
	tar cjf "$(distpkg).tar.bz2" "$(distpkg)"
	rm -fr "$(distpkg)/"
	echo "success."

dist-sign:
	gpg --armour --detach-sign "$(distpkg).tar.bz2"
	mv "$(distpkg).tar.bz2.asc" "$(distpkg).tar.bz2.signature"

dist-upload: dist dist-sign
	echo -ne "user anonymous gentoo-bashcomp\ncd incoming\nput $(distpkg).tar.bz2\nput $(distpkg).tar.bz2.signature\nbye" | \
		ftp -n ftp.berlios.de
	echo "uploaded."
