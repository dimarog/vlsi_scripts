#!/pkg/qct/software/gnu/bash/4.3/bin/bash
if [ "$1" == "" ] || [ ! -f "$1" ]
then
   echo -e "\e[31mError: Please provide a valid json file (for example swi/wmss_1.json) \e[39m"
   exit 1
fi
 
json=$1
rm -f temp_all_regs.txt
rm -f temp2_all_regs.txt
rm -f all_regs_no_desc.txt
echo "greping all regs from $json into temp_all_regs.txt"
grep '"CLOCK":' $json -A 2 > temp_all_regs.txt
echo '--' >> temp_all_regs.txt
echo "combining every 3 lines into 1"
sed 'N;N;N;s/\n/ /g' temp_all_regs.txt > temp2_all_regs.txt
echo "writing out 'all_regs_no_desc.txt' file"
grep '"CLOCK":' temp2_all_regs.txt | grep -v '"DESCRIPTION":' > all_regs_no_desc.txt
grep 'NO_DESCRIPTION' temp2_all_regs.txt >> all_regs_no_desc.txt
echo "DONE"
