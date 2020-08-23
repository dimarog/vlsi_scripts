'''
-------------------------------------------------------------------------
File name    : utils.py
Title        :
Project      : CAD
Developers   : Dima Roginsky
Description  : common utilities for python scripts
Notes        :
---------------------------------------------------------------------------
Copyright 2016 (c) _
---------------------------------------------------------------------------*/
'''
import os
import datetime
import inspect
import sys
#import pictures
import logging
import subprocess


formatter = logging.Formatter('%(name)s (%(levelname)s) %(message)s')
logging_unit = "DEFAULT"
logging_path = None
log_handler = None
global_verbosity = "LOW"
runner_verbosity = os.getenv("RUNNER_VERBOSITY")
hold_runner_terminal = os.getenv("HOLD_RUNNER_TERMINAL")
if hold_runner_terminal != None:
    hold_runner_terminal = "-hold"
else:
    hold_runner_terminal = ""

if runner_verbosity:
    global_verbosity = runner_verbosity

use_ctags = False
parse_ctags_env_var = os.getenv("PARSE_CTAGS")
if parse_ctags_env_var != None:
    use_ctags = True

projects_dir = os.getenv("PROJECTS_DIR")
project_name = os.getenv("PROJECT")
release_name = os.getenv("RELEASE")
tagname = os.getenv("RELEASE")
user_name = os.getenv("USER")
workdir_name = "work" # os.getenv("WORKDIR")
homedir_name = os.getenv("HOME")
uvm_home = os.getenv("UVM_HOME")
host_name = os.getenv("HOSTNAME")
altera_ip_path = os.getenv("ALTERA_IP_PATH")
fpga_model = os.getenv("FPGA_MODEL")
#release_path = projects_dir+"/"+project_name+"/Releases/"+release_name+"/"
#release_path = os.getenv("SVN_REL_PATH")
#workdir_path = projects_dir+"/"+project_name+"/Users/"+user_name+"/"+workdir_name+"/"
#workdir_path = os.getenv("WS")
#db_path_location = os.getenv("RUNNER_DB_PATH")
#if db_path_location == "LOCAL":
#    db_path = "/tmp/"+user_name+"/"
#else:
#    db_path = workdir_path

if project_name and workdir_name and host_name:
    terminal_name = '"Project '+project_name+' running from '+workdir_name+' on server '+host_name+'"'
else:
    terminal_name = "Default"

terminal_command =  "/usr/bin/xterm "+hold_runner_terminal+" -geometry 160x50 -T "+terminal_name+" -bc -e "
#terminal_command =  "/usr/local/bin/xterm -hold -geometry 160x50 -T "+terminal_name+" -l  -bc -ls -e "

def red_str(str_in):
    oc = "\033[31m"
    cc ="\033[0m"
    return oc+str_in+cc

def print_red(text=""):
    print (red_str(text))

def start_log(logging_unit_param="Default", logging_path_param=".",add_log_file=False):
    log_path = logging_path_param+'/'+logging_unit_param+'.log'
    if os.path.isfile(log_path):
        print ("removing previous: "+log_path)
        os.system('\\rm '+logging_path_param+'/'+logging_unit_param+'.log')

    logger = logging.getLogger(logging_unit_param+'_logger')
    logger.setLevel(logging.INFO)
    logger.debug("started logger",logger,logger.name)
    if logger.handlers:
        print ("Logger for "+logging_unit_param+" already exists!")
        return logger

    if add_log_file:
        logger_file_hdlr = logging.FileHandler(log_path)
        logger_file_hdlr.setFormatter(formatter)
        logger_file_hdlr.setLevel(logging.DEBUG)
        logger.addHandler(logger_file_hdlr)

    logger_console_hdlr = logging.StreamHandler()
    logger_console_hdlr.setFormatter(formatter)
    logger_console_hdlr.setLevel(logging.INFO)
    logger.addHandler(logger_console_hdlr)
#    logging.getLogger("").addHandler(logger_console_hdlr)
    return logger

