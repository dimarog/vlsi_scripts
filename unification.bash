#!/pkg/qct/software/gnu/bash/4.3/bin/bash
#################################################################################
# File name: unification.bash  				                                      #
# 										                                                  #
# Description:	                                                                 #
#  This script unifies a given block referred to another one                    #
#										                                                  #
# Author: Amir Albeck								                                   #
#										                                                  #
#################################################################################

########### parameters ###########   
debug=0
prefix=prefix
uniq_dir=/vobs/cores/modemss/emulation/wmss_vi/src/wmss_vi_uniq_dir
uniq_session_log=""
ref_session_log=""
errors=0
warnings=0
log=unification_log
enc_check_en=1
ref_view=aalbeck_wmss_dv_caster_top_dv
select_stages=0

ref_file_list=ref_file_list
uniq_file_list=uniq_file_list
ref_module_list=ref_module_list
uniq_module_list=uniq_module_list
common_module_list=common_module_list
uniq_define_list=uniq_define_list
ref_define_list=ref_define_list
common_define_list=common_define_list
uniq_package_list=uniq_package_list
binary_file_list=binary_file_list
uniq_include_list=uniq_include_list
dup_module_list=dup_module_list
makefile=makefile
##################################

function add_prefix()
{
   pattern_file=$1
   local_enc_check_en=$2
   i=1
   common_num=`cat $pattern_file | wc -l`
   for pattern in `cat $pattern_file`
   do 
      printf "%-80s (%-5s/%s)\n" $pattern $i $common_num | tee -a $log
      for file in `grep -wr "$pattern" $uniq_dir/* | cut -d":" -f1 | sort | uniq | grep -v makefile`
      do 
         if [ "$local_enc_check_en" == "1" ]
         then
            if [[ `grep -w $file $binary_file_list` ]]
            then
               let warnings++
               echo "Warning: attempting to eddit binary file $file, pattern is \"$pattern\"" >> $log
               continue
            fi
         fi
         sed -i "s/\b${pattern}\b/${prefix}_${pattern}/g" $file
       done
      let i++
   done
}

# abort function when signal trapped
function abort()
{
	echo " "
	echo -e "\e[0mScript aborted by user."
	exit
}

# clean up function for clean exit
function clean_up()
{
   trap - EXIT
   end_date=`date +%j | sed "s/^0*//g"`
   let date_change="$end_date-$start_date"
   let end_stamp="`date +%T | awk -F":" '{print $3}' | sed "s/^0//g"` + $((`date +%T | awk -F":" '{print $2}' | sed "s/^0//g"`*60)) + $(((`date +%T | awk -F":" '{print $1}' | sed "s/^0//g"` + ($date_change*24))*3600))"
   let total_time="$end_stamp-$start_stamp"

   echo " "
   echo "Script ran `echo $((total_time/3600))` hours, and `echo $((total_time%3600/60))` minutes, and `echo $((total_time%3600%60))` seconds."
   echo " "
   if [ "$debug" == "1" ]
   then
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
   fi
   echo " "
   echo "Script finished with $warnings warnings and $errors errors."
   echo " "
   echo "Good bye"
   echo " "
	exit
}

# menu function
while getopts "hsl:dr:ev:" switch
do
    case $switch in
	   h)	echo ""
    		echo "The script unifies a given design compared to a reference design."
    		echo "It will add a prefix to all common modules, packages, includes and defines."
    		echo "The script will copy all files to a created directory, and create a relevant makefile."
    		echo "By default the script will attempt to analyze reference design though it might be in a different vob."
    		echo "If for some reason this is not feasable, \"ref_unification\" script must be pre executed."
    		echo "The output of \"ref_unification\" script is \"ref_module_list\" and \"ref_define_list\" - these need to be copied to local dir"
         echo "After doing so, run this script with \"-s\" (see below)."
    		echo " "
    		echo "Basic switches:"
	  	   echo "	-l local session log [mandatory switch]."
	  	   echo "	-r reference session log."
	  	   echo "	-v reference view."
	  	   echo "	-p prefix, default is $prefix."
         echo "	-s select specific stages to run."
	  	   echo "	-o uniq dir name, default is $uniq_dir."
    		echo " "
    		echo "Advanced switches:"
	  	   echo "	-e disable checking encrypted files, just saving script running time."
	  	   echo "	-d debug mode."
    		echo " "
    		exit 0;;
    	r)	ref_session_log="$OPTARG";;
    	v)	ref_view="$OPTARG";;
    	l)	uniq_session_log="$OPTARG";;
    	o)	uniq_dir="$OPTARG";;
    	p)	prefix="$OPTARG";;
    	d)	debug="1";;
    	s)	select_stages="1";;
    	e)	enc_check_en="0";;
    	?) printf "Usage: %s: [-e] [-s suffix] args\n" $0
    	   exit 2;;
    esac
