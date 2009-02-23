# NOTE: this Makefile is mainly for developer use, as there isn't really
# anything to build.

distapp = gentoo-bashcomp
distver := $(shell date --iso | sed -e 's~-~~g')
distpkg := $(distapp)-$(distver)

PREFIX = /usr

all:
	@echo Nothing to compile.

install:
	install -d "$(DESTDIR)$(PREFIX)/share/bash-completion"
	install -m0644 gentoo "$(DESTDIR)$(PREFIX)/share/bash-completion"
	install -d "$(DESTDIR)/etc/bash_completion.d"
	ln -snf "../..$(PREFIX)/share/bash-completion/gentoo" \
		"$(DESTDIR)/etc/bash_completion.d/gentoo"

dist:
	mkdir -p "$(distpkg)"
	cp AUTHORS COPYING gentoo Makefile TODO "$(distpkg)/"
	svn2cl -o "$(distpkg)/"ChangeLog
	tar cjf "$(distpkg).tar.bz2" "$(distpkg)"
	rm -fr "$(distpkg)/"
	@echo "success."

dist-upload: dist
	scp $(distpkg).tar.bz2 dev.gentoo.org:/space/distfiles-local/
	ssh dev.gentoo.org chmod ug+rw /space/distfiles-local/$(distpkg).tar.bz2
