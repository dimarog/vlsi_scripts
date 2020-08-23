#!/usr/bin/python
'''
-------------------------------------------------------------------------
File name    : filter_opt_regs.py
Title        :
Project      :
Developers   :  droginsk & ynissani
Created      : Sun May 06, 2018  02:28AM
Description  :
Notes        :
---------------------------------------------------------------------------

---------------------------------------------------------------------------*/
'''
from __future__ import print_function
import argparse
import subprocess
import os,sys,re
import datetime
import utils
from time import sleep
import logging


# globals
#----------------------------------------------
# label dir parents
user = os.getlogin()
OrigPwd = os.getcwd()
tools = os.getenv('tools')
green_open = '\033[32m'
blue_open = '\033[34m'
red_open = '\033[31m'
yellow_open = '\033[33m'
color_close = '\033[0m'
logger = utils.start_log("filter_opt_regs",".",True)
#logger.setLevel(logging.DEBUG)
#logger.handlers[0].setLevel(logging.DEBUG)
#----------------------------------------------

def ParseArgs():
    global args
    usage = "\nfilter_opt_regs.py -i $synth/uflow/opt_regs/phy_fe_tx.initopt.opt_regs.rpt -w my_waiver.wl (optional -o <out_file_name>)\n"
    parser = argparse.ArgumentParser(description='filter_opt_regs.py', usage=usage, epilog='\n',formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-i' , nargs = '+'  , dest  = 'IN_FILES' , action = 'store' , default = []  , help = 'List of input files to filter. (note the syntax, single -i flag for all files)')
    parser.add_argument('-w'                , dest  = 'WAIVER'   , action = 'store' , default = ""  , help = 'waiver file name to use')
    parser.add_argument('-o' , nargs = '+'  , dest  = 'OUT_FILES', action = 'store' , default = []  , help = 'List of output file names. amount of names should be the same as the number of input files.\nif omitted - default naming is used <in_file>.filtered. (note the syntax, single -o flag for all files)')
    args = vars(parser.parse_args())

    # Arguments checks
    if not args["IN_FILES"]:
        logger.error(red_open + "You must specify an input opt_regs file, use -i flag.\tFor usage use -h flag." + color_close)
        sys.exit(1)
    else:
        for in_file in args["IN_FILES"]:
            if not os.path.isfile(in_file):
                logger.error(red_open + "No such file used with -i flag: " + in_file + "\tFor usage use -h flag." + color_close)
                sys.exit(1)

    if not args["WAIVER"]:
        logger.error(red_open + "You must specify a waiver file, use -w flag.\tFor usage use -h flag." + color_close)
        sys.exit(1)
    else:
        if not os.path.isfile(args["WAIVER"]):
            logger.error(red_open + "No such file used with -w flag: " + args["WAIVER"] + "\tFor usage use -h flag." + color_close)
            sys.exit(1)

    if args["OUT_FILES"]:
        if len(args["OUT_FILES"]) != len(args["IN_FILES"]):
            logger.warning(yellow_open + "number of specified output files is different than the amount of input files" + color_close)
            logger.warning(yellow_open + "going to use default naming : <input_file_name>.filtered" + color_close)
            logger.warning(yellow_open + "\tuse -o flag to psecify otherwise" + color_close)
            args["OUT_FILES"] = []
    else:
        logger.warning(yellow_open + "No output file names specified" + color_close)
        logger.warning(yellow_open + "going to use default naming : <input_file_name>.filtered" + color_close)
        logger.warning(yellow_open + "\tuse -o flag to psecify otherwise" + color_close)


def filter_regs(in_files_list,waiver,out_file_list):
    global curr_waive_rule

    # create waiver list
    waive_f = open(waiver,'r')
    waive_f_lines = waive_f.readlines()
    waive_f.close()
    # create regexp rules from waive lines
    waive_lines_len = len(waive_f_lines)
    for i in range (waive_lines_len):
        waive_f_lines[i] = replace_special_chars(waive_f_lines[i])
        waive_f_lines[i] = waive_f_lines[i].replace('\\[*\\]', '\\[\d+\\]') # change \\[*\\] to \\[\d+\\]
        waive_f_lines[i] = re.sub('([^\[])\*', r'\1\\w*', waive_f_lines[i]) # all * replaced by w+. except for [*]
        waive_f_lines[i] = re.sub('\s*;.*', '', waive_f_lines[i])           # removed comments. everything after ;


    # per input file create input list
    in_f_lines = {}
    for in_file in in_files_list:
        in_f = open(in_file,'r')
        in_f_lines[in_file] = in_f.readlines()
        in_f.close()


    # create output lists - go over each input list, insert non-waived lines to output list
    idx = 0
    last_rule_idx = 0
    for in_file_key in in_f_lines:                   # go over all input files
        logger.info("Processing input file:\t" + in_file_key + "\n")

        out_file = []
        for in_file_line in in_f_lines[in_file_key]: # and go over all lines
            if (idx%20 ==0):
                print("Processesed " + str(int(float(idx)/len(in_f_lines[in_file_key])*100)) + "%", end="\r", file=sys.stdout.flush())
            rule_match = False
            new_in_file_line = re.sub('\*', r'', in_file_line) # all * replaced by NULL
            line_bit_sel_list = re.split('\[*\]',new_in_file_line) # check if input line consists of bit select
            for rule_idx in range(last_rule_idx, waive_lines_len+last_rule_idx):         # check line vs waive rules
                waive_rule = waive_f_lines[rule_idx % waive_lines_len]
                curr_waive_rule = waive_rule
                rule_ranges_list = re.split('\[*\\\]',waive_rule) # split by [] . one or more digits in the []
                range_match = check_line_in_range(line_bit_sel_list,rule_ranges_list)  # check if line consist bit sel inside rule min & max range, update curr_waive_rule
                if re.match(curr_waive_rule, new_in_file_line) or range_match:
                    rule_match = True
                    break

            # insert line to output list if it doesn't match any waive rule
            if not rule_match and not in_file_line.startswith("Info:"):
                out_file.append(in_file_line)

            # save last rule idx to start the following input line from current rule
            last_rule_idx = rule_idx
            idx = idx+1

        # write curr output file
        if out_file_list:
            out_file_name = out_file_list[in_files_list.index(in_file_key)]
        else:
            out_file_name = in_file_key + '.filtered'
        out_f = open(out_file_name,'w')
        out_f.writelines(out_file)
        out_f.close()
        logger.info(blue_open + "Succefully created the following files:\t"+out_file_name + color_close)


    return



# if rule consist range and in line consist bit select - extract min and max
def check_line_in_range(line_bit_sel_list, rule_ranges_list):
#    global curr_waive_rule

    ret = False
#    new_waive_rule = ''
    sline_len = len(line_bit_sel_list)
    srule_len = len(rule_ranges_list)
    returns_list  = [False]*(srule_len-1) # dont need the last one. doesnt have a range
    if (srule_len > 1) and (sline_len > 1) and (srule_len == sline_len):
        for idx in range (len(rule_ranges_list)-1):
            sline = line_bit_sel_list[idx]
            srule = rule_ranges_list[idx]
            in_bit_sel_match = re.match('.*\[(\d+)\s*$',sline) # check if input line consists of bit select
            rule_range_match = re.match('^.*\[(\d+):(\d+)',srule)
            rule_mod_match   = re.match('^.*\[(\d+)%(\d+)',srule)
            if in_bit_sel_match and rule_range_match:
                in_bit_sel = int(in_bit_sel_match.group(1))
                rule_range_max = int(rule_range_match.group(1))
                rule_range_min = int(rule_range_match.group(2))
                waive_rule_part = re.sub('(^.*)\[(\d+):(\d+)', r'\1[\d+' ,srule) # remove range for srule comparison
#                new_waive_rule += waive_rule_part
                if (in_bit_sel >= rule_range_min and in_bit_sel <= rule_range_max) and (re.match(waive_rule_part, sline)):
                    returns_list[idx] = True
            elif in_bit_sel_match and rule_mod_match:
                in_bit_sel = int(in_bit_sel_match.group(1))
                rule_mod_val = int(rule_mod_match.group(1))
                rule_mod     = int(rule_mod_match.group(2))
                waive_rule_part = re.sub('(^.*)\[(\d+)%(\d+)', r'\1[\d+' ,srule) # remove modulo for srule comparison
#                new_waive_rule += waive_rule_part
                if ((in_bit_sel % rule_mod) == rule_mod_val) and (re.match(waive_rule_part, sline)):
                    returns_list[idx] = True
            else: # in case curr rule part has no range or modulo
                if re.match(srule,sline):
                    returns_list[idx] = True
#                new_waive_rule += srule

        # update the new rule. without ranges
#        curr_waive_rule = new_waive_rule
        if all(x for x in returns_list):
            ret = True

    return ret


def replace_special_chars(line):
    special_chars = ['\/', '\[', '\]', '\.', '\{', '\}']
    for sp_char in special_chars:
        line = re.sub(sp_char, '\\'+sp_char, line)

    return line



def main():

    # call filtering func
    filter_regs(args["IN_FILES"],args["WAIVER"],args["OUT_FILES"])



if __name__=="__main__":
    ParseArgs()
    main()
