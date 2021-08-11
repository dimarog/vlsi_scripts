#!/bin/bash
#################################################################################
# File name: run_test.bash     							                             #
# 										                                                  #
# Description:									                                         #
# 	run cmn600 test
#										                                                  #
# Author: Dima Roginsky
#										                                                  #
#################################################################################

# script default parameters
zenity_check=`which zenity 2>&-`
export RUNDIR=$PWD
debug=0
clean=0
backup=0
test_name=""
fatal_error=0
error=0
warning=0
crash=0
hold="-hold"
waves=""
uvm_verbosity="LOW"
use_stg="0"
use_spa=0
compilation_path="${RUNDIR}/xcelium.d"
curr_time=`date +"%Y_%m_%d_%H_%M_%S"`
command="$@"
errormax=""
open_waves=0
seed="1"
stg_gen=0
no_grid=0
qsub_intrctiv="qsub -V -q ipbu_int -l mem_tokens=20 -o ${RUNDIR}/sim/qsub.log -j y -v DISPLAY=${DISPLAY} -N simvision_waves_$curr_time"
qsub_verilog="qsub -V -q verilog -l mem_tokens=20 -o ${RUNDIR}/sim/qsub.log -j y -v DISPLAY=${DISPLAY} -N cmn_run_$curr_time"
#WS=echo $PWD | awk -F/ { print 5 }

# colors
# ---------------------------------------------
RED_COLOR="\e[31m"
LRED_COLOR="\e[91m" # light red
BLUE_COLOR="\e[34m"
LBLUE_COLOR="\e[94m" # light blue
YEL_COLOR="\e[33m"
LYEL_COLOR="\e[93m" # light yellow
GREEN_COLOR="\e[32m"
END_COLOR="\e[0m"


#location check  - verif/<name> . i.e. verif folder above you
# ---------------------------------------------
verif=`echo $PWD | rev | cut -d/ -f2 | rev`
if [ $verif != "verif" ]; then 
   echo -e "Wrong run folder. you must be under /verif/icn/"
   exit 1
fi
export PROJECT=`echo $PWD/../../`

# ---------------------------------------------
function abort()
{
	echo " "
	echo -e "\e[0mScript aborted by user."
	exit 1
}

# clean up function for interupt trapping
# ---------------------------------------------
function clean_up()
{
   #exit status meaning:
   # 0 - good. need to copy folders
   # 1 - bad . no need to copy folders
   # 2 - good but no run. no need to do anything

   exit_code=$?

   # print ascii art
   whale

   #
   if [ "$exit_code" == 0 ]
   then
      if [ -e ${RUNDIR}/xcelium.d/worklib ];  then \cp -r ${RUNDIR}/xcelium.d/worklib $exec_dir; fi
      if [ -e ${RUNDIR}/qsub.csh ];          then mv ${RUNDIR}/qsub.csh $exec_dir; fi
   fi

#   if [ -e $compilation_path/error.txt ]
#	then
#	    if [ "`cat $compilation_path/error.txt | wc -l`" -gt "0" ]
#	    then
#	        echo " "
#	        echo "Script finished with technical errors, please contact Dima for support"
#	        echo "Errors can be found under error.txt"
#	    else
#	        rm -f $compilation_path/error.txt
#	    fi
#	fi

   # unset temp variables
   unset RUNDIR
   unset PROJECT

   echo " "
   echo "Good bye"
   echo " "
	exit 0
}

#
function to_del()
{
#Xcelium installation
export CDS_INST_DIR=/nfs/cadtools/cds/xcelium/XLMA-20.09.001

#CDN_VIP_ROOT:: Environment variable pointing to Cadence VIP installation
export CDN_VIP_ROOT=/nfs/7nm_ddr_tmp/VIPCAT/vipcat_11.30.077-30_Jun_2021_12_51_41

#CDS_ARCH:: Platform for Cadence VIP libraries
#This is obtained from: ${CDN_VIP_ROOT}/bin/cds_plat
CDS_ARCH=lnx86

#DENALI:: Environment variable pointing to Cadence VIP base libraries
export DENALI=${CDN_VIP_ROOT}/tools.${CDS_ARCH}/denali_64bit

#CDN_VIP_LIB_PATH:: Location of Cadence VIP compiled libraries
#This is a user-specified directory.
#IMPORTANT:: The libraries must be recompiled (-install option)
#after each new VIP download (and after each Xcelium installation upgrade).
CDN_VIP_LIB_PATH=/nfs/rg1dv28/droginsky/ws_xp_02/vip_lib

#Additional components in ${PATH} to ensure necessary executables are available
export PATH=${CDS_INST_DIR}/tools.${CDS_ARCH}/bin:${PATH}

#Additional components in ${LD_LIBRARY_PATH} to ensure necessary libraries are available
	#The following line accounts for (extremely rare) users with no LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${CDN_VIP_LIB_PATH}/64bit:${DENALI}/verilog:${CDS_INST_DIR}/tools.${CDS_ARCH}/lib/64bit:${LD_LIBRARY_PATH}

# The *USING_CCORE* variables correspond to the VIPs for which simulations will proceed with the C implementation (instead of the VIP Virtual Machine)
export CDN_AXI_USING_CCORE="TRUE"

# Disable automatic nc to xm remapping
export CDN_VIP_DISABLE_REMAP_NC_XM  

export SIA_HOME=/nfs/7nm_ddr_tmp/VIPCAT/sysvip_01.21.005-28_Jun_2021_08_15_01/tools/stg/bin/lib

#CDN_VIP_COMMON_SRC:: Environment variable pointing to Cadence VIP common sv sources
export CDN_VIP_COMMON_SRC=${DENALI}/ddvapi/sv

# Variables pointing to vip "svd" source sub-dir
export CDN_VIP_SVD=${CDN_VIP_ROOT}
export CDN_VIP_SVD_SRC=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/svd
export CDN_VIP_SVD_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/svd/examples
export CDN_VIP_SVD_TC_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/triplecheck/svdTc/example


# Variables pointing to vip "axi" source sub-dir
export CDN_VIP_AXI=${CDN_VIP_ROOT}
export CDN_VIP_AXI_SRC=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/cdn_axi
export CDN_VIP_AXI_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/cdn_axi/examples
export CDN_VIP_AXI_TC_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/triplecheck/axiTc/example


# Variables pointing to vip "chi" source sub-dir
export CDN_VIP_CHI=${CDN_VIP_ROOT}
export CDN_VIP_CHI_SRC=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/chi
export CDN_VIP_CHI_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/chi/examples
export CDN_VIP_CHI_TC_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/triplecheck/chiTc/example

#Example Bitmode (32/64) from command-line (disable global variables bypassing command-line)
unset INCA_64BIT; unset CDS_AUTO_64BIT
#Disable a few other global variables bypassing command-line
unset NCSIMOPTS; unset NCVLOGOPTS; unset NCELABOPTS; unset NCVERILOGOPTS; unset XMSIMOPTS; unset XMVLOGOPTS; unset XMELABOPTS; unset XMVERILOGOPTS
#Location of UVM source:
export CDN_VIP_UVMHOME=/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools/methodology/UVM/CDNS-1.1d/sv
#Location of Additional PLI for Xcelium UVM:
export CDN_SV_UVMHOME=/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools/methodology/UVM/CDNS-1.1d/sv


echooo | tee working_echo.txt

${CDN_VIP_ROOT}/bin/cdn_vip_check_env -cdn_vip_root ${CDN_VIP_ROOT} -sim xrun -mode 3s -method sv_uvm -cdn_vip_lib $CDN_VIP_LIB_PATH -cdnautotest -64 -vips "svd axi chi"





}


