# NOTE: this Makefile is mainly for developer use, as there isn't really
# anything to build.

distapp = gentoo-bashcomp
distver := $(shell date --iso | sed -e 's~-~~g')
distpkg := $(distapp)-$(distver)

PREFIX = /usr

install:
	install -d "$(DESTDIR)$(PREFIX)/share/bash-completion"
	install -m0644 gentoo "$(DESTDIR)$(PREFIX)/share/bash-completion"
	install -d "$(DESTDIR)/etc/bash_completion.d"
	ln -snf "../..$(PREFIX)/share/bash-completion/gentoo" \
		"$(DESTDIR)/etc/bash_completion.d/gentoo"

dist:
	mkdir -p "$(distpkg)"
	$(MAKE) PREFIX="$(distpkg)" install
	cp ChangeLog AUTHORS TODO COPYING "$(distpkg)/"
	tar cjf "$(distpkg).tar.bz2" "$(distpkg)"
	rm -fr "$(distpkg)/"
	@echo "success."

dist-sign: dist
	gpg --armour --detach-sign "$(distpkg).tar.bz2"
	mv "$(distpkg).tar.bz2.asc" "$(distpkg).tar.bz2.signature"

dist-upload: dist-sign
	echo -ne "user anonymous gentoo-bashcomp\ncd incoming\nput $(distpkg).tar.bz2\nput $(distpkg).tar.bz2.signature\nbye" | \
		ftp -n ftp.berlios.de
	@echo "uploaded."