done

makefile=$uniq_dir/$makefile
makefile_inc="${makefile}.inc"

############## script start #############

# interupt trap
trap abort  SIGHUP SIGINT SIGTERM SIGKILL SIGSTOP
trap clean_up EXIT

let start_stamp="`date +%T | awk -F":" '{print $3}' | sed "s/^0*//g"` + $((`date +%T | awk -F":" '{print $2}' | sed "s/^0*//g"`*60)) + $((`date +%T | awk -F":" '{print $1}' | sed "s/^0*//g"`*3600))"
start_date=`date +%j | sed "s/^0*//g"`
# if debug mode record stderr to error log else dump to /dev/null
if [ "$debug" == "1" ]
then
   error_log="`echo $0 | awk -F "/" '{print $NF}' | cut -d. -f1`_error.log"
   rm -rf $error_log
   touch $error_log
else
   error_log=/dev/null
fi
exec 2>$error_log

# execution control
exe_stage="remove_stage ref_lists_stage local_lists_stage copy_stage makefile_stage module_stage define_stage package_stage include_stage dup_check_stage"
if [ "$select_stages" == "1" ]
then
   zenity_line=""
   for stage in $exe_stage
   do
      zenity_line="$zenity_line FALSE $stage"
   done
   exe_stage=`zenity --list --title="please select requested stages" --column="column" --column="select" $zenity_line --checklist --separator=" " --width=1300 --height=500`
fi
if [[ `echo $exe_stage | grep remove_stage` ]]; then remove_stage=1;else remove_stage=0;fi
if [[ `echo $exe_stage | grep ref_lists_stage` ]]; then ref_lists_stage=1;else ref_lists_stage=0;fi
if [[ `echo $exe_stage | grep local_lists_stage` ]]; then local_lists_stage=1;else local_lists_stage=0;fi
if [[ `echo $exe_stage | grep copy_stage` ]]; then copy_stage=1;else copy_stage=0;fi
if [[ `echo $exe_stage | grep makefile_stage` ]]; then makefile_stage=1;else makefile_stage=0;fi
if [[ `echo $exe_stage | grep module_stage` ]]; then module_stage=1;else module_stage=0;fi
if [[ `echo $exe_stage | grep define_stage` ]]; then define_stage=1;else define_stage=0;fi
if [[ `echo $exe_stage | grep package_stage` ]]; then package_stage=1;else package_stage=0;fi
if [[ `echo $exe_stage | grep include_stage` ]]; then include_stage=1;else include_stage=0;fi
if [[ `echo $exe_stage | grep dup_check_stage` ]]; then dup_check_stage=1;else dup_check_stage=0;fi

# check script mandatory inputs
if [ "$uniq_session_log" == "" ]
then
   echo -e "\e[31mError: Local session log not defined.\e[39m"
   let errors++
   exit 1
fi

# create log files
rm -f $log 
touch $log 

# remove old "uniq_dir"
if [ "$remove_stage" == "1" ]
then
   echo "Removing old \"$uniq_dir\" if exist. (`date +%T`)" | tee -a $log
   rm -rf $uniq_dir
   mkdir $uniq_dir
fi

echo "The script will add \"$prefix\" to all relevant files, modules, packages, includes and defines in local environment. (`date +%T`)" | tee -a $log
echo " " | tee -a $log

