# Gentoo Linux Bash Shell Command Completion
# Common functions to use in other completions
#
# Copyright 1999-2013 Gentoo Authors
# Distributed under the terms of the GNU General Public License, v2 or later

# Retrieve PORTDIR/PORTDIR_OVERLAY location.
#
# In order of highest to lowest priority:
# /etc/portage/repos.conf{,/*}
# /usr/share/portage/config/repos.conf
# /etc/portage/make.conf
# /etc/make.conf
# /usr/share/portage/config/make.globals
#
# The first two files are in repos.conf format and must be parsed for the
# variable "location".  The rest are make.conf style and are simply sourced
# for PORTDIR and PORTDIR_OVERLAY.  While repos.conf overrides any value of
# PORTDIR set in make.conf, PORTDIR_OVERLAY is incremental (combined across
# available sources).
#
# This would be a hell of a lot simpler if we used portageq, but also about
# 500 times slower.
_portdir() {
    local mainreponame mainrepopath overlayname overlaypath

    if [[ -e @GENTOO_PORTAGE_EPREFIX@/usr/share/portage/config/repos.conf ]]; then
        if [[ ${1} == -o ]]; then
            for overlayname in $(_parsereposconf -l); do
                overlaypath+=($(_parsereposconf ${overlayname} location))
            done

            source @GENTOO_PORTAGE_EPREFIX@/etc/make.conf 2>/dev/null
            source @GENTOO_PORTAGE_EPREFIX@/etc/portage/make.conf 2>/dev/null

            overlaypath+=(${PORTDIR_OVERLAY})

            # strip out duplicates
            overlaypath=($(printf "%s\n" "${overlaypath[@]}" | sort -u))

            echo "${overlaypath[@]}"
        else
            mainreponame=$(_parsereposconf DEFAULT main-repo)
            mainrepopath=$(_parsereposconf ${mainreponame} location)

            echo "${mainrepopath}"
        fi
    else
        source @GENTOO_PORTAGE_EPREFIX@/usr/share/portage/config/make.globals 2>/dev/null
        source @GENTOO_PORTAGE_EPREFIX@/etc/make.conf 2>/dev/null
        source @GENTOO_PORTAGE_EPREFIX@/etc/portage/make.conf 2>/dev/null

        echo "${PORTDIR}"

        if [[ ${1} == -o ]]; then
            echo "${PORTDIR_OVERLAY}"
        fi
    fi
}

