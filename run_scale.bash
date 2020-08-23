#!/pkg/qct/software/gnu/bash/4.3/bin/bash
#################################################################################
# File name: run_scale.bash							                                #
# 										                                                  #
# Description:									                                         #
#										                                                  #
# Author: Dima Roginsky								                                   #
#										                                                  #
#################################################################################

#script default parameters
debug=0
select_block_en=0
error_log=/dev/null
xterm=0
script_full_path=$doc/scale/run_scale.bash
cfg_file=""
make_cmd=make
docs_en=1
dv_en=1
rtl_en=1
co_en=1
ci_en=1
clean_en=1
make_log=make_log
grep_string='Error'
select_doc_en=0
basline_from_file=0
z_comp_name='z_caster_dtr_1.0'
prj_stream='caster_dtr_14lpcrf_1.0_int'
pvob_loc='/vobs/qct_modemss_pvob'
diff_file_list=($doc/scale/swi/dtr_rif0.json $doc/scale/swi/dtr_rif1.json)
block_list="dtr_wrapper phy_adc_ctrl adc_if_ctrl phy_dac_ctrl dac_if_ctrl phy_fe_rx phy_fe_rx_core phy_fe_rx_pri phy_fe_tx phy_fe_tx_post_comb phy_fe_tx_pre_comb phy_fe_logger adc_general_config adc_slice_config"
env_list="dtr_wrapper dtr_adc_if adc_cx2_interface dtr_dac_if dac_mx_interface phy_fe_rx phy_fe_rx_core phy_fe_rx_pri phy_fe_tx phy_fe_tx_post_comb phy_fe_tx_pre_comb phy_fe_logger cm_bbrx_cartwheel cm_bbrx_cartwheel"
#script internal parameters
select_block_list=""
select_env_list=""
select_doc_list=""
warnings=0
errors=0
print_template=0

# script functions
function analyze_make_log()
{
   if [ "$?" != "0" ]
   then
      echo -e "\e[31mError: Failed $1\e[39m"
      let errors++
      exit 1
   fi
   sed -n '/'"$1"'/,$p' $make_log | egrep $grep_string
}

function read_cfg_file()
{
   if [ $cfg_file != "" ]
   then
      env_list=`cat $cfg_file | grep "env_list" | cut -d: -f2`
      block_list=`cat $cfg_file | grep "block_list" | cut -d: -f2`

      if [ "$env_list" == "" ]
      then
         echo -e "\e[31mError: env list is empty, please check your configuration file!\e[39m"
         let errors++
         exit 1
      fi
   fi

   if [ "$block_list" == "" ]
   then
      echo -e "\e[31mError: block list is empty, please check your configuration file!\e[39m"
      let errors++
      exit 1
   fi
   
   i=1
   for block in $block_list
   do
      if [ "$select_block_en" == "1" ] && [[ ! `echo $select_block_list | grep -w $block` ]] && [[ ! `echo $select_block_list | grep -w all` ]]
      then
         if [ "$debug" == "1" ]
         then
            echo "Skipping $block because it was not requested by user"
         fi
      else
         if [ "$debug" == "1" ]
         then
            echo "block_arr[$block] = `echo $env_list | awk -v j=$i '{print $j}'`"
         fi
   	   block_arr[$block]=`echo $env_list | awk -v j=$i '{print $j}'`
      fi
      let i++
   done

   i=1
   for block in $select_block_list
   do
      if [ ! ${block_arr[$block]+_} ] && [ $block != all ]
		then
			block_arr[$block]=`echo $select_env_list | awk -v j=$i '{print $j}'`
		fi
      let i++
   done

   if [ "$debug" == "1" ]
   then
      echo " "
      echo "Running scale for the following blocks"
      for K in "${!block_arr[@]}"; do printf "$K --- ${block_arr[$K]}\n"; done
   fi
}