#### ref DB ####
if [ "$ref_lists_stage" == "1" ]
then
   if [ "$ref_session_log" == "" ]
   then
      echo -e "\e[31mError: Reference session log not defined.\e[39m"
      let errors++
      exit 1
   fi

   rm -f $ref_file_list $ref_module_list $ref_define_list 
   touch $ref_file_list $ref_module_list $ref_define_list 

   #create reference file list
   echo "Creating reference file list in \"$ref_file_list\" (`date +%T`)" | tee -a $log
   cat $ref_session_log | grep Parsing | cut -d"'" -f2 | sort | uniq >> $ref_file_list
   sed -i "s/\/vobs/\/view\/$ref_view\/vobs/g" $ref_file_list
   #support links
   for file in `cat $ref_file_list`
   do
      if [ ! -e $file ]
      then
         sed -i "s#$file##g" $ref_file_list
         dirname=`dirname $file`
         file_name=`echo $file | awk -F"/" '{print $NF}'`
         echo "/view/${ref_view}`ls -ltr $dirname | grep $file_name | awk '{print $NF}'`" >> $ref_file_list
      fi
   done
   sed -i '/^$/d' $ref_file_list
   echo "Found `cat $ref_file_list | wc -l` files." | tee -a $log
   
   #create reference module list
   echo "Creating reference module list in \"$ref_module_list\" (`date +%T`)" | tee -a $log
   for file in `cat $ref_file_list`; do grep "^[[:space:]]*module" $file | awk -F"[ (#]*" '{print $2}';done | sort | uniq >> $ref_module_list
   echo "Found `cat $ref_module_list | wc -l` modules." | tee -a $log
   
   #create reference define list
   echo "Creating reference define list in \"$ref_define_list\" (`date +%T`)" | tee -a $log
   for file in `cat $ref_file_list`; do grep "^[[:space:]]*"'`'"define" $file | grep -o '`'"define.*" | awk -F"[ /\t(]*" '{print $2}';done | sort | uniq >> $ref_define_list
   echo "Found `cat $ref_define_list | wc -l` defines." | tee -a $log
fi

#make sure ref module and define files exist, no matter if locally created or precreated
if [ ! -e $ref_module_list ]
then
   echo "$ref_module_list does not exist"
   let errors++
   exit 1
fi

if [ ! -e $ref_define_list ]
then
   echo "$ref_define_list does not exist"
   let errors++
   exit 1
fi

if [ "$local_lists_stage" == "1" ]
then
   rm -f $uniq_file_list $uniq_module_list $common_module_list 
   touch $uniq_file_list $uniq_module_list $common_module_list

   #create local file list
   echo "Creating local file list in \"$uniq_file_list\" (`date +%T`)" | tee -a $log
   cat $uniq_session_log | grep Parsing | cut -d"'" -f2 | sort | uniq >> $uniq_file_list
   file_num=`cat $uniq_file_list | wc -l`
   echo "Found $file_num files." | tee -a $log
   
   #create uniq module list
   echo "Creating local module list in \"$uniq_module_list\" (`date +%T`)" | tee -a $log
   for file in `cat $uniq_file_list`; do grep "^[[:space:]]*module" $file | awk -F"[ (#]*" '{print $2}';done | sort | uniq >> $uniq_module_list
   sed -i '/^module\b/d' $uniq_module_list
   echo "Found `cat $uniq_module_list | wc -l` modules." | tee -a $log
   
   #create common module list
   echo "Creating common module list in \"$common_module_list\" (`date +%T`)" | tee -a $log
   for module in `cat $ref_module_list`; do if [[ `grep -w "$module" $uniq_module_list` ]]; then echo "$module" >> $common_module_list;fi;done
   echo "Found `cat $common_module_list | wc -l` common modules." | tee -a $log
fi

