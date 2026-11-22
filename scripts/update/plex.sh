#!/bin/bash

# The old downloads.plex.tv repository no longer publishes a Release file, and its
# path contains "/deb/", which also matches the current repo.plex.tv URL. Migrate
# any leftover list instead of matching on that substring.
if [[ -f /etc/apt/sources.list.d/plexmediaserver.list ]] || grep -qs 'downloads.plex.tv' /etc/apt/sources.list.d/plex.list 2> /dev/null; then
    echo_info "Updating plex apt repo endpoint"
    rm -f /etc/apt/sources.list.d/plexmediaserver.list
    rm -f /usr/share/keyrings/plex-archive-keyring.gpg
    rm -f /usr/share/keyrings/plexmediaserver.gpg
    curl -fsSL https://downloads.plex.tv/plex-keys/PlexSign.v2.key | gpg --yes --dearmor -o /usr/share/keyrings/plexmediaserver.v2.gpg 2>> "${log}"
    echo "deb [signed-by=/usr/share/keyrings/plexmediaserver.v2.gpg] https://repo.plex.tv/deb/ public main" > /etc/apt/sources.list.d/plex.list
    apt_update
fi

# removing lockfile for the upgrade script so that it can be re-run as many times as people want
if [ -f "/install/.updateplex.lock" ]; then
    # echo file exists
    rm /install/.updateplex.lock
fi
