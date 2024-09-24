#!/bin/bash

# This will make sure the shell script works independent of where you invoke it from.
# parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
# cd "$parent_path"

# --- colors ---
_Black='\033[0;30m'     && _DarkGray='\033[1;30m'
_Red='\033[0;31m'       && _LightRed='\033[1;31m'
_Green='\033[0;32m'     && _LightGreen='\033[1;32m'
_Orange='\033[0;33m'    && _Yellow='\033[1;33m'
_Blue='\033[0;34m'      && _LightBlue='\033[1;34m'
_Purple='\033[0;35m'    && _LightPurple='\033[1;35m'
_Cyan='\033[0;36m'      && _LightCyan='\033[1;36m'
_LightGray='\033[0;37m' && _White='\033[1;37m'
_Reset='\033[0m' # resets the color to the terminal default

# --- logging ---
LOGPREFIX="Main" # default prefix

# prints a message to stderr and exits with exit code 1
function panic {
    echo -e "$_LightGray [$LOGPREFIX /$_Red Erorr$_LightGray]: $_LightRed$@$_Reset" 1>&2;
    exit 1
}
# prints debug messages if is debug
function debug {
    if [[ $debug ]]; then
        echo -e "$_LightGray [$LOGPREFIX /$_Cyan Debug$_LightGray]: $_LightCyan$@$_Reset";
    fi
}
# prints warning messages
function warn {
    echo -e "$_LightGray [$LOGPREFIX /$_Orange Warn $_LightGray]: $_Yellow$@$_Reset";
}
# prints info messages
function info {
    echo -e "$_LightGray [$LOGPREFIX /$_LightGray Info $_LightGray]: $_White$@$_Reset";
}

function intro {
    info
    info "$_LightBlue    _____                     _____ _    _ "
    info "$_LightBlue   / ____|                   / ____| |  | |"
    info "$_LightBlue  | (___  _   _ _ __   ___  | (___ | |__| |"
    info "$_LightBlue   \___ \| | | | '_ \ / __|  \___ \|  __  |"
    info "$_LightBlue   ____) | |_| | | | | (__ _ ____) | |  | |"
    info "$_LightBlue  |_____/ \__, |_| |_|\___(_)_____/|_|  |_|"
    info "$_LightBlue           __/ |                           "
    info "$_LightBlue          |___/                            "
    info
    info "$_LightGreen         --- Version 1.0.0 alpha ---"
    info "$_LightGreen      --- FabulousCraft Development ---"
    info
}

function help {
    echo "Usage: sync.sh [--clean|--sync|--clean --sync] [OPTIONS]..."
    echo "Synchronize plugins between multiple minecraft servers."
    echo
    echo " -h, --help          Shows this message"
    echo " -s, --source        sets the source directory where your shared plugins are"
    echo " -t, --target        sets the target directory to place your shared plugins"
    echo " -d, --debug         enables debug messages"
    echo " --disable-intro     disables the intro message"
}

# --- parse arguments ---
# defaults
source="../shared/plugins"
target="./plugins"
# define arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --clean) clean=1 ;;
        --sync) sync=1 ;;
        -h|--help) help ; exit 0 ;;
        -s|--source) source="$2"; shift ;;
        -t|--target) target="$2"; shift ;;
        -d|--debug) debug=1 ;;
        --disable-intro) nointro=1 ;;
        *) echo "sync.sh: invalid option -- $1"; help; exit 1 ;;
    esac
    shift
done

if [[ $clean == '' ]] && [[ $sync == '' ]]; then
    # panic "No task specified, run with -h for help"
    help
    exit 0
fi

if [[ $nointro == '' ]]; then
    intro
fi

# get parent directory
source_dir="$( cd "$source" 2>/dev/null && pwd )"
# get parent directory
target_dir="$( cd "$target" 2>/dev/null && pwd )"

debug "absolute source directory: \"$source_dir\""
debug "absolute target directory: \"$target_dir\""

if [[ $source_dir == '' ]]; then
    panic "invalid source directory \"$source\"!"
fi

if [[ $target_dir  == '' ]]; then
    panic "invalid target directory \"$target\"!"
fi

# Function Definition
function reletive_to_target_directory {
   echo $( realpath -s --relative-to=$target_dir $1 )
}

