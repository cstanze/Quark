#!/usr/bin/env bash

function command_exists() {
  type "$1" &> /dev/null ;
}

function escape_for_sed() {
  echo "$1" | sed -e 's/[\/&]/\\&/g'
}

function propagate_cancel() {
  if [ $? -ne 0 ]; then
    echo "Canceling due to previous error"
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
  alias whiptail=dialog
else
  echo "$(which whiptail)"
fi

# Get the basic project details

ProjectName=$(whiptail --title "Quark Generator" --inputbox "Enter the project name" 8 78 3>&1 1>&2 2>&3)
propagate_cancel

ProjectType=$(whiptail --menu "Select the target type" 15 78 4 \
  "1" "Executable" \
  "2" "Library" \
  --title "Project Type" 3>&1 1>&2 2>&3)
propagate_cancel

case $ProjectType in
  2)
    LibraryType=$(whiptail --menu "Select the library type" 15 78 4 \
      "1" "Static" \
      "2" "Shared" \
      --title "Library Type" 3>&1 1>&2 2>&3)
    propagate_cancel
    ;;
esac


TargetName=$(whiptail --title "Quark Generator" --inputbox "Enter the target name" 8 78 3>&1 1>&2 2>&3)
propagate_cancel

CxxStandardSelection=$(whiptail --menu "Select the C++ standard" 15 78 4 \
  "1" "C++11" \
  "2" "C++14" \
  "3" "C++17" \
  "4" "C++20" \
  --title "C++ Standard" 3>&1 1>&2 2>&3)
propagate_cancel

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

# Remove the git extras
rm -rf include/.keep
rm -rf src/.keep

# Should we reinitialize the git repository?

# rm -rf .git
# git init

# Create the build dir

mkdir -p build

# Use sed to replace the variables
# in the CMakeLists.template.txt file
# and write the result to CMakelists.txt
# <PN> is the project name but in all uppercase

sed -i -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
    -e "s/<PN>/$(escape_for_sed $(echo $ProjectName | tr '[:lower:]' '[:upper:]'))/g" \
    -e "s/<CxxStandard>/$(escape_for_sed $CxxStandard)/g" \
    CMakeLists.txt

sed -i -e "s/<PN>/$(escape_for_sed $(echo $ProjectName | tr '[:lower:]' '[:upper:]'))/g" \
    include/Config.hpp.in

if [ $ProjectType -eq 2 ] ; then
  if [ $LibraryType -eq 1 ] ; then
    sed -i -e "s/<TargetType>/STATIC/g" \
        -e "s/<TargetName>/$(escape_for_sed $TargetName)/g" \
        -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
        lib/CMakeLists.txt
  else
    sed -i -e "s/<TargetType>/SHARED/g" \
        -e "s/<TargetName>/$(escape_for_sed $TargetName)/g" \
        -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
        lib/CMakeLists.txt
  fi  
else
  sed -i -e "s/<TargetName>/$(escape_for_sed $TargetName)/g" \
      -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
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