function echooo()
{
   echo $RUNDIR
   #Xcelium installation
   echo $CDS_INST_DIR
   
   #CDN_VIP_ROOT:: Environment variable pointing to Cadence VIP installation
   echo $CDN_VIP_ROOT
   
   #CDS_ARCH:: Platform for Cadence VIP libraries
   #This is obtained from: ${CDN_VIP_ROOT}/bin/cds_plat
   echo $CDS_ARCH
   
   #DENALI:: Environment variable pointing to Cadence VIP base libraries
   echo $DENALI
   
   #CDN_VIP_LIB_PATH:: Location of Cadence VIP compiled libraries
   #This is a user-specified directory.
   #IMPORTANT:: The libraries must be recompiled (-install option)
   #after each new VIP download (and after each Xcelium installation upgrade).
   echo $CDN_VIP_LIB_PATH
   
   #Additional components in ${PATH} to ensure necessary executables are available
   echo $PATH
   
   #Additional components in ${LD_LIBRARY_PATH} to ensure necessary libraries are available
   echo $LD_LIBRARY_PATH
   
   # The *USING_CCORE* variables correspond to the VIPs for which simulations will proceed with the C implementation (instead of the VIP Virtual Machine)
   echo $CDN_AXI_USING_CCORE
   
   # Disable automatic nc to xm remapping
   echo $CDN_VIP_DISABLE_REMAP_NC_XM  
   
   echo $SIA_HOME
   
   #CDN_VIP_COMMON_SRC:: Environment variable pointing to Cadence VIP common sv sources
   echo $CDN_VIP_COMMON_SRC
   
   # Variables pointing to vip "svd" source sub-dir
   echo $CDN_VIP_SVD
   echo $CDN_VIP_SVD_SRC
   echo $CDN_VIP_SVD_EXAMPLES
   echo $CDN_VIP_SVD_TC_EXAMPLES
   
   
   # Variables pointing to vip "axi" source sub-dir
   echo $CDN_VIP_AXI
   echo $CDN_VIP_AXI_SRC
   echo $CDN_VIP_AXI_EXAMPLES
   echo $CDN_VIP_AXI_TC_EXAMPLES
   
   
   # Variables pointing to vip "chi" source sub-dir
   echo $CDN_VIP_CHI
   echo $CDN_VIP_CHI_SRC
   echo $CDN_VIP_CHI_EXAMPLES
   echo $CDN_VIP_CHI_TC_EXAMPLES
   
   #Example Bitmode (32/64) from command-line (disable global variables bypassing command-line)
   unset INCA_64BIT; unset CDS_AUTO_64BIT
   #Disable a few other global variables bypassing command-line
   unset NCSIMOPTS; unset NCVLOGOPTS; unset NCELABOPTS; unset NCVERILOGOPTS; unset XMSIMOPTS; unset XMVLOGOPTS; unset XMELABOPTS; unset XMVERILOGOPTS

   #Location of core VIP libraries:
   echo $CDN_VIP_LIB_PATH

   #Location of UVM source:
   echo $CDN_VIP_UVMHOME
   #Location of Additional PLI for Xcelium UVM:
   echo $CDN_SV_UVMHOME


   #spa configs
   echo $CDN_SYSVIP_ROOT
   echo $SPA_VIPCAT_APP


}

function whale()
{

   get_joke
   echo '               __   __'
   echo '              __ \ / __'
   echo '             /  \ | /  \'
   echo '                 \|/'
   echo '            _,.---v---._'
   echo '   /\__/\  /            \'
   echo '   \_  _/ /              \ '
   echo '     \ \_|           @ __|'
   echo '  hjw \                \_'
   echo '  `97  \     ,__/       /'
   echo '     ~~~`~~~~~~~~~~~~~~/~~~~'

   echo -e "${LYEL_COLOR}joke for you: ${END_COLOR}$joke"
   echo '------------------------------------------------'
}

