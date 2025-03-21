#!/bin/bash

echo "MadMediaTools v1.0 - Media manipulation with ffmpeg/dvdauthor/videotrans"
echo "Copyright (c) 2011 by m4D@n4\$7@"

if [ $# -ge 2 ]
then
	export INPUT="$1"
	export OUTPUT="$2"
	if [ ! -f "$INPUT" ]
	then
		echo "ERROR: Input file \"$INPUT\" does not exist"
		exit
	fi
	if [ -d "$OUTPUT" ]

	then
		echo "WARNING: Output directory \"$OUTPUT\" already exists. If you choose to proceed, its contents will be deleted."
		read -p "Are you sure you want to delete directory \"$OUTPUT\" and its contents? (y/n) " -n 1 a
		if [ "$a" != "y" ]
		then
			echo
			exit
		fi
		echo
		rm -rf "$OUTPUT" &> /dev/null
		if [ $? -ne 0 ]
		then
			echo "ERROR: Could not empty output directory \"$OUTPUT\""
			exit
		fi
	fi

	i="0"
	while [ $# -ge 3 ]
	do
		s="$3"
		sl="${s%%:*}"
		sf="${s##*:}"
		if [ "$sf" = "" ] || [ "$sl" = "" ] || [ "$sl" = "$s" ]
		then
		echo "ERROR: Bad subtitle argument \"$s\""
		exit
		fi
		if [ ! -f "$sf" ]
		then
		echo "ERROR: Subtitle file \"$sf\" does not exist"
		exit
		fi
		SUBLANGS[i]=$sl
		SUBFILES[i]=$sf
		if [ "${SUBLANGS[$i]}" == "el" ]
		then
			SUBENCODINGS[i++]="iso-8859-7"
		else
			SUBENCODINGS[i++]="`file -ib $sf | grep -o [0-9a-zA-Z\-]*$`"
		fi
		shift
	done
else
	echo 'Usage: filetodvd.sh <input> <output> [<lang>:<subs>]*'
	echo 'where:'
	echo '  <input> is the input media file (will be re-encoded even if in the right format)'
	echo '  <output> is the output directory (any contents will be deleted)'
	echo '  <lang> is a subtitles language indicator (must be a valid one)'
	echo '  <subs> is a subtitles file (must exist)'
	echo 'You can specify multiple <lang>:<subs> arguments to create a DVD with multiple subtitles'
	exit
fi

echo -n "Will create a DVD under $OUTPUT using $INPUT as a source, "

NUMSUBS="${#SUBLANGS[@]}"

if [ $NUMSUBS -ne 0 ]
then
	echo with the following subtitles:
	for i in `seq 0 $[$NUMSUBS-1]`; do
		echo " $i: ${SUBFILES[$i]} (${SUBLANGS[$i]}, ${SUBENCODINGS[$i]})"
	done
else
	echo without any subtitles.
fi

read -p "Press any key to begin... " -n 1 -s
echo

mkdir "$OUTPUT"

echo -n "Converting input file... "

TMPFILE="$OUTPUT/tmp.mpg"

ffmpeg -i "$INPUT" -target pal-dvd "$TMPFILE" 2> "$OUTPUT/ffmpeg.log"
if [ $? -ne 0 ]
then
	echo "failed"
	echo "ERROR: Input file conversion failed, check ffmpeg.log for more information"
	exit
fi

echo "done"

if [ $NUMSUBS -ne 0 ]
then
	echo -n "Creating subtitles definition file(s)... "
	for i in `seq 0 $[$NUMSUBS-1]`; do
		SPUMUXDEFFILES[i]="$OUTPUT/spumux.${SUBLANGS[$i]}.xml"
        echo -e "<subpictures>\r\n  <stream>\r\n    <textsub" >> ${SPUMUXDEFFILES[$i]}
		echo -e "      filename=\"${SUBFILES[$i]}\"" >> ${SPUMUXDEFFILES[$i]}
		echo -e "      characterset=\"${SUBENCODINGS[$i]}\"" >> ${SPUMUXDEFFILES[$i]}
		echo -e "      horizontal-alignment=\"center\"" >> ${SPUMUXDEFFILES[$i]}
		echo -e "      fontsize=\"28\"" >> ${SPUMUXDEFFILES[$i]}
        echo -e "    />\r\n  </stream>\r\n</subpictures>" >> ${SPUMUXDEFFILES[$i]}
	done

    echo "done"
	
	echo "Adding subtitles..."
	f=$TMPFILE
	for i in `seq 0 $[$NUMSUBS-1]`; do
        echo -n "- adding \"${SUBFILES[$i]}\"... "
	    n="$OUTPUT/tmp.$i.mpg"
        spumux -m dvd -s $i "$OUTPUT/spumux.${SUBLANGS[$i]}.xml" < $f > $n 2> "$OUTPUT/spumux.${SUBLANGS[$i]}.log"
		if [ $? -ne 0 ]
		then
			echo "failed"
			echo "ERROR: Could not add subtitles from \"${SUBFILES[$i]}\", check spumux.${SUBLANGS[$i]}.log for more information"
			exit
		fi
        echo "done"
		f=$n
	done
	RDYFILE=$f
else
    RDYFILE=$TMPFILE
fi

echo -n "Creating DVD definition file... "
DVDAUTHORDEFFILE="$OUTPUT/dvdauthor.xml"
echo -e "<dvdauthor>\r\n  <vmgm />\r\n  <titleset>\r\n    <titles>" >> "$DVDAUTHORDEFFILE"
for i in `seq 0 $[$NUMSUBS-1]`; do
    echo -e "      <subpicture lang=\"${SUBLANGS[$i]}\" />" >> "$DVDAUTHORDEFFILE"
done
echo -e "      <pgc>" >> "$DVDAUTHORDEFFILE"
echo -e "        <pre>subtitle=64;</pre>" >> "$DVDAUTHORDEFFILE"
echo -e "        <vob file=\"$RDYFILE\" />" >> "$DVDAUTHORDEFFILE"
echo -e "        <post>jump title 1;</post>" >> "$DVDAUTHORDEFFILE"
echo -e "      </pgc>" >> "$DVDAUTHORDEFFILE"
echo -e "    </titles>\r\n  </titleset>\r\n</dvdauthor>" >> "$DVDAUTHORDEFFILE"

echo "done"

echo -n "Creating DVD structure... "

dvdauthor -o "$OUTPUT/DVD" -x "$DVDAUTHORDEFFILE" 2> "$OUTPUT/dvdauthor.log"
if [ $? -ne 0 ]
then
	echo "failed"
	echo "ERROR: Could not add create DVD structure, check dvdauthor.log for more information"
	exit
fi

echo "done"

echo -n "Cleaning up... "
rm "$OUTPUT/*.mpg" &> /dev/null
if [ $? -ne 0 ]
then
	echo "failed"
	echo "ERROR: Could not delete temporary files in output directory"
	exit
fi

echo "done"

echo "Done."
