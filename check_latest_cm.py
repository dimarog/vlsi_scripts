#!/pkg/qct/software/python/3.6.0/bin/python3.6
'''
-------------------------------------------------------------------------
File name    : /usr2/droginsk/scripts/check_latest_cm.py
Title        : 
Project      : 
Developers   :  droginsk
Created      : Wed Nov 06, 2019  06:01AM
Description  : 
Notes        : 
---------------------------------------------------------------------------

---------------------------------------------------------------------------*/
'''
import os, sys, re, imp
import copy
import subprocess
import argparse
from datetime import datetime
import utils
#mail_to	= "droginsk@.somewhere.com"
#mail_to	= ["droginsk@.somewhere.com", "liorn@.somewhere.com"]
mail_to = "qpoll@.somewhere.com"


#----------------------------------------------
# globals
#----------------------------------------------
green_open = '\033[32m'
blue_open = '\033[34m'
red_open = '\033[31m'
color_close = '\033[0m'

logger = utils.start_log("check_latest_cm","/prj/qct/chips/magnus/sandiego/tapeout/r0_sec14lpp7lm/doc/scripts_common/",True)
#logger.setLevel(logging.DEBUG)
#logger.handlers[0].setLevel(logging.DEBUG)
#user = os.getlogin()
#OrigPwd = os.getcwd()
now = datetime.now()

stream_dict = {
        "droginsk_caster_wmss_14lpcrf_1.0_int"   : "/vobs/cores/modemss/caster_wmss/caster_wmss_prj/include/build.cshrc" ,
        "droginsk_magnus_wmss_14lpp_2.0_int"     : "/vobs/cores/modemss/magnus_wmss/wmss/include/build.cshrc"
        }



def check(stream_name,source_path):
    '''do the check'''
    cm_dict = {}

    #go to stream, source and return vars
    cmd = (f"/usr/atria/bin/cleartool setview -exec 'source {source_path}; env' {stream_name} | grep cm_")
    logger.info(cmd)
    out,err = utils.sys_cmd(cmd, encoding='utf8')
    #build dict with all the cm_
    for i in out.strip().split("\n"):
        if re.match("^cm_",i): # if line start with cm_
            key,path = i.split("=")
            cm_dict[key] = path

    #find latest version of each
    latest_ver_dict = {}
    for key in cm_dict:
         out,err = utils.sys_cmd(f"ls {cm_dict[key]}/../ | grep -E '^[0-9]' | sort -V | tail -1",encoding='utf8')
         latest_ver_dict[key] = out.strip()
    
    logger.info(f"cm_dict: {cm_dict}")
    logger.info(f"latest ver dict: {latest_ver_dict}")

    # exit view and return
    logger.info(f"exiting view : {stream_name}")
    utils.sys_cmd(f"exit")
    return cm_dict, latest_ver_dict

def prep_and_send_plain_email(cm_dict,latest_ver_dict):

    #find the largest cm name:
    cm_list = sorted(cm_dict,reverse=True, key=lambda elem: len(elem))
    longest_cm_name = len(cm_list[0])

    mail_arr = []
    len1 = longest_cm_name+1
    len2 = len("current cm ver")
    len3 = len("latest cm ver")
    line = "{0:<{1}}   {2:<{3}}   {4:<{5}}\n".format("cm_name",len1, "current cm ver",len2, "latest cm ver", len3)
    mail_arr.append(line)
    for key in cm_dict:
        # check if i have latest ver
        curr_ver   = cm_dict[key].split("/")[-1]
        latest_ver = latest_ver_dict[key]
#        if curr_ver != latest_ver :
        line = "{0:<{1}}   {2:<{3}}   {4:<{5}}\n".format(key,len1, curr_ver,len2, latest_ver, len3)
        mail_arr.append(line)

    # prep mail
    mail_file_path = f"{OrigPwd}/mail_file.txt"
    f= open(mail_file_path,'w')
#    arr = utils.asci_Tex()
#    arr += (utils.asci_duck())
#    arr +=(utils.asci_kang())
    f.writelines(mail_arr)
    f.close()
    mail_subj = 'test'

    # send
    utils.send_email(mail_to,mail_subj,mail_file_path,False)

#----------------------------------------------
def html_table_row(cell_list,color="black"):
    temp_str = '<tr>'
    for i in cell_list:
        temp_str += html_table_cell(i,color)
    return temp_str + '</tr>'

def html_table_cell(text, color="black"):
    return '<td class="cell"><span style=color:'+color+'>'+text+'</span></td>'

def prep_and_send_html_email(cm_dict,latest_ver_dict):
    # html example
    #html = """\
    #<html>
    #  <head></head>
    #  <body>
    #    <p style="color: red;">Hello World!</p>
    #  </body>
    #</html>
    #"""
    #find the largest cm name:
    cm_list = sorted(cm_dict,reverse=True, key=lambda elem: len(elem))
    longest_cm_name = len(cm_list[0])

    html_str = ''

    #start html
    html_str += ('<html>')
    html_str += ('  <head></head>')
    html_str += ('  <body>')
    html_str += ('<table style="border: blue 1px solid;">')
    html_str += ('<tbody>')


    len1 = longest_cm_name+1
    len2 = len("current cm ver")
    len3 = len("latest cm ver")
#    line = '    <p>{0:<{1}}   {2:<{3}}   {4:<{5}}</p>'.format("cm_name",len1, "current cm ver",len2, "latest cm ver", len3)
    line = html_table_row(["cm_name","current cm ver","latest cm ver"])
    html_str += (line)
    for key in cm_dict:
        # check if i have latest ver
        curr_ver   = cm_dict[key].split("/")[-1]
        latest_ver = latest_ver_dict[key]
        if curr_ver != latest_ver :