function do_clean {
    LOGPREFIX='Clean'

    info "removing existing hardlinks..."
    HFILES="$( find $target_dir -type f -links +1 2>&1)"
    if [[ $? != 0 ]]; then
        panic "failed to list hardlinks for target directory \"$target_dir\", message: \"$HFILES\", check if source and target are correct or run with -d for debug info"
    fi
    if [[ $HFILES == '' ]]; then
        warn "no hardlink found in target directory \"$target_dir\""
    fi
    # remove hardlinks
    while IFS= read -r line; do
        if [[ $line != '' ]] && [[ -f $line ]]; then
            debug "removing \"$line\"..."
            rm "$line"
            if [[ $? != 0 ]]; then
                panic "failed to remove \"$line\", check if source and target are correct or run with -d for debug info"
            fi
        fi
    done <<< "$HFILES"

    info "removing existing symlinks..."
    # find $target_dir -xtype l -delete
    HFILES="$( find -L $target_dir -maxdepth 1 -xtype l 2>&1)"
    if [[ $? != 0 ]]; then
        panic "failed to list symlinks for target directory \"$target_dir\", message: \"$HFILES\", check if source and target are correct or run with -d for debug info"
    fi
    if [[ $HFILES == '' ]]; then
        warn "no hardlink found in target directory \"$target_dir\""
    fi
    while IFS= read -r line; do
        if [[ $line != '' ]] && [[ -d $line ]]; then
            basename_file=$( basename "$line" )
            debug "removing \"$line\"..."
            rm "$line"
            if [[ $? != 0 ]]; then
                panic "failed to remove \"$line\", check if source and target are correct or run with -d for debug info"
            fi
        fi
    done <<< "$HFILES"
    # remove broken hardlinks that are not preserved
    info "removing broken hardlinks..."
    HFILES="$( find $source_dir/*.jar -type f 2>&1)"
    if [[ $? != 0 ]]; then
        panic "failed to list plugin jar files in source directory \"$source_dir\", message: \"$HFILES\", check if source and target are correct or run with -d for debug info"
    fi
    if [[ $HFILES == '' ]]; then
        warn "no plugin jar file was found in source directory \"$source_dir\""
    fi
    while IFS= read -r line; do
        if [[ $line != '' ]]; then
            basename_file=$( basename "$line" )
            src=$( echo "$line" )
            dst=$( echo "$target_dir/$basename_file" )
            if [[ -f $dst ]]; then
                debug "removing \"$dst\" to be replaced with a hardlink to \"$src\"..."
                rm "$dst"
                if [[ $? != 0 ]]; then
                    panic "failed to remove \"$dst\", check if source and target are correct or run with -d for debug info"
                fi
            fi
        fi
    done <<< "$HFILES"
}

function do_sync {
    LOGPREFIX='Sync'

    info "creating hardlink for plugin jar files..."
    HFILES="$( find $source_dir/*.jar -maxdepth 1 -type f )"
    if [[ $? != 0 ]]; then
        panic "failed to list plugin jar files in source directory \"$source_dir\", message: \"$HFILES\", check if source and target are correct or run with -d for debug info"
    fi
    if [[ $HFILES == '' ]]; then
        warn "no plugin jar file was found in source directory \"$source_dir\""
    fi
    while IFS= read -r line; do
        if [[ $line != '' ]]
        then
            # create relative hardlink
            basename_file=$( basename "$line" )
            src=$( echo "$line" )
            dst=$( echo "$target_dir/$basename_file" )
            debug "creating hardlink from \"$dst\" to \"$src\"..."
            ln_result="$( ln "$src" "$dst" 2>&1 )"
            if [[ $? != 0 ]]; then
                warn "failed to create hardlink for \"$basename_file\", message: \"$ln_result\""
            fi
        fi
    done <<< "$HFILES"

    info "creating softlink for plugin jar files..."
    HFILES="$( find $source_dir -maxdepth 1 -mindepth 1 -type d )"
    if [[ $? != 0 ]]; then
        panic "failed to list plugin data directoris in source directory \"$source_dir\", message: \"$HFILES\", check if source and target are correct or run with -d for debug info"
    fi
    if [[ $HFILES == '' ]]; then
        debug "no plugin data directory was found in source directory \"$source_dir\""
    fi
    while IFS= read -r line; do
        if [[ $line != '' ]]
        then
            # create relative softlink
            relative_dir=$( reletive_to_target_directory "$line" )
            basename_dir=$( basename "$line" )
            src=$( echo "$relative_dir" )
            dst=$( echo "$target_dir/$basename_dir" )
            debug "creating softlink from \"$dst\" to \"$src\"..."
            ln_result="$( ln -nsf "$src" "$dst" 2>&1 )"
            if [[ $? != 0 ]]; then
                warn "failed to create softlink for \"$basename_dir\", message: \"$ln_result\""
            fi
        fi
    done <<< "$HFILES"

}

if [[ $clean ]]; then
    do_clean
fi

if [[ $sync ]]; then
    do_sync
fi