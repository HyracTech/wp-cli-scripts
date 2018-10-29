#! /bin/bash

#formats of a function
#function name(){ Commands }
#name(){ commands}
#sequence of calling the function is very important, but declaration can be in any sequence
#To call a function just write its name e.g  quit 

#Passing an argument
function print(){
  # $1 is first argument given, $2 is second argument
  echo $1 $2
}

#calling the print function with two arguments
#print Hello world

#Function to quit the script
#function quit (){ exit }

#Variables
#By default all variables declared in a shell script are global variables
# To make a local variable use keyword 'local' e.g local name=$1
#function print(){ local name=$1 echo "the name is $name" }

function is_file_exist(){
  local file="$1"
  [[ -f "$file" ]] && return 0 || return 1
}

#check if any argument ia passed from the terminal and give a mesage
function usage(){
  echo "You need to provide an argument : "
  echo "usage : $0 file_name"
}
# $# will give all the arguments passed in the terminal
[[ $# -eq 0 ]] && usage

if ( is_file_exist "$1")
then
  echo "File found"
else
  echo "File not found"
fi