logger = start_log("python_script",".",False)

def end_log(logging_unit_param):
    logger = logging.getLogger(logging_unit_param+'_logger')
    if not logger:
        print ("WARNING! couldn't find logger to close!")
        return 1
    else:
        logger.shutdown()
        return 0


def line_without_comments(line):
    result = line.split("//")[0].strip()
    result = result.split("#")[0].strip()
    while "  " in result:
        result = result.replace("  "," ")
    while "\n" in result:
        result = result.replace("\n","")
    return result

def dir_exists(path):
    """
        this function verifies that a library exists
    """
    file_exists = 0
    if (os.path.isdir(path)):
        file_exists = 1

    return file_exists

def file_exists(path):
    """
        this function verifies that a file exists
    """
    file_exists = 0
    if (os.path.isfile(path)):
        file_exists = 1

    return file_exists

def proj_path():
    return os.getenv("PROJECTS_DIR")+"/"+os.getenv("PROJECT")+"/"

def check_run_from_workdir_root():
    if (os.getenv("WS")==os.getcwd()):
        return True
    else:
        return False

def check_run_from_workdir_root(path=os.getcwd()):
    #FIXME - .svn no longer exists in each directory, only root
    if dir_exists(path+"/.svn"):
        return True
    elif "/" in path:
        return check_run_from_workdir_root("".join(path.split("/")[:-1]))
    else:
        return False

def create_dir(dir_name):
    if not (dir_exists(workdir_path)):
        logger.fatal("workdir:"+str(workdir_path)+" doesn't exist!!!")
        return 1

    logger.info("workdir found "+str(workdir_path))
    if not (dir_exists(dir_name)):
        logger.info("creating directory: %s",dir_name)
        os.mkdir(dir_name)
        if not dir_exists(dir_name):
            logger.fatal("Failed to Create dir: %s",dir_name)

def run_system_command(command, path=None, new_terminal=False):
    logger.debug("executing command: %s at %s",command,path)
    orig_path = os.getcwd()
    if path:
        os.chdir(path)

    if new_terminal:
        system_command_return_code = os.system(terminal_command+command+" &")
    else:
        system_command_return_code = os.system(command)

    if path:
        os.chdir(orig_path)

    return system_command_return_code

def yes_no_question(question):
    try:
        answer = os.environ["DEBUG_YES_NO_QUES"]
    except:
        answer = raw_input(question+"?(n)")
    yes=["y","Y","Yes","yes","YES"]
    if answer in yes:
        return True
    else:
        return False

def cad_var_overriden():
    cwd = os.getcwd()
    WS = os.getenv["WS"]
    SOD = os.getenv["SOD"]
    if not WS:
        logger.warning("WS not defined, maybe you're not in a workdir?")
        return True
    elif ("/simout" in cwd) and (not SOD):
        logger.warning("SOD not defined, maybe you're not in a workdir?")
        return True
    elif (WS not in cwd) and ("/ourwork" in cwd):
        logger.warning("Looks like WS was overwriten, currently WS=%s, check your ~/.bashrc",WS)
        return True
    elif (SOD not in cwd) and ("/simout" in cwd):
        logger.warning("Looks like SOD or WS was overwriten, currently SOD=%s, check your ~/.bashrc",SOD)
        return True
    else:
        return False


def sys_cmd(cmd,encoding=None):
    r = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE, encoding = encoding)
    out,err = r.communicate()
    return out, err

def send_email(to,subject,input_txt_file="/dev/null",confirm_send=True):
   if type(to)==list:
      to = "'"+",".join(to)+"'"

   cmd = "mailx -s '"+subject+"' "+to+" < "+input_txt_file
   answer =1
   if confirm_send:
      answer = yes_no_question("Sending the following command:\n"+cmd+"\nare you sure")

   if answer:
      sys_cmd(cmd)
      print("Email sent")
   else:
      print("aborted")
      return

