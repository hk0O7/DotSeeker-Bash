#!/bin/bash
## DotSeeker
## Controls: WASD / HJKL
## Objective: Get 30 dots within a minute.


minscore=30
time_limit=60
res_y=24
res_x=80


set -o pipefail

tput civis
stty -echo
trap "safe_exit" EXIT
clear

function update {
	tput cup 0 0
	printf '\e[1;32m\n  %2s' $time_remaining
	tput cup "1" "$((res_x-2-${#dotcount}))"
	echo -ne "\e[1;34m$dotcount\e[0m"
	
	tput cup "$plr_cpos_y" "$plr_cpos_x"
	echo -ne "\e[1;47m  \e[0m"
	if [[ $plr_cpos_x != $plr_ppos_x || $plr_cpos_y != $plr_ppos_y ]]; then
		tput cup $plr_ppos_y $plr_ppos_x
		echo -ne "\e[1;40m  \e[0m"
	fi
	if [[ "$dot" = "true" && $dot_cpos_x != $plr_cpos_x && $dot_cpos_y != $plr_cpos_y ]]; then
		tput cup "$dot_cpos_y" "$dot_cpos_x"
		echo -ne "\e[1;43m  \e[0m"
	fi
}

function go {
	plr_ppos_x=$plr_cpos_x plr_ppos_y=$plr_cpos_y
	case "$1" in
		"up")
			if [[ "$plr_cpos_y" -le "0" ]]; then
				update
				return
			fi
			((plr_cpos_y--))
			;;
		"down")
			if [[ "$plr_cpos_y" -ge "$((res_y-1))" ]]; then
				update
				return
			fi
			((plr_cpos_y++))
			;;
		"left")
			if [[ "$plr_cpos_x" -le "0" ]]; then
				update
				return
			fi
			((plr_cpos_x-=2))
			;;
		"right")
			if [[ "$plr_cpos_x" -ge "$((res_x-3))" ]]; then
				update
				return
			fi
			((plr_cpos_x+=2))
			;;
	esac
	update
}

function input {
	sleep 0.04
	local lui ui
	while read -rn1 -t 0.0001 ui; do lui=$ui; done  # (clears out the buffer while saving the last keystroke)

	#local readtimens_target=50000000
	#local readtimens_start=$(date +%s%N)
	#read -rn1 -t "$(printf '0.%09d' $readtimens_target)" ui
	#local readtimens_remaining=$(( readtimens_target - ( $(date +%s%N) - readtimens_start ) ))
	#((readtimens_remaining > 0)) && { sleep "$(printf '0.%09d' $readtimens_remaining)"; echo slept >> ./debug.txt; }
	#echo readtimens_delta:$readtimens_delta readtimens_remaining:$readtimens_remaining >> ./debug.txt
	#echo readtimens_remaining:$readtimens_remaining >> ./debug.txt
	#utns_t=500000000; utns_b=$(date +%s%N); read -rsn1 -t "0.$utns_t" ui; utns_a=$(date +%s%N); utns_d=$(( utns_a - utns_b )); utns_r=$(( utns_t - utns_d )); ((utns_r > 0)) && sleep "0.$utns_r"; echo utns_d:$utns_d utns_r:$utns_r ui:$ui
	case "$lui" in
		[wWkK]) direction="up";;
		[sSjJ]) direction="down";;
		[aAhH]) direction="left";;
		[dDlL]) direction="right";;
		q|Q) exit;;
	esac
}

function control {
	case "$direction" in
		up) go up;;
		down) go down;;
		left) go left;;
		right) go right;;
		*) go null;;
	esac
}

function dot_spawn {
	((dot_cpos_y=RANDOM%(res_y)))
	((dot_cpos_x=(RANDOM%((res_x-2)/2))*2))
	dot=true
}

function dot_check {
	if [[ "$dot" = "true" && "$plr_cpos_y" = "$dot_cpos_y" && "$plr_cpos_x" = "$dot_cpos_x" ]]; then
		((dotcount++))
		dot=false
		unset -v dot_cpos_y dot_cpos_x
	fi
}

