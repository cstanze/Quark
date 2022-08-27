#!/usr/bin/env bash

function command_exists() {
  type "$1" &> /dev/null ;
}

function escape_for_sed() {
  echo "$1" | sed -e 's/[\/&]/\\&/g'
}

function propagate_cancel() {
  if [ $? -ne 0 ]; then
    echo "Canceling due to previous error: $1"
    exit $?
  fi
}

echo "Setting up the project..."

# Check if basic commands exist

printf "Checking for CMake... "
if ! command_exists cmake ; then
  printf "\n"
  echo "CMake is not installed. Please install it and try again."
  exit 1
fi
echo "ok"

printf "Checking for ninja... "
if ! command_exists ninja ; then
  printf "\n"
  echo "ninja is not installed. Please install it and try again."
  exit 1
fi
echo "ok"

printf "Checking for git... "
if ! command_exists git ; then
  printf "\n"
  echo "git is not installed. Please install it and try again."
  exit 1
fi
echo "ok"

printf "Checking for a suitable dialog tui... "
if ! command_exists whiptail ; then
  # whiptail is not available, try dialog
  if ! command_exists dialog ; then
    printf "\n"
    echo "Neither whiptail nor dialog are installed. Please install one of them and try again."
    exit 1
  fi

  # dialog is available, should be fine to use it
  echo "$(which dialog)"
  d=dialog
else
  echo "$(which whiptail)"
  d=whiptail
fi

# Get the basic project details

ProjectName=$($d --title "Quark Setup" --inputbox "Enter the project name" 8 78 3>&1 1>&2 2>&3)
propagate_cancel $LINENO

ProjectType=$($d --title "Quark Setup" --menu "Select the target type" 15 78 2 \
  "1" "Executable" \
  "2" "Library" 3>&1 1>&2 2>&3)
propagate_cancel $LINENO

case $ProjectType in
  2)
    LibraryType=$($d --title "Quark Setup" --menu "Select the library type" 15 78 4 \
      "1" "Static" \
      "2" "Shared" 3>&1 1>&2 2>&3)
    propagate_cancel $LINENO
    ;;
esac


TargetName=$($d --title "Quark Setup" --inputbox "Enter the target name" 8 78 3>&1 1>&2 2>&3)
propagate_cancel $LINENO

CxxStandardSelection=$($d --title "Quark Setup" --menu "Select the C++ standard" 15 78 4 \
  "1" "C++11" \
  "2" "C++14" \
  "3" "C++17" \
  "4" "C++20" 3>&1 1>&2 2>&3)
propagate_cancel $LINENO

case $CxxStandardSelection in
  1)
    CxxStandard="11"
    ;;
  2)
    CxxStandard="14"
    ;;
  3)
    CxxStandard="17"
    ;;
  4)
    CxxStandard="20"
    ;;
esac

echo "Creating project..."

# Should we reinitialize the git repository?

# rm -rf .git
# git init

# Create the build dir

mkdir -p build

# Use sed to replace the variables
# in the CMakeLists.template.txt file
# and write the result to CMakelists.txt
# <PN> is the project name but in all uppercase
# <ProjectName> is the original name input
# <pn> is the opposite of <PN>
# <CxxStandard> is the selected C++ standard
# <TargetType> is either "STATIC", "SHARED", or "BINARY"
# <TargetName> is the original target name input

sed -i '' -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
    -e "s/<PN>/$(escape_for_sed $(echo $ProjectName | tr '[:lower:]' '[:upper:]'))/g" \
    -e "s/<pn>/$(escape_for_sed $(echo $ProjectName | tr '[:upper:]' '[:lower:]'))/g" \
    -e "s/<CxxStandard>/$(escape_for_sed $CxxStandard)/g" \
    CMakeLists.txt

sed -i '' -e "s/<PN>/$(escape_for_sed $(echo $ProjectName | tr '[:lower:]' '[:upper:]'))/g" \
    -e "s/<pn>/$(escape_for_sed $(echo $ProjectName | tr '[:upper:]' '[:lower:]'))/g" \
    include/Config.hpp.in

if [ $ProjectType -eq 2 ] ; then
  if [ $LibraryType -eq 1 ] ; then
    sed -i '' -e "s/<TargetType>/STATIC/g" \
        -e "s/<TargetName>/$(escape_for_sed $TargetName)/g" \
        -e "s/<pn>/$(escape_for_sed $(echo $ProjectName | tr '[:upper:]' '[:lower:]'))/g" \
        -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
        lib/CMakeLists.txt
  else
    sed -i '' -e "s/<TargetType>/SHARED/g" \
        -e "s/<TargetName>/$(escape_for_sed $TargetName)/g" \
        -e "s/<pn>/$(escape_for_sed $(echo $ProjectName | tr '[:upper:]' '[:lower:]'))/g" \
        -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
        lib/CMakeLists.txt
  fi  
else
  sed -i '' -e "s/<TargetName>/$(escape_for_sed $TargetName)/g" \
      -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
      -e "s/<pn>/$(escape_for_sed $(echo $ProjectName | tr '[:upper:]' '[:lower:]'))/g" \
      -e "s/<TargetType>/BINARY/g" \
      lib/CMakeLists.txt
fi

mv lib/Quark.cpp lib/$ProjectName.cpp

echo "Configuring project..."

# Configure using cmake
cd build

cmake -G Ninja ..
cd ..

echo "Done!"