function check_latest_baseline()
{
   echo "Checking latest baseline" | tee -a $make_log
   if [ ! -e $cfg_file ]
   then
      #echo -e "\e[1;31mWarning: Configuration file $cfg_file not found\e[0;39m"
      let warnings++
   else
      if [ "$basline_from_file" == "1" ]
      then
         z_comp_name=`cat $cfg_file | grep "z_comp_name" | cut -d: -f2 | sed 's/^[ ]*//g'`
         prj_stream=`cat $cfg_file | grep "prj_stream" | cut -d: -f2 | sed 's/^[ ]*//g'`
         pvob_loc=`cat $cfg_file | grep "pvob_loc" | cut -d: -f2 | sed 's/^[ ]*//g'`
      fi
   fi
   cur_bl="`mybls | grep -w ^$z_comp_name | awk '{print $2}'`"
   last_recom_bl="`cleartool desc -fmt "%[rec_bls]CXp\n" stream:${prj_stream}@${pvob_loc} | awk -F\@ '{print $1}' | awk -F\: '{print $2}'`"
   if [ "$last_recom_bl" == "" ] || [ "$cur_bl" == "" ]
   then
      echo -e "\e[1;31mWarning: Couldnt identify \"last or current recomended baslines\"\e[0;39m"
      let warnings++
   else
      if [ "$last_recom_bl" != "$cur_bl" ]
      then
         #echo -e "\e[1;31mWarning: You are not using the latest baseline (your base = \e[96m$cur_bl\e[1;31m, latest base = \e[96m$last_recom_bl\e[1;31m)\e[0;39m"
         echo -e "\e[1;31mWarning:\e[0m You are not using the latest baseline (your base = $cur_bl, latest base = $last_recom_bl)"
         echo "Are you sure you want to continue ? [y/n]"
         read ans
         if [ ! "$ans" == "y" ] && [ ! "$ans" == "yes" ]
         then
            echo "Exiting"
            exit 1
         fi
         let warnings++
      fi
   fi
}

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
   if [ -e $error_log ] && [ "$debug" == "1" ]
	then
	    if [ "`cat $error_log | wc -l`" -gt "0" ]
	    then
	        echo " "
	        echo "Script finished with technical errors, please contact Dima for support"
	        echo "Errors can be found under $error_log"
	    else
	        rm -f $error_log
	    fi
	fi
   echo " "
   if [ $errors == 0 ] && [ $warnings == 0 ]
   then
      echo -e "\e[32mScript finished with $errors errors and $warnings warnings.\e[0m"
   else
      echo -e "\e[31mScript finished with $errors errors and $warnings warnings.\e[0m"
   fi
   echo " "
   echo "Good bye"
   echo " "
	exit
}

function help_func()
{
   echo ""
   echo "Run Scale."
   echo "There are two ways to configure the script:"
   echo "   1. Use a configuration file, default is local \"$cfg_file\" (but can be changed using \"-f\" switch)."
   echo "      When using this method, all other \"basic\" and \"basline\" switches are not required"
   echo "      Run script with \"-t\" to see an example for a configuration file."
   echo "   2. The other option, is to define manually all script variables using \"basic\" and \"basline\" switches."
   echo " "
	echo "Basic switches:"
   echo "	-f configuration file."
   echo "	-b select blocks (or all as block name)"
   echo "	-e select envs."
#   echo "	-u select docs."
   echo " "
	echo "Baseline control switches:"
   echo "	-z define comp name for example: \"z_caster_dtr_1.0\""
   echo "	-s define project stream for example: \"caster_dtr_14lpcrf_1.0_int\""
   echo "	-l define vob location for example: \"/vobs/qct_modemss_pvob\""
   echo " "    		
	echo "Execution control switches:"
   echo "	-r disable \"rtl\" stage"
   echo "	-o disable \"co (check out)\" stage"
   echo "	-v disable \"dv/sw\" stage"
   echo "	-m disable \"doc\" stage"
   echo "	-i disable \"ci (check in)\" stage"
   echo "	-c disable \"clean\" stage"
   echo " "
	echo "Advanced switches:"
   echo "	-d debug mode"
   echo "	-x run script in external xterm window."
   echo "	-g define string from scale script STD out to be presented (default is \"$grep_string\")."
   echo " "
   echo -e "\e[34mFor example:"
   echo -e "run_scale.bash -x -b dtr_wrapper -d"
   echo -e "run_scale.bash -x -b all -d"
   echo -e "run_scale.bash -o (runs the script without checking out)\e[0m"
   echo " "
   if [ "$print_template" == "1" ]
   then
      echo -e "\e[37mConfiguration file example:"
      echo "env_list: dtr_wrapper dtr_adc_if adc_cx2_interface dtr_dac_if dac_mx_interface phy_fe_rx phy_fe_rx_core phy_fe_rx_pri"
      echo "block_list: dtr_wrapper phy_adc_ctrl adc_if_ctrl phy_dac_ctrl dac_if_ctrl phy_fe_rx phy_fe_rx_core phy_fe_rx_pri"
      echo "man_blocks: dtr_rif0 dtr_rif1"
      echo " "
      echo "basline parameters:"
      echo "z_comp_name: z_caster_dtr_1.0"
      echo "prj_stream: caster_dtr_14lpcrf_1.0_int"
      echo -e "pvob_loc: /vobs/qct_modemss_pvob\e[0m"
      echo " "
   fi
   exit 0
}

