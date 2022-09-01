#!/bin/bash

remakeFile(){
	rm "$TEST_DIR/$VCCNAME"
	
	echo "$FILE"
	FILETIME=$(date -d "$(sed s/_/:/g<<<$(expr substr $(basename $FILE) 12 8))" +%s)
	echo "Remaking $VCCNAME"	
	for File in $HOURLY_FILE_DIR/`expr substr $(basename $FILE) 1 10`*VCClog;
	do
		echo "Remade and Readded File $File"
		sed -i -e '$a\' "$File"
		cat $File >> "$TEST_DIR/$VCCNAME"
		((NUM_FILES++))
		[[ $(date -d "$(sed s/_/:/g<<<$(expr substr $(basename $File) 12 8))" +%s) -gt $FILETIME ]] && ((SKIP_FILES++));
	done
	
	DATA_SUM="$(stat --printf="%s" "$TEST_DIR/$VCCNAME")"
	((NUM_DAYS++))
}
makePreamble(){
	[[ ( ! -z "$VCCNAME" ) && ( -z `sed -n '1{/^------------------------/p};q' "$TEST_DIR/$VCCNAME"` ) ]] && {
		echo "Creating Preamble for $VCCNAME"
		echo -e "\n------------------------\n<START LOG>\n-----------------------\nSTART DATE: `date`\nLines Down:" >> "$TEST_DIR/$VCCNAME"
		awk '$2~/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/{cmd="date +%s -d "$2;cmd| getline a;if ((a-p)<0) a=(a+86400); b=((a-p)/60); if( NR > 1 && b > 15 && b < 1425) {cmd="date +%H:%M:%S -d@"p;cmd| getline c; print "Down for "b" minutes from "c" to "$2}} {p=a}' "$TEST_DIR/$VCCNAME" 2>/dev/null >> "$TEST_DIR/$VCCNAME"
		echo -e "-------------------------" >> "$TEST_DIR/$VCCNAME"


		FIRSTLINE=`grep -n -- ------------------------ "$TEST_DIR/$VCCNAME" | head -n 1 | cut -d: -f1`
		LASTLINE=`grep -n -- ------------------------ "$TEST_DIR/$VCCNAME" | tail -n 1 | cut -d: -f1`
		ITER=$((LASTLINE - FIRSTLINE + 1)); COUNTER=0; 
		
			while [ $COUNTER -ne $ITER ]
			do 
				printf '%s\n' "$FIRSTLINE"'m'"$COUNTER" 'wq' | ed -s "$TEST_DIR/$VCCNAME"
				((COUNTER++))
				((FIRSTLINE++))
			done
		#truncate -s -25 "$TEST_DIR/$VCCNAME"
	}
}
checkForValid(){
				 COUNTER=0
				 FIRSTP="$(grep -a -m 1 -n "[0-9][0-9]:" "$FILE")"
				 FIRSTPAT="${FIRSTP#*:}"
				 LINENUM="$(echo "$FIRSTP" | cut -d: -f1)"
				 CONFLICTNUM="$(grep -a -F "$FIRSTPAT" "$TEST_DIR/$VCCNAME" | wc -l)"
				 BOOL=0
				 [[ -z "$FIRSTPAT" ]] && {
				 CONFLICTNUM="0"
				[[ "$DATA_SUM" -ne "$(stat --printf="%s" "$TEST_DIR/$VCCNAME")" ]] && BOOL=1; 
				 }
				 #echo "$CONFLICTNUM $FILE"
			while [ $COUNTER -lt $CONFLICTNUM ]
			do	
				[[ "$(echo $(awk -v num="$LINENUM" 'NR>=num' "$FILE"))" =~ "$(echo $(awk -v pat="$FIRSTPAT" -v conflict="$COUNTER" 'NR==FNR{a[NR]=$0;len=NR;if($0==pat)init=NR; next} $0==pat{if(conflict==0){for(i=init;i<=len;i++){print $0;getline}} else conflict--}' "$FILE" "$TEST_DIR/$VCCNAME" 2>/dev/null))" ]] && {
				COUNTER="$CONFLICTNUM"
				BOOL=1
				}
				((COUNTER++))
			done
}
#Variable Declarations
TIMESTAMP_FORMAT=%Y_%m_%d

TODAY_DATE=$(date -d "today" +$TIMESTAMP_FORMAT)

HOURLY_FILE_DIR=/home/shamarkus/SRTVCC/testlogs		

TEST_DIR=/home/shamarkus/SRTVCC/TEST

TEMP_FILENAME=$(ls $HOURLY_FILE_DIR | grep "VCClog$" | head -n 1)

START_FILENAME="$(sed s/_/-/g<<<${TEMP_FILENAME:0:13})"

END_FILENAME="$(sed s/_/-/g<<<`expr substr $(ls $HOURLY_FILE_DIR | grep "VCClog$" | tail -n 1) 1 13`)" 

NUM_FILES=0

NUM_DAYS=0

SKIP_FILES=0

