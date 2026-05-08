#!/bin/bash

# Constants
INST_ARCH=x86_64
INST_PATH="/var/opt/Plogue"
LOCAL_ARCH=$(uname -m)
INST_PKGS=
LOCAL_SHARE="$HOME/.local/share"
HOME="/home/$USER"
unzip_tmp=
tmp=

# User-input parameters
install=
files=
help=false


set -euo pipefail

usage() {
    echo "Usage: $0 -i <option> -f <zip files, using wildcard or separated by spaces> [-h for help]"
    echo ""
    echo "Install Options:"
    echo "  debian              Install in system dirs (Debian distros)"
    echo "  non-debian          Install in system dirs (non-Debian distros)"
    echo "  local               Install in local dirs (atomic distros)"
}

unzip_file(){
    unzip_tmp=$(mktemp -d)
    echo "Unpacking $file into $unzip_tmp"

    mkdir -p $unzip_tmp
    cd "$unzip_tmp"
    unzip -j "$OLDPWD/$file" -d "$unzip_tmp"                # extracts control.tar.* data.tar.* etc.
    INST_PKGS=(`ls "${unzip_tmp}"/*.deb`)    # handles .xz .zst .gz …
    echo $INST_PKGS

}

cleanup() {
    if [[ -d $unzip_tmp ]]; then
        rm -rf "$unzip_tmp"
    fi
    if [[ -d $tmp ]]; then
        rm -rf "$tmp"
    fi
}

error_exit(){
    cleanup
    exit 1
}

ok_exit(){
    cleanup
    exit 0
}

convert_to_file_list(){
    files=(`ls $files`)
}

# Function for Debian-based systems.
# This will internally check for required dependencies
debian_branch() {
    if [[ ! -f /etc/debian_version ]]; then
        echo "Not a debian-based distro, exiting..."
        usage
        error_exit
    else
        echo "Identified Debian-derived distribution."

        echo "This script will require 'sudo' and call 'apt' to install a few .deb files"
        echo "into '${INST_PATH}' and also integrate into your desktop ($HOME/.local/share)"
        echo "It will also try and install any missing dependencies."
        read -p "Continue(Y/N)? " answer
        if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
            echo "Exiting..."
            error_exit
        fi

        for deb in "${INST_PKGS[@]}"; do
        [[ -f $deb ]] || { echo "Package '$deb' not found!" >&2; error_exit; }
        echo "---------------------------------------------------------"
        echo "Installing $deb"
        #sudo dpkg -i $deb
        #dpkg does not automatically install dependencies. and the -y removes some Y/N prompts
        sudo apt install -y "./$deb"
        done
    fi
}



# Function for non-Debian systems
non_debian_branch() {

    echo "Running other-distro install..."
	echo -n "Checking for presence of basic utilities: "
	for cmd in ar tar sudo rsync; do
	  command -v "$cmd" &>/dev/null || {
		echo "ERROR: '$cmd' not found – install binutils (for ar) and tar." >&2
		error_exit
	  }
	done
	echo "Ok!"

	echo "---------------------------------------------------------------------------------"
	echo "This script will attempt to install the necessary files on your system."
	echo "Compatibility may vary, as it was originally designed for Debian-based distros."
	echo "It extracts various .deb files and places the required components accordingly:"
	echo "namely ${INST_PATH}, /usr/lib/vst3 (and CLAP), and /usr/share/doc (and icons)."
	echo "WARNING: THIS MAY CAUSE FILE PERMISSION PROBLEMS ON ATOMIC DISTROS"

	read -p "Continue(Y/N)? " answer

	if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
		echo "Exiting..."
		error_exit
	fi

	# -----------------------------------------------------------------------------#
	# unpack loop
	for deb in "${INST_PKGS[@]}"; do
		[[ -f $deb ]] || { echo "Package '$deb' not found!" >&2; error_exit; }

		#tmp=$(mktemp -d)
		tmp="TMP_EXTRACTED"

		echo "Unpacking $deb into $tmp"

		mkdir -p $tmp
		trap 'rm -rf "$tmp"' RETURN  # clean-up even on failure
		(
			cd "$tmp"
			ar x "$OLDPWD/$deb"                # extracts control.tar.* data.tar.* etc.
			data_archive=$(echo data.tar.*)    # handles .xz .zst .gz …
			[[ -f $data_archive ]] || { echo "No data.tar.* inside $deb" >&2; error_exit; }

			tar --extract \
			--file="$data_archive" \
			--directory="." \
			--preserve-permissions \
			--no-same-owner
		)
	done

	#We could have extracted to "/" but this is too dangerous!

	#we want to fake dpkg remember? all that is root:root
	sudo chown -R root:root $tmp/ 

	echo "Copying required files to /opt/Plogue"
	sudo rsync -a --info=progress2 $tmp/opt/Plogue/ /opt/Plogue

	echo "Copying vst3 plugin into /usr/lib/vst3"
	sudo rsync -a --info=progress2 $tmp/usr/lib/vst3/ /usr/lib/vst3

	echo "Copying clap plugin into /usr/lib/clap"
	sudo rsync -a --info=progress2 $tmp/usr/lib/clap/ /usr/lib/clap

	echo "Copying '.desktop' integration to /usr/share/applications"
	sudo rsync -a --info=progress2 $tmp/usr/share/applications/ /usr/share/applications
	
	echo "Copying Documentation to /usr/share/doc"
	sudo rsync -a --info=progress2 $tmp/usr/share/doc/ /usr/share/doc
	
	echo "Copying Icons to /usr/share/icons/hicolor/256x256/apps"
	sudo rsync -a --info=progress2 $tmp/usr/share/icons/hicolor/256x256/apps/ /usr/share/icons/hicolor/256x256/apps

	echo "Refreshing icons and application caches"
	sudo gtk-update-icon-cache --force /usr/share/icons/hicolor
	sudo update-desktop-database /usr/share/applications

	echo "Deleting $tmp"
	sudo rm -rf $tmp
}