# menu function
while getopts "hdxb:mf:g:e:u:vroicz:s:l:t" switch
do
    case $switch in
	   h)	help_func;;
    	t)	print_template=1
         help_func;;
    	d)	debug=1;;
    	x)	xterm=1;;
      b) select_block_en=1
         select_block_list+="$OPTARG ";;
      e) select_env_list+="$OPTARG ";;
      u) select_doc_en=1
         select_doc_list+="$OPTARG ";;
    	m)	docs_en=0;;
      v) dv_en=0;;
      r) rtl_en=0;;
      o) co_en=0;;
      i) ci_en=0;;
      c) clean_en=0;;
      f) cfg_file="$OPTARG";;
      g) grep_string="$OPTARG";;
      z) basline_from_file=0
         z_comp_name="$OPTARG";;
      s) basline_from_file=0
         prj_stream="$OPTARG";;
      l) basline_from_file=0
         pvob_loc="$OPTARG";;
    	?) printf "Usage: %s: [-e] [-s suffix] args\n" $0
    	   exit 2;;
    esac
done

if [ "$xterm" == "1" ]
then
   switches=`echo $* | sed 's/-x//g'`
   xterm -title run_scale -e $script_full_path $switches &
   exit
fi

# interupt trap
trap abort  SIGHUP SIGINT SIGTERM SIGKILL SIGSTOP
trap clean_up EXIT

if [ "$debug" == "1" ]
then
   error_log="`pwd`/error.log"
   rm -rf $error_log
   touch $error_log
fi
exec 2>$error_log

rm -f $make_log
touch $make_log

declare -A block_arr

echo "=============================================="
echo "Running run_scale.bash"
echo "You can track the progress in : $make_log"
echo "=============================================="
echo " "
check_latest_baseline
read_cfg_file

if [[ `echo ${make_cmd%/*} | grep Makefile` ]]
then
   echo -e "\e[31mError: No Makefile found under `echo ${make_cmd%/*}` path\e[39m"
   let errors++
   exit 1
fi

# check script mandatory inputs
if [ "$select_block_en" == "0" ] && ([ "$rtl_en" == "1" ] || [ "$dv_en" == "1" ])
then
   echo -e "\e[31mError: No block name specified, use \"-b\" switch, or see help with \"-h\".\e[39m"
   let errors++
   exit 1
fi

# generating RTL
if [ "$rtl_en" == "1" ]
then
   echo "==============================================" | tee -a $make_log
   echo "Generating RTL" | tee -a $make_log
   echo "==============================================" | tee -a $make_log
   
   for block in "${!block_arr[@]}"
   do 
      if (($block == "adc_general_config") || ($block == "adc_slice_config"))
      then
         continue
      fi
      echo "Generating RTL block $block" >> $make_log
      $make_cmd gen_rtl BLOCK_NAME=$block ENV_NAME=\$${block_arr[$block]} >> $make_log
      analyze_make_log "Generating RTL block $block"
   done
fi

# cheking out all relevant files
if [ "$co_en" == "1" ]
then
   echo "==============================================" | tee -a $make_log
   echo "Checking out files" | tee -a $make_log
   echo "==============================================" | tee -a $make_log
#   for block in "${block_list[@]}"
#   do 
#      xml_name=`echo $block | tr '[:lower:]' '[:upper:]'`
#      echo "Checking out files $block" >> $make_log
#      $make_cmd co BLOCK_NAME=$block xml_name=$xml_name>> $make_log
#      analyze_make_log "Checking out files $block"
#   done
   $make_cmd co >> $make_log
   analyze_make_log "Checking out files $block"
fi

# generating DV/SW files"
if [ "$dv_en" == "1" ]
then
   echo "==============================================" | tee -a $make_log
   echo "Generating DV and SW files" | tee -a $make_log
   echo "==============================================" | tee -a $make_log
   for block in "${block_arr[@]}"
   do 
      echo "Generating DV and SW files $block" >> $make_log
      $make_cmd gen_verif BLOCK_NAME=$block ENV_NAME=\$${block_arr[$block]} >> $make_log
      analyze_make_log "Generating DV and SW files $block"
   done
fi

# Running 'Makefile all' to generate PDF/HTML/JSON/etc"
if [ "$docs_en" == "1" ]
then
   echo "==============================================" | tee -a $make_log
   echo "Generating docs" | tee -a $make_log
   echo "==============================================" | tee -a $make_log
   
   $make_cmd gen_doc BLOCK_NAME="dtr_rif0" >> $make_log
   analyze_make_log "Generating docs dtr_rif0"

   $make_cmd gen_doc BLOCK_NAME="dtr_rif1" >> $make_log
   analyze_make_log "Generating docs dtr_rif1"
fi

# cheking in all relevant files (un-checking out identical)
if [ "$ci_en" == "1" ]
then
   #make sure your changes have been populated to output files:
   echo "making sure your changes have been populated to output files:" >> $make_log
   for diff_file in ${diff_file_list[@]}
   do
      diff_files="$diff_file $diff_file@@/main/$prj_stream/LATEST"
      echo "diff -qBaw $diff_files" >>  $make_log
      diff -qBaw $diff_files >>  $make_log
      if [ "$?" != "0" ]
      then
         echo "Please Review the tkdiff :"
         /pkg/qct/software/tkdiff/current/tkdiff $diff_files
         echo -e "\e[1;31mDo You Approve the cahnges and Wish to Proceed with checkins [y/n]? \e[0;39m"
         read ans
         if [ ! "$ans" == "y" ] && [ ! "$ans" == "yes" ] && [ ! "$ans" == "Yes" ]
         then
            echo "Exiting"
            exit 1
         fi
      fi
   done

   echo "==============================================" | tee -a $make_log
   echo "Checking in files" | tee -a $make_log
   echo "==============================================" | tee -a $make_log
   $make_cmd ci >> $make_log
   #analyze_make_log "Checking in files"

   echo "UN-Checking out identical files " >> $make_log
   $make_cmd unco >> $make_log
   #analyze_make_log "UN-Checking out files"
fi

# clean up after yourself
if [ "$clean_en" == "1" ]
then
   echo "==============================================" | tee -a $make_log
   echo "Cleaning up" | tee -a $make_log
   echo "==============================================" | tee -a $make_log
   $make_cmd clean >> $make_log
   analyze_make_log "Cleaning up"
fi



echo " "
echo "==============================================" | tee -a $make_log
echo "Scale run has finished" | tee -a $make_log
echo "==============================================" | tee -a $make_log
echo " "
echo "Full Scale log can be found under \"$make_log\""