function get_joke()
{
   array=(
   "Complaining about the lack of smoking shelters, the nicotine addicted Python programmers said there ought to be 'spaces for tabs'."
   "Ubuntu users are apt to get this joke."
   "Obfuscated Reality Mappers (ORMs) can be useful database tools."
   "Asked to explain Unicode during an interview, Geoff went into detail about his final year university project. He was not hired."
   "Triumphantly, Beth removed Python 2.7 from her server in 2030. 'Finally!' she said with glee, only to see the announcement for Python 4.4."
   "An SQL query goes into a bar, walks up to two tables and asks, 'Can I join you?'"
   "When your hammer is C++, everything begins to look like a thumb."
   "If you put a million monkeys at a million keyboards, one of them will eventually write a Java program. The rest of them will write Perl."
   "To understand recursion you must first understand recursion."
   "I suggested holding a 'Python Object Oriented Programming Seminar', but the acronym was unpopular."
   "'Knock, knock.' 'Who's there?' ... very long pause ... 'Java.'"
   "How many programmers does it take to change a lightbulb? None, that's a hardware problem."
   "What's the object-oriented way to become wealthy? Inheritance."
   "Why don't jokes work in octal? Because 7 10 11."
   "How many programmers does it take to change a lightbulb? None, they just make darkness a standard."
   "Two bytes meet. The first byte asks, 'Are you ill?' The second byte replies, 'No, just feeling a bit off.'"
   "Two threads walk into a bar. The barkeeper looks up and yells, 'Hey, I want don't any conditions race like time last!'"
   "Old C programmers don't die, they're just cast into void."
   "Eight bytes walk into a bar. The bartender asks, 'Can I get you anything?' 'Yeah,' replies the bytes. 'Make us a double.'"
   "Why did the programmer quit his job? Because he didn't get arrays."
   "Why do Java programmers have to wear glasses? Because they don't see sharp."
   "Software developers like to solve problems. If there are no problems handily available, they will create their own."
   ".NET was named .NET so that it wouldn't show up in a Unix directory listing."
   "Hardware: The part of a computer that you can kick."
   "A programmer was found dead in the shower. Next to their body was a bottle of shampoo with the instructions 'Lather, Rinse and Repeat'."
   "Optimist: The glass is half full. Pessimist: The glass is half empty. Programmer: The glass is twice as large as necessary."
   "In C we had to code our own bugs. In C++ we can inherit them."
   "How come there is no obfuscated Perl contest? Because everyone would win."
   "If you play a Windows CD backwards, you'll hear satanic chanting ... worse still, if you play it forwards, it installs Windows."
   "How many programmers does it take to kill a cockroach? Two: one holds, the other installs Windows on it."
   "What do you call a programmer from Finland? Nerdic."
   "What did the Java code say to the C code? A: You've got no class."
   "Why did Microsoft name their search engine BING? Because It's Not Google."
   "Pirates go 'arg!', computer pirates go 'argv!'"
   "Software salesmen and used-car salesmen differ in that the latter know when they are lying."
   "Child: Dad, why does the sun rise in the east and set in the west? Dad: Son, it's working, don't touch it."
   "Why do programmers confuse Halloween with Christmas? Because OCT 31 == DEC 25."
   "How many Prolog programmers does it take to change a lightbulb? false."
   "Real programmers can write assembly code in any language."
   "Waiter: Would you like coffee or tea? Programmer: Yes."
   "What do you get when you cross a cat and a dog? Cat dog sin theta."
   "If loving you is ROM I don't wanna read write."
   "A programmer walks into a foo..."
   "A programmer walks into a bar and orders 1.38 root beers. The bartender informs her it's a root beer float. She says 'Make it a double!'"
   "What is Benoit B. Mandelbrot's middle name? Benoit B. Mandelbrot."
   "Why are you always smiling? That's just my... regular expression."
   "ASCII stupid question, get a stupid ANSI."
   "A programmer had a problem. He thought to himself, 'I know, I'll solve it with threads!'. has Now problems. two he"
   "Why do sin and tan work? Just cos."
   "Java: Write once, run away."
   "I would tell you a joke about UDP, but you would never get it."
   "A QA engineer walks into a bar. Runs into a bar. Crawls into a bar. Dances into a bar. Tiptoes into a bar. Rams a bar. Jumps into a bar."
   "My friend's in a band called '1023 Megabytes'... They haven't got a gig yet!"
   "I had a problem so I thought I'd use Java. Now I have a ProblemFactory."
   "QA Engineer walks into a bar. Orders a beer. Orders 0 beers. Orders 999999999 beers. Orders a lizard. Orders -1 beers. Orders a sfdeljknesv."
   "A product manager walks into a bar, asks for drink. Bartender says no, but will consider adding later."
   "How do you generate a random string? Put a first year Computer Science student in Vim and ask them to save and exit."
   "I've been using Vim for a long time now, mainly because I can't figure out how to exit."
   "How do you know whether a person is a Vim user? Don't worry, they'll tell you."
   "Waiter: He's choking! Is anyone a doctor? Programmer: I'm a Vim user."
   "3 Database Admins walked into a NoSQL bar. A little while later they walked out because they couldn't find a table."
   "How to explain the movie Inception to a programmer? When you run a VM inside another VM, inside another VM ... everything runs real slow!"
   "What do you call a parrot that says \"Squawk! Pieces of nine! Pieces of nine!\"? A parrot-ey error."
   "There are only two hard problems in Computer Science: cache invalidation, naming things and off-by-one-errors."
   "There are 10 types of people: those who understand binary and those who don't."
   "There are 2 types of people: those who can extrapolate from incomplete data sets..."
   "There are II types of people: Those who understand Roman Numerals and those who don't."
   "There are 10 types of people: those who understand hexadecimal and 15 others."
   "There are 10 types of people: those who understand binary, those who don't, and those who were expecting this joke to be in trinary."
   "There are 10 types of people: those who understand trinary, those who don't, and those who have never heard of it."
   "What do you call eight hobbits? A hobbyte."
   "The best thing about a Boolean is even if you are wrong, you are only off by a bit."
   "A good programmer is someone who always looks both ways before crossing a one-way street."
   "There are two ways to write error-free programs; only the third one works."
   "QAs consist of 55% water, 30% blood and 15% Jira tickets."
   "Sympathy for the Devil is really just about being nice to QAs."
   "How many QAs does it take to change a lightbulb? They noticed that the room was dark. They don't fix problems, they find them."
   "A programmer crashes a car at the bottom of a hill, a bystander asks what happened, he says \"No idea. Let's push it back up and try again\"."
   "What do you mean 911 is only for emergencies? I've got a merge conflict."
   "Writing PHP is like peeing in the swimming pool, everyone did it, but we don't need to bring it up in public."
   "Why did the QA cross the road? To ruin everyone's day."
   "Number of days since I have encountered an array index error: -1."
   "Number of days since I have encountered an off-by-one error: 0."
   "Speed dating is useless. 5 minutes is not enough to properly explain the benefits of the Unix philosophy."
   "Microsoft hold a bi-monthly internal \"productive week\" where they use Google instead of Bing."
   "Schrodinger's attitude to web development: If I don't look at it in Internet Explorer then there's a chance it looks fine."
   "Finding a good PHP developer is like looking for a needle in a haystack. Or is it a hackstack in a needle?"
   "Unix is user friendly. It's just very particular about who its friends are."
   "A COBOL programmer makes millions with Y2K remediation and decides to get cryogenically frozen. \"The year is 9999. You know COBOL, right?\""
   "The C language combines all the power of assembly language with all the ease-of-use of assembly language."
   "An SEO expert walks into a bar, bars, pub, public house, Irish pub, tavern, bartender, beer, liquor, wine, alcohol, spirits..."
   "What does 'Emacs' stand for? 'Exclusively used by middle aged computer scientists.'"
   "What does pyjokes have in common with Adobe Flash? It gets updated all the time, but never gets any better."
   "Why does Waldo only wear stripes? Because he doesn't want to be spotted."
   "why does python live on land ? becasue it's above c-level"
   "I went to a street where the houses were numbered 8k, 16k, 32k, 64k, 128k, 256k and 512k. It was a trip down Memory Lane."
   "!false, (It's funny because it's true)"
   "['hip', 'hip'] (hip hip array!)"
   )

   size=${#array[@]}
   index=$(($RANDOM % $size))
   joke=${array[$index]}
}


function huge_smiley()
{
   echo '                          oooo$$$$$$$$$$$$oooo'
   echo '                      oo$$$$$$$$$$$$$$$$$$$$$$$$o'
   echo '                   oo$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o         o$   $$ o$'
   echo '   o $ oo        o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o       $$ $$ $$o$'
   echo 'oo $ $ "$      o$$$$$$$$$    $$$$$$$$$$$$$    $$$$$$$$$o       $$$o$$o$'
   echo '"$$$$$$o$     o$$$$$$$$$      $$$$$$$$$$$      $$$$$$$$$$o    $$$$$$$$'
   echo '  $$$$$$$    $$$$$$$$$$$      $$$$$$$$$$$      $$$$$$$$$$$$$$$$$$$$$$$'
   echo '  $$$$$$$$$$$$$$$$$$$$$$$    $$$$$$$$$$$$$    $$$$$$$$$$$$$$  """$$$'
   echo '   "$$$""""$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$     "$$$'
   echo '    $$$   o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$     "$$$o'
   echo '   o$$"   $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$       $$$o'
   echo '   $$$    $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$" "$$$$$$ooooo$$$$o'
   echo '  o$$$oooo$$$$$  $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$   o$$$$$$$$$$$$$$$$$'
   echo '  $$$$$$$$"$$$$   $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$     $$$$""""""""'
   echo ' """"       $$$$    "$$$$$$$$$$$$$$$$$$$$$$$$$$$$"      o$$$'
   echo '            "$$$o     """$$$$$$$$$$$$$$$$$$"$$"         $$$'
   echo '              $$$o          "$$""$$$$$$""""           o$$$'
   echo '               $$$$o                 oo             o$$$"'
   echo '                "$$$$o      o$$$$$$o"$$$$o        o$$$$'
   echo '                  "$$$$$oo     ""$$$$o$$$$$o   o$$$$""  '
   echo '                     ""$$$$$oooo  "$$$o$$$$$$$$$"""'
   echo '                        ""$$$$$$$oo $$$$$$$$$$       '
   echo '                                """"$$$$$$$$$$$        '
   echo '                                    $$$$$$$$$$$$       '
   echo '                                     $$$$$$$$$$"      '
   echo '                                      "$$$""""'


}

# ---------------------------------------------
function set_envs()
{

   echo "Setting needed Env variables"

   old_path=$PATH

   # clean old variables
   unset CDS_INST_DIR; unset CDN_VIP_ROOT; unset CDN_SYSVIP_ROOT; unset DENALI; unset PATH; unset LD_LIBRARY_PATH; unset CDN_AXI_USING_CCORE; unset CDN_VIP_DISABLE_REMAP_NC_XM; unset SIA_HOME; unset CDN_VIP_COMMON_SRC; unset CDN_VIP_SVD; unset CDN_VIP_SVD_SRC; unset CDN_VIP_SVD_EXAMPLES; unset CDN_VIP_SVD_TC_EXAMPLES; unset CDN_VIP_AXI; unset CDN_VIP_AXI_SRC; unset CDN_VIP_AXI_EXAMPLES; unset CDN_VIP_AXI_TC_EXAMPLES; unset CDN_VIP_CHI; unset CDN_VIP_CHI_SRC; unset CDN_VIP_CHI_EXAMPLES; unset CDN_VIP_CHI_TC_EXAMPLES; unset CDN_VIP_LIB_PATH;unset CDN_VIP_UVMHOME; unset CDN_SV_UVMHOME;unset SPA_VIPCAT_APP; unset CDS_ARCH

   export PATH=$old_path

   #Xcelium installation
   export CDS_INST_DIR=/nfs/cadtools/cds/xcelium/XLMA-20.09.001
   
   #CDN_VIP_ROOT:: Environment variable pointing to Cadence VIP installation
   export CDN_VIP_ROOT=/nfs/7nm_ddr_tmp/VIPCAT/vipcat_11.30.077-30_Jun_2021_12_51_41
   
   #CDS_ARCH:: Platform for Cadence VIP libraries
   #This is obtained from: ${CDN_VIP_ROOT}/bin/cds_plat
   export CDS_ARCH=lnx86
   
   #DENALI:: Environment variable pointing to Cadence VIP base libraries
   export DENALI=${CDN_VIP_ROOT}/tools.${CDS_ARCH}/denali_64bit
   
   #CDN_VIP_LIB_PATH:: Location of Cadence VIP compiled libraries
   #This is a user-specified directory.
   #IMPORTANT:: The libraries must be recompiled (-install option)
   #after each new VIP download (and after each Xcelium installation upgrade).
   #CDN_VIP_LIB_PATH=${RUNDIR}/vip_lib
   export CDN_VIP_LIB_PATH=${RUNDIR}/vip_lib
   
   #Additional components in ${PATH} to ensure necessary executables are available
   export PATH=${CDS_INST_DIR}/tools.${CDS_ARCH}/bin:${PATH}
   
   #Additional components in ${LD_LIBRARY_PATH} to ensure necessary libraries are available
   export LD_LIBRARY_PATH=${CDN_VIP_LIB_PATH}/64bit:${DENALI}/verilog:${CDS_INST_DIR}/tools.${CDS_ARCH}/lib/64bit:${LD_LIBRARY_PATH}
   
   # The *USING_CCORE* variables correspond to the VIPs for which simulations will proceed with the C implementation (instead of the VIP Virtual Machine)
   export CDN_AXI_USING_CCORE="TRUE"
   
   # Disable automatic nc to xm remapping
   export CDN_VIP_DISABLE_REMAP_NC_XM  
   
   export SIA_HOME=/nfs/7nm_ddr_tmp/VIPCAT/sysvip_01.21.005-28_Jun_2021_08_15_01/tools/stg/bin/lib
   
   #CDN_VIP_COMMON_SRC:: Environment variable pointing to Cadence VIP common sv sources
   export CDN_VIP_COMMON_SRC=${DENALI}/ddvapi/sv
   
   # Variables pointing to vip "svd" source sub-dir
   export CDN_VIP_SVD=${CDN_VIP_ROOT}
   export CDN_VIP_SVD_SRC=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/svd
   export CDN_VIP_SVD_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/svd/examples
   export CDN_VIP_SVD_TC_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/triplecheck/svdTc/example
   
   
   # Variables pointing to vip "axi" source sub-dir
   export CDN_VIP_AXI=${CDN_VIP_ROOT}
   export CDN_VIP_AXI_SRC=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/cdn_axi
   export CDN_VIP_AXI_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/cdn_axi/examples
   export CDN_VIP_AXI_TC_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/triplecheck/axiTc/example
   
   
   # Variables pointing to vip "chi" source sub-dir
   export CDN_VIP_CHI=${CDN_VIP_ROOT}
   export CDN_VIP_CHI_SRC=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/chi
   export CDN_VIP_CHI_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/ddvapi/sv/uvm/chi/examples
   export CDN_VIP_CHI_TC_EXAMPLES=/nfs/cadtools/cds/VIPCAT112/tools/denali/triplecheck/chiTc/example
   
   #Example Bitmode (32/64) from command-line (disable global variables bypassing command-line)
   unset INCA_64BIT; unset CDS_AUTO_64BIT
   #Disable a few other global variables bypassing command-line
   unset NCSIMOPTS; unset NCVLOGOPTS; unset NCELABOPTS; unset NCVERILOGOPTS; unset XMSIMOPTS; unset XMVLOGOPTS; unset XMELABOPTS; unset XMVERILOGOPTS

   #Location of UVM source:
   export CDN_VIP_UVMHOME=${CDS_INST_DIR}/tools/methodology/UVM/CDNS-1.1d/sv
   #Location of Additional PLI for Xcelium UVM:
   export CDN_SV_UVMHOME=${CDS_INST_DIR}/tools/methodology/UVM/CDNS-1.1d/sv


   #spa configs
   export CDN_SYSVIP_ROOT=/nfs/7nm_ddr_tmp/VIPCAT/sysvip_01.21.005-28_Jun_2021_08_15_01/
   export SPA_VIPCAT_APP=${CDN_SYSVIP_ROOT}/tools/spa
   export stg=$CDN_SYSVIP_ROOT/tools/stg/bin/stg
   export spa=$CDN_SYSVIP_ROOT/tools/spa/bin/spa

   export simvision=/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools.lnx86/bin/simvision

   #Additional components in ${PATH} to ensure necessary executables are available
   #export PATH="/nfs/7nm_ddr_tmp/VIPCAT/vipcat_11.30.077-30_Jun_2021_12_51_41/tools/spa/bin:/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools.lnx86/bin:/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools.lnx86/bin:/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools.lnx86/bin:/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools.lnx86/bin:/nfs/cadtools/cds/xcelium/XLMA-20.09.001/tools/xcelium/bin:/nfs/cadtools/cavium/eg/bin:/nfs/cadtools/git/linux-SL6-x86_64/2.22.0/bin:/nfs/cadtools/flexlm/11.10.1/bin:/nfs/cadtools/curl/linux-SL6-x86_64/curl-7.68.0/bin:/opt/subversion-1.8.14/bin:/usr/qlc/apps/univa/uge_8.5.5/bin/lx-amd64:/nfs/cadtools/common/bin:/nfs/cadtools/os/linux-SL6-x86_64/bin:/nfs/cadtools/atrenta/latest/SPYGLASS_HOME/bin:/nfs/cadtools/synopsys/syn/latest/bin:/nfs/cadtools/synopsys/jxt/latest/bin/IA.32:/nfs/cadtools/synopsys/icc/latest/bin:/nfs/cadtools/synopsys/pt/latest/bin:/nfs/cadtools/synopsys/fm/latest/bin:/usr/local/bin:/usr/bin:/bin:/nfs/cadtools/cavium/bin:/nfs/cadtools/fcov-2.0/gui/bin:/nfs/cadtools/cavium/pre_commit/bin:${PATH}:${CDS_INST_DIR}/tools.${CDS_ARCH}/bin:${PATH}"

}

# spa congigs and run
function enable_spa()
{
   echo -e "SPA : enabling SPA recording" | tee -a $log_name

   #spa server status
   spa_is_on=0
   spa_status=`${SPA_VIPCAT_APP}/bin/spa -status | grep -v "spa" | grep "Server Status" | grep "UP"`
   if [[ ! -z $spa_status ]]
   then 
      spa_is_on=1
   else
      spa_is_on=0
   fi

   # spa -correlate -run_id <runId> -config <file>
   # run id taken from spa -runs_report summary
   # -config received the svd_config_file
   #if [ "$spa_corr" == 1 ]
   #then
   #   ${SPA_VIPCAT_APP}/bin/spa -correlate -run_id <runId> -config ${RUNDIR}/stg_gen/

   #fi

   # create spa server config
   if [ "$spa_is_on" == 0 ]
   then
      if [ -d "${RUNDIR}/spa_config" ]; then
         $SPA_VIPCAT_APP/bin/spa -refresh_config -username spaUser -password spaPass -database_port 9091 >> $log_name
      else
         $SPA_VIPCAT_APP/bin/spa -create_config -username spaUser -password spaPass  -database_port 9091 >> $log_name
      fi
      if [[ $? -ne 0 ]]
      then
         echo -e "${RED_COLOR}SPA Error - an error has occured during configuration setup, please check ${log_name}${END_COLOR}" | tee -a $log_name
         exit 1;
      fi
   fi

   SPA_SERVER_PORT=$( grep 'server.port' $SPA_CONFIG_DIR/spa_webserver.properties | grep -o '[0-9]*' )
   SPA_SERVER_NAME=$( grep 'server.cadence.hostname' $SPA_CONFIG_DIR/spa_webserver.properties | cut -d = -f 2 )
   echo -e "SPA : to see the performance results, go to - $SPA_SERVER_NAME:$SPA_SERVER_PORT (user=spaUser , pass=spaPass)" | tee -a  $log_name

   #create denalirc
   if [ -f "${RUNDIR}/.denalirc" ]; then
      mv ${RUNDIR}/.denalirc ${RUNDIR}/.denalirc.old
   fi
   ${SPA_VIPCAT_APP}/bin/spa -enable_recording -for_correlation -instance "*.passive*" >> $log_name
   #echo -e 'randomoutputdelay 0\nhistorydebug on\n# tracefile denali.trc\n# historyfile denali.his\nRefreshchecks 1\nTimingChecks 1\nrecordCategory "PerformanceAnalysis"\nspaEnableCorrelationAnalysis' > ${RUNDIR}/.denalirc
   if [[ $? -ne 0 ]]
   then
      echo -e "${RED_COLOR}Error - couldn't cerate ${RUNDIR}/.denalirc${END_COLOR}" | tee -a $log_name
      exit 1;
   fi

   echo "created ${RUNDIR}/.denalirc" >> tee -a $log_name

   #start spa server
   if [ "$spa_is_on" == 1 ]
   then
      echo -e "SPA server is already running. no need to start again" >> $log_name
   else
      echo -e "SPA : Starting spa server. ${LBLUE_COLOR}this takes a min${END_COLOR}. patience ...." | tee -a $log_name
      echo -e "SPA : Running Recording Server from - $SPA_VIPCAT_APP/bin" >> $log_name
      ${SPA_VIPCAT_APP}/bin/spa -start >> $log_name
      if [[ $? -ne 0 ]]
      then
         echo -e "${RED_COLOR}Error - an error has occured during server startup, please check ${log_name}${END_COLOR}"
         exit 1;
      fi
   fi

   echo -e "${LYEL_COLOR}SPA Server is up${END_COLOR}"  | tee -a $log_name

}

# ---------------------------------------------
function prepare_test_cmds()
{

   # setup vip libs
   xrun_setup_cmd="${CDN_VIP_ROOT}/bin/cdn_vip_setup_env -cdnautotest -64 -s xrun -mode 3s -cdn_vip_root ${CDN_VIP_ROOT} -m sv_uvm -csh -cdn_vip_lib vip_lib -i \"svd axi chi\""

   #The environment is validated by the following script:
   #This script is intended to be executed before any simulation (or compile/if compile is a separate step)
   #It can be commented out once you have confirmed that the environment is valid.
   #IMPORTANT:: The environment must be validated on each new VIP download, change in simulator version
   xrun_check_cmd="${CDN_VIP_ROOT}/bin/cdn_vip_check_env -cdn_vip_root ${CDN_VIP_ROOT} -sim xrun -mode 3s -method sv_uvm -cdn_vip_lib ${CDN_VIP_LIB_PATH} -cdnautotest -64 -vips \"svd axi chi\""


#   #replace RUNDIR with correct path
#   grep "${RUNDIR}"  ${RUNDIR}/logical/cmn600/compile.vc
#   if [ "$?" == "0" ]
#      sed -i 's/${RUNDIR}/$RUNDIR/' ${RUNDIR}/logical/cmn600/compile.vc

   #Compile System Verilog source files
   #-work <worklib_name>
   xrun_compile_cmd="xrun -compile -64 -mess -sv -define DENALI_SV_NC \
      -define DENALI_UVM -uvmhome ${CDN_VIP_UVMHOME} \
   	-incdir ${DENALI}/ddvapi/sv \
   	${DENALI}/ddvapi/sv/denaliMem.sv \
   	${DENALI}/ddvapi/sv/denaliSvd.sv \
   	-incdir ${DENALI}/ddvapi/sv/uvm/svd \
   	${DENALI}/ddvapi/sv/uvm/svd/cdnSvdUvmTop.sv \
   	${DENALI}/ddvapi/sv/denaliCdn_axi.sv \
   	-incdir ${DENALI}/ddvapi/sv/uvm/cdn_axi \
   	${DENALI}/ddvapi/sv/uvm/cdn_axi/cdnAxiUvmTop.sv \
   	${DENALI}/ddvapi/sv/denaliChi.sv \
   	-incdir ${DENALI}/ddvapi/sv/uvm/chi \
   	${DENALI}/ddvapi/sv/uvm/chi/cdnChiUvmTop.sv \
   	-enable_work_yvlib -delay_trigger -atstar_lsp -f stg_gen/scripts/run.xrunargs  \
      -f ${PROJECT}/rtl/icn/XP_FULL_FOR_PD_DDR_ONE_SIDE/logical/cmn600/compile.vc -log ${exec_dir}/comp.log \
   	-incdir ${RUNDIR} \
      ${RUNDIR}/stg_gen/stg_cmn600.sv \
      ${RUNDIR}/stg_gen/usr/stg_cmn600_usr_pkg.sv" 
#      -f ${RUNDIR}/../../rtl/icn/compile.vc -log comp.log
   
   
   #Elaborate
   xrun_elab_cmd="xrun -elaborate -64 -access +rw -mess \
   	-top worklib.stg_cmn600 \
   	-top worklib.stg_cmn600_usr_pkg \
   	-log ${exec_dir}/elab.log \
   	-loadpli1 ${CDN_SV_UVMHOME}/lib/64bit/libuvmpli.so:uvm_pli_boot:export \
   	-loadvpi ${DENALI}/verilog/libcdnsv.so:cdnsvVIP:export"
   
   #Simulate
   xrun_run_cmd="xrun -R -64 \
   	-write_metrics  +UVM_VERBOSITY=$uvm_verbosity -svseed ${seed} -access +r -input ${exec_dir}/waves.tcl -run \
   	-sv_lib ${CDN_VIP_LIB_PATH}/64bit/libcdnvipuvmdpi.so \
   	-xmsimargs \"-loadrun ${CDN_VIP_LIB_PATH}/64bit/libcdnvipcuvm.so\" \
      -log ${exec_dir}/run.log \
   	+UVM_TESTNAME=$test_name \
      -loadvpi $CDN_VIP_ROOT/tools/denali_64bit/verilog/libcdnsv.so:cdnsvVIP:export"

   if [ "$use_stg" == "0" ]
   then
      if [ -d ${RUNDIR}/vip_lib ]
      then
         test_cmds="${xrun_check_cmd}; ${xrun_compile_cmd}; ${xrun_elab_cmd}; ${xrun_run_cmd};"
      else
         test_cmds="${xrun_setup_cmd}; ${xrun_check_cmd}; ${xrun_compile_cmd}; ${xrun_elab_cmd}; ${xrun_run_cmd};"
      fi
   else
      #test_cmds="${CDN_SYSVIP_ROOT}/tools/stg/bin/stg -sim -prefix stg -dut_name cmn600 -file \"-f ${RUNDIR}/logical/cmn600/compile.vc\" -64 -xrunopts \"-enable_work_yvlib\" -xrunopts \"-delay_trigger -atstar_lsp\" -test ${test_name} -nogui -${waves} -verbosity ${uvm_verbosity} -dir ${test_name}_${curr_time} -denalirc .denalirc"
      test_cmds="${CDN_SYSVIP_ROOT}/tools/stg/bin/stg -sim -prefix stg -dut_name cmn600 -file \"-f ${PROJECT}/rtl/icn/XP_FULL_FOR_PD_DDR_ONE_SIDE/logical/cmn600/compile.vc\" -64 -xrunopts \"-enable_work_yvlib\" -xrunopts \"-delay_trigger -atstar_lsp\" -test ${test_name} -nogui ${waves} -verbosity ${uvm_verbosity} -denalirc ${RUNDIR}/.denalirc ${errormax}"
   fi
}


function create_tcl()
{
   #create tcl to run on simvision open
   export tcl_name=${RUNDIR}/sim/open_waves.tcl

   echo '#databse' > $tcl_name
   echo 'database require waves -search {' >> $tcl_name
   echo "	${waves_folder}" >> $tcl_name
   echo '}' >> $tcl_name
   echo '' >> $tcl_name
   echo '# Waveform windows' >> $tcl_name
   echo '#' >> $tcl_name
   echo 'if {[catch {window new WaveWindow -name "Waveform 1" -geometry 1010x600+1+56}] != ""} {' >> $tcl_name
   echo '    window geometry "Waveform 1" 1010x600+1+56' >> $tcl_name
   echo '}' >> $tcl_name
   echo 'window target "Waveform 1" on' >> $tcl_name
   echo 'waveform using {Waveform 1}' >> $tcl_name
   echo 'waveform sidebar select designbrowser' >> $tcl_name
   echo 'waveform set \' >> $tcl_name
   echo '    -primarycursor TimeA \' >> $tcl_name
   echo '    -signalnames name \' >> $tcl_name
   echo '    -signalwidth 175 \' >> $tcl_name
   echo '    -units ns \' >> $tcl_name
   echo '    -valuewidth 75' >> $tcl_name
   echo 'waveform baseline set -time 0' >> $tcl_name
}

#
function run_stg_gen()
{
   #[-gen, -top, cmn600.csv, -prefix, stg, -dut_name, cmn600, -config, ENABLE_SVD=true]
   # ${RUNDIR}/stg_gen/tools/svd_config_file.cfg
   stg_gen_cmd="${CDN_SYSVIP_ROOT}/tools/stg/bin/stg -gen -top cmn600.csv -prefix stg -dut_name cmn600 -config ENABLE_SVD=true"
   echo "Running stg -gen in xterm window"
   if [ "$hold" == "-hold" ]
   then
      echo -e "${LBLUE_COLOR}Notice you have selected to keep xterm windows open, close them manually when you are ready for the script to continue${END_COLOR}"
   fi
   
   stg_log_name="${RUNDIR}/stg_gen_$curr_time.log"
   xterm -title "stg_gen" -geometry 200x50 $hold -e bash -c 'echo -e "Goging to run:\n $1"; eval $1  2>&1 | tee -a $2; echo -e "\n\n\e[34mFINISHED !!! you can close\e[39m"' bash "$stg_gen_cmd" "$stg_log_name" &

   # waiting for jobs to finish
   # ---------------------------------------------
   #echo "Waiting for jobs to be complete"
   # rotating marker animation : while(true); do for a in \\ \| \/ -; do echo -n $a; sleep 1 ; echo -n -e \\r ; done; done
   while [ "`ps -f | grep xterm | grep -v grep | wc -l`" -gt "0" ]
   do
      running=`ps -f | grep xterm | grep -v grep | wc -l`
      printf "Still Running Test in Xterm window...\r"
      sleep 1
   done
   printf "\e[A\033[0K"
 
}


# interupt trap
trap abort  SIGHUP SIGINT SIGTERM SIGKILL SIGSTOP
trap 'clean_up $?' EXIT

# menu function
#while getopts "t:e:l:hcsdkbwv:u" switch
#do
#    case $switch in
#	   h|help)	echo ""
#    		echo "The script runs ARM test with various options"
#    		echo " "
#	   	echo "Basic switches:"
#         echo "	-t test name (example: configure_test)."
#         echo "	-e compilation exec_dir  (default is $exec_dir)"
#         echo "	-s run spa (system perforamnce) recording in the background"
#         echo "	-w run with waves (default = no waves)"
#         echo "	-v UVM VERBOSITY level (<NONE|LOW|MEDIUM|HIGH|FULL>)"
#    		echo " "
#		   echo "Advanced switches:"
#         echo "	-u use STG to run <1/0> (default : 1)"
#	  	   echo "	-c clean compilation area before run."
#	  	   echo "	-b backup compilation dir into <compilation_dir>_backup"
#	  	   echo "	-d debug mode."
#         echo "	-l change used log name (default name is: <run_test>_time.log)"
#	  	   echo "	-k keep xterm windows open and do not close them automatically."
#	  	   echo "	-k keep xterm windows open and do not close them automatically."
#    		echo " "
#    		echo "Usage:"
#         echo "Usage run_test.bash -t <test_name> [-w -e <exec_dir> -l <log_name> -c -s -d]"
#    		echo " "
#    		exit 0;;
#    	d)	debug=1;;
#    	c)	clean=1;;
#    	s)	spa=1;;
#    	b)	backup=1;;
#      w) waves="-waves";;
#      v) uvm_verbosity="$OPTARG";;
#      k) hold="-hold";;
#      u) use_stg="$OPTARG";;
#      t) test_name="$OPTARG";;
#      e) exec_dir="$OPTARG";;
#      l) log_name="$OPTARG";;
#    	?) printf "Usage run_test.bash -t <test_name> [-w -e <exec_dir> -l <log_name> -c -s -d]\n" $0
#    	   exit 2;;
#    esac
#done

function process_args() {
   POSITIONAL=()
   while [[ $# -gt 0 ]]; do
      key="$1"
   
      case $key in
   	   -h|--help)	echo ""
       		echo "The script runs ARM test with various options"
       		echo " "
   	   	echo "Basic switches:"
            echo "	-t             : test name (example : configure_test)."
            echo "	-e             : compilation exec_dir  (default is $exec_dir)"
            echo "	-s|--spa       : run spa (system perforamnce) recording in the background (disabled by default)"
            echo "	-w|--waves     : run with waves (no waves by default)"
            echo "	--open_waves   : open waves folder."
       		echo " "
   		   echo "Advanced switches : "
            echo "	--use_stg      : use STG to run. (by default runs without stg)"
            echo "	--stg_gen      : creates \"stg_gen\" folder (with all the goodies inside it)"
            echo "	-v             : UVM VERBOSITY level . <NONE|LOW|MEDIUM|HIGH|FULL>"
            echo "	-c|--clean     : clean compilation area before run (deletes xcelium.d folder)"
   	  	   echo "	-b |--backup   : backup compilation dir into xcelium.d_backup"
   	  	   echo "	-d|--debug     : debug mode."
            echo "	-l             : change used log name. <log_name> (default name is : run_test_<time>.log)"
   	  	   echo "	-k             : DONT keep xterm windows open after run has finished"
            echo "	--seed         : seed number to use. <number> (default is 1)"
            echo "	--errormax     : stop the run after max errors. <number> (disabled by default)"
            echo "	--no_grid      : run on local machine. no grid usage (disabled by default)"
       		echo " "
       		echo "Usage example:"
            echo "Usage run_test.bash -t <test_name> [-w -e <exec_dir> -l <log_name> -c -k ]"
       		echo " "
       		exit 2;;
         -d|--debug) debug=1
            shift
            ;;
         -c|--clean) clean=1
            shift;;
         -s|--spa) use_spa=1
            shift;;
         -b|--backup) backup=1
            shift;;
         -w|--waves) waves="-waves"
            shift;;
         -v) uvm_verbosity="$2"
            shift # past argument
            shift # past value
            ;;
         -k) hold=""
            shift;;
         --use_stg) use_stg="1"
            shift # past argument
            ;;
         --stg_gen) stg_gen=1
            shift # past argument
            ;;
         -t) test_name="$2"
            shift # past argument
            shift # past value
            ;;
         -e) export exec_dir="$2"
            shift # past argument
            shift # past value
            ;;
         -l) log_name="$2"
            shift # past argument
            shift # past value
            ;;
         --errormax) errormax="-errormax $2"
            shift # past argument
            shift # past value
            ;;
         --open_waves) open_waves=1
            waves_folder="$2"
            shift # past argument
            shift # past value
            ;;
         --seed) seed="$2"
            shift # past argument
            shift # past value
            ;;
         --no_grid) no_grid=1
            shift # past argument
            shift # past value
            ;;

         *)    # unknown option
            echo -e "\n${LRED_COLOR}Unknown flag given "$1". run_test.bash -h (for help)${END_COLOR}" 
            exit 1
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
      esac
   done
   
   set -- "${POSITIONAL[@]}" # restore positional parameters


   if [ -z $exec_dir ]
   then
      export exec_dir="${RUNDIR}/sim/${test_name}_${curr_time}"
   else
      export exec_dir="${RUNDIR}/sim/$exec_dir"
   fi
   log_name="${exec_dir}/run_test_$curr_time.log"
}

