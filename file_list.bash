#!/bin/bash
#################################################################################
# File name: file_list.bash							                                #
# 										                                                  #
# Description:									                                         #
# 	Creates file list                                                            #
#										                                                  #
# Author: Amir Albeck								                                   #
#										                                                  #
#################################################################################

# script default parameters
error_log=file_list_error.log
root=""
file_list=file_list
log=file_list.log
src=src

function abort()
{
	echo " "
	echo -e "\e[0mScript aborted by user."
	exit
}

# clean up function for interupt trapping
function clean_up()
{
   trap - EXIT
   if [ -e $error_log ]
	then
	    if [ "`cat $error_log | wc -l`" -gt "0" ]
	    then
	        echo " "
	        echo "Script finished with technical errors, please contact Amir for support"
	        echo "Errors can be found under $error_log"
	    else
	        rm -f $error_log
	    fi
	fi
   echo " "
   echo "Good bye"
   echo " "
	exit
}

function add_files()
{
	echo " " | tee -a $log
	echo "adding $dir files to file list" | tee -a $log
   find $dir/$src -type f -name "*\.v" -or -name "*\.sv" | tee -a $log
   find $dir/$src -type f -name "*\.v" -or -name "*\.sv" >> $file_list

   if [[ `ls $dir/$src | grep "makefile.inc"` ]]
   then
      echo "found inc file $dir/$src/makefile.inc" | tee -a $log
      for incdir in `cat $dir/$src/makefile.inc | grep incdir | sed 's/.*incdir+\(.*\)/\1/g' | grep -v SOURCE | grep -v "[[:space:]]*#"`
      do
         env_key=`echo $incdir | sed "s/.*{\(.*\)}.*/\1/g"`
         env_val=`env | grep -w "^$env_key" | cut -d"=" -f2`
         if [[ $env_val ]]
         then
            echo "   $incdir -> `echo $incdir | sed "s#.*}#$env_val#g"`" | tee -a $log
            find `echo $incdir | sed "s#.*}#$env_val#g"` -type f -name "*\.v" -or -name "*\.sv" -or -name "*\.svh" -or -name "*\.h" -or -name "*pkg*" | tee -a $log
            find `echo $incdir | sed "s#.*}#$env_val#g"` -type f -name "*\.v" -or -name "*\.sv" -or -name "*\.svh" -or -name "*\.h" -or -name "*pkg*" >> $file_list
         else
            echo "Error: It seems \"$env_key\" is not defined" | tee -a $log
         fi
      done
   fi

   if [[ `ls $dir/$src | grep "makefile.dep"` ]]
   then
      echo "found dep file $dir/$src/makefile.dep" | tee -a $log
      for file in `cat $dir/$src/makefile.dep | grep -v "[[:space:]]*#"`
      do
         dep_val=`env | grep -w "^$file" | cut -d"=" -f2`
         if [[ $dep_val ]]
         then
            echo "   $file -> $dep_val" | tee -a $log
         else
            echo "   Error: It seems \"$file\" is not defined" | tee -a $log
         fi
      done

      for new_dir in `cat $dir/$src/makefile.dep | grep -v "[[:space:]]*#"`
      do
         old_dir="$dir"
         new_dir=`env | grep -w "^$new_dir" | cut -d"=" -f2`
         if [[ $new_dir ]]
         then
            dir=$new_dir
            src=src
            add_files
            dir="$old_dir"
         else
            echo "Error: It seems \"$new_dir\" is not defined" | tee -a $log
         fi
      done
   fi
}

# interupt trap
trap abort  SIGHUP SIGINT SIGTERM SIGKILL SIGSTOP
trap clean_up EXIT

# menu function
while getopts "hdr:l:f:s:" switch
do
    case $switch in
	   h)	echo ""
    		echo "The script creates a file list."
    		echo " "
	   	echo "Basic switches:"
         echo "	-r root dir (mandatory switch)."
         echo "	   directory to start for (above \"$src\" dir)."
    		echo " "
		   echo "Advanced switches:"
	  	   echo "	-d debug mode."
	  	   echo "	-f file list name default is $file_list."
	  	   echo "	-l log name, default is $log."
	  	   echo "	-s change \"src\" dir name, default is $src."
    		echo " "
    		echo "Usage:"
    		echo "   file_list.bash -r <root dir> [-f <file list name> -d -l <log name>]"
    		echo " "
    		exit 0;;
    	d)	debug=1;;
    	f)	file_list="$OPTARG";;
      r) root="$OPTARG";;
      l) log="$OPTARG";;
      s) src="$OPTARG";;
    	?) printf "Usage: %s: [-e] [-s suffix] args\n" $0
    	   exit 2;;
    esac
done

rm -rf $error_log
touch $error_log
exec 2>$error_log

if [ "$root" == "" ]
then
   echo " "
   echo "\"-r\" is mandatory - root dir is not defined"
   exit
fi

rm -f $log $file_list
touch $log $file_list

dir=$root
add_files

echo " " | tee -a $log
echo "Sorting filelist" | tee -a $log
cat $file_list | sort | uniq -c >> $log
sort $file_list -o $file_list
sed -i '$!N; /^\(.*\)\n\1$/!P; D' $file_list
echo " " | tee -a $log
echo "File list can be found under \"$file_list\"" | tee -a $log
echo "Log can be found under: \"$log\""
echo " " >> $log
exit