def send_html_email(to, subject, html):
    import smtplib
    import re

    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText

    if type(to)==list:
       to = ";".join(to)

    me = os.getenv("USER")+"@.somewhere.com"

    # Create message container - the correct MIME type is multipart/alternative.
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = me
    msg['To'] = to

    # remove html tags for plain text
    text = data = re.sub(r'<.*?>', ' ', html)

    # Record the MIME types of both parts - text/plain and text/html.
    part1 = MIMEText(text, 'plain')
    part2 = MIMEText(html, 'html')

    # Attach parts into message container.
    # According to RFC 2046, the last part of a multipart message, in this case
    # the HTML message, is best and preferred.
    msg.attach(part1)
    msg.attach(part2)

    # Send the message via local SMTP server.
    s = smtplib.SMTP('localhost')
    # sendmail function takes 3 arguments: sender's address, recipient's address
    # and message to send - here it is sent as one string.
    s.sendmail(me, to.split(";"), msg.as_string())
    s.quit()


def asci_Tex():
    arr = []
    arr.append("                      _\n")
    arr.append("                     : \\n")
    arr.append("                     ;\ \_                   _\n")
    arr.append("                     ;@: ~:              _,-;@)\n")
    arr.append("                     ;@: ;~:          _,' _,'@;\n")
    arr.append("                     ;@;  ;~;      ,-'  _,@@@,'\n")
    arr.append("                    |@(     ;      ) ,-'@@@-;\n")
    arr.append("                    ;@;   |~~(   _/ /@@@@@@/\n")
    arr.append("                    \@\   ; _/ _/ /@@@@@@;~\n")
    arr.append("                     \@\   /  / ,'@@@,-'~\n")
    arr.append("                       \\  (  ) :@@(~\n")
    arr.append("                    ___ )-'~~~~`--/ ___\n")
    arr.append("                   (   `--_    _,--'   )\n")
    arr.append("                  (~`- ___ \  / ___ -'~)\n")
    arr.append("                 __~\_(   \_~~_/   )_/~__\n")
    arr.append(" /\ /\ /\     ,-'~~~~~`-._ 0\/0 _,-'~~~~~`-.\n")
    arr.append("| |:  ::|    ;     ______ `----'  ______    :\n")
    arr.append("| `'  `'|    ;    {      \   ~   /      }   |\n")
    arr.append(" \_   _/     `-._      ,-,' ~~  `.-.      _,'        |\\n")
    arr.append("   \ /_          `----' ,'       `, `----'           : \\n")
    arr.append("   |_( )                `-._/#\_,-'                  :  )\n")
    arr.append(" ,-'  ~)           _,--./  (###)__                   :  :\n")
    arr.append(" (~~~~_)          /       ; `-'   `--,               |  ;\n")
    arr.append(" (~~~' )         ;       /@@@@@@.    `.              | /\n")
    arr.append(" `.HH~;        ,-'  ,-   |@@@ @@@@.   `.             .')\n")
    arr.append("  `HH `.      ,'   /     |@@@@@ @@@@.  `.           / /(~)\n")
    arr.append("   HH   \_   ,'  _/`.    |@@@@@ @@@@@;  `.          ; (~~)\n")
    arr.append("   ~~`.   \_,'  /   ;   .@@@@@ @@@@@@;\_  \___      ; H~\)\n")
    arr.append("       \_     _/    `.  |@@@@@@ @@@@@;  \     `----'_HH[~)\n")
    arr.append("         \___/       `. :@@@@@ @@@@@@'   \__,------' HH ~\n")
    arr.append("        ______        ; |@@@@@@ @@@'                 HH\n")
    arr.append("      _)      \_,     ; :@@@@@@@@@;                  ~~\n")
    arr.append("    _;          \\   ,' |@@@@@@@@@:\n")
    arr.append("  ,'     ; :      \_,   :@@@@@@@@@@.\n")
    arr.append("  `.__,-'~~`._,-.  ,    :@@@@@@@@@@`.\n")
    arr.append("                 \/    /@@@@@@@@@@@@:\n")
    arr.append("                 /    ,@@@@@@@@@@@@@@.\n")
    arr.append("                |    ,@@@@@@@@@@@@@@@:\n")
    arr.append("                |    :@@@@@@@@@@@@@@@'\n")
    arr.append("                `.   \@@@@/  `@@@@@/(\n")
    arr.append("                  )   ~~~/    \~~~~  \\n")
    arr.append("                  :     /       \_    \\n")
    arr.append("                  (    /          \_   `.\n")
    arr.append("                  /   ;             \_  `.\n")
    arr.append("                 /   /                \  `.\n")
    arr.append("                /   /                  `.  \\n")
    arr.append("              ,'  ,'/~~)                ;  /\n")
    arr.append("              {   `'   (               /  /\n")
    arr.append("              `.___,-'  \             /  /\n")
    arr.append("                 __/     |           /  /\n")
    arr.append("                /        |           : :   __\n")
    arr.append("                :        |           ; : _;  )__\n")
    arr.append("                (  |  |  /          /  `,'  ~   )_\n")
    arr.append("                 `-:__;-'          :  ,'      ~~  ;\n")
    arr.append("                                  /          (_,--'\n")
    arr.append("                                 (       ,-'~~\n")
    arr.append("                                  \__,-'~\n")
    return arr