if [ "$#" == 0 ]
then
   echo -e "${LRED_COLOR}Usage help : run_test.bash -h${END_COLOR}"
   exit 1
else
   process_args $command
fi

#source all variables
# ---------------------------------------------
set_envs

#sim dir
# ---------------------------------------------
if [ ! -d "${RUNDIR}/sim" ]
then
   mkdir ${RUNDIR}/sim
fi

# ---------------------------------------------
if [ "$open_waves" == 1 ] # verify waves folder
then
   if [ -d "$waves_folder" ]
   then
      echo "Opening waves...$waves_folder"
      create_tcl
      if [ "$no_grid" == 1 ]
      then
         $simvision -waves -input $tcl_name &
      else
         echo -e "setenv PATH $PATH:\${PATH}\n$simvision -waves -input $tcl_name" > ${RUNDIR}/qsub.csh
         exit 1
         $qsub_intrctiv source ${RUNDIR}/qsub.csh
      fi
      echo -e "${LYEL_COLOR}relax, need to wait a few seconds for waves to open${END_COLOR}"
      exit 2
   else
      echo "no such waves folder : $waves_folder"
      echo "exiting..."
      exit 1
   fi
elif [ "$test_name" == "" ] # verify test name
then
   if [ "$stg_gen" == 1 ] # create stg gen folder
   then
      run_stg_gen
      exit 2
   fi
   echo -e "\e[31mtop name is not defined, please use \"-t\" or refer to help menu for additional help (\"-h\")\e[39m"
   exit 1
