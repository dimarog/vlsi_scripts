#set prompt="[%n@%m:$cwd]%#"
#set prompt="%B[%m]%~> "
# set the prompt to bold /path >
#set prompt="%B[%m]%/> "
#set prompt="%B[%m]%~> "
#set prompt="%/> "WORKING FULL PATH
#set prompt="%.04> " # ONLY 4 trailing folders. 0 before the 4 means to display how many folders were skipped
#set prompt = "{!}%M..\/%C >"
#set prompt="%S%/> "

#set prompt="%B%P%b[%M]%.04>%b " # time bold, host name in brackets, path 
#set prompt="%P[%M]%B%.04>%b " # time, host name in brackets, path in bold
set prompt="%B%P%b[%n]%.04> " # time bold, username in brackets, path

#if ( $?prompt ) then
#   if ( $?CLEARCASE_ROOT ) then
#      set prompt = "%B[`basename $CLEARCASE_ROOT`]%b$prompt"
#      #set prompt = "`basename $CLEARCASE_ROOT` %B[`hostname`]%~> "
#      #set prompt = "%B[`basename $CLEARCASE_ROOT`] `pwd | sed 's/.*\///'`-\!> %b"
#   endif
#endif

#------------------------------
## bindkeys:
#------------------------------

# delete last word
bindkey "^W" backward-delete-word

# SMART HISTOY
bindkey -k up     history-search-backward       # up arrow
bindkey -k down   history-search-forward        # down arrow

# History
bindkey ' '       magic-space                   # Space

# For now using the right/left arrows for word jump and not char jump
#bindkey -k right  forward-char                  # same as standard CTRL-F
#bindkey -k left   backward-char                 # same as standard CTRL-B

#bindkeys (CTRL+left/right arrows to move from word to word)
bindkey "\e[1;5D" backward-word
bindkey "\e[1;5C" forward-word

