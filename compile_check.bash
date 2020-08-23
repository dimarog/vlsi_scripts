#!/bin/bash
#################################################################################
# File name: compile_check.bash							                             #
# 										                                                  #
# Description:									                                         #
# 	Verifies compilation using several tools                                     #
#										                                                  #
# Author: Amir Albeck								                                   #
#										                                                  #
#################################################################################

# script default parameters
zenity_check=`which zenity 2>&-`
compilation_path="$UNMANAGED_DIR/qvmr"
debug=0
clean=0
backup=0
session_name="session.log"
tools="vcs mti ius novas"
top_name=""
exec_dir=$qbar_compile
fatal_error=0
error=0
warning=0
hold=""
crash=0

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
   if [ -e $compilation_path/error.txt ]
	then
	    if [ "`cat $compilation_path/error.txt | wc -l`" -gt "0" ]
	    then
	        echo " "
	        echo "Script finished with technical errors, please contact Amir for support"
	        echo "Errors can be found under error.txt"
	    else
	        rm -f $compilation_path/error.txt
	    fi
	fi
   echo " "
   echo "Good bye"
   echo " "
	exit
}

# interupt trap
trap abort  SIGHUP SIGINT SIGTERM SIGKILL SIGSTOP
trap clean_up EXIT

# menu function
while getopts "hdcn:t:f:e:bk" switch
do
    case $switch in
	   h)	echo ""
    		echo "The script compiles RTL using multiple tools."
    		echo " "
	   	echo "Basic switches:"
         echo "	-t top level name (mandatory switch)."
	  	   echo "	-c clean compilation area before run."
	  	   echo "	-b in case clean is enabled, backup existing qvmr dir."
    		echo "	   backup dir will be called \"qvmr_bk\". notice that if such dir exists it will be overwritten."
	  	   echo "	-e compilation exec_dir."
    		echo "	   default is $exec_dir."
    		echo " "
		   echo "Advanced switches:"
	  	   echo "	-d debug mode."
	  	   echo "	-f compilers to use."
         echo "	   supported tools are \"$tools\"."
         echo "	   default is to run all."
    		echo "	-n change used log name."
    		echo "	   default name is: $session_name"
	  	   echo "	-k keep xterm windows open and do not close them automatically."
    		echo " "
    		echo "Usage:"
    		echo "   compile_check.bash -t <RTL top name> [-e <exec_dir> -d -c -b -k -f \"<tool1> <tool2>\" -n <log name>]"
    		echo " "
    		exit 0;;
    	d)	debug=1;;
    	c)	clean=1;;
    	b)	backup=1;;
    	n)	session_name="$OPTARG";;
    	f)	tools="$OPTARG";;
      t) top_name="$OPTARG";;
      e) exec_dir="$OPTARG";;
      k) hold="-hold";;
    	?) printf "Usage: %s: [-e] [-s suffix] args\n" $0
    	   exit 2;;
    esac
done

# verify top name
if [ "$top_name" == "" ]
then
   echo -e "\e[31mtop name is not defined, please use \"-t\" or refer to help menu for additional help (\"-h\")\e[39m"
   exit
fi

# verify exec_dir
if [ ! -e $exec_dir ]
then
   echo -e "\e[31mIt seems that your exec dir ($exec_dir) does not exist , please use \"-e\" or refer to help menu for additional help (\"-h\")\e[39m"
   exit
fi

# clean compilation area
if [ -e $compilation_path ]
then
   if [ "$clean" == "1" ]
   then
      if [ "$backup" == "1" ]
      then
         echo "Backuping existing qvmr dir"
         if [ -e $UNMANAGED_DIR/qvmr_bk ]
         then
            rm -rf $UNMANAGED_DIR/qvmr_bk
         fi
         mv $UNMANAGED_DIR/qvmr $UNMANAGED_DIR/qvmr_bk
      fi
      echo "Cleaning compilation area"
      rm -rf $compilation_path
   fi
fi

if [ ! -e $compilation_path ]
then
   mkdir $compilation_path
fi

rm -rf $compilation_path/error.txt
touch $compilation_path/error.txt
exec 2>error.txt

# job launch
tool_num=`echo $tools | wc -w`
location=0
let toolnum_for_calc=$tool_num-1
let hight=30-$toolnum_for_calc*5
let toolnum_for_calc--
loc_increase=400-$toolnum_for_calc*75
for tool in $tools
do
   echo "Running compilation using $tool"
   if [ "$debug" == "1" ] 
   then
      echo "command line is:"
      echo "xterm -title ${tool}_compilation -geometry 400x$hight+0+$location $hold -e qbar elab_dut -exec_dir $exec_dir HDL_TOP_SPEC=$top_name -${tool}&"
      echo " "
   fi
   xterm -title ${tool}_compilation -geometry 400x$hight+0+$location $hold -e qbar elab_dut -exec_dir $exec_dir HDL_TOP_SPEC=$top_name -${tool} &
   let location=$location+$loc_increase
done

if [ "$hold" == "-hold" ]
then
   echo -e "\e[96mNotice you have selected to keep xterm window opened, close them manually when you are ready for script to continue run\e[39m"
fi
# waiting for dispatch
echo " "
echo "Waiting for jobs to be dispatched"
while [ "`find $compilation_path -type f -name $session_name | wc -l`" -lt "$tool_num" ]
do
   running=`find $compilation_path -type f -name $session_name | wc -l`
   let queued=$tool_num-$running
   printf "Running: %-4s, Queued: %-4s\r" $running $queued 
   if [ "`ps -f | grep xterm | grep -v grep | wc -l`" == "0" ]
   then
      printf "\e[A\033[0K"
      echo  -e "\e[31mIt seems that $queued jobs crashed before $session_name was created.\e[39m"
      echo "In such case it is recomended to use the \"-k\" switch so xterm will not close."
      crash=$queued
      if [ "$running" == "0" ]
      then
         echo "No remaining jobs to track and analyze."
         exit
      fi
      echo " "
      echo " "
      break
   fi
   sleep 1
