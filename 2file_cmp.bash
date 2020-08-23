#!/bin/bash
#################################################################################
# File name: 2file_cmp.bash							                                #
# 										                                                  #
# Description:									                                         #
# 	compares 2 files                                                             #
#										                                                  #
# Author: Amir Albeck								                                   #
#										                                                  #
#################################################################################

debug=0
log=compare.log
pattern=""
range=""
only=0

function comp_func()
{
	first=$1
	second=$2
   miss=0
	echo "[INFO]    The following exist in $first but do not exist in $second" | tee -a $log
   if [ "$range" != "" ]
   then
      cmd='sed -n "/$range_start/,/$range_end/p" $first'
   else
      cmd="cat $first"
   fi
	eval $cmd | while read -r "line"
	do
      if [ "$pattern" != "" ]
      then
         for pattern_i in $pattern
         do
            if [[ `echo "$line" | grep $pattern_i` ]]
            then
               if [ "$debug" -gt "0" ]; then echo "[DEBUG]   found $pattern_i pattern in $line therefore continuing." | tee -a $log; fi
               break
            fi
            if [ "$pattern_i" == "`echo "$pattern" | awk '{print $NF}'`" ]
            then
               if [ "$debug" -gt "0" ]; then echo "[DEBUG]   skipping $line since it does not contain any requested pattern.";echo " " | tee -a $log; fi
               continue 2
            fi
         done
      fi
      line_fix="`echo "$line" | sed -e 's#/#\\\/#g' | sed 's#\[#\\\[#g'`"
      if [ "$debug" -gt "1" ]
      then
         echo "[VERBOS]  line    : $line" | tee -a $log
         echo "[VERBOS]  fix_line: $line_fix" | tee -a $log
      fi
      if [[ ! `cat $second | grep -w "^[[:space:]]*$line_fix[[:space:]]*$"` ]]
      then
         if [ "$debug" -gt "0" ]; then echo "[DEBUG]   didnt find $line in $second" | tee -a $log; fi
        	echo "[INFO]    ${line}" | tee -a $log
         let miss++
      else
         if [ "$debug" -gt "0" ]; then echo "[DEBUG]   found $line in $second, line number `cat $second | grep -wn "^[[:space:]]*$line_fix[[:space:]]*$" | cut -d: -f1`"| tee -a $log; fi
      fi
      if [ "$debug" -gt "0" ]; then echo " " | tee -a $log; fi
   done
   echo "[INFO]    All together found $miss missmatches" | tee -a $log
   echo " " | tee -a $log
}

function exit_func()
{
   echo "[INFO]    compare data can be found in $log"
   exit
}

# menu function
while getopts "hdf:s:p:vr:o" switch
do
    case $switch in
	   h)	echo ""
    		echo "The script compares 2 files."
    		echo " "
	   	echo "Basic switches:"
         echo "	-f first file to compare."
	  	   echo "	-s second file to compare."
	  	   echo "	-o compare only first to second."
    		echo " "
		   echo "Advanced switches:"
	  	   echo "	-d debug mode."
         echo "	-p compare only lines with specific pattern (supports more than one pattern)."
	  	   echo "	-v verbos mode."
	  	   echo "	-r search only in range between 2 patterns."
	  	   echo "           use as the following -r \"<start pattern> <end pattern>\"."
    		echo " "
    		echo "Usage:"
    		echo "   2file_cmp.bash -f <first file name> -s <second file name> [-d -p \"<pattern1> <pattern2>\" -v -r \"<start pattern> <end pattern>\"]"
    		echo " "
    		exit 0;;
    	d)	debug=1;;
    	v)	debug=2;;
      o) only=1;;
    	f)	first="$OPTARG";;
      s) second="$OPTARG";;
      p) pattern+="$OPTARG ";;
      r) range+="$OPTARG ";;
    	?) printf "Usage: %s: [-e] [-s suffix] args\n" $0
    	   exit 2;;
    esac
done

if [ ! "$first" ]; then echo "first file not defined. use \"-f\" switch";exit; fi
if [ ! "$second" ]; then echo "second file not defined. use \"-s\" switch";exit; fi

if [ ! -e $first ]; then echo "couldnt find $first";exit; fi
if [ ! -e $second ]; then echo "couldnt find $second";exit; fi

rm -f $log
touch $log

if [ "$debug" -gt "0" ] && [ "$pattern" != "" ] ; then echo "[DEBUG]   Comparring only the following patterns: \"$pattern\"";echo " " | tee -a $log; fi
if [ "$range" != "" ]
then
   range_start=`echo $range | awk '{print $1}'`
   range_end=`echo $range | awk '{print $2}'`
   if [ "$debug" -gt "0" ] ; then echo "[DEBUG]   Searching only in range between 2 patterns: \"$range\"";echo " " | tee -a $log; fi
fi
comp_func $first $second
echo " " 
if [ "$only" == "0" ]
then
   comp_func $second $first
   echo " "
fi
exit_func
