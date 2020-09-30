#!/bin/bash
#
#通过对于选项和参数的判断获得一些变量，比如说是否永久记录到文件标示，MAC。
#通过iptables的语法和重定向的功能添加规则和文件。
#

# Initialize some variables.
IPTS=/sbin/iptables
SHELL_DIR=/shells/firewall
MAC_FILE=$SHELL_DIR/allow_mac.txt
LEVEL=temp
VERSION=0.2

# Usage: usage
# Print the usage.
usage (){
 cat <<EOF
Usage: add_mac [OPTION] mac-address
Add source mac address to iptables's FORWARD chain and MAC_FILE.

-h, --help 	print this message and exit
-v, --version 	print the version information and exit
-p, --persistent ....	
-n, --name=NAME	....
-f, --file=FILENAME  .... no -f option , default "allow_mac.txt"

EXAMPLE:
    # add_mac 00:11:22:33:44:55
    Add a mac-address into iptables MAC-FORWARD chain.
    # add_mac -p -n zhangsan 00:11:22:33:44:55
    ......
EOF
}

missarg (){
	echo "Miss arguments ." 1>&2
	exit 1
}
# Check the arguments.
if [ $# -eq 0 ];then
	usage 1>&2
	exit 1
fi

while [ $# -gt 0 ];do
	case "$1" in
		-h | --help)
		 usage
		 exit 0 ;;
		-v | --version)
		echo "add_mac (GNU ${VERSION})"
		exit 0 ;;
		-p | --persistent)
		  PER=1
		  mustargn=1;;
		-n | --name=*)
		if [ "$1" = "-n" ];then
			[ -z "$2" ] && missarg
			NAME="$2"
			shift
		   else
			NAME=`echo "$1"|sed 's/--name=//'`
		fi ;;
		-f | --file=*)
		if [ "$1" = "-f" ];then
			[ -z "$2" ]&& missarg
			MAC_FILE="$2"	
			shift
		   else
			MAC_FILE=`echo "$1"|sed 's:--file=::'`
		fi ;;
			*)
			   MAC="$1" ;;
	esac
		shift
done
	if [ "$mustargn" = "1" ];then
		if [ -z "$NAME" ];then
			echo " --name=NAME must be need when --persistent is used ." 1>&2
			exit 1
		fi
	fi

# Add mac-address and username to file.

if [ ! -z "$NAME" ];then
	if [ ! -z "$MAC_FILE" ];then
	echo "$NAME    $MAC" >> "$MAC_FILE"  && echo "$MAC is added to $MAC_FILE ."
	else
	  echo "$MAC_FILE is not existing . " 1>&2
	  exit 1
	fi
fi


# Add mac-address to iptables.
if test -z `echo "$MAC"|sed -n '/^[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}$/p'`;then
# or use sed -nr '/^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$/p'
	echo "$MAC address must be specified and format as 00:11:22:aa:bb:cc" 1>&2
	exit 1
   else
#	FW_NUM=`$IPTS -nL MAC-FORWARD --line-number | sed -n '/MAC/p'|awk 'END{print $1}'`
#	let FW_NUM=FW_NUM+1
#	$IPTS -I MAC-FORWARD $FW_NUM -m mac --mac-source "$MAC" -j ACCEPT && echo "$MAC is added to MAC-FORWAD ."
	$IPTS -A MAC-FORWARD  -m mac --mac-source "$MAC" -j ACCEPT && echo "$MAC is added to MAC-FORWAD ."
	
fi

				
			 