fi


# check exec dir and stg_gen dir
# --------------------------------------------
echo "Creating log File : $log_name"
mkdir -p $exec_dir
printf "Command given:\n\trun_test.bash $command\n " >> $log_name

if [ "$stg_gen" == 1 ] # create stg gen folder
then
   echo "going to run stg -gen"  | tee -a $log_name
   run_stg_gen
   exit 2
fi

if [ ! -d "${RUNDIR}/stg_gen" ]
then
   echo -e "${RED_COLOR}stg_gen folder doesnt exist${END_COLOR}"
   echo -e "You can use \"--stg_gen\" flag to create it correctly. (or refer to help menu for additional help (\"-h\")"
   exit 1
fi

# clean compilation area
# ---------------------------------------------
if [ -e $compilation_path ]
then
   echo "going to backup and clean $compilation_path" | tee -a $log_name
   if [ "$clean" == "1" ]
   then
      if [ "$backup" == "1" ]
      then
         echo "Backuping existing dir" | tee -a $log_name
         if [ -e ${compilation_path}_backup ]
         then
            rm -rf ${compilation_path}_backup
         fi
         mv ${compilation_path} ${compilation_path}_backup
      fi
      echo "Cleaning compilation area" | tee -a $log_name
      rm -rf $compilation_path
   fi
