#!/bin/bash

function command_exists() {
  type "$1" &> /dev/null ;
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

# Get the project name
echo "Project name: "
read ProjectName

# Check if the user wants to
# set a configure script
echo "Do you want to set a configure script? (y/n)"
read ConfigureScript

if [ "$ConfigureScript" = "y" ] ; then
  echo "Configure in file: "
  read ConfigureFile

  if [ ! -f "$ConfigureFile" ] ; then
    printf "\n"
    echo "The configure file does not exist. Please try again."
    exit 1
  fi

  echo "Configure out file: "
  read ConfigureOutFile

  if [ -f "$ConfigureOutFile" ] ; then
    printf "\n"
    echo "The configure out file already exists. Please try again."
    exit 1
  fi

  FileConfigure="configure_file(\"$ConfigureFile\" \"$ConfigureOutFile\" @ONLY)"
fi

# Everything should be ok, so we can
# create the project now
echo "Creating project..."

# Create the build dir
mkdir build

# Use sed to replace the variables
# in the CMakeLists.template.txt file
# and write the result to CMakelists.txt
sed -e "s/<ProjectName>/$ProjectName/g" \
    -e "s/<FileConfigure>/$FileConfigure/g" \
    # <PN> is the project name but in all uppercase
    -e "s/<PN>/$(echo $ProjectName | tr '[:lower:]' '[:upper:]')/g" \
    CMakeLists.template.txt > CMakeLists.txt

# Configure using cmake
cd build

cmake -G Ninja ..
cd ..

echo "Done!"

# Print the next steps
echo "When you're ready to build, run the following commands:"
echo ""
echo "cd build"
echo "ninja"
