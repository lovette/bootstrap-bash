#!/usr/bin/make -f

SBINDIR = usr/sbin
SHAREDIR = usr/share/bootstrap-bash
STATEDIR = var/bootstrap-bash
MANDIR = usr/share/man/man8

all:

install:
	# Create directories
	install -d $(DESTDIR)/$(SBINDIR)
	install -d $(DESTDIR)/$(SHAREDIR)/lib
	install -d $(DESTDIR)/$(MANDIR)

	# Install admin scripts
	install -m 755 src/bootstrap-bash.sh $(DESTDIR)/$(SBINDIR)/bootstrap-bash

	# Install lib scripts
	install -m 644 src/lib/* $(DESTDIR)/$(SHAREDIR)/lib

	# Install man page
	gzip -c docs/bootstrap-bash.8 > $(DESTDIR)/$(MANDIR)/bootstrap-bash.8.gz

uninstall:
	# Remove admin scripts
	-rm -f  $(DESTDIR)/$(SBINDIR)/bootstrap-bash

	# Remove lib scripts
	-rm -rf $(DESTDIR)/$(SHAREDIR)

	# Remove state files
	-rm -rf $(DESTDIR)/$(STATEDIR)

	# Remove man page
	-rm -f $(DESTDIR)/$(MANDIR)/bootstrap-bash.8.gz

help2man:
	help2man -n "simple server kickstart and software configuration tool" -s 8 -N -o docs/bootstrap-bash.8 "bash src/bootstrap-bash.sh"

doxygen:
	-rm -rf docs/html
	-chmod +x docs/doxygen/sh2doxy.sh
	doxygen docs/doxygen/bootstrap-bash.d

podman-build-docs:
	podman build -f Dockerfile-docs -t bootstrap-bash-docs

podman-run-docs:
	podman run -it --rm -v "${PWD}":/usr/src bootstrap-bash-docs

podman-build-src:
	podman build -f Dockerfile-src -t bootstrap-bash

gitsync:
	@git diff HEAD --quiet || (echo "Working directory is not clean"; exit 1)
	git fetch --all && git reset --hard origin/master && git clean --quiet --force -dx
