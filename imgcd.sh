#!/bin/bash
# Create an image file of a CD

###############################################################################
# Constants
# Declare variables that will not change
###############################################################################
readonly DATE=$(which date)           || die "Can't find 'date' command"
readonly LSDVD=$(which lsdvd)         || die "Can't find 'lsdvd' command"
readonly SETCD=$(which setcd)         || die "Can't find 'setcd' command"
readonly CLEAR=$(which clear)         || die "Can't find 'clear' command"
readonly RIPPER=$(which HandBrakeCLI) || die "Can't find 'HandBreakCLI' command"
readonly DD=$(which ddrescue)         || die "Can't find 'ddrescue' command"
readonly ISOSIZE=$(which isosize)     || die "Can't find 'isosize' command"
readonly ISOINFO=$(which isoinfo)     || die "Can't find 'isoinfo' command"
readonly SENDMAIL=$(which ssmtp)      || die "Can't find 'ssmtp' command"
readonly ADDRESS="$TXT"
readonly CD_DEV="/dev/cdrom"
readonly MAP="/tmp/ddrescue.map"

###############################################################################
# Initialize
# Initialize variables
###############################################################################
TitleName=""
StartTime=""
EndTime=""
Status=""
BlockSize=""
BlockCount=""
OutputDir=""
OutputFormat=""

###############################################################################
# Colors
# Declare colors as constants
###############################################################################
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'

###############################################################################
# die ()
# Output a message and exit with an error
###############################################################################
die () { printf '%b %s %b \n' "$RED" "$@" "$WHITE" 1>&2; exit 1; }

###############################################################################
# notify ()
# Send notice via email
###############################################################################
notify() { 
  printf "%s\n" "$@" | "$SENDMAIL" "$ADDRESS" 
}

###############################################################################
# test_prereq ()
# Make sure we can find everything
###############################################################################
test_prereq () {
  [[ -x "$LSDVD" ]]       || die "Can't run $LSDVD; exiting!"
  [[ -x "$SETCD" ]]       || die "Can't run $SETCD; exiting!"
  [[ -x "$CLEAR" ]]       || die "Can't run $CLEAR; exiting!"
  [[ -x "$DD" ]]          || die "Can't run $DD; exiting!"
  [[ -x "$ISOSIZE" ]]     || die "Can't run $ISOSIZE; exiting!"
  [[ -x "$ISOINFO" ]]     || die "Can't run $ISOINFO; exiting!"
  [[ -r "$CD_DEV" ]]      || die "Can't read $DVD_DEV; exiting!"
}

###############################################################################
# title ()
# Clear the screen and output the title, making it look like we 
#   are updating just the fields instead of printing everything
#   over and over.
###############################################################################
output_title () { 
  $CLEAR
  # These next 3 are strange.
  #   First printf just sets the color
  #   Next line prints out 81 '=' by giving 81 parameters printed with a width of 0
  #   Last line gives us the newline
  printf '%b' "$CYAN"
  printf '=%.0s' {1..81}
  printf '\n'

  printf '%b  The Automated CD Imager \n' "$BLUE"

  printf '%b' "$CYAN"
  printf '=%.0s' {1..81}
  printf '\n'
  printf '%b  Block Size:%b  %-43s %b Started:%b  %-8s \n' \
    "$GREEN" \
    "$WHITE" \
    "$BlockSize" \
    "$GREEN" \
    "$WHITE" \
    "$StartTime"
  printf '%b  Block Count:%b %-43s %b Finished:%b %-8s \n' \
    "$GREEN" \
    "$WHITE" \
    "$BlockCount" \
    "$GREEN" \
    "$WHITE" \
    "$EndTime"
  printf '%b  Title Name: %b %-43s\n' \
    "$GREEN" \
    "$WHITE" \
    "$TitleName" 
  printf '%b  Saved As:   %b %-43s \n\n' \
    "$GREEN" \
    "$WHITE" \
    "$OutputDir$TitleName$OutputFormat"
  printf '%b  Status:     %b %-43s \n' \
    "$GREEN" \
    "$RED" \
    "$Status"
  printf '%b' "$CYAN"
  printf '=%.0s' {1..81}
  printf '\n'
  printf '%b' "$WHITE"
}

###############################################################################
# get_cd_info ()
# Use isoinfo to get cd title and block information
###############################################################################
get_cd_info () {
  local cdinfo

  # get a lot of info from isoinfo and save it in a var
  cdinfo=$($ISOINFO -d -i "$CD_DEV") || ""

  # extract the title name from the line that looks like
  #   "Volume id: <title>"
  TitleName=$(echo "$cdinfo" | awk -F": " '/Volume id/ {print $2}')
  if [ -z "$TitleName" ]
  then
    TitleName="Rip-$StartDay-$StartTime"
  fi

  # extract the block size from the line that looks like
  #   "Logical block size is: <number>"
  BlockSize=$(echo "$cdinfo" | awk -F": " '/Logical block size is/ {print $2}')

  # extract the block count from the line that looks like
  #   "Volume size is: <number>"
  BlockCount=$(echo "$cdinfo" | awk -F": " '/Volume size is/ {print $2}')
}

###############################################################################
# rip_it
# Rip the CD to an iso using dd
###############################################################################
rip_it() {

  "$DD" \
    "$CD_DEV" \
    "$OutputDir$TitleName$OutputFormat" \
    "$MAP"

  #"$DD" \
    #if="$CD_DEV" \
    #of="$OutputDir$TitleName$OutputFormat" \
    #bs="$BlockSize" \
    #count="$BlockCount" \
    #status=progress
}

###############################################################################
# Main
# Loop until a disk is inserted
###############################################################################

test_prereq

Status="Checking for Disc..."
output_title

while true; do

  cdstatus=$($SETCD -i) 2> /dev/null

  case "$cdstatus" in
    *'Disc found'*)
      StartDay=$($DATE +"%F")
      StartTime=$($DATE +"%T")
      EndTime="---"
      get_cd_info
      Status="Imaging..."
      OutputDir="./"
      OutputFormat=".iso"
      output_title
      rip_it
      EndTime=$($DATE +"%T")
      notify  "====================" "Image Complete" "Title: $TitleName" \
        "Start: $StartTime" "End: $EndTime" "====================" 
      eject
    ;;
    *'not ready'*)
      Status="Waiting for drive to be ready..."
      output_title
      sleep 10;
    ;;
    *'is open'*)
      Status="Drive is open..."
      output_title
      sleep 10;
    ;;
    *'No disc'*)
      Status="No disc is inserted..."
      output_title
      sleep 10;
    ;;
    *)
      Status="ERROR"
      output_title
      die "Confused by setcd -i, bailing out:
      
      $cdinfo"
  esac
done

# End