function safe_exit {
	stty echo
	tput cnorm
	clear
	echo
	exit 0
}

function screen_lose {
	clear
	tput cup "$(( res_y/2 ))" "$(( (res_x/2)-5 ))"
	echo -e "\e[1;31mYOU LOSE!\e[0m"
}

function screen_win {
	clear
	tput cup "$(( (res_y/2)-1 ))" "$(( (res_x/2)-7 ))"
	echo -e '\e[1;32mYOU ARE WINNER\e[0m'
	local highscore_new=$((dotcount > highscore))
	if ((highscore_new)); then
		local highscore_saved=0 highscore_pattern highscore_lineno
		highscore_pattern='^(highscore=)'"$highscore"'(.*)'
		tput cup 0 0  # (for possible STDERR)
		if highscore_lineno=$(grep -nE -m1 "$highscore_pattern" "$0" | cut -d: -f1); then
			sed -ri "${highscore_lineno}s/${highscore_pattern}/\1${dotcount}\2/" "$0" && highscore_saved=1
		fi
		tput cup "$(( (res_y/2)+1 ))" "$(( (res_x/2)-7 ))"
		echo -ne '\e[1;33mNew high-score!'
		if ! ((highscore_saved)); then
			echo -e ' \e[0;31m(saving failed)\e[0m'
		fi
	fi
	tput cup "$(( (res_y/2)+1+highscore_new ))" "$(( (res_x/2)-5 ))"
	echo -e '\e[1;32mScore: \e[1;34m'"$dotcount"'\e[0m'
}

function endgame {
	if [[ "$dotcount" -lt "$minscore" ]]; then
		screen_lose
	else
		screen_win
	fi
	read -t1 -N9
	read -n1
	safe_exit
}

function screen_title {
	clear
	tput cup "4" "$(( (res_x/2)-6 ))"
	echo '|\  ('
	tput cup "5" "$(( (res_x/2)-6 ))"
	echo '|/O'$([[ $(date +%m%d) == 1031 ]] && echo O)'T·)EEKER'
	tput cup "9" "$(( (res_x/2)-20 ))"
	echo "Objective: Get ${minscore} dots within a minute."
	tput cup "12" "$(( (res_x/2)-20 ))"
	echo -n 'Controls:'
	tput cup "12" "$(( (res_x/2)-7 ))"
	echo 'W,A,S,D / H,J,K,L (move)'
	tput cup "13" "$(( (res_x/2)-7 ))"
	echo 'Q - Quit game'
	if ((highscore >= minscore)); then
		tput cup 15 "$(( (res_x/2)-20 ))"
		echo -e "High-score:  \e[1;m${highscore}\e[0m"
	fi
	tput cup 18 "$(( (res_x/2)-12 ))"
	echo 'Press any key to start!'
	read -t 0.5 -N9
	read -n1 title_keystroke
	case "$title_keystroke" in
		Q|q) safe_exit;;
		*) :;;
	esac
	unset -v title_keystroke
}

highscore=0  # (updated by program itself)

dot=false
dotcount=0
((plr_cpos_x=$res_x/2))
plr_ppos_x=$plr_cpos_x
((plr_cpos_y=$res_y/2))
plr_ppos_y=$plr_cpos_y

screen_title
clear

time_start=$(( $(date +%s) + 1 ))
tput cup "$(( res_y/2 ))" "$(( (res_x/2)-3 ))"
echo '"Loading"...'
while (( $(date +%s) < time_start )); do
	sleep 0.01
done
tput cup "$(( res_y/2 ))" "$(( (res_x/2)-3 ))"
echo -ne "\e[1;40m            \e[0m"

time_remaining=$time_limit

update

while [[ "loop" ]]; do
	input
	time_delta=$(( $(date +%s) - time_start ))
	time_remaining=$(( time_limit - time_delta ))

	control
	if [[ "$dot" = "false" ]]; then
		dot_spawn
	fi
	dot_check
	if ((time_remaining == 0)); then
		endgame
		break
	fi
done
