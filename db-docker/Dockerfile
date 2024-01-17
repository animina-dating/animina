FROM postgres:16

ADD "./dumps/*.sh"   "/docker-entrypoint-initdb.d/"
#ADD "./dumps/*.sql"  "/docker-entrypoint-initdb.d/"

EXPOSE 5432


# For Emacs:
# Local Variables:
# mode: unix-shell-script
# indent-tabs-mode:nil
# tab-width:2
# c-basic-offset:2
# End:
# For VIM:
# vim:set ft=dockerfile softtabstop=2 shiftwidth=2 tabstop=2 expandtab:

