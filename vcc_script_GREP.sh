#!/bin/bash

remakeFile(){
	rm "$TEST_DIR/$VCCNAME"

	echo "Remaking $VCCNAME"	
	for File in $HOURLY_FILE_DIR/`expr substr $(basename $FILE) 1 10`*VCClog;
	do
		echo "Remade and Readded File $File"
		cat $File >> "$TEST_DIR/$VCCNAME"
	done
}

TIMESTAMP_FORMAT=%Y_%m_%d

TODAY_DATE=$(date -d "today" +$TIMESTAMP_FORMAT)

HOURLY_FILE_DIR=/home/shamarkus/SRTVCC/VCCHourly

TEST_DIR=/home/shamarkus/SRTVCC/TEST

# One-Time Mode

TEMP_FILENAME=$(ls $HOURLY_FILE_DIR | grep "VCClog$" | head -n 1)

START_FILENAME="$(sed s/_/-/g<<<${TEMP_FILENAME:0:13})"

END_FILENAME="$(sed s/_/-/g<<<`expr substr $(ls $HOURLY_FILE_DIR | grep "VCClog$" | tail -n 1) 1 13`)" 

# Removing all previous files - temporary fix
#rm -r $TEST_DIR/*

#Variable Declarations
NUM_FILES=0
NUM_DAYS=0
MISSING_FILES="MISSING FILES:\n"
TOTAL_TIME=`date +%s%3N`
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

		TEMP_VCCNAME="VCC [${TEMP_FILENAME:0:10}].log"  
		
		#If New Daily File Needs to be created
		if [[ "$VCCNAME" != "$TEMP_VCCNAME" ]];
	       	then
			[[ ! -z "$VCCNAME" ]] && {
				LINEDOWN="Lines Down:\n"
							echo "`awk '$2~/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/{cmd="date +%s -d "$2;cmd| getline a;if ((a-p)<0) a=(a+86400); b=((a-p)/60); if( NR > 1 && b > 8) {cmd="date +%H:%M:%S -d@"p;cmd| getline c; print "Down for "b" minutes from "c" to "$2}} {p=a}' "$TEST_DIR/$VCCNAME" 2>/dev/null`"
			}
			VCCNAME=$TEMP_VCCNAME
			[[ ! -f "$TEST_DIR/$VCCNAME" ]] && {
				((NUM_DAYS++))	
				cat $FILE>"$TEST_DIR/$VCCNAME"	
			} 
			DATA_SUM=$(stat --printf="%s" "$FILE")
		else  	
			[[ `cat $FILE | tr -d '\n' | wc -c` != `grep -Foaf "$TEST_DIR/$VCCNAME" "$FILE" | tr -d '\n' | wc -c` ]] && {
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

	#One Time Run Summary To CLI
	echo "Execution Time: $(($(date +%s%3N)-$TOTAL_TIME))"
	echo "Files Processed: $NUM_FILES"
	echo "Days Processed: $NUM_DAYS"
	echo "Date Ranges: `date -d "${START_FILENAME:0:10} ${START_FILENAME:11:2}"` -- `date -d "${TEMP_FILENAME:0:10} ${TEMP_FILENAME:11:2}"`"	
	echo -e ${MISSING_FILES::-2}
fi


	#	TEMP_YEAR=${TEMP_FILENAME:0:4}
  	#	TEMP_MONTH=${TEMP_FILENAME:5:2}
  	#TEMP_DAY=${TEMP_FILENAME:8:2}
  	#	TEMP_HOUR=${TEMP_FILENAME:11:2}
