#!/pkg/qct/software/python/3.6.0/bin/python3.6

'''
-------------------------------------------------------------------------
File name    : ctags.py
Title        :
Project      :
Developers   : Dima Roginsky
Created      : Mon Sep 02, 2013  11:30AM
Description  :
Notes        :
---------------------------------------------------------------------------
---------------------------------------------------------------------------*/
this script generates ctags file for gvim, it looks for a file list (ncvlog.args) and
generates the tags file in the home directory.
'''

import os,sys
import _thread
import argparse
import utils
import logging
from time import sleep
import run_sim

# globals
#----------------------------------------------
op_done = False
file_list_arr = []
user = os.getlogin()
OrigPwd = os.getcwd()
unmanaged_dir = os.getenv('UNMANAGED_DIR')
tags_path = unmanaged_dir + "/"
scripts = os.getenv("scripts_common") + "/"
tools = os.getenv('tools')
green_open = '\033[32m'
blue_open = '\033[34m'
red_open = '\033[31m'
color_close = '\033[0m'
ctags = utils.start_log("ctags",".",True)
#ctags.setLevel(logging.DEBUG)
#ctags.handlers[0].setLevel(logging.DEBUG)
#----------------------------------------------

usage = "\n" +blue_open+ "gen_ctags.py -t <top_module_name> (-o for output filename) (-e for emacs)"+color_close+"\n"
epilog = blue_open+ '\nYou can close the window' +color_close+ '\n'
parser = argparse.ArgumentParser(description='Generate a tags file (default - for Gvim)', usage=usage, epilog=epilog,formatter_class=argparse.RawTextHelpFormatter)
parser.add_argument('-i'   , help='Specify input filelist (for vcs no need to specify)')
parser.add_argument('-o'   , help='Specify output filename (default is ' + tags_path + '<file_name>)')
parser.add_argument('-e'   , help='gen tags to use with emacs (instead of vim)'       , action="store_true")
parser.add_argument('-t'   , help='Specify top module name'                           , action="store", default = '')
parser.add_argument('--dv' , help='gen tags for DV env'                               , action="store_true")
parser.add_argument('--qbar_comp'  , dest   = 'QBAR_COMP' , action = 'store'      , default = ''    , help = 'in case you want to override the default qbar_compile env variable')
#parser.add_argument('-sv'  , help='gen tags to systemverilog project'                 , action="store_true")
#parser.add_argument('-spv' , help='gen tags to spv project'                           , action="store_true")
#parser.add_argument('-v'   , help='gen tags to verilog project'                       , action="store_true")
#parser.add_argument('-nc'  , help='gen tags to verilog/systemverilog cadance project' , action="store_true")
#parser.add_argument('-vcs' , help='gen tags to verilog/systemverilog VCS project'     , action="store_true")
args = vars(parser.parse_args())
if not args["t"] and not args["dv"]:
    ctags.error(red_open+ "ctags creation Failed. \nYou must specify top module name. use -t flag. \nFor usage help : -h flag."+color_close)
#    parser.print_help()
    print(blue_open+ '\nYou can close the window' +color_close+ '\n')
    sys.exit(1)


def gen_proj_ctags(lang="systemverilog"):
    global op_done
    global args
    ctags.info( "generating ctags...")
    #cmd_str = '/usr/bin/ctags --options=%s/.vim/bin/.ctags --extra=+q --fields=+i --language-force=%s -L filelist.tmp -f '%(home,lang)
    cmd_str = '/usr/bin/ctags --options=%s/verilog_systemverilog_ctags --extra=+q --fields=+i --language-force=%s -L filelist.tmp -f '%(scripts,lang)
    if args['o']:
        cmd_str += args['o']
    else:
        if args["e"]:
            cmd_str += tags_path + "/tags_emacs "
            cmd_str += " -e "
        else:
            cmd_str += tags_path + "/tags_gvim "



    ctags.info( "executing: "+cmd_str)
    return_code = os.system(cmd_str)
    ctags.info( "return code was "+str(return_code))
    if return_code != 0:
        ctags.error(red_open+ "ctags creation Failed. see log for info"+color_close)
    else:
        ctags.info(green_open+ "ctags creation was Successful"+color_close)

    op_done = True

def wait_for_op_end():
    global op_done
    while not op_done:
        sleep(1)
        sys.stdout.write(".")
        sys.stdout.flush()

def thread_for_op_done():
    global op_done
    op_done = False
    _thread.start_new_thread(wait_for_op_end,())

def gen_systemverilog_tags():
    global file_list_arr
    ctags.info( "using file : "+file_list_arr[0])
    ctags.info( "creating temp file...")

    thread_for_op_done()
    popen_cmd = 'grep --regexp .*Parsing.*\\\\.sv '+file_list_arr[0].strip()+'*.log'
    ctags.info( "running "+popen_cmd)
    filelist = os.popen(popen_cmd)
    output_file = open("filelist.tmp","w")
    for line in filelist:
        output_file.write(line.split("'")[1]+"\n")

    output_file.close()
    op_done = True
    #ctags.info( "parsing temp file list...")
    #thread_for_op_done()
    #os.system("perl -pi -e 's/^\s+//' filelist.tmp")
    #op_done = True
    ctags.info( "generating ctags file (at " + tags_path + ")",)
    thread_for_op_done()
    gen_proj_ctags("systemverilog")


def gen_spv_tags():
    global file_list_arr
    ctags.info( "using file :"+file_list_arr[0])
    ctags.info( "creating temp file...")

    thread_for_op_done()
    os.system('find . -name "*.cpp" > filelist.tmp')
    os.system('find . -name "*.h" >> filelist.tmp')
    os.system('find ../../../SpvCommon/ -name "*.cpp" >> filelist.tmp')
    os.system('find ../../../SpvCommon/ -name "*.h" >> filelist.tmp')
    os.system('find ../../../SpvCommonPkt/ -name "*.cpp" >> filelist.tmp')
    os.system('find ../../../SpvCommonPkt/ -name "*.h" >> filelist.tmp')
    os.system('ls /sw/SpvProduct/include/*.h >> filelist.tmp')
    os.system('cat filelist.tmp')
    op_done = True
    #ctags.info( "parsing temp file list...")
    #thread_for_op_done()
    #os.system("perl -pi -e 's/^\s+//' filelist.tmp")
    #op_done = True
    ctags.info( "generating ctags file (at ~/tags)",)
    thread_for_op_done()
    gen_proj_ctags("C++")

def gen_nc_tags():
    ctags.info( "using file :"+args["i"])
    ctags.info( "creating temp file...")

    thread_for_op_done()
    with open(args["i"],"r") as filelist:
        filelist_lines = filelist.readlines()
        os.system("\\rm -rf filelist.tmp")
        for line in filelist_lines:
            try:
                line = line.strip()
                ctags.info( "HANDLING: "+line)
                if line[0]=="/" and line[1]!="/":
                    os.system('echo %s >> filelist.tmp'%line)
                elif "incdir" in line:
                    ctags.info(('find %s -name "*.v" >> filelist.tmp'%(line.split("+")[-1])))
                    os.system('find %s -name "*.v" >> filelist.tmp'%(line.split("+")[-1]))
                    os.system('find %s -name "*.sv" >> filelist.tmp'%(line.split("+")[-1]))
                    os.system('find %s -name "*.svh" >> filelist.tmp'%(line.split("+")[-1]))
                else:
                    ctags.info( "skipping "+line)
                    continue
            except:
                ctags.info( "skipping "+line)
                continue

    os.system('cat filelist.tmp')
    op_done = True
    ctags.info( "generating ctags file (at ~/tags)",)
    thread_for_op_done()
    gen_proj_ctags("systemverilog")

def gen_vcs_tags():
    ctags.info("Generating VCS tags")
    thread_for_op_done()

    # run qbar compilation. (if filelist exists, delete it first)
#    filelist_path = unmanaged_dir+'/qvmr/'+user+'/simland/standalone/default/hdl/vcs_mx/vcs-mx_vK-2015.09-SP2-13-T0428/LINUX64/session.log'
#    if (os.path.isfile(filelist_path)):
#        os.system("\\rm -f "+filelist_path)

    # i don't need to compile qbar anymore. i can generate fielist directly
    if not args["QBAR_COMP"]:
        args["QBAR_COMP"] = os.getenv('qbar_compile')

    # ctags.info("going to run QBAR compilation")
    if args["dv"] :
        ret, logfile = run_sim.comp_qbar_verif("ctags_comp.log")
        args["t"] = "dtr" # no real purpose for this assignment
        in_f = run_sim.prep_filelist(args["t"],args["t"],logfile)
    else:
        #ret, logfile = run_sim.comp_qbar(args["t"], "ctags_comp.log",args["QBAR_COMP"])
        ret, in_f = run_sim.gen_filelist(args["t"])
    if ret:
        ctags.error(red_open+ 'Error generating filelist' +color_close+ '\n')
        ctags.info(red_open+ 'Return Value: '+ret+color_close+ '\n')
        print(blue_open+ '\nYou can close the window' +color_close+ '\n')
        sys.exit(1)
    else:
        ctags.info(green_open+ 'Generated filelist successfully '+color_close+ '\n')


    filelist = open(in_f,'r')

    # create temp filelist for ctags to use
    #ctags.info( "using file :"+filelist)
    ctags.info( "creating temp file...")

    filelist_lines = filelist.readlines()
    os.system("\\rm -rf filelist.tmp")
    for line in filelist_lines:
        try:
            line = line.strip()
            ctags.info( "HANDLING: "+line)
            if line[0]=="/" and line[1]!="/":
                os.system('echo %s >> filelist.tmp'%line)
            elif "incdir" in line:
                ctags.info(('find %s -name "*.v" >> filelist.tmp'%(line.split("+")[-1])))
                os.system('find %s -name "*.v" >> filelist.tmp'%(line.split("+")[-1]))
                os.system('find %s -name "*.sv" >> filelist.tmp'%(line.split("+")[-1]))
                os.system('find %s -name "*.svh" >> filelist.tmp'%(line.split("+")[-1]))
            else:
                ctags.info( "skipping "+line)
                continue
        except:
            ctags.info( "skipping "+line)
            continue

    os.system('cat filelist.tmp')
    op_done = True
    ctags.info( "generating ctags file (at " + tags_path + ")",)
    thread_for_op_done()
    gen_proj_ctags("systemverilog")

def gen_verilog_tags():
    global file_list_arr
    ctags.info( "using file :"+file_list_arr[0])
    ctags.info( "creating temp file...")
    if args["i"]:
        file_list_arr=[args["i"]]
    else:
        file_list_arr=["comp.log"]


    thread_for_op_done()
    popen_cmd = 'grep --regexp .*Parsing.*\\\\.v '+file_list_arr[0].strip()
    ctags.info( "running "+popen_cmd)
    filelist = os.popen(popen_cmd)
    output_file = open("filelist.tmp","w")
    for line in filelist:
        output_file.write(line.split("'")[1]+"\n")

    output_file.close()
    os.system('find . -name "*.v" >> filelist.tmp')
    os.system('find ../../common/rtl -name "*.v" >> filelist.tmp')
    os.system("cat filelist.tmp")
    op_done = True
    #ctags.info( "parsing temp file list...")
    #thread_for_op_done()
    #os.system("perl -pi -e 's/^\s+//' filelist.tmp")
    #op_done = True
    ctags.info( "generating ctags file (at ~/tags)",)
    thread_for_op_done()
    gen_proj_ctags()


def main():
    global op_done
    global args
    global file_list_arr

    #ctags.info( "searching for file list...")
    #thread_for_op_done()
    #file_list = os.popen('find . -name "ncls.log"')
    #op_done = True
    #file_list_arr = file_list.readlines()
    #if not file_list_arr:
    #    ctags.info( "could not find file list, please compile your
    #    project before running the script.")
    #    return
    #else:
    if args["i"]:
        file_list_arr.append(args["i"])
    else:
        file_list_arr.append("")

#    if args["spv"]:
#        gen_spv_tags()

#    if args["v"]:
#        gen_verilog_tags()

#    if args["sv"]:
#        gen_systemverilog_tags()

#    if args["nc"]:
#        gen_nc_tags()

#    if args["vcs"]:
#        gen_vcs_tags()
    gen_vcs_tags()

    ctags.info( "\nctags generation done...")
    #os.system('rm -f filelist.tmp')
    ctags.info( "temp file removed...")
    ctags.info( "operation done.")
    print(blue_open+ '\nYou can close the window' +color_close+ '\n')

main()



