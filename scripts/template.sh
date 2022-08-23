#!/usr/bin/env bash

function command_exists() {
  type "$1" &> /dev/null ;
}

function escape_for_sed() {
  echo "$1" | sed -e 's/[\/&]/\\&/g'
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

echo "Should we generate a library or binary? [lib/bin] "
read ProjectType

if [ "$ProjectType" != "lib" ] && [ "$ProjectType" != "bin" ] ; then
  echo "Invalid project type. Please try again."
  exit 1
fi

if [ "$ProjectType" == "lib" ] ; then
  echo "Library type [static/shared]: "
  read LibraryType

  if [ "$LibraryType" != "static" ] && [ "$LibraryType" != "shared" ] ; then
    echo "Invalid library type. Please try again."
    exit 1
  fi
fi

# Get name of library/binary
echo "Name of library/binary: "
read TargetName

# Everything should be ok, so we can
# create the project now
echo "Creating project..."

# Remove the git garbage
rm -rf include/.keep
rm -rf src/.keep
rm -rf .git

git init # Reinitialize git with the new project

# Create the build dir
mkdir -p build

# Use sed to replace the variables
# in the CMakeLists.template.txt file
# and write the result to CMakelists.txt
# <PN> is the project name but in all uppercase
sed -i -e "s/<ProjectName>/$(escape_for_sed $ProjectName)/g" \
    -e "s/<PN>/$(escape_for_sed $(echo $ProjectName | tr '[:lower:]' '[:upper:]'))/g" \
    CMakeLists.txt

sed -i -e "s/<PN>/$(escape_for_sed $(echo $ProjectName | tr '[:lower:]' '[:upper:]'))/g" \
    include/Config.hpp.in

if [ "$ProjectType" == "lib" ] ; then
  if [ "$LibraryType" == "static" ] ; then
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

# Print the next steps
echo "When you're ready to build, run the following commands:"
echo ""
echo "cd build"
echo "ninja"
