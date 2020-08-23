#!/pkg/qct/software/python/3.6.0/bin/python3.6
'''
-------------------------------------------------------------------------
File name    : /usr2/droginsk/scripts/run_sim.py
Title        :
Project      :
Developers   :  droginsk
Created      : Sun Feb 18, 2018  04:19AM
Description  :
Notes        :
---------------------------------------------------------------------------

---------------------------------------------------------------------------*/
'''

import argparse
import subprocess
import os,sys,re
import datetime
import utils
from time import sleep
import logging
import _thread
import shutil


# globals
#----------------------------------------------
op_done = False
# label dir parents
user = os.getlogin()
OrigPwd = os.getcwd()
unmanaged_dir = os.getenv('UNMANAGED_DIR')
tools = os.getenv('tools')
green_open = '\033[32m'
blue_open = '\033[34m'
red_open = '\033[31m'
color_close = '\033[0m'
logger = utils.start_log("run_sim",".",True)
#logger.setLevel(logging.DEBUG)
#logger.handlers[0].setLevel(logging.DEBUG)
bsub = 'bsub -Ip -R "select[type==LINUX64  && sles12 &&  mem>8000]" -q priority '
#----------------------------------------------


class c_port():
    def __init__(self, direction, size, name):
        self.direction = direction
        self.size = size
        self.name = name