fi

#rm -rf $compilation_path/error.txt
##touch $compilation_path/error.txt
#exec 2>error.txt


# create spa configurations
# ---------------------------------------------
if [ "$use_spa" == 1 ] 
then
   SPA_CONFIG_DIR=${RUNDIR}/spa_config
   echo "Using SPA_CONFIG_DIR=$SPA_CONFIG_DIR" >> $log_name

   enable_spa
fi


# job launch
# ---------------------------------------------
location=0
#let hight=30-$toolnum_for_calc*5
#let toolnum_for_calc--
#loc_increase=400-$toolnum_for_calc*75
#xterm_cmd=xterm -title ${test_name} -geometry 400x$hight+0+$location -e run_test &

prepare_test_cmds
echo -e "Going to run the following xrun commands :\n $test_cmds"  >>  $log_name

#  create waves.tcl
if [ "$waves" != "" ] 
then
   echo -e "Creating waves tcl file :\n $exec_dir/waves.tcl"  >>  $log_name
   echo -e "# this tcl file was created by run_test.bash\ndatabase -open waves -into ${exec_dir}/waves.shm -default\nprobe -create stg_cmn600 -tasks -functions -all -depth all -database waves\n" > ${exec_dir}/waves.tcl
fi

#echo -e "Created run directory for this run "  >>  $log_name
echo "Running test in xterm window"
if [ "$hold" == "-hold" ]
then
   echo -e "${LBLUE_COLOR}Notice you have selected to keep xterm windows open, close them manually when you are ready for the script to continue${END_COLOR}"