#copy all files to $uniq_dir
if [ "$copy_stage" == "1" ]
then
   rm -f $makefile
   touch $makefile
   local_time=`date +%T`
   echo  "Copying all relevant files to \"$uniq_dir\" ($local_time)" >> $log
   echo -en "Copying all relevant files to \"$uniq_dir\" ($local_time)\r"
   echo 'include ${SOURCE}/makefile.inc' >> $makefile
   echo " " >> $makefile
   echo "${prefix}_lib:	\\" >> $makefile
   i=1
   for file in `cat $uniq_file_list`
   do 
      file_name=`echo $file | awk -F"/" '{print $NF}'`
      file_short_name=`echo $file_name | sed "s/.[^\.]*$//g"`
      echo "   $file -> $uniq_dir/${prefix}_${file_name}" >> $log
      cp -f $file $uniq_dir/${prefix}_${file_name}
      echo "   ${prefix}_${file_short_name} \\" >> $makefile
      printf "Copying all relevant files to \"$uniq_dir\" ($local_time) - (%-5s/%s)\r" $i $file_num
      let i++
   done
   echo  "Copying all relevant files to \"$uniq_dir\" ($local_time) - Done                        "
   sed -i '$ d' $makefile
   echo "   ${prefix}_${file_short_name}" >> $makefile
   echo -e '\ttouch $@' >> $makefile
   echo " "
fi

#continue create makefile
if [ "$makefile_stage" == "1" ]
then
   rm -f $makefile_inc
   touch $makefile_inc
   local_time=`date +%T`
   echo "Creating makefile under \"$makefile\" ($local_time)" >> $log
   echo -en "Creating makefile under \"$makefile\" ($local_time)\r"
   echo " " >> $makefile
   i=1
   for file in `cat $uniq_file_list`
   do
      file_name="${prefix}_`echo $file | awk -F"/" '{print $NF}'`"
      echo "`echo $file_name | sed "s/.[^\.]*$//g"`: \\" >> $makefile
      echo -e '\t${SOURCE}/'"$file_name" >> $makefile
      echo -e '\t${COMPILE} ${COMPILE_FLAGS} ${SYNTH_FLAGS} ${COMPILE_DEFINES} ${COMPILE_LIBS} ${SOURCE}/'"$file_name" >> $makefile
      echo -e '\ttouch $@' >> $makefile
      echo " " >> $makefile
      printf "Creating makefile under \"$makefile\" ($local_time) - (%-5s/%s)\r" $i $file_num
      let i++
   done
   echo "Creating makefile under \"$makefile\" ($local_time) - Done                      "
   echo " "
   #crerate makefile.inc
   echo "Creating makefile.inc under \"$makefile_inc\" (`date +%T`)" | tee -a $log
   echo "INCLUDE += +incdir+$uniq_dir" >> $makefile_inc
   echo " " >> $makefile_inc
   echo 'COMPILE_FLAGS = ${INCLUDE}' >> $makefile_inc
   echo " " >> $makefile_inc
fi

#binary files - needed to make sure binary files will not be eddited, in case such an attempt exists a warning will appear (see add_prefix function)
if [ "$enc_check_en" == "1" ]
then
   rm -f $binary_file_list
   touch $binary_file_list
   echo "Creating binary file list in \"$binary_file_list\" (`date +%T`)" | tee -a $log
   find $uniq_dir -type f -exec grep -IL . "{}" \; >> $binary_file_list
fi

#add prefix to all common modules
if [ "$module_stage" == "1" ]
then
   echo " " | tee -a $log
   echo "Adding \"${prefix}\" to common modules (`date +%T`)" | tee -a $log
   add_prefix $common_module_list $enc_check_en
fi

#define search
if [ "$define_stage" == "1" ]
then
   rm -f $uniq_define_list $common_define_list
   touch $uniq_define_list $common_define_list
   echo " " | tee -a $log
   echo "Creating local define list in \"$uniq_define_list\" (`date +%T`)" | tee -a $log
   grep -r "^[[:space:]]*"'`'"if[n]*def" $uniq_dir/* | grep -o '`'"if[n]*def.*" | awk -F"[ /\t]*" '{print$2}' | sort | uniq >> $uniq_define_list
   grep -r "^[[:space:]]*"'`'"define" $uniq_dir/* | grep -o '`'"define.*" | awk -F"[ /\t(]*" '{print $2}' | sort | uniq >> $uniq_define_list
   sort $uniq_define_list -o $uniq_define_list
   sed -i '$!N; /^\(.*\)\n\1$/!P; D' $uniq_define_list
   echo "Found `cat $uniq_define_list | wc -l` defines." | tee -a $log

   #create common define list
   echo "Creating common define list in \"$common_define_list\" (`date +%T`)" | tee -a $log
   for define in `cat $ref_define_list`; do if [[ `grep -w "$define" $uniq_define_list` ]]; then echo "$define" >> $common_define_list;fi;done
   echo "Found `cat $common_define_list | wc -l` common defines." | tee -a $log

   #adding prefix to all common defines
   echo " " | tee -a $log
   echo "Adding prefix to all common defines (`date +%T`)" | tee -a $log
   add_prefix $common_define_list $enc_check_en
fi

#create uniq package list
if [ "$package_stage" == "1" ]
then
   rm -f $uniq_package_list
   touch $uniq_package_list
   echo " " | tee -a $log
   echo "Creating local package list in \"$uniq_package_list\" (`date +%T`)" | tee -a $log
   grep -r "^[[:space:]]*package" $uniq_dir/* | awk -F"[ (#;]*" '{print $2}' | sort | uniq >> $uniq_package_list
   echo "Found `cat $uniq_package_list | wc -l` packages." | tee -a $log
   
   #adding prefix to all packages - there arnt many, so just add prefix to all
   echo "Adding prefix to all packages (`date +%T`)" | tee -a $log
   add_prefix $uniq_package_list $enc_check_en
   echo " " | tee -a $log
fi

#adding prefix to relevant includes
if [ "$include_stage" == "1" ]
then
   rm -f $uniq_include_list
   touch $uniq_include_list
   echo " " | tee -a $log
   # TODO support include paths
   #echo "Cleaning include paths in $uniq_dir files (`date +%T`)" | tee -a $log
   #for file in `grep -r "^[[:space:]]*""\`""include" $uniq_dir/* | sed "s/\/\/.*$//g" | cut -d: -f1 | sort | uniq`
   #do
   #   echo $file
   #   sed -i "s/include[[:space:]]*\".*\/\(.*\)/include \"\1/g" $file
   #done
   echo "Creating local include list in \"$uniq_include_list\" (`date +%T`)" | tee -a $log
   grep -r "^[[:space:]]*"'`'"include" $uniq_dir/* | grep -v '"'"$prefix" | sed "s/\/\/.*$//g" | awk -F'"' '{print $2}' | sort | uniq >> $uniq_include_list
   echo "Found `cat $uniq_include_list | wc -l` includes" | tee -a $log
   echo " " | tee -a $log
   echo "Adding prefix to includes (`date +%T`)" | tee -a $log
   add_prefix $uniq_include_list $enc_check_en
   echo " " | tee -a $log
fi

if [ "$dup_check_stage" == "1" ]
then
   rm -f $dup_module_list
   touch $dup_module_list
   echo "Analyzing files that contain the same modulesin \"$dup_module_list\". (`date +%T`)" | tee -a $log
   for module in `grep -r "^[[:space:]]*module" $uniq_dir/* | awk -F"[ (#;]*" '{print $2}' | sort | uniq -c | sort -n | grep -v "^[[:space:]]*1" | awk '{print $2}'`;do files="`grep -r "^[[:space:]]*module[[:space:]]*$module" $uniq_dir/* | cut -d: -f1 | sort | uniq`" ; if [ "`echo "$files" | wc -w`" -gt "1" ]; then echo "$files" | tr -s "\n" " " | awk '{printf "%s - %s\n" ,$1, $2}' ;fi;done | sort | uniq >> $dup_module_list
   if [ "`cat $dup_module_list  | wc -l`" -gt "0" ]
   then
      echo "Warning: The following files include duplicated modules. (`date +%T`)" | tee -a $log
      cat $dup_module_list | tee -a $log
      let warnings++
   fi
fi