def ParseArgs():
    global args
    usage       = "\nMandatory: run_sim.py -t <top name> \nOptional: -xf <extra_filelist> -m <makefile> --tb <testbench> -c <clean> ...."
    description = "this is a script for compiling a design, running your own testbench, generating fileslists, etc..."
    parser = argparse.ArgumentParser(description=description, usage=usage, epilog='\n',formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-t'           , dest  = 'TOP'        , action = 'store'      , default = ""    , help = 'top name')
    parser.add_argument('-m'           , dest  = 'MAKEFILE'     , action = 'store'      , default = ""    , help = 'specify this makefile name ONLY if it is other than top_name. the main Makefile o use (if needed)')
    parser.add_argument('--tb'         , dest  = 'TB_FILE'    , action = 'store'      , default = ""    , help = 'testbench to use with your design. if none is specified, a default one is created')
    parser.add_argument('--vo'           , dest  = 'COMP_ONLY'  , action = 'store_true' , default = False , help = 'ONLY compile the design. without running')
    parser.add_argument('--wo'           , dest  = 'WAVES_ONLY' , action = 'store_true' , default = False , help = 'ONLY OPEN gui with the run results. "post preocessing"')
    parser.add_argument('--ro'           , dest  = 'RUN_ONLY'   , action = 'store_true' , default = False , help = 'Runs the already compiled design. used when only tcl file has changed')
    parser.add_argument('--xf'         , dest  = 'EXTRA_F'    , action = 'store'      , default = ""    , help = 'additional filelist to the one compiled for the given module_name')
    parser.add_argument('-c'           , dest   = 'CLEAN'     , action = 'store_true' , default = False , help = 'clean previous compilation before the new one')
    parser.add_argument('-g'           , dest   = 'GUI'       , action = 'store_true' , default = False , help = 'open gui and run')
    parser.add_argument('--tcl'        , dest   = 'TCL'       , action = 'store'      , default = ''    , help = 'provide a tcl file to execute in simulation')
    parser.add_argument('-o'           , dest   = 'OUT_DIR'   , action = 'store'      , default = ''    , help = 'define an output dir other than $UNMANAGED_DIR/my_vcs/<top name>')
    parser.add_argument('--qbar_comp'  , dest   = 'QBAR_COMP' , action = 'store'      , default = ''    , help = 'in case you want to override the default qbar_compile env variable')
    parser.add_argument('--tbo'        , dest  = 'TB_FILE_DIR', action = 'store'      , default = "."   , help = 'testbench file location. default is current dir')
#    parser.add_argument('--nq'         , dest   = 'NO_QBAR'   , action = 'store_true' , default = False , help = 'DONT compile qbar first')
#    parser.add_argument('--first_time' , dest  = 'FIRST_TIME' , action = 'store_true' , default = False , help = 'first time use.  creates a testbench over your DUT, and compiles it')
    args = vars(parser.parse_args())

    if not args["TOP"]:
        logger.error(red_open + "You must specify a top name. use -t flag" + color_close)
        sys.exit(1)

#    if args["FIRST_TIME"]:
#        if not args["EXTRA_F"] or not args["TOP"]:
#            logger.error(red_open+ "You must specify a filielist to run. use '--xf' flag" +color_close)
#            sys.exit()
    

    if not args["OUT_DIR"]:
        args["OUT_DIR"] = unmanaged_dir+"/my_vcs/"+args["TOP"]
        if os.path.isdir(args["OUT_DIR"]) :
            if args["CLEAN"]:
                shutil.rmtree(args["OUT_DIR"], ignore_errors=True)
                sleep(1)
                os.makedirs(args["OUT_DIR"])
                sleep(1)
            else:
                logger.info(red_open+"Warning! overwriting existing test directory "+args["OUT_DIR"]+color_close)
        else:
            logger.info("Creating output directory %s"%args["OUT_DIR"])
            os.makedirs(args["OUT_DIR"])
            sleep(1)

    if not args["MAKEFILE"]:
        args["MAKEFILE"] = args["TOP"]
        if not os.getenv(args["MAKEFILE"]):
            logger.info("no makefile for module '"+args["MAKEFILE"]+"'")
            logger.info("Using DTR_WRAPPER instead")
            args["MAKEFILE"] = "dtr_wrapper"


    if args["EXTRA_F"]:
        if not os.path.isfile(OrigPwd + "/"+args["EXTRA_F"]): # relative path
            if not os.path.isfile(args["EXTRA_F"]): #absolute path
                logger.error(red_open + "No such file list used with --xf flag" + color_close)
                sys.exit(1)
        else:
            args["EXTRA_F"] = OrigPwd + "/"+args["EXTRA_F"]

    if args["TB_FILE"]:
        if not os.path.isfile(args["TB_FILE"]):
            logger.error(red_open + "No such file "+args["TB_FILE"] + color_close)
            sys.exit(1)
        args["TB_FILE"] = os.path.abspath(args["TB_FILE"])

    if not args["QBAR_COMP"]:
        args["QBAR_COMP"] = os.getenv('qbar_compile')
        #if not qbar_compile:
        #    logger.error(red_open + "No qbar_compile specified. i don't know how to compile.\nuse --qbar_comp flag to set it.\n example : --qbar_comp tools/setup" + color_close)
        #    sys.exit(1)

def wait_for_op_end():
    global op_done
    while not op_done:
        sleep(1)
        sys.stdout.write(".")
        sys.stdout.flush()

def wait_for_file_created(file_path):
    global op_done
    while not op_done:
        sleep(1)
        if os.path.isfile(file_path):
            op_done = True
            return

def thread_for_op_done(func_name = wait_for_op_end):
    global op_done
    op_done = False
    _thread.start_new_thread(wait_for_op_end,())


def modify_fe_gen_filelist(in_file, extra_filelist=None):
    extra_lines = []

    if not os.path.isfile(in_file):
        logger.error(red_open+"No such filelist : "+in_file+color_close)
        sys.exit(1)

    opened_file = open(in_file)
    in_lines = opened_file.readlines()
    opened_file.close()
    lines=['\n'.join(l.split(' ')) for l in in_lines]

    if extra_filelist:
        extra_in_f = open(extra_filelist)
        extra_lines = extra_in_f.readlines()
        extra_in_f.close()


    new_file_path = os.path.dirname(in_file) + "/my_generated_filelist.f"
    new_file = open(new_file_path,"w")
    new_file.writelines(lines + extra_lines)
    new_file.close()

    return new_file_path

def modify_qbar_filelist(top,module,qbar_logfile,extra_f=None):
    extra_lines = []
    design_files = []
    included_files = []
    # not complete. missing incdirs
    #in_f = open(unmanaged_dir+'/qvmr/'+user+'/simland/standalone/default/hdl/vcs_mx/vcs-mx_vK-2015.09-SP2-13-T0428/LINUX64/'+module+'_dut.fe_filelist','r')
    # not complete. missing incdirs also. but shorter
    #in_f = open(unmanaged_dir+'/qvmr/'+user+'/simland/standalone/default/hdl/vcs_mx/vcs-mx_vK-2015.09-SP2-13-T0428/LINUX64/simv.dut.'+module+'.daidir/debug_dump/src_files_verilog','r')

    module_dir = os.getenv(module)
    module_dir += "/src/"
    if module_dir and os.path.isdir(module_dir):
        # parse qbar log file
        #in_f = open(unmanaged_dir+'/qvmr/'+user+'/simland/standalone/default/hdl/vcs_mx/vcs-mx_vK-2015.09-SP2-13-T0428/LINUX64/session.log','r')
        in_f = open(qbar_logfile,'r')
        in_f_lines = in_f.readlines()
        in_f.close()
        for line in (in_f_lines):
            if "Parsing design file" in line:
                temp = line.split("Parsing design file")
                temp = temp[1].strip().replace("'","")
                temp += "\n"
                if temp not in design_files:
                    design_files.append(temp)
            elif "Parsing included file" in line:
                temp = line.split("Parsing included file")
                temp = temp[1].strip().strip(".").replace("'","") # clean the line
                temp = ("/").join(temp.split("/")[:-1]) # remove filename. leave only the path to it
                temp = "+incdir+" +temp
                temp += "\n"
                if temp not in included_files:
                    included_files.append(temp)
    else:
        logger.info(blue_open+ "No valid module name given. using ONLY the specified filelist\n"+color_close)


    if extra_f:
        extra_in_f = open(extra_f)
        extra_lines = extra_in_f.readlines()
        extra_in_f.close()



    # write final file
    new_f_name = top+ '_new.f'
    out_f = open(new_f_name,'w')
    out_f.writelines(included_files + design_files + extra_lines)
    out_f.close()

    filelist = new_f_name

    return filelist

def gen_filelist(module,out_dir=".",extra_filelist=None):
    ''' 
    command example :
    /pkg/qct/bin/perl /iceng/fe_ref_flow/rtlutil/1.6/fe_gen_filelist/fe_gen_filelist.pl -t vcs -d makefile -b dtr_wrapper
    '''
    global op_done
    #set temporary UNMANAGED_DIR
    temp_qvmr_path = unmanaged_dir+"/temp_qvmr"
    if os.path.isdir(temp_qvmr_path):
        os.system("rm -rf "+temp_qvmr_path)
    os.mkdir(temp_qvmr_path)
    os.environ["UNMANAGED_DIR"] = temp_qvmr_path

    # generate filelist
    # prepare command
    file_name = 'vcs_filelist'
    file_path = out_dir
    cmd = '/pkg/qct/bin/perl /iceng/fe_ref_flow/rtlutil/1.6/fe_gen_filelist/fe_gen_filelist.pl -t vcs -d makefile -b '+module+ ' -o '+file_path+' -f '+file_name

    logger.info ("Generating inital filelist : "+cmd+"\n")
    thread_for_op_done()

    out,err = utils.sys_cmd(cmd,"utf-8")
    wait_for_file_created(file_path + "/" +file_name)
    generation_ret_val = err

    #revert UNMANAGED_DIR to original location
    # NOT NEEDED. once you exit, it reverts to original
    #os.environ["UNMANAGED_DIR"] = unmanaged_dir

    filelist = out_dir+"/vcs_filelist"
    new_filelist = modify_fe_gen_filelist(filelist, extra_filelist)
    logger.info(f'{blue_open} Generated filelist : {filelist} {color_close} \n')
    return generation_ret_val, new_filelist


def comp_qbar(module, logfile_name, qbar_compile):
    #set temporary UNMANAGED_DIR
    temp_qvmr_path = unmanaged_dir+"/temp_qvmr"
    logfile = temp_qvmr_path + '/' + logfile_name
    if os.path.isdir(temp_qvmr_path):
        os.system("rm -rf "+temp_qvmr_path)
    os.mkdir(temp_qvmr_path)
    os.environ["UNMANAGED_DIR"] = temp_qvmr_path

    # compile using qbar. to create the file list
    # prepate qbar command
    if qbar_compile:
        qbar_cmd = bsub + 'qbar -vcs elab_dut -exec_dir '+qbar_compile+' HDL_TOP_SPEC=' +module+' -logfile ' + logfile
#    elif "caster_wmss" in os.getenv["CLEARCASE_ROOT"]:
#        qbar_cmd = bsub + 'qbar elab_dut -exec_dir '+tools+'/setup HDL_TOP_SPEC=' +module + ' -logfile ' + logfile
    else:
        qbar_cmd = bsub + 'qbar elab_dut -exec_dir '+tools+'/setup HDL_TOP_SPEC=' +module + ' -logfile ' + logfile

    logger.info(blue_open+ 'Running qbar compilation to create a filelist to use for vcs later' +color_close+ '\n')
    logger.info ("command : "+qbar_cmd+"\n")
    #compilation = subprocess.call(qbar_cmd, shell=True)
    compilation = os.system(qbar_cmd)

    #revert UNMANAGED_DIR to original location
    # NOT NEEDED. once you exit, it reverts to original
    #os.environ["UNMANAGED_DIR"] = unmanaged_dir

    return compilation, logfile

def comp_qbar_verif(logfile_name):
    #set temporary UNMANAGED_DIR
    temp_qvmr_path = unmanaged_dir+"/temp_qvmr"
    logfile = temp_qvmr_path + '/' + logfile_name
    if os.path.isdir(temp_qvmr_path):
        os.system("rm -rf "+temp_qvmr_path)
    os.mkdir(temp_qvmr_path)
    os.environ["UNMANAGED_DIR"] = temp_qvmr_path
    qvmr_path = os.getenv("qvmr")

    # compile using qbar. to create the file list
    # prepate qbar command
    if "magnus_dtr" in os.getenv("CLEARCASE_ROOT"):
        qbar_cmd = bsub + 'qbar  elab -exec_dir '+qvmr_path+' -logfile ' + logfile
    elif "caster_dtr" in os.getenv("CLEARCASE_ROOT"):
        qbar_cmd = bsub + 'qbar  elab -exec_dir '+qvmr_path+ ' BLOCK=dtr_wrapper TEST_NAME=DtrWrapTxRampUp.sv -logfile ' + logfile
    elif "rfc" in os.getenv("CLEARCASE_ROOT"):
        qbar_cmd = bsub + 'qbar  elab -exec_dir /vobs/cores/modemip/rfc/rfc_verif/tool_setup/qvmr TEST_NAME=rfc_reg_test -logfile ' + logfile
    else :
        logger.info(red_open+ 'Only magnus_dtr and caster_dtr are currently supported' +color_close+ '\n')
        sys.exit(1)

    logger.info(blue_open+ 'Running qbar compilation to create a filelist to use for vcs later' +color_close+ '\n')
    logger.info ("command : "+qbar_cmd+"\n")
    #compilation = subprocess.call(qbar_cmd, shell=True)
    compilation = os.system(qbar_cmd)

    #revert UNMANAGED_DIR to original location
    # NOT NEEDED. once you exit, it reverts to original
    #os.environ["UNMANAGED_DIR"] = unmanaged_dir

    return compilation, logfile

def create_tb_file(filelist, top):
    dut_file_path = None

    dut_file_path = find_module_in_filelist(filelist,top)
    logger.info("the found TOP file path is : "+dut_file_path)
    if not dut_file_path:
        logger.error(red_open+ 'could not find '+top+' in any filelist , So couldnt Create TestBench file....'+color_close+'\n')

    tb_file = create_testbench(dut_file_path, args["TB_FILE_DIR"])
    logger.info(blue_open+"Don't forget to add the new TestBench file to your filelist"+color_close)

    return os.path.abspath(tb_file)

def create_work_dir():
    err = 0
    QVMR_VERSION     = os.getenv("QVMR_VERSION")
    QVMR_HOME        = "/pkg/qvmr/"+QVMR_VERSION
    config_file_name = "synopsys_sim.setup"
    config_file      = QVMR_HOME+"/qbar/templates/vcs_mx/"+config_file_name
    hdl_work = "hdl_work"

    # check if comp folder exist:
    # ------------------------
    if os.path.isfile(config_file_name):
        #cmd = f'grep hdl_work {config_file} | cut -d ":" -f2'
        #grep_res,e = utils.sys_cmd(cmd,'utf-8')
        #grep_res = grep_res.strip()
        #if grep_res == 
        logger.info(f"config_file already exists : {config_file}")
        return hdl_work

    # copy synopsys_sim.setup to run_dir
    # ------------------------
    logger.info("Copying "+config_file+" to "+os.getcwd())
    shutil.copy(config_file, ".")

    # mkdir "hdl_work" or something, under run_dir. and Vcmap
    # ------------------------
    if os.path.isdir(hdl_work):
        os.system("rm -rf "+hdl_work)
    os.mkdir(hdl_work)
    cmd = "Vcsmap "+hdl_work+" "+os.getcwd()+"/"+hdl_work
    #logger.info("VCS_MX command: "+cmd)
    #vcs_map = os.system(vcs_cmd)
    logger.info(cmd)
    vcs_map,err = utils.sys_cmd(cmd)

    if err:
        logger.error(f"{red_open}Error Creating working dir{color_close}")
        logger.info(err)
        logger.info("Exiting...")
        sys.exit(1)
    
    return hdl_work

def comp_vcs_mx(top, makefile, out_dir, tb_file = None, extra_filelist=None):
    '''
    3 steps:
        1. create filelist
        2. copy synopsys_sim.setup to run_dir
        3. mkdir "hdl_work" or something, under run_dir
        4. Vcsmap "hdl_work" to "run_dir_full_path/hdl_work"
        5. Vlogan -sverliog -f "filelist" -work hdl_work
        6. Vcs  hdl_work.<top_name> -debug_all -timescale=1ps/1ps -P /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.6/pli/bin/qcmemmodel_pli_0_6.tab /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.6/pli/bin/amd64/qcmemmodel_pli_0_6.so  -o simv.dut.phy_fe_logger
        '''

    # Create filelist
    # ------------------------
    if not os.path.isfile("my_generated_filelist.f"):
        ret,filelist = gen_filelist(makefile,out_dir,extra_filelist)
    else:
        filelist = os.getcwd()+"/my_generated_filelist.f"

    # create tb_file and add to 
    # ------------------------
    if not tb_file:
        tb_file = create_tb_file(filelist,top)

    # Create working folder
    # ------------------------
    hdl_work = create_work_dir()
    
    # Vlogan
    # ------------------------
    timescale = "-timescale=1ns/1ns"
    cmd = "Vlogan -qc_force64 -qc_remove_env DW_LICENSE_OVERRIDE -qc_standalone +warn=noPHNE +v2k -sverilog "+timescale+" -f "+filelist+" "+tb_file+" -work "+hdl_work

    #logger.info("VCS_MX command: "+cmd)
    #vlogan = os.system(vcs_cmd)
    logger.info(cmd)
    #vlogan,e = utils.sys_cmd(cmd,"utf-8")
    #logger.info(vlogan)
    #e = os.system(bsub+" " +cmd)
    e = os.system(cmd)
    if e:
        logger.error(f"{red_open} Failed Vlogan. see log under $UNMANAGED_DIR {color_close}\n")
        sys.exit(1)
    
    # retrieve variables and run elaboration
    # ------------------------
    cmd = 'grep -e "VCS_OPTS.*-P" '+args["QBAR_COMP"]+'/Makefile | cut -d "=" -f2'
    grep_res,e = utils.sys_cmd(cmd,'utf-8')
    grep_res = grep_res.strip()
    hdl_work = hdl_work+"."+os.path.basename(tb_file).split(".")[0]
    #cmd = "Vcs "+hdl_work+" -debug_all "+timescale+" "+grep_res+" -o simv"
    cmd = "Vcs "+hdl_work+" -debug "+timescale+" "+grep_res+" -o simv"
    logger.info(cmd)
    #vcs_res,e = utils.sys_cmd(cmd,"utf-8")\
    #logger.info(vcs_res)
    #e = os.system(bsub+" " +cmd)
    e = os.system(cmd)
    if e:
        logger.error(f"{red_open} Failed VCS. see log under $UNMANAGED_DIR {color_close}\n")
        sys.exit(1)

    return


def comp_vcs(top, filelist, tb_file = None):
    # compile using VCS

    vcs_cmd = bsub+ 'Vcs -l vcs.log -debug_all +v2k -timescale=1ns/1ns -sverilog -Mupdate '

    if "caster" in os.getenv("CLEARCASE_ROOT"):
        vcs_cmd += '-P /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.6/pli/bin/qcmemmodel_pli_0_6.tab /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.6/pli/bin/amd64/qcmemmodel_pli_0_6.so '
    elif "magnus" in os.getenv("CLEARCASE_ROOT"):
        vcs_cmd += '-P /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpp/0.5/pli/bin/qcmemmodel_pli_0_5.tab /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpp/0.5/pli/bin/amd64/qcmemmodel_pli_0_5.so '
    elif "rfc_1.0" in os.getenv("CLEARCASE_ROOT"):
        vcs_cmd += '-qc_standalone -qc_remove_env DW_LICENSE_OVERRIDE -timescale=1ns/1ps +plusarg_save +plusarg_ignore -full64 -sverilog -assert enable_diag +error+100 +QSB_AXI_UVM_VCS +QSB_AHB_UVM_VCS +vcs+lic+wait -cm_name test1 -lca  -CFLAGS "-O0" +vc+list /pkg/qcsw/memoryMagic2/QCmemmodel_sec5lpe/2.0/pli/bin/amd64/qcmemmodel_pli.so +vc+list /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.5/pli/bin/amd64/qcmemmodel_pli_0_5.so -P /pkg/qcsw/memoryMagic2/QCmemmodel_sec5lpe/2.0/pli/bin/qcmemmodel_pli.tab -P /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.5/pli/bin/qcmemmodel_pli_0_5.tab -xlrm uniq_prior_final /prj/qct/evals_synopsys_projects7/RFFE/N-2017.12-3/vip/common/latest/C/lib/suse64/VipCommonNtb.so '
    else:
        vcs_cmd += '-P /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.5/pli/bin/qcmemmodel_pli_0_5.tab /pkg/qcsw/memoryMagic2/QCmemmodel_sec14lpcrf/0.5/pli/bin/amd64/qcmemmodel_pli_0_5.so '

    vcs_cmd += '-f '+filelist+ ' '
    if tb_file:
        top = os.path.basename(tb_file).split(".")[0]

    vcs_cmd += '-top '+top+' '+tb_file+' '


#    compilation = subprocess.Popen((cmd), shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
#    val, err = compilation.communicate()
#    if err:
#        logger.error(red_open + "compilation error " +color_close+ "Command used :\n%s " %(cmd))
#        sys.exit(1)

    logger.info(blue_open+ 'Running VCS compilation  ' +color_close+ '\n')
    logger.info ("command : "+vcs_cmd+"\n")
    #compilation = subprocess.call(vcs_cmd, shell=True)
    compilation = os.system(vcs_cmd)

    return compilation

def run(gui,tcl_file):
    run_cmd = './simv '
    if gui:
        run_cmd += '-gui '
    else:
        if not os.path.isfile(tcl_file):
            logger.info("No valid tcl file specified. using default one")
            tcl = open("run.tcl",'w')
            tcl.write("dump -add / -depth 0 \n")
            tcl.write("run 1ms\n")
            tcl.write("quit\n")
            tcl.close()
            tcl_file = "run.tcl"

    run_cmd += '-ucli -i %s ' %(tcl_file)

    logger.info(blue_open+ 'Running DVE simulation ' +color_close+ '\n')
    logger.info ("command : "+run_cmd+"\n")
    os.system(run_cmd)


def find_module_in_filelist(filelist, module_name):
    ''' recieves a filelist, and returns a module path '''

    # check file exists
    if not os.path.isfile(filelist):
        logger.error(red_open+"No such file "+filelist+color_close)
        sys.exit()

    in_file    = open(filelist)
    lines      = in_file.readlines()
    in_file.close()

    #
    for line in lines:
        if re.match("^\s*//", line): # comment line
            continue
        if re.match("^\s*$", line): # empty line
            continue

        file_path = line.strip()
        file_name = os.path.basename(line).split(".")[0]
        if module_name == file_name:
            break

    return file_path


def create_testbench(dut_file_path, tb_file_dir):
    ''' create testbench wrapper for a DUT module '''

    # # check file exists
    # if not os.path.isfile(dut_file_path):
    #     logger.error(red_open+"No such file "+dut_file_path+color_close)
    #     sys.exit()

    # out_file_path = os.path.abspath(dut_file_path).split(".")[0]+"_tb.v"
    out_file_path = tb_file_dir + "/" +os.path.basename(dut_file_path).split(".")[0]+"_tb.sv"
    if os.path.isfile(out_file_path):
        logger.info("Testbench file already exists. not creating a new one:\n\t"+out_file_path)
        return out_file_path

    dut_file       = open(dut_file_path)
    dut_lines      = dut_file.readlines()
    dut_file.close()

    finished_ports = False
    port_list      = []
    param_dict     = []

    #find all parameters/output/inputs
    for line in dut_lines:
        if re.search("^\s*//",line): # comment line
            continue
        if re.search("^\s*$",line): # empty line
            continue
        if re.search("^\s*module",line): # module name
            module_name = line.split("module")[1].split()[0]

        if re.search("\s*PARAMETER",line): # PARAMETER
            pass # need to do anything with that ?
        if re.search("\s*input",line): # input port
            sline          = line.strip().split(",")[0].split()
            port_name      = sline[-1]
            port_size      = re.search("\[.*\]",line)
            if port_size:
                port_size      = port_size.group(0)
            port_direction = "input"
            port_list.append(c_port(port_direction,port_size,port_name))
        if re.search("\s*output",line): # output port
            sline          = line.strip().split(",")[0].split()
            port_name      = sline[-1]
            port_size      = re.search("\[.*\]",line)
            if port_size:
                port_size      = port_size.group(0)
            port_direction = "output"
            port_list.append(c_port(port_direction,port_size,port_name))

        if re.search("\)\s*;\s*$",line): # end of ports
            finished_ports = True
            break

    write_lines = []
    # prepare output file lines
    #header
    write_lines.append("// File name		: "+module_name+"_tb.v\n")
    write_lines.append("// Developers   	: droginsk \n")
    write_lines.append("// Created      	: Sun Feb 25, 2018  03:40AM \n")
    write_lines.append("// ---------------------------------------------------------------------------\n")

    write_lines.append("// Confidential Proprietary \n")
    write_lines.append("// ---------------------------------------------------------------------------\n")
    write_lines.append("`timescale 1ns/1ns\n")
    write_lines.append("\n")
    write_lines.append("module "+module_name+"_tb ();\n")

    # reg/wires
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\t// regs / wires\n")
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\treg clk;\n")
    write_lines.append("\treg rst_n;\n")
    for port in port_list:
        if port.direction == "input":
            if port.size:
                write_lines.append("\t// reg "+port.size+" "+port.name+";\n")
            else:
                write_lines.append("\t// reg "+port.name+";\n")
        #elif port.direction = "output":

    write_lines.append("\n")
    # apb task example
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\t// task example\n")
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\t//task apb_write;\n")
    write_lines.append("\t\t//input [31:0] data;\n")
    write_lines.append("\t\t//input [14:0] addr;\n")
    write_lines.append("\t\t//@ (posedge clk_apb)\n")
    write_lines.append("\t\t//#1\n")
    write_lines.append("\t\t//psel = 1'b1;\n")
    write_lines.append("\t\t//penable = 1'b1;\n")
    write_lines.append("\t\t//pwrite = 1'b1;\n")
    write_lines.append("\t\t//paddr = addr;\n")
    write_lines.append("\t\t//pwdata = data;\n")
    write_lines.append("\t\t//@ (posedge clk_apb)\n")
    write_lines.append("\t\t//#1\n")
    write_lines.append("\t\t//psel = 1'b0;\n")
    write_lines.append("\t\t//penable = 1'b0;\n")
    write_lines.append("\t\t//pwrite = 1'b0;\n")
    write_lines.append("\t//endtask\n")

    write_lines.append("\n")
    # logic
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\t// logic\n")
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\tinitial begin\n")
    write_lines.append("\t\t#100\n")
    write_lines.append('\t\t$display("STARTING simulation....");\n')
    write_lines.append("\t\t// ----------------------\n")
    write_lines.append('\t\t$display("Ending simualtion");\n')
    write_lines.append("\t\t$finish;\n")
    write_lines.append("\tend\n")

    write_lines.append("\n")
    # clock/reset
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\t// clocks\n")
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\tinitial begin\n")
    write_lines.append("\t\tclk = 1'b0;\n")
    write_lines.append("\t\trst_n = 1'b0;\n")
    write_lines.append("\t\trepeat (4) #10 clk = ~clk;\n")
    write_lines.append("\t\trst_n = 1'b1;\n")
    write_lines.append("\t\tforever #10 clk = ~clk; \n")
    write_lines.append("\tend\n")
 
    write_lines.append("\n")

    #find the largest port name:
    temp_list = sorted(port_list,reverse=True, key=lambda elem: len(elem.name))
    longest_port_name = len(temp_list[0].name)

    # DUT instantiation
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\t// "+module_name+" instance\n")
    write_lines.append("\t// --------------------------------------------\n")
    write_lines.append("\t"+module_name+" i_"+module_name+" (\n")
    write_lines.append("\t\t//Outputs\n")
    for port in port_list:
        if port.direction == "output":
            #write_lines.append("\t\t.{0:<longest_port_name+1} (),\n".format(port.name))
            write_lines.append("\t\t.{0:<{1}} (),\n".format(port.name,longest_port_name+1))

    write_lines.append("\t\t//Inputs\n")
    first_input = True
    for port in port_list:
        if port.direction == "input":
            if not first_input:
                write_lines.append(",\n") # close the previous line
            write_lines.append("\t\t.{0:<{1}} (0)".format(port.name,longest_port_name+1))
            first_input = False

    write_lines.append("\n\t);\n")
    write_lines.append("\n")

    #
    write_lines.append("endmodule\n")

    # finalize
    out_file = open(out_file_path,'w')
    out_file.writelines(write_lines)
    out_file.close()
    logger.info(green_open+"Created TestBench file : "+os.path.abspath(out_file_path)+color_close)

    return out_file_path

def main():


    # move to out dir
    # ------------------------
    os.chdir(args["OUT_DIR"])

    # compile only
    # ------------------------
    if (args["COMP_ONLY"]):
        ret = comp_vcs_mx(args["TOP"], args["MAKEFILE"],args["OUT_DIR"],args["TB_FILE"],args["EXTRA_F"])
        sys.exit(0)

    # run only
    # ------------------------
    elif args["RUN_ONLY"]:
        run(args["GUI"],args["TCL"])
        sys.exit(0)

    # waves only
    # ------------------------
    elif args["WAVES_ONLY"]:
        if "magnus" in os.getenv("CLEARCASE_ROOT"):
            os.system("tcsh /vobs/cores/modemss/magnus_wmss/dtr_tools/qbar_compile/build.cshrc")
        elif "caster_dtr" in os.getenv("CLEARCASE_ROOT"):
            os.system("tcsh /vobs/cores/modemss/caster_wmss/caster_dtr_prj/include/caster_dtr.cshrc")
        elif "streamer_dtr" in os.getenv("CLEARCASE_ROOT"):
            os.system("tcsh /vobs/cores/modemss/streamer_wmss/dtr_prj/include/streamer_dtr.cshrc")
        
        os.system("bsub -q interactive -Ip Dve -vpd inter.vpd &")

    # full compile and run
    # ------------------------
    else:
        comp_vcs_mx(args["TOP"], args["MAKEFILE"],args["OUT_DIR"],args["TB_FILE"],args["EXTRA_F"])
        run(args["GUI"],args["TCL"])
        logger.info("Reminder: to open waves - $script_common/run_sim.py -t <top> -w")


    # return to main folder
    # ------------------------
    os.chdir(OrigPwd)

if __name__=="__main__":
    ParseArgs()
    main()

