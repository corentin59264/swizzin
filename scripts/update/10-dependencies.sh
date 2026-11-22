#!/bin/bash
# Ensures that dependencies are installed and corrects them if that is not the case.

# Debian 13 dropped software-properties-common. Every older supported release still
# needs apt-add-repository before universe/contrib can be enabled.
if [[ $(_os_codename) != "trixie" ]]; then
    if ! which add-apt-repository > /dev/null; then
        apt_install software-properties-common # Ubuntu may require universe/mutliverse enabled for certain packages so we must ensure repos are enabled before deps are attempted to installed
    fi
fi

if [[ $(_os_distro) == "ubuntu" ]]; then
    if [[ $(_os_codename) == "jammy" ]]; then
        if ! grep -s 'ubuntu-toolchain-r' /etc/apt/sources.list.d/ubuntu-toolchain-r-ubuntu-ppa-jammy.list 2> /dev/null | grep -q -v '^#'; then
            echo_info "Adding toolchain repo"
            add-apt-repository -y ppa:ubuntu-toolchain-r/ppa >> ${log} 2>&1
            trigger_apt_update=true
        fi
    fi
    listFile="/etc/apt/sources.list.d/ubuntu.sources"
    if [[ -f ${listFile} ]]; then
        components=(universe multiverse restricted)
        tmpFile=$(mktemp)
        cp "$listFile" "$tmpFile"
        for component in "${components[@]}"; do
            sed -i "/^Components:/ {
                /$component/! s/$/ $component/
            }" "$tmpFile"
        done

        if ! cmp -s "$listFile" "$tmpFile"; then
            trigger_apt_update=true
            mv "$tmpFile" "$listFile"
        else
            rm "$tmpFile"
        fi
    else
        if ! grep 'universe' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling universe repo"
            add-apt-repository -y universe >> ${log} 2>&1
            trigger_apt_update=true
        fi
        if ! grep 'multiverse' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling multiverse repo"
            add-apt-repository -y multiverse >> ${log} 2>&1
            trigger_apt_update=true
        fi
        if ! grep 'restricted' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling restricted repo"
            add-apt-repository -y restricted >> ${log} 2>&1
            trigger_apt_update=true
        fi
    fi
elif [[ $(_os_distro) == "debian" ]]; then
    listFile="/etc/apt/sources.list.d/debian.sources"
    if [[ -f ${listFile} ]]; then
        if [[ $(_os_codename) == "trixie" ]]; then
            components=(contrib non-free non-free-firmware)
        else
            components=(contrib non-free)
        fi
        tmpFile=$(mktemp)
        cp "$listFile" "$tmpFile"
        for component in "${components[@]}"; do
            if [[ $(_os_codename) == "trixie" ]]; then
                # "non-free" is a prefix of "non-free-firmware", so match the whole word.
                sed -i -E "/^Components:/ {
                    /[[:space:]]${component}([[:space:]]|\$)/! s/\$/ ${component}/
                }" "$tmpFile"
            else
                sed -i "/^Components:/ {
            /$component/! s/$/ $component/
        }" "$tmpFile"
            fi
        done

        if ! cmp -s "$listFile" "$tmpFile"; then
            trigger_apt_update=true
            mv "$tmpFile" "$listFile"
        else
            rm "$tmpFile"
        fi
    elif [[ $(_os_codename) == "trixie" ]]; then
        # Trixie has no apt-add-repository. Edit a classic sources.list in place when
        # the image has not been converted to deb822.
        for component in contrib non-free non-free-firmware; do
            if [[ -f /etc/apt/sources.list ]] && ! grep -P "\\b${component}(\\s|\$)" /etc/apt/sources.list | grep -q -v '^#'; then
                echo_info "Enabling ${component} repo"
                sed -i -E "/^deb /{
                    /debian/ {
                        /[[:space:]]${component}([[:space:]]|\$)/! s/\$/ ${component}/
                    }
                }" /etc/apt/sources.list
                trigger_apt_update=true
            fi
        done
    else
        if ! grep contrib /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling contrib repo"
            apt-add-repository -y contrib >> ${log} 2>&1
            trigger_apt_update=true
        fi
        if ! grep -P '\bnon-free(\s|$)' /etc/apt/sources.list | grep -q -v '^#'; then
            echo_info "Enabling non-free repo"
            apt-add-repository -y non-free >> ${log} 2>&1
            trigger_apt_update=true
        fi
    fi
fi
if [[ $trigger_apt_update == "true" ]]; then
    apt_update
fi

#space-separated list of required GLOBAL SWIZZIN dependencies (NOT application specific ones)
dependencies="whiptail git sudo curl wget lsof rsyslog fail2ban apache2-utils vnstat tcl tcl-dev build-essential dirmngr apt-transport-https bc uuid-runtime jq net-tools gnupg2 cracklib-runtime unzip ccze cron"

apt_install "${dependencies[@]}"

#shellcheck source=sources/functions/gcc
. /etc/swizzin/sources/functions/gcc
GCC_Jammy_Upgrade