done

printf "\e[A\033[0K"
echo "Waiting for jobs to be dispatched - Done"

# waiting for jobs to finish
echo "Waiting for jobs to be complete"
while [ "`ps -f | grep xterm | grep -v grep | wc -l`" -gt "0" ]
do
   running=`ps -f | grep xterm | grep -v grep | wc -l`
   let finished=$tool_num-$running
   printf "Running: %-4s, Done: %-4s\r" $running $finished
   sleep 1
done
printf "\e[A\033[0K"
echo "Waiting for jobs to be complete - Done"

# analyze results
echo "                                                         "
for log in `find $compilation_path -type f -name $session_name`
do
   if [[ `echo $log | grep vcs` ]]
   then
      echo -e "\e[96mVCS:\e[39m"
      echo "$log"
      error_num=`cat $log | grep "^Error" | wc -l`
      warning_num=`cat $log | grep "^Warning" | wc -l`
   elif [[ `echo $log | grep modelsim` ]]
   then
      echo -e "\e[96mModelsim:\e[39m"
      echo "$log"
      error_num=`cat $log | grep "# Errors: [0-9]*, Warnings: [0-9]*" | tail -1 | sed 's/# Errors: \([0-9]*\), Warnings: \([0-9]*\)/\1/g'`
      warning_num=`cat $log | grep "# Errors: [0-9]*, Warnings: [0-9]*" | tail -1 | sed 's/# Errors: \([0-9]*\), Warnings: \([0-9]*\)/\2/g'`
   elif [[ `echo $log | grep ius` ]]
   then
      echo -e "\e[96mIUS:\e[39m"
      echo "$log"
      error_num=`cat $log | grep '*E' | wc -l`
      warning_num=`cat $log | grep '*W' | wc -l`
   elif [[ `echo $log | grep novas` ]]
   then
      echo -e "\e[96mNOVAS:\e[39m"
      echo "$log"
      error_num=`cat $log | grep "Total[[:space:]]*[0-9]* error(s),[[:space:]]*[0-9]* warning(s)" | tail -1 | sed 's/Total[[:space:]]*\([0-9]*\) error(s),[[:space:]]*\([0-9]*\) warning(s)/\1/g'`
      warning_num=`cat $log | grep "Total[[:space:]]*[0-9]* error(s),[[:space:]]*[0-9]* warning(s)" | tail -1 | sed 's/Total[[:space:]]*\([0-9]*\) error(s),[[:space:]]*\([0-9]*\) warning(s)/\2/g'`
   else
      echo "Error, unrecognized log file:"
      echo "$log"
      error_num=0
      warning_num=0
   fi

   if [[ `cat $log | egrep "\[ERROR]|CompLock[[:space:]]*Error"` ]]
   then
      echo -e "\e[31mCritical Techincal Errors were found during job setup!\e[39m"
      echo " "
      let fatal_error++
      let error++
   else
      if [ "$error_num" == "" ]
      then
         echo -e "\e[31mError number was not recognized!\e[39m"
         error_num="NA"
         let error++
      elif [ "$error_num" -gt "0" ]
      then
         let error++
      fi

      if [ "$warning_num" == "" ]
      then
         echo -e "\e[31mWarning number was not recognized!\e[39m"
         warning_num="NA"
         let warning++
      elif [ "$warning_num" -gt "0" ]
      then
         let warning++
      fi

      echo "Errors: $error_num Warnings: $warning_num"
      echo " "
   fi
done

echo "Summary:"
if [ "$fatal_error" == "0" ]
then
   if [ "$error" == "0" ]
   then
      echo -e "\e[96mAll compilers finished with no errors\e[39m"
      if [ "$warning" -gt "0" ]
      then
         echo -e "\e[31mNotice that warnings were found during compilation phase\e[39m"
      fi
   else
      echo -e "\e[31mCritical Errors were found during compilation phase!\e[39m"
   fi   
else
      echo -e "\e[31mCritical Techincal Errors were found during job setup!\e[39m"
      echo -e "\e[31mIn such case, it is recommended to use \"-k\" switch for keeping xterm windows opened.\e[39m"
fi
if [ "$crash" -gt "0" ]
then
   echo -e "\e[31mNotice that $crash jobs crashed and did not even start running.\e[39m"
fi
echo " "
echo '  ___  ___  ___  ___  ___.---------------------------------.'
echo '\ \__\ \__\ \__\ \__\ \__,`         ____  _                 \'
echo '\\/ __\/ __\/ __\/ __\/ _:\        / __ \| |                 \'
echo ' \\ \__\ \__\ \__\ \__\ \_`.      | |  | | |__   __ _ _ __    \'
echo '  \\/ __\/ __\/ __\/ __\/ __:     | |  | | |_ \ / _` |  __|    \'
echo '   \\/ __\/ __\/ __\/ __\/ __:    | |__| | |_) | (_| | |        \'
echo '    \\/ __\/ __\/ __\/ __\/ __:    \___\_\_.__/ \__,_|_|         \'
echo '     \\/ __\/ __\/ __\/ __\/ __:                                  \'
echo '      \\ \__\ \__\ \__\ \__\ \__;----------------------------------`'
echo '       \\/   \/   \/   \/   \/  :                                  |'
echo '        \|______________________;__________________________________|'

exit