# _parsereposconf [-l] <repo> <variable>
#   -l lists available repos
_parsereposconf() {
    local f insection line section v value var

    for f in @GENTOO_PORTAGE_EPREFIX@/usr/share/portage/config/repos.conf \
        @GENTOO_PORTAGE_EPREFIX@/etc/portage/repos.conf \
        @GENTOO_PORTAGE_EPREFIX@/etc/portage/repos.conf/[!.]*[!~]; do

        [[ -f ${f} ]] || continue
        insection=0

        while read -r line; do
            # skip comments and blank lines
            [[ -z ${line} || ${line} == '#'* ]] && continue

            if [[ ${insection} == 1 && ${line} == '['*']' ]]; then
                # End of the section we were interested in so stop
                secname+=(${line//[(\[|\])]/}) # record name for -l
                break
            elif [[ ${line} == '['*']' ]]; then
                # Entering a new section, check if it's the one we want
                section=${line//[(\[|\])]/}
                [[ ${section} == "${1}" ]] && insection=1
                secname+=(${section}) # record name for -l
            elif [[ ${insection} == 1 ]]; then
                # We're in the section we want, grab the values
                var=${line%%=*}
                var=${var// /}
                value=${line#*=}
                value=${value# }
                [[ ${var} == ${2} ]] && v=${value}
            fi
            continue
        done < "${f}"
    done

    if [[ ${1} == -l ]]; then
        echo "${secname[@]}"
    else
        echo "${v}"
    fi
}

# like _pkgname but completes on package names only (no category)
_pkgname_only()
{
    local i pd
    local cur="$1"
    shift
    local dir="$@"

    COMPREPLY=($(compgen -W "$(\
        for pd in $dir ; do \
            builtin cd ${pd}; \
            for i in *-*/${cur}*; do \
                [[ -d ${i} ]] && { local x=${i##*/} ; echo ${x%-[0-9]*}; } \
            done ; \
        done)" -- ${cur}))
}

#
# This function completes package names.
#
# usage: pkgname <mode> <current-directory>
#
# Where mode is one of:
#   -A  Search all available packages (except for those in the overlays)
#   -I  Only search the installed packages
#
# TODO: Look at breaking this function out and making it a "universal"
#       category/package name completion function.
#
_pkgname()
{
    local mode cur portdir only
    mode="$1"
    cur="$2"
    portdir=$(_portdir -o)
    # Ignore '=' at the beginning of the current completion
    [[ ${cur:1:1} == "=" ]] && cur=${cur:2}
    [[ ${cur:0:1} == "=" ]] && cur=${cur:1}
    case $mode in
    -I)
        # Complete either the category or the complete package name
        if [[ $cur == */* ]]; then
        COMPREPLY=($(builtin cd @GENTOO_PORTAGE_EPREFIX@/var/db/pkg; compgen -W "$(compgen -G "$cur*" )" -- $cur))
        else
        COMPREPLY=($(builtin cd @GENTOO_PORTAGE_EPREFIX@/var/db/pkg; compgen -W "$(compgen -G "$cur*" -S /)" -- $cur))
        fi
        # We may just have finished completing the category.
        # Make sure there isn't anything more to complete now.
        if [[ ${#COMPREPLY[@]} == 1 ]]; then
        COMPREPLY=($(builtin cd @GENTOO_PORTAGE_EPREFIX@/var/db/pkg; compgen -W "$(compgen -G "$COMPREPLY*")" -- $cur))
        fi

            if [[ -z "${COMPREPLY}" ]] ; then
                only=1
                _pkgname_only ${cur} @GENTOO_PORTAGE_EPREFIX@/var/db/pkg
            fi
        ;;
    -A)
        # Complete either the category or the complete package name
        if [[ $cur == */* ]]; then
            # Once the category has been completed, it's safe to use ${portdir}
            # to continue completion.
                local ww=$(\
                    for pd in ${portdir} ; do
                        builtin cd ${pd};
                        compgen -W "$(compgen -G "${cur}*")" -- "${cur}" ;
                    done)
                COMPREPLY=($(\
                    for x in ${ww}; do echo $x; done|sort -u
                        ))
            # When we've completed most of the name, also display the version for
            # possible completion.
            if [[ ${#COMPREPLY[@]} -le 1 || ${cur:${#cur}-1:1} == "-" ]] \
                && [[ ${cur} != */ ]]; then
                    # Use the portage cache to complete specific versions from
                    COMPREPLY=(${COMPREPLY[@]} $(
                        for pd in ${portdir}; do
                            if [[ -d ${pd}/metadata/md5-cache ]]; then
                                builtin cd ${pd}/metadata/md5-cache
                                compgen -W "$(compgen -G "${cur}*")" -- "${cur}"
                            elif [[ -d ${pd}/metadata/cache ]]; then
                                builtin cd ${pd}/metadata/cache
                                compgen -W "$(compgen -G "${cur}*")" -- "${cur}"
                            fi
                        done
                    ))
            fi
        else
            # 1. Collect all the categories among ${portdir}
            local ww=$(\
                for pd in ${portdir}; do
                    builtin cd ${pd};
                    compgen -X "!@(*-*|virtual)" -S '/' -G "$cur*";
                done)

            # 2. Now ugly hack to delete duplicate categories
            local w x
            for x in ${ww} ; do w="${x}\n${w}"; done
            local words=$(echo -e ${w} | sort -u)

            COMPREPLY=($(compgen -W "$words" -- $cur))

            if [[ ${#COMPREPLY[@]} == 1 ]]; then
                COMPREPLY=($(compgen -W "$(
                    for pd in ${portdir}; do
                        if [[ -d ${pd}/metadata/md5-cache ]]; then
                            builtin cd ${pd}/metadata/md5-cache
                            compgen -G "$COMPREPLY*"
                        elif [[ -d ${pd}/metadata/cache ]]; then
                            builtin cd ${pd}/metadata/cache
                            compgen -G "$COMPREPLY*"
                        fi
                    done
                )" -- $cur))
            fi
        fi

            if [[ -z "${COMPREPLY}" ]] ; then
                only=1
                _pkgname_only ${cur} ${portdir}
            fi
        ;;
    *)
        # Somebody screwed up! :-)
        ;;
    esac
    # 'equery' wants an '=' in front of specific package versions.
    # Add it if there is only one selected package and it isn't there already.
    if [[ ${#COMPREPLY[@]} == 1 && ${COMP_WORDS[COMP_CWORD]:0:1} != "=" ]]
    then
        [[ -z "${only}" ]] && COMPREPLY=("="$COMPREPLY)
    fi
}

#
# This is an helper function for completion of  "-o <list>" / "--option=<list>"
# kind of command lines options.
#
# Usage: _list_compgen <current> <sep> <item1>[<sep><item2> ...]
# - <current>: what we have so far on the command line
# - <sep>: the separator character used in lists
# - <itemN>: a valid item
# Returns: the function outputs each possible completion (one per line),
# and returns 0. Typical usage is COMPREPLY=($(_list_compgen ...)).
#
# Note: items must not contain the <sep> character (no backslash escaping has
# been implemented).
#
_list_compgen()
{
    # Read the three parameters.
    local current="${1}" ; shift
    local sep="${1}" ; shift
    local items="${*}"

    # This is the maximum number of "<current><sep><other_item>" possible
    # completions that should be listed in case <current> is a valid list.
    # Setting it to a negative value means "no bound" (always list everything).
    # Setting it to 0 means "never list anything" (only suggest <sep>).
    # Setting it to a positive value N means "list up to N possible items, and
    # only suggest <sep> if there are more".
    # It is probably not worth a parameter, thus it will defaults to my
    # prefered setting (1) if not already defined in the environment.
    local max_others_number=${max_others_number:-1}

    # Save IFS. The <sep> character will be used instead in the following.
    local saved_IFS="${IFS}"
    IFS="${sep}"

    # Split the current items list in two parts:
    # - current_item is the last one (maybe partial or even empty)
    # - prefix_item are items are the previous ones
    local current_item="${current##*${sep}}"
    local prefix_items="${current%${current_item}}"

    # Iterate through valid items to recognize those that are:
    # - partial matches of the <current_item>
    # - already used in the list prefix
    # - not used in the list prefix, and not an exact match of <current_item>
    # Also check whether the <current_item> is exactly a valid one.
    local matching_items
    local other_items
    local exact_match
    local my_item
    for my_item in ${items} ; do
        if [[ "${sep}${prefix_items}${sep}" == *"${sep}${my_item}${sep}"* ]] ; then
            # The item has already been used in the list prefix: ignore it.
            continue
        elif [[ "${my_item}" == "${current_item}" ]] ; then
            # The item _exactly_ matches the <current_item>: that means that we
            # will have to suggest some more items to add behind.
            exact_match=1
        elif [[ "${my_item}" == "${current_item}"* ]] ; then
            # The item matches the <current_item>: it will be a possible
            # completion. It will also be a possible additional item in case of
            # exact match.
            matching_items="${matching_items}${sep}${my_item}"
            other_items="${other_items}${sep}${my_item}"
        else
            # The item neither matches the <current_item> nor has been already
            # used: it will only be a possible additional item in case of exact
            # match.
            other_items="${other_items}${sep}${my_item}"
        fi
    done
    matching_items="${matching_items#${sep}}"
    other_items="${other_items#${sep}}"

    # Takes care of the case where <current_item> is not exactly valid but
    # there is only one matching item: force this completion, and handle it
    # just as an exact match.
    if [[ -z "${exact_match}" ]] \
    && [[ "${matching_items}" != *"${sep}"* ]] ; then
        exact_match=1
        current="${current%${current_item}}${matching_items}"
        current_item="${matching_items}"
        matching_items=""
        other_items="${sep}${other_items}${sep}"
        other_items="${other_items/${sep}${current_item}${sep}/${sep}}"
        other_items="${other_items#${sep}}"
        other_items="${other_items%${sep}}"
    fi

    # List all possible completions. They are stored in an array.
    # XXX: maybe if should be COMPREPLY directly? (with no output at the end)
    local my_compreply=()
    local i=0
    if [[ -n "${exact_match}" ]] ; then
        # Found an exact match? Then add "<current>".
        my_compreply[${i}]="${current}"
        let i++
    fi
    if [[ -n "${matching_items}" ]] ; then
        # Found some matching items?
        # Then add "<prefix_items><matching_item>".
        for my_item in ${matching_items} ; do
            my_compreply[${i}]="${prefix_items}${my_item}"
            let i++
        done
    fi
    if [[ -n "${exact_match}" ]] \
    && [[ -n "${other_items}" ]] ; then
        # Found an exact match and some other possible items remain?
        # First, count them:
        local count_others=0
        for my_item in ${other_items} ; do
            let count_others++
        done
        # Then decide how to behave depending on the max_others_number setting:
        if (( max_others_number < 0 )) \
        || (( count_others <= max_others_number )) ; then
            # List the possible "<current><sep><other_item>" completions.
            for my_item in ${other_items} ; do
                my_compreply[${i}]="${current}${sep}${my_item}"
                let i++
            done
        else # Only suggest adding the <sep> character.
            my_compreply[${i}]="${current}${sep}"
            let i++
        fi
    fi

    # Restore IFS.
    IFS="${saved_IFS}"

    # Output the array of possible completions and returns.
    local j=0
    while (( i > j )) ; do
        echo ${my_compreply[$j]}
        let j++
    done
    return 0
}

#
# Helper routine for the subcommand 'meta' of 'equery'
# (Used two times, by _equery and _epkginfo, therefore in an extra function)
#
_equery_meta()
{
    local cur="$1"

    case $cur in
        -*)
            COMPREPLY=($(compgen -W "--help -h --description -d --herd -H --keywords -k --maintainer -m --useflags -u --upstream -U --xml -x" -- $cur))
            ;;
        *)
            _pkgname -A $cur
            ;;
    esac
}
