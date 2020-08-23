#!/pkg/qct/software/python/3.6.0/bin/python3.6
'''
-------------------------------------------------------------------------
File name    : gen_ctags.py
Title        :
Project      :
Developers   :  droginsk
Created      : Sun Apr 22, 2018  04:53AM
Description  :
Notes        :
---------------------------------------------------------------------------

---------------------------------------------------------------------------*/
'''
import os,sys
from sys import argv

# globals
#----------------------------------------------
user = os.getlogin()
scripts = os.getenv('scripts_common')
unmanaged = os.getenv('UNMANAGED_DIR')
tags_path = unmanaged + "/"
tags_path_gvim = unmanaged + "/tags_gvim"
tags_path_emacs = unmanaged + "/tags_emacs"
green_open = '\033[32m'
blue_open = '\033[34m'
red_open = '\033[31m'
color_close = '\033[0m'
#----------------------------------------------


def main():
    arguments = ' '.join(sys.argv[1:])
#    end_str = "\necho 'Press the 'X' at the upper right corner to close the window'"
    end_str = ""
    if os.path.isfile(tags_path_gvim):
        os.system("\mv "+tags_path_gvim+" "+tags_path_gvim+"_old")
    if os.path.isfile(tags_path_emacs):
        os.system("\mv "+tags_path_emacs+" "+tags_path_emacs+"_old")

    #os.system("xterm -hold -geometry 180x60 -fa monaco -fs 9 -e '/home/droginsk/scripts/ctags.py "+arguments+";echo 'Press the X at the upper right corner to close the window''")
#    os.system("xterm -hold -geometry 180x60 -fa monaco -fs 9 -e '/home/droginsk/scripts/ctags.py "+arguments+";echo Press the X at the upper right corner to close the window'")
    os.system("xterm -hold -geometry 140x40 -fa monaco -fs 12 -e '"+scripts+"/ctags.py "+arguments+end_str+"'")
    if os.path.isfile(tags_path_gvim) or os.path.isfile(tags_path_emacs):
        print (green_open+"Successfully created "+tags_path+" file to use by your GVIM or emcas"+color_close)
        #print ("you can close the window")
    else:
        print (red_open+"Failed to create tags file in: "+tags_path+color_close)
        #print ("you can close the window")

main()