fi

#preapre command in temp script, and launch it
xterm_cmd="${test_cmds}"
#xterm_cmd="/nfs/7nm_ddr_tmp/VIPCAT/vipcat_11.30.077-30_Jun_2021_12_51_41/tools/bin/checkSysConf -r -d /nfs/cadtools/cds/xcelium/XLMA-20.09.001/share/patchData"
if [ "$no_grid" == 1 ]
then
   xterm -title ${test_name} -geometry 200x50 $hold -e bash -c 'echo -e "Goging to run:\n $1"; eval $1  2>&1 | tee -a $2; echo -e "\n\n\e[34mFINISHED !!! you can close\e[39m"' bash "$test_cmds" "$log_name" &
   # waiting for jobs to finish
   # ---------------------------------------------
   #echo "Waiting for jobs to be complete"
   # rotating marker animation : while(true); do for a in \\ \| \/ -; do echo -n $a; sleep 1 ; echo -n -e \\r ; done; done
   while [ "`ps -f | grep xterm | grep -v grep | wc -l`" -gt "0" ]
   do
      running=`ps -f | grep xterm | grep -v grep | wc -l`
      printf "Still Running Test in Xterm window...\r"
      sleep 1
   done
   printf "\e[A\033[0K"

else
   printf "%s\n%s\n%s\n%s\n" "setenv PATH $PATH\${PATH};" "setenv DENALI $DENALI;" "setenv LD_LIBRARY_PATH $LD_LIBRARY_PATH:\$LD_LIBRARY_PATH;" "xterm -title ${test_name} -geometry 200x50 $hold -e bash -c '$xterm_cmd 2>&1 | tee -a $log_name ; echo -e \"\n\n\e[34mFINISHED !!! you can close\e[39m\" 2>&1 | tee -a $log_name '" > ${RUNDIR}/qsub.csh
   $qsub_verilog source ${RUNDIR}/qsub.csh | tee -a $log_name
   # waiting for jobs to finish
   # get job number : qstat -j cmn_run_2021_08_10_11_34_47 | grep job_number | awk '{print $2}'
   # get job state :  qstat -j cmn_run_2021_08_10_11_34_47 | grep state
   while [ "`grep \"FINISHED.*you can close\" $log_name | wc -l`" == "0" ]
   do
      printf "Still Running Test in Xterm window...\r"
      sleep 1
   done