# Delete Keys
bindkey ^[^[[3~   delete-word                   # esc-del key (not binded by default)
bindkey ^[^?      backward-delete-word          # esc-backspace key (not needed because this bindkey is standard)
bindkey ^[^[      kill-whole-line               # esc-esc

# Movement Keys
bindkey ^[[228z   backward-word	  	        # F5
bindkey ^[[229z   forward-word		        # F6

# My Keys
bindkey "\e[1~"   beginning-of-line             # Home
bindkey "\e[2~"   overwrite-mode                # Ins
bindkey "\e[3~"   delete-char                   # Delete
bindkey "\e[4~"   end-of-line                   # End             
#
#


#------------------------------
# set ws_root
#------------------------------
set lc=''{''
set rc=''}''
set dollar=\$
set print_5="'${lc}print ${dollar}5${rc}'"
set get_ws='bash -c "echo $PWD | awk -F\/ ${print_5}"'
setenv ws_root /proj/ipdvyellow01/extvols/wa_302/droginsky
#alias temp2 'cd $ws_root/`bash -c "echo $PWD | awk -F\/ ${print_5}"`/'  - working example
alias temp2 'cd $ws_root/`bash -c "echo $PWD | awk -F\/ ${print_5}"`/'
alias temp3 'cd $ws_root/`eval $get_ws`/'


#------------------------------
#setenv
#------------------------------
setenv rtl $ws_root/`eval $get_ws`/106A0/soc/rtl/nix
setenv ws_head $ws_root/`eval $get_ws`/

#------------------------------
#alias
#------------------------------
#set gvim="/nfs/cadtools/vim/8.2.615/bin/gvim"
setenv e '/proj/ipbutools/fe/os/linux-SL7-x86_64/emacs/26.1/bin/emacs'
#alias gvim /nfs/cadtools/vim/8.2.615/bin/gvim
alias g 'gvim  -p \!* &'
alias gdiff 'gvimdiff'
alias .. "cd .."
alias ... "cd ../.."
alias ls 'ls -a --color=auto'
alias ltr 'ls -ltr'
alias fullpath 'readlink -f \!:1'
alias ll 'ls -lh'
alias grep 'grep --color'
alias python '/nfs/cadtools/python/3.6.5/bin/python3'
alias eclipse_modeling /nfs/dc5dv27/rthakar/svn/eclipse/oxygen/eclipse/eclipse

alias urg 'Urg +urg+lic+wait -qc_standalone -qcx_vcs -qc_force64'
alias merge_coverage 'urg -dbname \!:1 -f \!:2'   #urg -dbname <new_mergged_vdb_name> -f <file_list_with_simulation_vdb_and_tgl_vdb>
alias coverage_open 'covmrg -n --mergedvdb \!:1' # or covmrg -n --mergedvdb merged.vdb -r verdi
alias lint_106 'cd $ws_root/`eval $get_ws`/106A0/soc/rtl/nix/ ; cn_lint \!:1 ; cd - '
alias lint_103 'cd $ws_root/`eval $get_ws`/103A0/soc/rtl/nix/ ; cn_lint \!:1 ; cd - '
alias git_rtl_dir 'cd $ws_root/`eval $get_ws`/eg_ip/blocks/nix/rtl__nix/master'
alias git_rtl_status 'cd $ws_root/`eval $get_ws`/eg_ip/blocks/nix/rtl__nix/master; git status; cd -;'
alias git_rtl_checkout 'cd $ws_root/`eval $get_ws`/eg_ip/blocks/nix/rtl__nix/master; git checkout \!:*; cd -'
alias gen_mem 'mg2 nix'
alias run_reb_test 'cd $ws_root/`eval $get_ws`/10x/soc/verif/nixrx_reb/; cnmake sim CFG=\!:1 WAVE=1'
alias office '/proj/eda/UNSUPPORTED/OPENOFFICE/4.1.0/program/soffice'
alias set_dsu_env 'cd /proj/perseus01/wa/droginsky/xplorer_v000.2; marshell perseus01  -ovrd PLILIB PLILIB_1_8_7b -ovrd PLIServer PLISERVER_0_6_0%001 -ovrd vcs R-2020.12-SP2-2 -ovrd Verdi R-2020.12; setenv USER_ROOT /proj/perseus01/wa/droginsky/xplorer_v000.2; setenv ENVIR_WORK $USER_ROOT/VERIF_TOOLS/Envir; setenv MODEL_ROOT /proj/armgit01/configured_rtl/herculesae/v000.2; setenv WA /mrvl2g/dc3_perseus01/perseus01/perseus01/wa/droginsky/temp'
#
# ----------------------------------------
# mateterm startup from main terminal
# ----------------------------------------
#if (!($?SGE_O_LOGIN)) then
#   echo "going to login"
#   sleep 10
#   /proj/sge/IT/sdslogin -mateterm
#endif
   


# ----------------------------------------
# useful
# ----------------------------------------
#  run test : 
#     If you have not created WS so :
#     eg construct active5_roc_net_nixrx <WS_NAME>
#     cd <WS_NAME>/10x/soc/verif/nixrx_reb
#     cnmake sim cfg=<test_name> WAVE/FSDB=1 dbg=1
#  limit simulation time to 1000ns (using WDOG flag):
#     cnmake sim cfg=<test_name> WAVE/FSDB=1 dbg=1 WDOG=1000
#  re-run test:
#     cd sim (where the failed test is)
#     .sim/<test_name>/rerun fsdb=1 dbg=UVM_LOW/MEDIUM/HIGH/FULL/DEBUG
#  git add-commit-push:
#     eg commit -a -F <delivery_notes_file>
#     egp run --gui
#     start
#  generate dbg3:
#     fix in file : /eg_ip/blocks/nix/rtl__nix/master/nixrx.dbg3
#     cd $rtl_<>
#     dbg3 gen-rtl
#  full regression (106 proj):
#     sreg -l nix.rx_full,nix.aq,nix.reg_short,ALL.publish,arb_cmds.hard -m 200
#  full regression (103/105 proj):
#     sreg -l ALL.nixrx_sanity,arb_cmds.hard
#  makeclean
#     makeclean --noremote  (not advised. need to correct the ssh keys instead)
#  rerun flags
#     rerun WAVE/FSDB=0/1 DIR=<dir_name> VCOMPSHARE=0 (to rebuild) NOBLD=1 (donn't compile)
#  srand example
#     srand -c 40 -m 20  -f 10 -t 3 tests/basic_wqe_sso.cfg --args="MEM_TOKENS=10 BISTSKIP=2  TIMEOUT=18 WDOGX=6"
#     srand -c 20 -m 20 -f 10 tests/top_bp_cpt.cfg --abort  (stops exactly after 20 tests)
#   
#  run coverage test:
#     cnmake sim CFG=<cfg name> WAVE=1 DBG=UVM_FULL DIR=<dir name>  WAVEMAX=300000 NCVOPTS+=" -cnst_impl_for_packed_union=disable -covg_ref_packed_struct -cm_tgl portsonly+mda" CCOV=1 SVFCOV=11 CCOVTYPE=line+assert+cond+tgl VWARN=1 MEM_TOKENS=28 BISTSKIP=2
#  arb_cmds (run from verif/arb_cmds):
#     sreg  --dbnovc  -l arb_cmds.hard --fail-first --log_roll
#
#  open verdi
#     ./fsdb.sh -m 15
#
#  diff file by file:
#  cdip
#  git config --global difftool.prompt false
#  git config --global diff.tool tkdiff
#  cdrun
#  eg foreach difftool
#
# ------------------------------------------------------------
#  foreach example
#     foreach f ( `ls .`)
#     foreach? tkdiff $f
#     foreach? end

# ------------------------------------------------------------
#  merge data bases
#     Urg -qc_standalone -qcx_vcs -dir dir1 [dir2 dir3 ...] -dbname merged_dir.vdb

# search (grep/sed) from 1 pattern (aaa) to another pattern (bbb) in file (file.txt)
#      sed -n '/aaa/,/cdn/p' file   : -n flag prints only between those patterns and not the whole file
# ------------------------------------------------------------
#  find and exec (grep) . for several filetypes:
#     find . \( -name "*.v" -o -name "*.sv" \) -exec grep -l -R ncm_chksumxN {} \;

# copy ws without vpd :
#     rsync -avr --exclude='*.vpd' <from> <to>
#  covmrg (open merged database)
#    covmrg -n --mergedvdb <vdb database> // optional :  --urg_args '-format text -show brief'
#  another way to open coverage :
#     qsub -N verdi -w n -V -l mem_tokens=12 -l site_osbin=linux-SL6-x86_64 -q ipbu_int -j y -l urg_plus1=20 ' runmod verdi -cov -covdir merged.vdb -elfilelist cov_flist.txt'
#
#  generate registers
#     cd .....soc/rtl/nix
#     csr3 --input nix.csr #to check that it works
#     csr3 rtl # generate rtl
#     csr verif # generate verif/simulation files
#
#
#
#  create coverage report from command line :
#     urg -full64 -dir <current database> -metric +line+cond -report /nfs/causers2/droginsky/nixrx_coverage/ -format both -show brief -elfile <current exclusion>
#
#  copy a folder from Cavium DC3 to M1F DC3
#     scp  ${USER}@cahw-vnc14.caveonetworks.com:/nfs/<yourdisk>/${USER}/foo.txt  .
# copy dc3 to dc5 and vise versa
# alias scpto5 'scp -r \!:1 droginsky@dc5-etxvm28:\!:2'
# alias scpto3 'scp -r \!:1 droginsky@dc3-etxvm14:\!:2'
#

#net100 push
# sreg --publish
# eg push --skip-expand-check

# use basic test:
# cnmake sim test=basic FSDB=1 NCVDEFS+=+define+VERIF_TEMP_DIS_EOT_ASSERTIONS
# cnmake sim test=basic FSDB=1 NCVDEFS+=+define+VERIF_TEMP_DIS_EOT_ASSERTIONS DBG=UVM_HIGH VCOMPSHARE=0 DIR+=_rerun4
#
# report_autos.py
# ../../../dvtools/dvtools/bin/report_autos.py
# to change the yaml file called, change in this file :  dvtools/dvtools/lib/report_autos_py
#
# git diff tkdiff
# git difftool --tool=tkdiff
#
# for cdb push sreg:
# for push, sreg : sreg -l arb_cmds.publish (can kill before final lint)
# full sreg i you wish :  sreg -l cdb_d2c.hard --simopts=' SIMOPTS+=+d2c_sb_enable=0'
#
# iliad 
# eg construct active5_cdb iliad_ws2 --project iliadA0
#
# iliad close a bug fix git commit :
# git commit -a -m "BUGFIX:IPBUCDB-12345 bla bla"