MISSING_FILES="MISSING FILES:\n"

TOTAL_TIME=`date +%s%3N`

PREVTIME=0
#If the directory contains VCClog files, then Continue normal operation
if [ -z "$TEMP_FILENAME" ]
then
	echo "The Specified Directory Has No Hourly VCClog Files"
else
	for FILE in $HOURLY_FILE_DIR/*VCClog;
	do

		TEMP_FILENAME="$(sed s/_/-/g<<<`expr substr $(basename $FILE) 1 13`)" 

		[[ ! -z "$PREV_FILENAME" ]] && { 
			[[ ! -s "$FILE" ]] && {
			MISSING_FILES="${MISSING_FILES}$(basename $FILE)\n"
			continue;
			}
			NUM_MISSING=$((($(date -d "${TEMP_FILENAME:0:10}" '+%s')+(10#${TEMP_FILENAME:11:2}*60*60)-$(date -d "${PREV_FILENAME:0:10}" '+%s')-(10#${PREV_FILENAME:11:2}*60*60))/(60*60)-1)); COUNTER=0; 

			while [ $COUNTER -lt $NUM_MISSING ]
			do	
				((COUNTER++))
				[[ ! -f "$HOURLY_FILE_DIR/`date -d "${PREV_FILENAME:0:4}${PREV_FILENAME:5:2}${PREV_FILENAME:8:2} ${PREV_FILENAME:11:2}+$COUNTER hour" '+%Y_%m_%d-%H'`_00_00-VCClog" ]] && MISSING_FILES="${MISSING_FILES}`date -d "${PREV_FILENAME:0:4}${PREV_FILENAME:5:2}${PREV_FILENAME:8:2} ${PREV_FILENAME:11:2}+$COUNTER hour" '+%Y_%m_%d-%H'`_00_00-VCClog\n";
			done
		}

		[[ $SKIP_FILES -ne 0 ]] && { 
			((SKIP_FILES--))
			PREV_FILENAME=$TEMP_FILENAME
			continue
		}
		TEMP_VCCNAME="VCC [${TEMP_FILENAME:0:10}].log"  
		
		#If New Daily File Needs to be created
		if [[ "$VCCNAME" != "$TEMP_VCCNAME" ]];
	       	then
			[[ ( ! -z "$VCCNAME" ) && ( $DATA_SUM -ne $(stat --printf="%s" "$TEST_DIR/$VCCNAME") ) ]] && {
				TEMPFILE="$FILE"
				FILE="$HOURLY_FILE_DIR/$(sed s/-/_/g<<<"${PREV_FILENAME:0:10}")${PREV_FILENAME:10:3}_00_00-VCClog"
				remakeFile
				FILE="$TEMPFILE"
			}
			makePreamble

			VCCNAME=$TEMP_VCCNAME

			[[ ! -f "$TEST_DIR/$VCCNAME" ]] && {
				((NUM_DAYS++))	
				cat $FILE>"$TEST_DIR/$VCCNAME"	
				PREAMBLEDATA=0
				echo "Working on $TEMP_VCCNAME"
			} || {
				echo "Inspecting $TEMP_VCCNAME"
			
				checkForValid
				[[ "$BOOL" == "0" ]] && remakeFile;

				PREAMBLEDATA="$(($(sed -n '/^------------------------/,/^-------------------------/{p;/^-------------------------/q}' "$TEST_DIR/$VCCNAME" | wc -c)+1))"
				#[[ "$PREAMBLEDATA" > "141" ]] && echo "CHECK $VCCNAME -- PREAMBLE OF $PREAMBLEDATA bytes";
			}
				DATA_SUM=$(($PREAMBLEDATA+$(stat --printf="%s" "$FILE")))
		else  	
				 checkForValid
				 [[ "$BOOL" == "0" ]] && {
					 [[ "$DATA_SUM" -ne "$(stat --printf="%s" "$TEST_DIR/$VCCNAME")" ]] && {
						 remakeFile
					} || {
						sed -i -e '$a\' "$FILE"
						cat $FILE>>"$TEST_DIR/$VCCNAME"
						((NUM_FILES++))	
			         		DATA_SUM=$(($DATA_SUM + $(stat --printf="%s" "$FILE")))	
					}
				} || {
					DATA_SUM=$(($DATA_SUM + $(stat --printf="%s" "$FILE")));	
				}
		fi
			
		PREV_FILENAME=$TEMP_FILENAME

	done
	
	makePreamble

	#One Time Run Summary To CLI
	echo -e "\n-------------------"
	echo "Execution Time: $(($(date +%s%3N)-$TOTAL_TIME)) ms"
	echo "Files Processed: $NUM_FILES"
	echo "Days Processed: $NUM_DAYS"
	echo "Date Ranges: `date -d "${START_FILENAME:0:10} ${START_FILENAME:11:2}"` -- `date -d "${TEMP_FILENAME:0:10} ${TEMP_FILENAME:11:2}"`"	
	echo -e ${MISSING_FILES::-2}
fi
