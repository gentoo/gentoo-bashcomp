# NOTE: this Makefile is mainly for developer use, as there isn't really
# anything to build.

distapp = gentoo-bashcomp
distver := $(shell date -u +%Y%m%d)
distpkg := $(distapp)-$(distver)

all:
	@echo Nothing to compile.

tag:
	git pull
	git tag -a $(distpkg) -m "tag $(distpkg)"
	@echo
	@echo "created tag $(distpkg) - remember to push it"
	@echo

dist: tag
	git archive --prefix=$(distpkg)/ --format=tar -o $(distpkg).tar $(distpkg)
	mkdir $(distpkg)/
	git log > $(distpkg)/ChangeLog
	tar vfr $(distpkg).tar $(distpkg)/ChangeLog
	bzip2 $(distpkg).tar
	rm -rf $(distpkg)/
	@echo "success."

dist-upload: dist
	scp $(distpkg).tar.bz2 dev.gentoo.org:/space/distfiles-local/
	ssh dev.gentoo.org chmod ug+rw /space/distfiles-local/$(distpkg).tar.bz2