#            line = '    <p style="color: red;">{0:<{1}}   {2:<{3}}   {4:<{5}}</p>'.format(key,len1, curr_ver,len2, latest_ver, len3)
            line = html_table_row([key, curr_ver,latest_ver],"red")
        else:
#            line = '    <p>{0:<{1}}   {2:<{3}}   {4:<{5}}</p>'.format(key,len1, curr_ver,len2, latest_ver, len3)
            line = html_table_row([key, curr_ver,latest_ver])
        html_str += (line)
#
#    html_str = ''
#    html_str += '<table style="border: blue 1px solid;">'
#    html_str += ' '
#    html_str += '<tbody>'
#    html_str += '<tr>'
#    html_str += '<td class="cell">Cell 1.1</td>'
#    html_str += '<td class="cell">Cell 1.2</td>'
#    html_str += '</tr>'
#    html_str += ' '
#    html_str += ' '
#    html_str += '<tr>'
#    html_str += '<td class="cell">Cell 2.1</td>'
#    html_str += '<td class="cell"></td>'
#    html_str += '</tr>'
#    html_str += ' '
#    html_str += '</tbody>'
#    html_str += '</table>'

    # close html
    html_str += ('</tbody>')
    html_str += ('</table>')
    html_str += ('  </body>')
    html_str += ('</html>')

    # prep mail
    mail_subj = 'test'

    # send
    utils.send_html_email(mail_to,mail_subj,html_str)

#----------------------------------------------

def prep_html_table(cm_dict,latest_ver_dict):
    # html example
    #html = """\
    #<html>
    #  <head></head>
    #  <body>
    #    <p style="color: red;">Hello World!</p>
    #  </body>
    #</html>
    #"""
    #find the largest cm name:
    cm_list = sorted(cm_dict,reverse=True, key=lambda elem: len(elem))
    #logger.info("DEBUG:")
    #logger.info(f"cm_dict : {cm_dict}")
    #logger.info(f"cm_list : {cm_list}")
    longest_cm_name = len(cm_list[0])

    html_str = ''


    len1 = longest_cm_name+1
    len2 = len("current cm ver")
    len3 = len("latest cm ver")
#    line = '    <p>{0:<{1}}   {2:<{3}}   {4:<{5}}</p>'.format("cm_name",len1, "current cm ver",len2, "latest cm ver", len3)
    #line = html_table_row(["cm name","current cm ver","latest cm ver"])
    #html_str += (line)
    html_str += '<thead>'
    html_str += '<tr>'
    html_str += '<th scope="col"><span style="font-size=13px">cm name       </span></th>'
    html_str += '<th scope="col"><span style="font-size=13px">current cm ver</span></th>'
    html_str += '<th scope="col"><span style="font-size=13px">latest cm ver </span></th>'
    html_str += '</tr>'
    html_str += '</thead>'
    for key in cm_dict:
        # check if i have latest ver
        curr_ver   = cm_dict[key].split("/")[-1]
        latest_ver = latest_ver_dict[key]
        if curr_ver != latest_ver :
#            line = '    <p style="color: red;">{0:<{1}}   {2:<{3}}   {4:<{5}}</p>'.format(key,len1, curr_ver,len2, latest_ver, len3)
            line = html_table_row([key, curr_ver,latest_ver],"red")
        else:
#            line = '    <p>{0:<{1}}   {2:<{3}}   {4:<{5}}</p>'.format(key,len1, curr_ver,len2, latest_ver, len3)
            line = html_table_row([key, curr_ver,latest_ver])
        html_str += (line)
#
#    html_str = ''
#    html_str += '<table style="border: blue 1px solid;">'
#    html_str += ' '
#    html_str += '<tbody>'
#    html_str += '<tr>'
#    html_str += '<td class="cell">Cell 1.1</td>'
#    html_str += '<td class="cell">Cell 1.2</td>'
#    html_str += '</tr>'
#    html_str += ' '
#    html_str += ' '
#    html_str += '<tr>'
#    html_str += '<td class="cell">Cell 2.1</td>'
#    html_str += '<td class="cell"></td>'
#    html_str += '</tr>'
#    html_str += ' '
#    html_str += '</tbody>'
#    html_str += '</table>'

    return html_str

#----------------------------------------------
def main():

    # start html mail:
    html_str = ''
    html_str += ('<html>')
    html_str += ('  <head></head>')
    html_str += ('  <body>')


    for stream in stream_dict:
        if stream and stream_dict[stream]:
            html_str += ('')
            html_str += (f'<p style="color: black;"><strong>stream : {stream}</strong></p>')
            html_str += ('')
            #html_str += ('<table style="border: blue 1px solid;">')
            html_str += ('<table border="1">')
            html_str += ('<tbody>')
            first_dict, second_dict = check(stream, stream_dict[stream])
            #prep_and_send_plain_email(first_dict,second_dict)
            #prep_and_send_html_email(first_dict,second_dict)
            html_str += prep_html_table(first_dict,second_dict)
            html_str += ('</tbody>')
            html_str += ('</table>')

    # close html
    html_str += ('  </body>')
    html_str += ('</html>')

    # send email
    mail_subj = "MSIPs versions"
    utils.send_html_email(mail_to,mail_subj,html_str)


#----------------------------------------------
if __name__=="__main__":
    logger.info(f"start time : {now}")
    #args = ParseArgs()
    main()

