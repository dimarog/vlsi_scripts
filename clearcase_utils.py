#!/usr/bin/python
'''
-------------------------------------------------------------------------
File name    : clearcase_utils.py
Title        : 
Project      : 
Developers   :  droginsk
Created      : Wed Jun 12, 2019  01:58AM
Description  : 
Notes        : 
---------------------------------------------------------------------------

---------------------------------------------------------------------------*/
'''

'''
#----------------------------------------------
#  examples and HELP
#----------------------------------------------

# integration view : 
#------------------    
/prj/qct/clearcase/scripts/list_my_int_view

# find my baseline
#------------------
curr_bl = mybls | grep -w ^$z_magnus_wmss | awk '{print $2}'`

# find pvob
#------------------
pvob= ct lsstream -fmt "%[project]Xp\n"

# find stream
#------------------
stream = ct lsstream -s

# find rebases. extract latest. extract date: 
#------------------
rebase_acts =ct lsact -in $stream@$pvob
last_rebase_act = rebase_acts[-1]
$last_rebase_act=~s/ [\w\W]+//g; 
$find_date=$last_rebase_act;

# find deliveries. extract latest. find date
#------------------
lsbl=ct lsbl -s -stream $stream@$pvob`;
deliverbl=grep(/^deliverbl\./,@lsbl);
$last_deliver_bl_date=deliverbl[-1];
$find_date=`$CT lsbl -fmt "%d\n" $last_deliver_bl_date\@$pvob`;


# find example
#To get the diff of PROD_LABEL_B elements with their predecessor, just exec cleartool diff:
#------------------
cleartool find -avobs \
-element 'lbtype_sub(PROD_LABEL_A) && lbtype_sub(PROD_LABEL_B)' \
-branch 'brtype(whatever_branch_to_speed_up_serach_if_available)' \
-version 'lbtype(PROD_LABEL_B) && !lbtype(PROD_LABEL_A)'
-exec 'cleartool diff -pred $CLEARCASE_PN'

# another find example
#------------------
ct find . -name "*" -version "created_by($USER) / created_since($find_date) / brtype($stream) / 

# find latest checked in version :
#------------------
#ct find <path> -name "<file_name>" -version "brtype(ct lsstream -s)" -print | tail -n 1

# find all checkins since last rebase
#------------------
arr = ct find <path> -name <file_name> -version "brtype(ct lsstream -s) && created_since(<last_rebase_date>)" -print
first_check_in_after_rebase = arr[0]

# find all checkins since last delivery
#------------------
#arr = ct find <path> -name <file_name> -version "brtype(ct lsstream -s) && created_since(<last_delivery_date>)" -print
#first_check_in_after_delivery = arr[0]

'''

import os, sys
import subprocess
import argparse
import utils


#----------------------------------------------
# globals
#----------------------------------------------
green_open = '\033[32m'
blue_open = '\033[34m'
red_open = '\033[31m'
color_close = '\033[0m'

logger = utils.start_log("clearcase_utils",".",True)
#logger.setLevel(logging.DEBUG)
#logger.handlers[0].setLevel(logging.DEBUG)
user = os.getlogin()
OrigPwd = os.getcwd()
mybls = '/usr/local/projects/qct/clearcase/scripts/mybls'

#----------------------------------------------


