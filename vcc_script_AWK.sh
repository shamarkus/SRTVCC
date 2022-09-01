#!/bin/bash

remakeFile(){
	rm "$TEST_DIR/$VCCNAME"
	
	FILETIME=$(date -d "$(sed s/_/:/g<<<$(expr substr $(basename $FILE) 12 8))" +%s)
	echo "Remaking $VCCNAME"	
	for File in $HOURLY_FILE_DIR/`expr substr $(basename $FILE) 1 10`*VCClog;
	do
		echo "Remade and Readded File $File"
		cat $File >> "$TEST_DIR/$VCCNAME"
		((NUM_FILES++))
		[[ $(date -d "$(sed s/_/:/g<<<$(expr substr $(basename $File) 12 8))" +%s) -gt $FILETIME ]] && ((SKIP_FILES++));
	done

	((NUM_DAYS++))
}
makePreamble(){
	[[ ( ! -z "$VCCNAME" ) && ( -z `sed -n '1{/^------------------------/p};q' "$TEST_DIR/$VCCNAME"` ) ]] && {
		echo "Creating Preamble for $VCCNAME"
		echo -e "\n------------------------\n<START LOG>\n-----------------------\nSTART DATE: `date`\nLines Down:" >> "$TEST_DIR/$VCCNAME"
		awk '$2~/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/{cmd="date +%s -d "$2;cmd| getline a;if ((a-p)<0) a=(a+86400); b=((a-p)/60); if( NR > 1 && b > 15) {cmd="date +%H:%M:%S -d@"p;cmd| getline c; print "Down for "b" minutes from "c" to "$2}} {p=a}' "$TEST_DIR/$VCCNAME" 2>/dev/null >> "$TEST_DIR/$VCCNAME"
		echo -e "------------------------" >> "$TEST_DIR/$VCCNAME"

		FIRSTLINE=`grep -n -- ------------------------ "$TEST_DIR/$VCCNAME" | head -n 1 | cut -d: -f1`
		LASTLINE=`grep -n -- ------------------------ "$TEST_DIR/$VCCNAME" | tail -n 1 | cut -d: -f1`
		ITER=$((LASTLINE - FIRSTLINE + 1)); COUNTER=0;
		
			while [ $COUNTER -ne $ITER ]
			do 
				printf '%s\n' "$FIRSTLINE"'m'"$COUNTER" 'wq' | ed -s "$TEST_DIR/$VCCNAME"
				((COUNTER++))
				((FIRSTLINE++))
			done
	}
}
#Variable Declarations
TIMESTAMP_FORMAT=%Y_%m_%d

TODAY_DATE=$(date -d "today" +$TIMESTAMP_FORMAT)

HOURLY_FILE_DIR=/home/shamarkus/SRTVCC/VCCHourly

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
			NUM_MISSING=$((($(date -d "${TEMP_FILENAME:0:10}" '+%s')+(10#${TEMP_FILENAME:11:2}*60*60)-$(date -d "${PREV_FILENAME:0:10}" '+%s')-(10#${PREV_FILENAME:11:2}*60*60))/(60*60)-1)); COUNTER=0; 

			while [ $COUNTER -ne $NUM_MISSING ]
			do	
				((COUNTER++))
				MISSING_FILES="${MISSING_FILES}`date -d "${PREV_FILENAME:0:4}${PREV_FILENAME:5:2}${PREV_FILENAME:8:2} ${PREV_FILENAME:11:2}+$COUNTER hour" '+%Y_%m_%d-%H'`_00_00-VCClog\n"
			done
		}

		[[ $SKIP_FILES -ne 0 ]] && { 
			((SKIP_FILES--))
			continue
		}
		TEMP_VCCNAME="VCC [${TEMP_FILENAME:0:10}].log"  
		
		#If New Daily File Needs to be created
		if [[ "$VCCNAME" != "$TEMP_VCCNAME" ]];
	       	then
			makePreamble
			VCCNAME=$TEMP_VCCNAME
			CURTIME=`date +%s%3N`
			echo $(($CURTIME-$PREVTIME))
			PREVTIME=$CURTIME

			[[ ! -f "$TEST_DIR/$VCCNAME" ]] && {
				((NUM_DAYS++))	
				cat $FILE>"$TEST_DIR/$VCCNAME"	
				PREAMBLEDATA=0
				echo "Working on $TEMP_VCCNAME"
			} || {
				echo "Inspecting $TEMP_VCCNAME"
				[[ `cat $FILE | tr -d '\n' | wc -c` != `awk 'NR==FNR{a[$0]; next} {for (i in a) if ($0 == i) print $0}' "$TEST_DIR/$VCCNAME" "$FILE" | tr -d '\n' | wc -c` ]] && remakeFile;
				PREAMBLEDATA=`sed -n '/^------------------------/,/^------------------------/{p;/^------------------------/q}' "$TEST_DIR/$VCCNAME" | wc -c`
			}
				DATA_SUM=$(($PREAMBLEDATA+$(stat --printf="%s" "$FILE")))
		else  	
				 [[ `cat $FILE | tr -d '\n' | wc -c` != `awk 'NR==FNR{a[$0]; next} {for (i in a) if ($0 == i) print $0}' "$TEST_DIR/$VCCNAME" "$FILE" | tr -d '\n' | wc -c` ]] && {
				 	 [[ $DATA_SUM -ne `stat --printf="%s" "$TEST_DIR/$VCCNAME"` ]] && {
						remakeFile
					} || {
						cat $FILE>>"$TEST_DIR/$VCCNAME"
						DATA_SUM=$(($DATA_SUM + $(stat --printf="%s" "$FILE")))	
						((NUM_FILES++))	
					}
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