def asci_kang():
    arr = []
    arr.append("                                     .,cccchhhhccc,?''?L\n")
    arr.append("                                    ,cb$$$$$$$$$$$$$$$$$$$c,\n")
    arr.append("                                 ,r='3$$$$$$$?$$?$$$$$$$$$$$$c           ,,cccc\n")
    arr.append("                                ,$,d$$$$$$$$$c ?c`?$$$$$$$$$$$$$ ,,ccc$$P'',nn,'\n")
    arr.append("                               ,$$$$$$$$$$$$$$$,$h`$$$$$$$$$$$$$$$$$$',nMMMMMMMn\n")
    arr.append("                               $$$??$$$$$$??$$$$$$$$$$$$$$$$$$$$$$$',nMMMMMMMMMM\n")
    arr.append("                               ?$'nn`$$$F,nn ?$$$$$$$$$$$$$$$$$$$P'nMMMMMMMMMMM'\n")
    arr.append("                               `F.MM,?$$ MMML`$$$$$$$$$$$$$$$$$$$.MMMMMMMMMMMMM\n")
    arr.append("                                $:P  J$F{M'  ,$$$$$$$$$$$$$$$$$$$.'.,nMMMMMMMP'\n")
    arr.append("                                $_`_ ''F `   J$$$$$$$$$$$$$$$$$$F.MndMMMMMMMP'\n")
    arr.append("                              ,'    ``'4,,,c$$$$$$$$$$$$$$$$$$$$$.TMMMMMMMMf'\n")
    arr.append("                             ;$,       ,$$$$$$$$$$$$$$$$$$$$$$F '?bc,,'''''\n")
    arr.append("                             ?$C`3cccc$$$xc `???$$$$$$$$$$$''\n")
    arr.append("                               ''\,'?$$$P',d$$ccc$$$$$$$$$F\n")
    arr.append("                                   '?ccccd$$$$$$$$$$$$$P''\n")
    arr.append("                                     `?$$$$$$$$$c\n")
    arr.append("                                      `$$$$$$$$$'\n")
    arr.append("                                       $$$$$$,cc,\n")
    arr.append("                                      J??$$$P$$$$\n")
    arr.append("                                 ,r, ,',cc,'P'$$$$\n")
    arr.append("                                4$ F,F,$$$$bcc,'?$                          ,,ccc\n")
    arr.append("                               zF-  F $$L4,'?$$$$E                      _,d$$$$$$\n")
    arr.append("                              ,?d 'JF d'F'$$c`?$$'4c,.               _,d$$$$$$$$'\n")
    arr.append("                                  4$$c...J$$$$$eed$$$$$c,      _,ccd$$$$$$$$$$F\n")
    arr.append("                                  J$$$$$$$$$$$$$$$$$$$$$$$,`?$$$$$$$$$$$$$$$P'\n")
    arr.append("                                  $$$$$$$$$$$$$$$$$$$$$$$$$$ $$$$$$$$$$$$$P'\n")
    arr.append("                                  `$$$$$$$$$$$$$$$$$$$$$$$$$,)$$$$$$$$$$$'\n")
    arr.append("                                   ?$$$$$$$$$$$$$$$$$$$$$$$$>)$$$$$$$$$F\n")
    arr.append("                                    `$$$$$ $$$$$$$$$$$$$$$$$ $$$$$$$P'\n")
    arr.append("        ,cc=                       ,$c,'?F,$$$$$$$$$$$$$$$$'J$$$$P'\n")
    arr.append("      ,$$',$$$$$$$bc.              $$$$$P $$$$$$$$$$$$$$$F',$PF'\n")
    arr.append("     {$$'c$$$$$$',,zcchhc,         $$$$$ d$$$$$$$$$$$$$$  ''\n")
    arr.append("      ?b{$$$$$ ,$',ccccc,$$$bc,    `$$$$ $$$$$$$$$$$$$P'\n")
    arr.append("         `''?' ',J$$$$$$$$$$$$$$cc  ?$$$ ?$$$$$$$$$$$'\n")
    arr.append("                ?$$$$$$$$$$$$$$$$$$c,'$$b`?$$$$$$$$P'\n")
    arr.append("                  `''????$$$$$$$$$$$$b,'?b`?$$$$$$$'\n")
    arr.append("                           `''??$$$$$$$$c`?`?$$$$'\n")
    arr.append("                                  `'?$$$$$ec.$$$$\n")
    arr.append("                                      `'?$$$$$$$$L\n")
    arr.append("                                          `'??$$$F\n")
    return arr

