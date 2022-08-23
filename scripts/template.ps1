function Check-Command($cmdName) {
  return [bool](Get-Command -Name $cmdName -ErrorAction SilentlyContinue)
}

function Printf($str) {
  Write-Output $str
}

function ExitIfLastCommandFailed($msg) {
  if ($? -ne 0) {
    Write-Error $msg
    exit $?
  }
}

function Clear-Console() {
  Clear-Host
}

function Get-Input($title, $prompt, $default) {
  Clear-Console

  $sep = "-" * $title.Length
  $input = Read-Host -Prompt "$title`n$sep`n$prompt"
  if ($input -eq "") {
    $input = $default
  }
  return $input
}

function Select-Option($title, $prompt, $options, $default) {
  Clear-Console

  # example:
  # 
  # $title
  # - * $title.Length
  # $prompt
  #
  # (<letter>) option1
  # (<letter>) option2  
  # (<letter>) option3
  # ...
  #
  # Enter your choice: <user input>

  $sep = "-" * $title.Length 
  $optionsStr = ""
  $i = 0
  foreach ($option in $options) {
    $letter = [char]([int]([char]'a') + $i)
    $optionsStr += "($letter) $option`n"
    $i++
  }

  $input = Read-Host -Prompt "$title`n$sep`n$prompt`n$optionsStr`nEnter your choice"
  if ($input -eq "") {
    $input = $default
  }

  # verify input
  $input = $input.ToLower()
  if ($input -lt 'a' -or $input -gt [char]([int]('a') + $options.Length - 1)) {
    Write-Error "Invalid input: $input"
    exit 1
  }

  # return the selected option as a number
  return [int]([char]($input) - [int]([char]'a'))
}

function Template-File($file, $vars, $outFile) {
  # example:
  #
  # Template-File "template.txt" @{"<var1>"="value1"; "<var2>"="value2"}
  #
  # should open file template.txt and replace all occurrences of <var1> with value1 and <var2> with value2
  # then save the result to a new file (optionally the same file) in utf8 encoding

  $content = Get-Content -Raw -Path $file
  foreach ($var in $vars.Keys) {
    $content = $content.Replace($var, $vars[$var])
  }

  Set-Content -Path $outFile -Value $content -Encoding utf8
}

echo "Setting up the project..."

Printf "Checking for CMake... "
if (Check-Command "cmake") {
  echo "ok"
} else {
  echo "CMake Not found"
  echo "Please install CMake and add it to your PATH"
  exit 1
}

Printf "Checking for Ninja... "
if (Check-Command "ninja") {
  echo "ok"
} else {
  echo "Ninja Not found"
  echo "Please install Ninja and add it to your PATH"
  exit 1
}

Printf "Checking for git... "
if (Check-Command "git") {
  echo "ok"
} else {
  echo "git Not found"
  echo "Please install git and add it to your PATH"
  exit 1
}

$projectName = Get-Input "Project Name" "Enter the name of the project" ""

$targetType = Select-Option "Project Type" "Select the type of project" @("Executable", "Library")

Switch ($targetType) {
  1 {
    $libraryType = Select-Option "Library Type" "Select the type of library" @("Static", "Shared")
  }
}

$targetName = Get-Input "Target Name" "Enter the name of the target" $projectName

$cxxStandardPre = Select-Option "C++ Standard" "Select a C++ standard to use" @("C++11", "C++14", "C++17", "C++20")

Switch ($cxxStandardPre) {
  0 {
    $cxxStandard = "11"
  }
  1 {
    $cxxStandard = "14"
  }
  2 {
    $cxxStandard = "17"
  }
  3 {
    $cxxStandard = "20"
  }
}

Clear-Console
echo "Creating project..."

# Should we reinitialize the git repository?

# Remove-Item -Path .git -Recurse -Force
# git init

# create build directory, ignore if it already exists
mkdir build -ErrorAction SilentlyContinue

# replace the template file variables with the user input

# templates:
# <PN> = project name but capitalized
# <ProjectName> = normal project name
# <CxxStandard> = C++ standard

Template-File "CMakeLists.txt" @{"<PN>"=$projectName.ToUpper(); "<ProjectName>"=$projectName; "<CxxStandard>"=$cxxStandard} "CMakeLists.txt"

# do the same for the lib/CMakeLists.txt file
# except use only the following:
# <TargetName> = target name
# <ProjectName> = normal project name
# <TargetType> = if library, then "STATIC" or "SHARED" else "BINARY"

$targetType = if ($targetType -eq 1) { if ($libraryType -eq 0) { "STATIC" } else { "SHARED" } } else { "BINARY" }
Template-File "lib/CMakeLists.txt" @{"<TargetName>"=$targetName; "<ProjectName>"=$projectName; "<TargetType>"=$targetType} "lib/CMakeLists.txt"

# rename lib/Quark.cpp to lib/<ProjectName>.cpp
Rename-Item -Path "lib/Quark.cpp" -NewName "$projectName.cpp"

echo "Configuring project..."

cd build
cmake -G Ninja ..
ExitIfLastCommandFailed "Failed to configure project"

cd ..
echo "Done!"
