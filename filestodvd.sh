#!/bin/bash

echo "MadMediaTools v1.0 - Media manipulation with ffmpeg/dvdauthor/videotrans"
echo "Copyright (c) 2011 by m4D@n4\$7@"

if [ $# -ge 4 ]
then
	OUTPUT="$1"
	BACKGROUND="$2"
	MUSIC="$3"
	if [ ! -f $MUSIC ]
	then
		echo "ERROR: Title menu music file \"$MUSIC\" does not exist"
		exit
	fi
	if [ -d $OUTPUT ]
	then
		echo "WARNING: Output directory \"$OUTPUT\" already exists. If you choose to proceed, its contents will be deleted."
		read -p "Are you sure you want to delete directory \"$OUTPUT\" and its contents? (y/n) " -n 1 a
		if [ "$a" != "y" ]
		then
			echo
			exit
		fi
		echo
		rm -rf $OUTPUT &> /dev/null
		if [ $? -ne 0 ]
		then
			echo "ERROR: Could not empty output directory \"$OUTPUT\""
			exit
		fi
	fi

	i="0"
	while [ $# -ge 4 ]
	do
		s="$4"
		h="${s%%:*}"
		
		INPUTFILES[i]="$h"
		
		if [ "$s" != "$h" ]
		then

			r="${s#*:}"

			l=""
			f=""

			if [ "$h" != "$r" ]
			then
			
				h="${r%%:*}"
				r="${r#*:}"

				l="$l$h"
				
				if [ "$r" == "$h" ] || [ "$h" == "" ] || [ "$r" == "" ]
				then
					echo "ERROR: Bad argument \"$s\""
					exit
				fi

				h="${r%%:*}"
				r="${r#*:}"

				f="$f$h"

				while [ "$h" != "$r" ]
				do
					h="${r%%:*}"
					r="${r#*:}"

					l="$l:$h"
					
					if [ "$r" == "$h" ] || [ "$h" == "" ] || [ "$r" == "" ]
					then
						echo "ERROR: Bad argument \"$s\""
						exit
					fi

					h="${r%%:*}"
					r="${r#*:}"

					f="$f:$h"
				done

			fi

			SUBLANGS[i]=$l
			SUBFILES[i++]=$f
		else
			SUBLANGS[i]=""
			SUBFILES[i++]=""
		fi
		shift
	done
else
	echo 'Usage: filestodvd.sh <output> <background> <music> <input>[:<lang>:<subs>]* ...'
	echo 'where:'
	echo '  <output> is the output directory (any contents will be deleted)'
	echo '  <background> is a file or color value to be used as the title menu background (if the file does not exist, the argument will interpreted as a color value in RRGGBB format)'
	echo '  <music> is an audio file to be as the title menu background music'
	echo '  <input> is an input media file (will be re-encoded even if in the right format)'
	echo '  <lang> is a subtitles language indicator (must be a valid one)'
	echo '  <subs> is a subtitles file (must exist)'
	echo 'You can specify multiple <lang>:<subs> arguments to create a DVD with multiple subtitles'
	exit
fi

echo "Will create a DVD under \"$OUTPUT\" from the following sources:"

NUMINPUTS="${#INPUTFILES[@]}"

for i in `seq 0 $[$NUMINPUTS-1]`; do
	echo "  $i) ${INPUTFILES[i]}"
	if [ "${SUBLANGS[i]}" != "" ]
	then
		l=(`echo ${SUBLANGS[i]} | tr ':' ' '`)
		f=(`echo ${SUBFILES[i]} | tr ':' ' '`)
		n="${#f[@]}"
		for j in `seq 0 $[$n-1]`; do
			echo "    - ${f[j]} (${l[j]})"
		done
	else
		echo "    - No subtitles"
	fi
done

read -p "Press any key to begin... " -n 1 -s
echo

mkdir $OUTPUT

echo "Converting input file(s)... "

for i in `seq 0 $[$NUMINPUTS-1]`; do

	echo -n "  - ${INPUTFILES[i]}... "

	t="`basename \"${INPUTFILES[i]}\"`"
	TEMPFILES[i]="`echo $OUTPUT/${t%%.*}.mpg | sed 's/ /_/g'`"
	logfile="$OUTPUT/ffmpeg.$i.log"

	ffmpeg -i "${INPUTFILES[i]}" -target pal-dvd -y "${TEMPFILES[i]}" 2> $logfile
	if [ $? -ne 0 ]
	then
		echo "failed"
		echo "ERROR: Input file conversion failed, check \"ffmpeg.$i.log\" for more information"
		exit
	fi

	echo "done"
done

echo "Creating subtitles definition file(s)... "

for i in `seq 0 $[$NUMINPUTS-1]`; do
	if [ "${SUBLANGS[i]}" != "" ]
	then
		echo "  - ${INPUTFILES[i]}"
		langs=(`echo ${SUBLANGS[i]} | tr ':' ' '`)
		files=(`echo ${SUBFILES[i]} | tr ':' ' '`)
		n="${#langs[@]}"
		for j in `seq 0 $[$n-1]`; do

			echo -n "    - ${langs[j]}... "

			spumuxdeffile="$OUTPUT/spumux.${INPUTFILES[i]}.${langs[j]}.xml"
			echo -e "<subpictures>\r\n  <stream>\r\n    <textsub" >> "$spumuxdeffile"
			echo -e "      filename=\"${files[$j]}\"" >> "$spumuxdeffile"
			if [ "${langs[$j]}" == "el" ]
			then
				echo -e "      characterset=\"ISO8859-7\"" >> "$spumuxdeffile"
			fi
			echo -e "      horizontal-alignment=\"center\"" >> "$spumuxdeffile"
			echo -e "      fontsize=\"28\"" >> "$spumuxdeffile"
			echo -e "    />\r\n  </stream>\r\n</subpictures>" >> "$spumuxdeffile"

			echo "done"

		done
	fi
done

echo "Adding subtitles... "

for i in `seq 0 $[$NUMINPUTS-1]`; do
	if [ "${SUBLANGS[i]}" != "" ]
	then
		echo "  - ${INPUTFILES[i]}"
		langs=(`echo ${SUBLANGS[i]} | tr ':' ' '`)
		files=(`echo ${SUBFILES[i]} | tr ':' ' '`)
		f=${TEMPFILES[i]}
		n="${#langs[@]}"
		for j in `seq 0 $[$n-1]`; do

			echo -n "    - ${langs[j]}... "

			n="$OUTPUT/$i.$j.mpg"

			spumuxdeffile="$OUTPUT/spumux.${INPUTFILES[i]}.${langs[j]}.xml"
			logfile="$OUTPUT/spumux.${INPUTFILES[i]}.${langs[j]}.log"

			spumux -m dvd -s $j "$spumuxdeffile" < "$f" > $n 2> "$logfile"

			if [ $? -ne 0 ]
			then
				echo "failed"
				echo "ERROR: Could not process \"$spumuxdeffile\", check \"$logfile\" for more information"
				exit
			fi

			rm "$f"
			f=$n
			
			echo "done"

		done
		mv "$f" "${TEMPFILES[i]}"
	fi
	RDYFILES[i]="`basename \"${TEMPFILES[i]}\"`";

done

echo "Creating title menu... "

logfile="$OUTPUT/movie-make-title-simple.log"
if [ -f $BACKGROUND ]
then
	movie-make-title-simple -o $OUTPUT/title -m pal -i $BACKGROUND -s -a $MUSIC 2> $logfile
else
	movie-make-title-simple -o $OUTPUT/title -m pal -b $BACKGROUND -a $MUSIC 2> $logfile
fi
if [ $? -ne 0 ]
then
	echo "failed"
	echo "ERROR: Could not prepare title menu, check \"$logfile\" for more information"
	exit
fi
for i in `seq 0 $[$NUMINPUTS-1]`; do
	t="`basename \"${INPUTFILES[i]}\"`"
	n="${t%%.*}"
	f="`echo $OUTPUT/$n | sed 's/ /_/g'`.info"
	echo "$n" > "$f" 
done

s=""
for i in `seq 0 $[$NUMINPUTS-1]`; do
    f="${RDYFILES[i]}"
	s="$s $f"
done
logfile="movie-title.log"
RETURNDIR="`pwd`"
cd $OUTPUT
movie-title -o title.vob -t title$s 2> $logfile
if [ $? -ne 0 ]
then
	echo "failed"
	echo "ERROR: Could not create title menu VOB file, check \"$OUTPUT/$logfile\" for more information"
	cd $RETURNDIR
	exit
fi

logfile="dvdauthor.log"
echo "Creating DVD structure... "
s="`cat title.vob-dvdauthor.xml | tr -d '[\t\n\r]'`"
s="${s//resolution=\"???x???\" /}"
for i in `seq 0 $[$NUMINPUTS-1]`; do
	if [ "${SUBLANGS[i]}" != "" ]
	then
		r="<pgc><vob file=\"${RDYFILES[i]}\""
		langs=(`echo ${SUBLANGS[i]} | tr ':' ' '`)
		files=(`echo ${SUBFILES[i]} | tr ':' ' '`)
		t=""
		n="${#langs[@]}"
		for j in `seq 0 $[$n-1]`; do
			t="$t<subpicture lang=\"${langs[j]}\" />"
		done
		t="$t<pgc><vob file=\"${RDYFILES[i]}\""
		s="${s/$r/$t}"
	fi
done
echo "$s" > title.vob-dvdauthor.xml
dvdauthor -o DVD -x title.vob-dvdauthor.xml 2> $logfile
if [ $? -ne 0 ]
then
	echo "failed"
	echo "ERROR: Could not create DVD structure, check \"$OUTPUT/$logfile\" for more information"
	cd $RETURNDIR
	exit
fi

cd $RETURNDIR

echo "Done."