fi


# analyze results
# ---------------------------------------------
# echo "                                                         "
# for log in `find $compilation_path -type f -name $session_name`
# do
#    if [[ `echo $log | grep vcs` ]]
#    then
#       echo -e "\e[96mVCS:\e[39m"
#       echo "$log"
#       error_num=`cat $log | grep "^Error" | wc -l`
#       warning_num=`cat $log | grep "^Warning" | wc -l`
#    elif [[ `echo $log | grep modelsim` ]]
#    then
#       echo -e "\e[96mModelsim:\e[39m"
#       echo "$log"
#       error_num=`cat $log | grep "# Errors: [0-9]*, Warnings: [0-9]*" | tail -1 | sed 's/# Errors: \([0-9]*\), Warnings: \([0-9]*\)/\1/g'`
#       warning_num=`cat $log | grep "# Errors: [0-9]*, Warnings: [0-9]*" | tail -1 | sed 's/# Errors: \([0-9]*\), Warnings: \([0-9]*\)/\2/g'`
#    elif [[ `echo $log | grep ius` ]]
#    then
#       echo -e "\e[96mIUS:\e[39m"
#       echo "$log"
#       error_num=`cat $log | grep '*E' | wc -l`
#       warning_num=`cat $log | grep '*W' | wc -l`
#    elif [[ `echo $log | grep novas` ]]
#    then
#       echo -e "\e[96mNOVAS:\e[39m"
#       echo "$log"
#       error_num=`cat $log | grep "Total[[:space:]]*[0-9]* error(s),[[:space:]]*[0-9]* warning(s)" | tail -1 | sed 's/Total[[:space:]]*\([0-9]*\) error(s),[[:space:]]*\([0-9]*\) warning(s)/\1/g'`
#       warning_num=`cat $log | grep "Total[[:space:]]*[0-9]* error(s),[[:space:]]*[0-9]* warning(s)" | tail -1 | sed 's/Total[[:space:]]*\([0-9]*\) error(s),[[:space:]]*\([0-9]*\) warning(s)/\2/g'`
#    else
#       echo "Error, unrecognized log file:"
#       echo "$log"
#       error_num=0
#       warning_num=0
#    fi
# 
#    if [[ `cat $log | egrep "\[ERROR]|CompLock[[:space:]]*Error"` ]]
#    then
#       echo -e "\e[31mCritical Techincal Errors were found during job setup!\e[39m"
#       echo " "
#       let fatal_error++
#       let error++
#    else
#       if [ "$error_num" == "" ]
#       then
#          echo -e "\e[31mError number was not recognized!\e[39m"
#          error_num="NA"
#          let error++
#       elif [ "$error_num" -gt "0" ]
#       then
#          let error++
#       fi
# 
#       if [ "$warning_num" == "" ]
#       then
#          echo -e "\e[31mWarning number was not recognized!\e[39m"
#          warning_num="NA"
#          let warning++
#       elif [ "$warning_num" -gt "0" ]
#       then
#          let warning++
#       fi
# 
#       echo "Errors: $error_num Warnings: $warning_num"
#       echo " "
#    fi
# done
# 
# echo "Summary:"
# if [ "$fatal_error" == "0" ]
# then
#    if [ "$error" == "0" ]
#    then
#       echo -e "\e[96mAll compilers finished with no errors\e[39m"
#       if [ "$warning" -gt "0" ]
#       then
#          echo -e "\e[31mNotice that warnings were found during compilation phase\e[39m"
#       fi
#    else
#       echo -e "\e[31mCritical Errors were found during compilation phase!\e[39m"
#    fi   
# else
#       echo -e "\e[31mCritical Techincal Errors were found during job setup!\e[39m"
#       echo -e "\e[31mIn such case, it is recommended to use \"-k\" switch for keeping xterm windows opened.\e[39m"
# fi
# if [ "$crash" -gt "0" ]
# then
#    echo -e "\e[31mNotice that $crash jobs crashed and did not even start running.\e[39m"
# fi

# ---------------------------------------------
# ---------------------------------------------

exit 0