def asci_duck():
    arr = []
    arr.append("         _____\n")
    arr.append("     _-~~     ~~-_//\n")
    arr.append("   /~             ~\\n")
    arr.append("  |              _  |_\n")
    arr.append(" |         _--~~~ )~~ )___\n")
    arr.append("\|        /   ___   _-~   ~-_\n")
    arr.append("\          _-~   ~-_         \\n")
    arr.append("|         /         \         |\n")
    arr.append("|        |           |     (O  |\n")
    arr.append(" |      |             |        |\n")
    arr.append(" |      |   O)        |       |\n")
    arr.append(" /|      |           |       /\n")
    arr.append(" / \ _--_ \         /-_   _-~)\n")
    arr.append("   /~    \ ~-_   _-~   ~~~__/\n")
    arr.append("  |   |\  ~-_ ~~~ _-~~---~  \\n")
    arr.append("  |   | |    ~--~~  / \      ~-_\n")
    arr.append("   |   \ |                      ~-_\n")
    arr.append("    \   ~-|                        ~~--__ _-~~-,\n")
    arr.append("     ~-_   |                             /     |\n")
    arr.append("        ~~--|                                 /\n")
    arr.append("          |  |                               /\n")
    arr.append("          |   |              _            _-~\n")
    arr.append("          |  /~~--_   __---~~          _-~\n")
    arr.append("          |  \                   __--~~\n")
    arr.append("          |  |~~--__     ___---~~\n")
    arr.append("          |  |      ~~~~~\n")
    arr.append("          |  |\n")
    return arr

#-------------------------------------------------------------------------
# SVN FUNCTIONS (consider also using "svn" module available under the cad
# development environment (import svn.remote)
#-------------------------------------------------------------------------
def SvnDirContents(svn_root,dir):
    lines = os.popen("svn ls "+svn_root+"/"+dir+" -v |sort -b -g").readlines()
    content_list = [i.strip().split()[-1][:-1] for i in lines]
    return " ".join(content_list[-3:])
