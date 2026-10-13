PLUGIN     = check_ntrip_clients
PLUGINDIR  = /usr/lib/nagios/plugins
SUDOERSDIR = /etc/sudoers.d
DESTDIR    =

.PHONY: all check install install-sudoers uninstall

all: check

check:
	bash -n $(PLUGIN)
	visudo -cf sudoers.d/$(PLUGIN)

install:
	install -D -o root -g root -m 0755 $(PLUGIN) $(DESTDIR)$(PLUGINDIR)/$(PLUGIN)

install-sudoers:
	visudo -cf sudoers.d/$(PLUGIN)
	install -D -o root -g root -m 0440 sudoers.d/$(PLUGIN) $(DESTDIR)$(SUDOERSDIR)/$(PLUGIN)

uninstall:
	rm -f $(DESTDIR)$(PLUGINDIR)/$(PLUGIN) $(DESTDIR)$(SUDOERSDIR)/$(PLUGIN)
