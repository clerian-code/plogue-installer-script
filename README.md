# plogue-installer-script
A generalized version of plogue's linux install script that adds support for atomic distros by extracting and installing files into the local user profile. 

The original Debian and Non-Debian functionality is retained, but is handled by the flags `-i debian` and `-i non-debian` instead of purely being auto-detected by the script. 

The Debian option will throw an error if it detects that the OS is not actually a Debian-based distro.

# How to use
1. Download `plogue-installer.sh` from this repo.
2. Make `plogue-installer.sh` executable by running `chmod +x plogue-installer.sh` from a terminal in the directory with the script.
3. Download a Linux build of one of plogue's plugins from https://www.plogue.com/downloads.html
4. From the directory containing plogue-installer.sh, run `./plogue-installer.sh --help` to see options.

## Local Install (Atomic Distros)
From the directory containing plogue-installer.sh, run 
```
./plogue-installer.sh -i local -f path_to_zip_file_here
```
If you were to use this on the current version of OPS7 (at the time of writing this, 1.124), a fully qualified example would be 
```
./plogue-installer.sh -i local -f LINUX_plogue-chipsynth-ops7_1.124~beta1_x86_64.zip
```

# Known Issues
Attempting to use wildcard expansion in the filename to install multiple files will result in only installing the first matching file.