def ParseArgs():
    global args
    usage = "\nclearcase_utils.py --ld/lr'\n"
    parser = argparse.ArgumentParser(description='', usage=usage, epilog='\n',formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('--lr' , dest  = 'LAST_REBASE' , action = 'store_true' , default = False , help = 'show changes since last rebase by me')
    parser.add_argument('--ld' , dest  = 'LAST_DELV'   , action = 'store_true' , default = False , help = 'show changes since last delivery by me')

    args = vars(parser.parse_args())

    if not args["LAST_REBASE"] and not args["LAST_DELV"]:
        logger.error(red_open + "You must specify what to run. use -h flag" + color_close)
        sys.exit(1)


def set_defines():
    global curr_stream, curr_pvob

    # my baseline
    r = subprocess.Popen('cleartool lsstream -s', shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    curr_stream = r.communicate()[0].rstrip() # ('<stream_name>\n', '')

    # my pvob
    r = subprocess.Popen('cleartool lsstream -fmt "%[project]Xp"',shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    curr_pvob = r.communicate()[0].split('@')[1].rstrip() # ('project:<main_stream>@<pvob_name>\n', '')

    #logger.error(red_open+ "DEBUG: curr_stream = "+curr_stream+color_close)
    #logger.error(red_open+ "DEBUG: curr_pvob = "+curr_pvob+color_close)

# find all modifiable components root paths
#----------------------------------------------
def list_all_components():
    comp_path_list = []
    
    # create list of components
    cmd = 'cleartool des -fmt "%[mod_comps]CXp" stream:' +curr_stream+ '@' +curr_pvob
    #logger.error("DEBUG : list_all_components : running command : "+cmd)
    r = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    out, err = r.communicate()
    mod_component_list = out.split(',')

    # find elements in list
    for comp in mod_component_list:
        cmd = 'cleartool lscomp -fmt "%[root_dir]p" '+comp
        #logger.error("DEBUG : list_all_components : running command : "+cmd)
        r = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        out , err = r.communicate()
        comp_path_list.append(out)


    #logger.error(red_open+ "DEBUG: comp_path_list = :"+color_close)
    #logger.error(comp_path_list)

    return comp_path_list


#----------------------------------------------
def find_rebase_date():
    ''' 
    finds and returns the latest rebase date
    you've done. gets a list of deliveries, and picks the last one
    '''

    # 
    cmd = 'cleartool lsact -in ' +curr_stream+ '@'+curr_pvob
    #logger.error("DEBUG : find_rebase_date: running command : "+cmd)
    r = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    out , err = r.communicate() 
    last_rebase = out.rstrip().split("\n")[-1] #list of line like this:  2019-06-10T03:50:11-07:00  QCTDD06080350  droginsk   "rebase droginsk_magnus_wmss_14lpp_1.0_2 on 20190610.034955
    rebase_date = last_rebase.split()[0]

    #logger.error("DEBUG : find_rebase_date = "+rebase_date)
    return rebase_date


#----------------------------------------------
def find_deliver_date():
    ''' 
    finds and returns the latest delivery date
    you've done. gets a list of deliveries, and picks the last one
    '''

    # 
    cmd = 'cleartool lsbl -s -stream ' +curr_stream+ '@'+curr_pvob
    #logger.error("DEBUG : find_deliver_date: running command : "+cmd)
    r = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    out , err = r.communicate() 
    out_list = out.rstrip().split("\n") #list of line like this:  magnus_wmss_verif_deliverbl.droginsk_magnus_wmss_14lpp_1.0_2.20190611.001648
    delivery_list = [s for s in out_list if "deliverbl." in s]
    last_delivery = delivery_list[-1]
    
    r = subprocess.Popen('cleartool lsbl -fmt "%d\n" ' +last_delivery+ '@'+curr_pvob, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    out , err = r.communicate()
    delivery_date = out.rstrip()

    #logger.error("DEBUG : find_deliver_date: date = "+delivery_date)
    return delivery_date


# all checked in files since date
def first_ci_since_date(paths_list, date):
#arr = ct find <path> -name <file_name> -version "brtype(ct lsstream -s) && created_since(<last_delivery_date>)" -print
#first_check_in_after_delivery = arr[0]

    file_list_without_version = []
    ci_files_with_version_num = []
    element_list = []
    for path in paths_list:
        cmd = 'cleartool find '+path+' -name "*" -version "brtype('+curr_stream+') && created_since('+date+')" -print'
        #logger.error("DEBUG : first_ci_since_date: running command : "+cmd)
        r = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        out , err = r.communicate()
        if out.rstrip():
            ci_files_with_version_num = out.rstrip().split("\n")
            #ci_files = ["/".join(x.split("/")[:-1]) for x in ci_files_with_version_num] # removing version number for each file
            #version_nums = [x.split("/")[-1] for x in ci_files_with_version_num] # taking version numbers 

        # find latest check in per file. assuming they are ordered by version number, so i just need to take the first occurence
        if ci_files_with_version_num:
            for ci_file in ci_files_with_version_num:
                ci_file_without_version_num = "/".join(ci_file.split("/")[:-1]) 
                if ci_file_without_version_num not in file_list_without_version:
                    file_list_without_version.append(ci_file_without_version_num) # saving file without version number
                    element_list.append(ci_file) # saving file with version number

    # print result . decrement 1 from the version number
    #logger.info(green_open+"element_list:"+color_close)
    #for i in element_list:
    #    file_name = "/".join(i.split("/")[:-1])
    #    version_num = i.split("/")[-1]
    #    if version_num != "0":
    #        new_version_num = int(i.split("/")[-1])-1 # decrement version by 1

    #    logger.info(file_name+"/"+str(version_num))

    return element_list


#----------------------------------------------
def print_out_file(element_list):

    ci_changes_list = []
    changes_againt_int_list = []
    ci_changes_file_name = "diff_against_first_checkin_"+user+".txt"
    changes_againt_int_file_name = "diff_against_integration_"+user+".txt"

    for element in element_list:
        element_name = element.split("@")[0]
        integration_latest = "/".join(element.split("/")[:-2]) + "/LATEST"
        element_latest = "/".join(element.split("/")[:-1]) + "/LATEST"

        # check if there was a change indeed
        r = subprocess.Popen("diff "+element+" "+element_name, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        diffs , err = r.communicate()
        if diffs:
            ci_changes_list.append("# changes you've done to the file since last rebase/delivery:\n")
            ci_changes_list.append("# -----------------------------------------------------------\n")
            ci_changes_list.append("tkdiff "+element+" "+element_name+"\n")
            ci_changes_list.append("\n")

        r = subprocess.Popen("diff "+integration_latest+ " "+element_latest, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        diffs , err = r.communicate()
        if diffs:
            changes_againt_int_list.append("# changes in the files against LATEST in integration:\n")
            changes_againt_int_list.append("# -----------------------------------------------------------\n")
            changes_againt_int_list.append("tkdiff "+integration_latest+ " "+element_latest+"\n")
            changes_againt_int_list.append("\n")



    #if ci_changes_list:
    ci_changes_file = open(ci_changes_file_name,"w")
    ci_changes_file.writelines(ci_changes_list)
    ci_changes_file.close()

    #if changes_againt_int_list:
    changes_againt_int_file = open(changes_againt_int_file_name,"w")
    changes_againt_int_file.writelines(changes_againt_int_list)
    changes_againt_int_file.close()

    logger.info("all DIFFS summed up in those files")
    logger.info(blue_open+"\t\t"+ci_changes_file_name+color_close)
    logger.info(blue_open+"\t\t"+changes_againt_int_file_name+color_close)


#----------------------------------------------
def main():
    set_defines()
    comp_path_list = list_all_components()
    
    if args["LAST_REBASE"]:
        element_list = first_ci_since_date(comp_path_list , find_rebase_date())
        print_out_file(element_list)

    if args["LAST_DELV"]:
        element_list = first_ci_since_date(comp_path_list , find_deliver_date())
        print_out_file(element_list)


#----------------------------------------------
if __name__=="__main__":
    ParseArgs()
    main()

