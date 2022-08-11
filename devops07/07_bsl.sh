#!/bin/bash

# Bash Scripting Lab: Write a script that does the following:
# 
# Part 1: Install + Start nginx
# * Install nginx using the systems package manager
# * Start the nginx service
# * Send a message of completion to the screen
# 
# Part 2: Multi-Distro Support (RHEL + Debian)
# * The user can pass their distribution in as a parameter. For now the parameters are either “debian” or “redhat”
# * If debian is passed in, the apt package manager should be used to install nginx
# * If redhat is passed in, the yum or dnf package manager should be used to install apache
# * The user should see a message about which package manager we are going to use for the install before it happens
# 
# Part 3: Extend for Usability
# * If the user passes an “-h” or “--help” as a parameter, they should be get a message that tells them how to use the script
# * If no distribution is included by the user, the same message should be shown to the user.
# 
# Bonus: Some Checks for Robustness
# * Autodetect distribution
# * Don’t run install if package is already installed
# * Don’t start service if service is already started


# Exit program with code 1, displaying stderr and provided text 
die() {
    echo >&2 "$@"
    exit 1
}

# Display help text
help() {
    echo "DevOps Anthology, Class 7 Lab: Bash Scripting"
    echo "Download, install, and enable nginx on a modern (systemd-based) Debian (apt)"
    echo "or RHEL (yum) system, in an at least somewhat robust manner. Requires root."
    echo
    echo "Usage: ./07_bsl.sh [-h] [-d (debian|redhat)]"
    echo "  -h|--help    Displays this help text"
    echo "  -d|--distro  Set distro by ID (\"debian\" and \"redhat\" supported)"
    echo "               If none provided, will attempt to autodetect supported distros"
    echo
}

# Get options & perform option/parameter validation
getopts_and_validation() {
    while [[ "$#" -gt 0 ]]; do
        #echo "D: Parsing arg \"$1\""
        arg="$1"
        case "$1" in
            # convert "--opt=the value" to --opt "the value".
            # quotes around the = sign is a workaround for a bug in emacs syntax parsing
            # Source: https://stackoverflow.com/a/6310937
            --*'='*) shift; set -- "${arg%%=*}" "${arg#*=}" "$@"; continue;;
            -h|--help)  # display help text and exit
                help
                exit;;
            -d=*|--distro=*) # set distro (equals-separated)
                #echo "D: Setting \$distro to \"${1#*=}\""
                distro="${1#*=}"
                validate_distro "$distro"
                shift;;
            -d|--distro)  # set distro (space-separated)
                #echo "D: Setting \$distro to \"$2\""
                distro="$2"
                validate_distro "$distro"
                shift; shift;;
            -*|--*) # any other parameters
                die "E: Invalid option \"$arg\"";;
            *)
                break;; # end of parameters list
        esac
    done
}

# There's no canonical best way to detect a Linux distro because distros vary wildly and the semantics for /etc/os-release are, accordingly, very broad.
# (There's also the remote possibility of triggering a malicious execution, since this file is globally writable.)
# For more info on the types of shenanigans possible there: https://unix.stackexchange.com/a/433245
# Even though it's not actually built for this use case, the best way is probably still to just grep through it for ID and ID_LIKE, since uname isn't sufficient here and there's not really a better way to do it without adding a third-party dependency.
# Note that parameter expansion requires bash 4 to be installed; it's used here to convert values to lowercase.
# Sources for the code patterns used here: https://unix.stackexchange.com/a/498788, https://stackoverflow.com/a/27679748
detect_distro() {
    ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
    ID_LIKE=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release | tr -d '"')
    if [[ "${ID,,}" == "debian" || "${ID_LIKE,,}" == *"debian"* || "${ID,,}" == "ubuntu" || "${ID_LIKE,,}" == *"ubuntu"* ]] ; then
        echo "I: Debian distro detected"
        distro="debian"
    elif [[ "${ID,,}" == "rhel" || "${ID_LIKE,,}" == *"rhel"* || "${ID,,}" == "centos" || "${ID_LIKE,,}" == *"centos"* ]] ; then
        echo "I: Red Hat distro detected"
        distro="redhat"
    else
        die "E: Distro not provided and autodetection failed. Exiting..."
    fi
}

# Parameter validation: distro should be either "debian" or "redhat"
validate_distro() {
    echo "$distro" | grep -E -q '^(debian)|(redhat)$' || die "E: Invalid distro \"$distro\" (should be either \"debian\" or \"redhat\")";
}

# Debian: install nginx, if not installed already
debian_install_nginx() {
    if sudo apt list nginx; then
        echo "I: nginx already installed, skipping apt-get install"
    else
        if sudo apt update; then
            echo "W: repolist update failed, attempting to install anyways..."
        fi
        if sudo apt-get install -y nginx; then
            echo "I: nginx successfully installed"
        else
            die "E: nginx failed to install"
        fi
    fi
}

# RHEL: install nginx, if not installed already
redhat_install_nginx() {
    if sudo yum list installed nginx; then
        echo "I: nginx already installed, skipping yum install"
    else
        if sudo yum update; then
            echo "W: repolist update failed, attempting to install anyways..."
        fi
        if sudo yum install -y nginx; then
            echo "I: nginx successfully installed"
        else
            die "E: nginx failed to install"
        fi
    fi
}

# Enable the nginx service. Works the same on both RHEL and Debian now, since they both use systemd.
enable_nginx() {
    if sudo systemctl is-enabled --quiet nginx; then
        echo "I: nginx already enabled"
    else
        if sudo systemctl enable nginx; then
            echo "I: nginx successfully started and enabled"
        else
            die "E: nginx failed to start"
        fi
    fi
}

main() {

    # Initialize vars before doing anything
    distro=""

    # Get options and perform validation
    getopts_and_validation "$@"

    # Distro autodetection
    if [ "$distro" == "" ] ; then
        echo "I: No distro provided, autodetecting..."
        detect_distro
    fi

    # Install nginx
    if [ "$distro" == "debian" ] ; then
        echo "I: Debian distro set or autodetected, installing with apt-get..."
        debian_install_nginx
    elif [ "$distro" == "redhat" ] ; then
        echo "I: Red Hat distro set or autodetected, installing with yum..."
        redhat_install_nginx
    else
        die "E: Unsupported distro passed, parameter validation is probably broken. Exiting..."
    fi

    # Wait a second, just in case of unknown unknowns
    sleep 1

    # Start and enable nginx
    enable_nginx

    # Success!
    echo "I: nginx is installed, started, and enabled. Exiting..."
    exit

}

# Computer. Do the thing, pls.
main "$@"
