#!/bin/bash
# 通过iptables上的流量统计功能进行限速。
#
# 
VERSION=1.0

# Initialize some variables.
IPTS=/sbin/iptables
SHELL_DIR=/shells/firewall
MAC_FILE=$SHELL_DIR/allow_mac.txt
NET=192.168.4
NAT=192.168.4.128/25
CUS_CHAIN=DOWN-RATE
TIME=60
c=1
CTIME=$TIME
DIS_RATE=30
LIM_RATE=200
NLIMIT_LOG=$SHELL_DIR/nlimit_log.txt
DEV=eth1


#Useage: Usage
# Print the usage.
usage () {
	cat <<EOF
Usage: rate_limit [OPTION] [&]
Monitor and limit the download speeds.

 -h, --help		print this message and exit
 -v, --version		print the version information and exit
 -t, --time=TIME        Default  60s
 -d, --drate=DIS_RATE   display, Default  30
 -l, --ltate=LIM_RATE   limit,  Default  200

 EXAMPLE:
	# rate_limit

	# rate_limit -t 10

	# rate_limit -t 10 -d 30 -l 200 &

EOF
}

missarg () {
        echo "Miss arguments ." 1>&2
        exit 1
}

errorarg () {
        echo "Error arguments ." 1>&2
        exit 1
}

# Check the arguments.
while [ $# -gt 0 ];do
        case "$1" in
          -h | --help)
                usage
                exit 0 ;;
          -v | --version)
                echo "rate (GNU ${VERSION})"
                exit 0 ;;
	  -t | --time=*)
		  if [ "$1" = "-t" ];then
                        [ -z "$2" ] && missarg
                        TIME="$2"
                        shift
                else
                        TIME=`echo "$1" | sed 's/--time=//'`
                fi
			[ `echo "$TIME > 1"|bc` -eq 0 ] && errorarg
			;;
	   -d | --drate=*)
                  if [ "$1" = "-d" ];then
                        [ -z "$2" ] && missarg
                        DIS_RATE="$2"
                        shift
                else
                      	DIS_RATE=`echo "$1" | sed 's/--drate=//'`
                fi
			[ `echo "$DIS_RATE > 1"|bc` -eq 0 ] && errorarg
                        ;;
	   -l | --lrate=*)
                  if [ "$1" = "-l" ];then
                        [ -z "$2" ] && missarg
                        LIM_RATE="$2"
                        shift
                else
                        LIM_RATE=`echo "$1" | sed 's/--lrate=//'`
                fi
			[ `echo "$LIM_RATE > 1"|bc` -eq 0 ] && errorarg
                        ;;
			\&)
			BG_RUN=1
			;;
			*)
			echo "Unrecognized option '$1'" 1>&2
               		usage
               		exit 1
                        ;;
	esac
		shift
done
DLIMIT=$(($DIS_RATE*1024*$TIME)) 
NLIMIT=$(($LIM_RATE*1024*$TIME)) 

### Monitor the download traffic for each IP
Add_cus_chain(){
	$IPTS -N $CUS_CHAIN
	for ip in {131..254}
       		do
               		$IPTS -A $CUS_CHAIN  -d $NET.$ip -j RETURN
      		 done
			FW_NUM=`$IPTS -nL FORWARD --line-number|sed -n '/state RELATED,ESTABLISHED/p'|awk '{print $1}'`
			$IPTS -I FORWARD $FW_NUM ! -s $NAT -d $NAT -j $CUS_CHAIN
}

Drop_net(){
#		echo -e "$(date +%Y/%m/%d-%H:%M:%S)" "\t" "$RATE kbytes/s" "\t" "$IP" "\t" "$NAME" |tee -a $NLIMIT_LOG
		for CHAIN_NUM in `$IPTS -nL $CUS_CHAIN --line-number|awk '$NF~/'"$IP"'/{print $1}'`
		do 
			$IPTS -R "$CUS_CHAIN" "$CHAIN_NUM" -d "$IP" -j DROP
#			$SHELL_DIR/del-mac.sh "$MAC"
		done
}


dis_limit(){
	#for RATEIP in "$($IPTS -xnvL $CUS_CHAIN|awk '(NR>2 && $2>'"$LIMIT"'){print $2,$9}')"
	$IPTS -xnvL $CUS_CHAIN|awk '(NR>2 && $2>'"$DLIMIT"'){print $2,$9}'|while read RATEIP
	do
		[ -z "$RATEIP" ] && break
		RATE=$(echo "${RATEIP}"|awk '{print $1/1024/'"$TIME"'}')
		IP=$(echo "${RATEIP}"|awk '{print $2}')
		#MAC=`arp -en -i $DEV|awk '$1~/'"$IP"'/{print $3}'`
		MAC=`arp -en -i $DEV|grep "$IP"|awk '{print $3}'`
		NAME=`grep -ih "$MAC" "$MAC_FILE"` 
		if [ `echo "$RATE < $LIM_RATE"|bc` -eq 1 ];then
				echo -e "\t" "$RATE kbytes/s" "\t" "$IP" "\t" "$NAME"
			else
			echo -e "$(date +%Y/%m/%d-%H:%M:%S)" "\t" "\\033[31m$RATE\\033[0m kbytes/s" "\t" "$IP" "\t" "$NAME" |tee -a $NLIMIT_LOG
				Drop_net 
		fi
	done
}

only_limit(){
	#for RATEIP in "$($IPTS -xnvL $CUS_CHAIN|awk '(NR>2 && $2>'"$LIMIT"'){print $2,$9}')"
	$IPTS -xnvL $CUS_CHAIN|awk '(NR>2 && $2>'"$NLIMIT"'){print $2,$9}'|while read RATEIP
	do
		[ -z "$RATEIP" ] && break
		RATE=$(echo "${RATEIP}"|awk '{print $1/1024/'"$TIME"'}')
		IP=$(echo "${RATEIP}"|awk '{print $2}')
		MAC=`arp -en -i $DEV|grep "$IP"|awk '{print $3}'`
		NAME=`grep -i "$MAC" "$MAC_FILE"` 
		echo -e "$(date +%Y/%m/%d-%H:%M:%S)" "\t" "$RATE kbytes/s" "\t" "$IP" "\t" "$NAME" >>$NLIMIT_LOG
		Drop_net &>> /$NLIMIT_LOG
	done
}

ps -C `basename "$0"` -o pid=,user=,tty=,stat=,comm= |grep -v "$$" && echo -e "These is a `basename $0` script running......" 1>&2 && exit 1

while true;
do
$IPTS -nL |grep -q  "$CUS_CHAIN"
[ $? -ne 0 ] && Add_cus_chain
	$IPTS -Z
	sleep $TIME #; clear
	if [ "$BG_RUN" = "1" ] ;then
		only_limit
	else
		echo -e "\t ************ \\033[36mAfter ${TIME}s , run ${c}c ${CTIME}s $(date +%Y/%m/%d-%H:%M:%S)\\033[0m *************"
		dis_limit
	fi
	let c++
	let CTIME=TIME*c
done		
