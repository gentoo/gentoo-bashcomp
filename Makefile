# NOTE: this Makefile is mainly for developer use, as there isn't really
# anything to build.

distapp = gentoo-bashcomp
distver := $(shell date -u +%Y%m%d)
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

tag:
	svn up
	svn cp ../trunk ../tags/release-$(distver)
	@echo
	@echo "tag created remember to check it in"
	@echo

dist: tag
	mkdir -p "$(distpkg)"
	cp AUTHORS COPYING gentoo repoman Makefile TODO "$(distpkg)/"
	svn up
	svn2cl -o "$(distpkg)/"ChangeLog
	tar cjf "$(distpkg).tar.bz2" "$(distpkg)"
	rm -fr "$(distpkg)/"
	@echo "success."

dist-upload: dist
	scp $(distpkg).tar.bz2 dev.gentoo.org:/space/distfiles-local/
	ssh dev.gentoo.org chmod ug+rw /space/distfiles-local/$(distpkg).tar.bz2