# Function for local user installs
local_user_branch() {

    echo "Running local-user install..."
	echo -n "Checking for presence of basic utilities: "
	for cmd in ar tar sudo rsync; do
	  command -v "$cmd" &>/dev/null || {
		echo "ERROR: '$cmd' not found – install binutils (for ar) and tar." >&2
		error_exit
	  }
	done
	echo "Ok!"

	echo "---------------------------------------------------------------------------------"
	echo "This script will attempt to install the necessary files on your system."
	echo "Compatibility may vary, as it was originally designed for Debian-based distros."
	echo "It extracts various .deb files and places the required components accordingly:"
	echo "namely ${INST_PATH}, $HOME/.vst3 (and $HOME/.clap),"
	echo "and $LOCAL_SHARE/doc (and $LOCAL_SHARE/icons)."

	read -p "Continue(Y/N)? " answer

	if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
		echo "Exiting..."
		error_exit
	fi

	# -----------------------------------------------------------------------------#
	# unpack loop
	echo "INST_PKGS: $INST_PKGS"
    tmp=$(mktemp -d)
	for deb in "${INST_PKGS[@]}"; do
		[[ -f $deb ]] || { echo "Package '$deb' not found!" >&2; error_exit; }


		echo "Unpacking $deb into $tmp"

		mkdir -p $tmp
        cd "$tmp"
        ar x "$deb"                # extracts control.tar.* data.tar.* etc.
        data_archive=$(echo data.tar.*)    # handles .xz .zst .gz …
        [[ -f $data_archive ]] || { echo "No data.tar.* inside $deb" >&2; error_exit; }

        tar --extract \
        --file="$data_archive" \
        --directory="." \
        --preserve-permissions \
        --no-same-owner

	done

	echo "User: $USER"
	echo "HOME: $HOME"

    # Make sure files and directories are accessible after sudo
    chmod -R o+r $tmp

	echo "Copying required files to /var/opt/Plogue"
	sudo rsync -a --info=progress2 $tmp/opt/Plogue/ $INST_PATH

	echo "Copying vst3 plugin into $HOME/.vst3"
	rsync -a --info=progress2 $tmp/usr/lib/vst3/ $HOME/.vst3

	echo "Copying clap plugin into $HOME/.clap"
	rsync -a --info=progress2 $tmp/usr/lib/clap/ $HOME/.clap

	echo "Copying '.desktop' integration to $LOCAL_SHARE/applications"
	rsync -a --info=progress2 $tmp/usr/share/applications/ $LOCAL_SHARE/applications

	echo "Copying Documentation to $LOCAL_SHARE/doc"
	rsync -a --info=progress2 $tmp/usr/share/doc/ $LOCAL_SHARE/doc

	echo "Copying Icons to $LOCAL_SHARE/icons/hicolor/256x256/apps"
	rsync -a --info=progress2 $tmp/usr/share/icons/hicolor/256x256/apps/ $LOCAL_SHARE/icons/hicolor/256x256/apps

	echo "Refreshing icons and application caches"
	gtk-update-icon-cache --force $LOCAL_SHARE/icons/hicolor
	update-desktop-database $LOCAL_SHARE/applications


	echo "Deleting $tmp"
	sudo rm -rf $tmp
}

# -----------------------------------------------------------------------------#
# -----------------------------------------------------------------------------#
# -----------------------------------------------------------------------------#
# -----------------------------------------------------------------------------#

# Main program

if [ $? != 0 ] ; then usage ; error_exit ; fi

OPTIND=1
while getopts "h?i:f:" opt; do
    case "$opt" in
    h|\?)
        HELP=true
        ;;
    i)
        install=$OPTARG
        ;;
    f)
        files=$OPTARG
        ;;
    esac
done

if [ $help = true ]; then
    usage
    ok_exit
fi

if [ -z "$install" ] || [ -z "$files" ]; then
    echo "Error: An install option and file must be provided..."
    usage
    error_exit
fi

echo "---------------------------------------------------------"
echo "Plogue Install script"
echo "---------------------------------------------------------"
echo "Local architecture: ${LOCAL_ARCH}"
echo "Install type: ${install}"

if [ "$LOCAL_ARCH" != "$INST_ARCH" ]; then
    echo "Error! You are trying to install '${INST_ARCH}' packages on a '${LOCAL_ARCH}' distro!"
    echo "Please download and run the appropriate archive."
    error_exit
fi

echo -n "Checking for presence of '${INST_PATH}'... "
if [ -d ${INST_PATH} ]; then
    echo " it already exists!"
else
    echo " does not exist."
fi

for file in $files; do
    # check if file exists
    if [[ ! -f $file ]]; then
        echo "File not found!"
        error_exit
    fi

	echo "User: $USER"
	echo "HOME: $HOME"
    # extract *.deb files from zip file and then proceed with installation
    # defining $unzip_tmp and the trap outside of unzip_file is necessary
    # for $unzip_tmp to exist long enough for the different install branches

    unzip_file
    echo "INST_PKGS: $INST_PKGS"
    # perform install based upon install type

    case "$install" in
    local)
        if [ $(id -u) -eq 0 ]; then
            echo "Please run this script as a regular user for local installs!"
            error_exit
        fi
        local_user_branch
        ;;
    debian)
        debian_branch
        ;;
    non-debian)
        non_debian_branch
        ;;
    *)
        echo "Invalid option provided for -i parameter"
        error_exit
    esac
    cleanup
done
ok_exit
