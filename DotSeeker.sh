#!/bin/bash
## DotSeeker
## Controls: WASD / HJKL
## Objective: Get 30 dots within a minute.


initialseconds="60"
minscore="30"
res_y="24"
res_x="80"


set -o pipefail

tput civis
trap "safe_exit" EXIT
clear

function update {
	clear
	
	echo -ne "\e[1;32m\n  `<"$shv_secrem_path"`"
	tput cup "1" "$((res_x-2-${#dotcount}))"
	echo -ne "\e[1;34m$dotcount\e[0m"
	
	tput cup "$plr_cpos_y" "$plr_cpos_x"
	echo -ne "\e[1;47m  \e[0m"
	if [[ "$dot" = "true" ]]; then
		tput cup "$dot_ppos_y" "$dot_ppos_x"
		echo -ne "\e[1;43m  \e[0m"
	fi
}

function go {
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
	read -rsn1 -t.05 ui
	case "$ui" in
		[wWkK]) export direction="up";;
		[sSjJ]) export direction="down";;
		[aAhH]) export direction="left";;
		[dDlL]) export direction="right";;
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
	((dot_ppos_y=RANDOM%(res_y)))
	((dot_ppos_x=(RANDOM%((res_x-2)/2))*2))
	dot=true
}

function dot_check {
	if [[ "$dot" = "true" && "$plr_cpos_y" = "$dot_ppos_y" && "$plr_cpos_x" = "$dot_ppos_x" ]]; then
		((dotcount++))
		dot=false
		unset -v dot_ppos_y dot_ppos_x
	fi
}

function keep_time {
	while [ "loop" ]; do
		sleep "1.0"
		echo "$((`<"$shv_secrem_path"` -1))" >"$shv_secrem_path"
	done
}

function safe_exit {
	kill -SIGKILL "$keep_time_pid" 2>/dev/null
	wait "$keep_time_pid" 2>/dev/null
	rm "$shv_secrem_path" 2>/dev/null
	clear
	echo
	tput cnorm
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
	read -s -t1 -N9
	read -s -n1
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
	read -s -t 0.5 -N9
	read -s -n1 title_keystroke
	case "$title_keystroke" in
		Q|q) safe_exit;;
		*) :;;
	esac
	unset -v title_keystroke
}

highscore=0  # (updated by program itself)

dot=false
dotcount=0
((plr_cpos_y=$res_y/2))
((plr_cpos_x=$res_x/2))
shv_secrem_path="/dev/shm/dotseek_secondsrem"
echo "$initialseconds" >"$shv_secrem_path"

screen_title

keep_time &
keep_time_pid="$!"
update

while [[ "loop" ]]; do
	input
	control
	if [[ "$dot" = "false" ]]; then
		dot_spawn
	fi
	dot_check
	if [[ "$(<"$shv_secrem_path")" = "0" ]]; then
		endgame
		break
	fi
done
