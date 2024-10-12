#!/bin/bash
## DotSeeker
## Controls: WASD
## Objective: Get 30 dots within a minute.


initialseconds="60"
minscore="30"
res_y="24"
res_x="80"


tput civis
trap "safe_exit" EXIT
clear

function update {
	clear
	
	echo -ne "\e[1;32m\n  `<"$shv_secrem_path"`"
	tput cup "1" "$((res_x-2-${#pointcount}))"
	echo -ne "\e[1;34m$pointcount\e[0m"
	
	tput cup "$cpos_y" "$cpos_x"
	echo -ne "\e[1;47m  \e[0m"
	if [[ "$point" = "true" ]]; then
		tput cup "$ppos_y" "$ppos_x"
		echo -ne "\e[1;43m  \e[0m"
	fi
}

function go {
	case "$1" in
		"up")
			if [[ "$cpos_y" -le "0" ]]; then
				update
				return
			fi
			((cpos_y--))
			;;
		"down")
			if [[ "$cpos_y" -ge "$((res_y-1))" ]]; then
				update
				return
			fi
			((cpos_y++))
			;;
		"left")
			if [[ "$cpos_x" -le "0" ]]; then
				update
				return
			fi
			((cpos_x-=2))
			;;
		"right")
			if [[ "$cpos_x" -ge "$((res_x-3))" ]]; then
				update
				return
			fi
			((cpos_x+=2))
			;;
	esac
	update
}

function input {
	read -rsn1 -t.05 ui
	case "$ui" in
		w|W) export direction="up";;
		s|S) export direction="down";;
		a|A) export direction="left";;
		d|D) export direction="right";;
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

function point_spawn {
	((ppos_y=RANDOM%(res_y)))
	((ppos_x=(RANDOM%((res_x-2)/2))*2))
	point=true
}	

function point_check {
	if [[ "$point" = "true" && "$cpos_y" = "$ppos_y" && "$cpos_x" = "$ppos_x" ]]; then
		((pointcount++))
		point=false
		unset -v ppos_y ppos_x
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
	echo -e "\e[1;32mYOU ARE WINNER\e[0m"
	tput cup "$(( (res_y/2)+1 ))" "$(( (res_x/2)-5 ))"
	echo -e "\e[1;32mScore: \e[1;34m"$pointcount"\e[0m"
}

function endgame {
	if [[ "$pointcount" -lt "$minscore" ]]; then
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
	echo '|/OT·)EEKER'
	tput cup "9" "$(( (res_x/2)-20 ))"
	echo 'Objective: Get 30 dots within a minute.'
	tput cup "12" "$(( (res_x/2)-20 ))"
	echo -n 'Controls:'
	tput cup "12" "$(( (res_x/2)-7 ))"
	echo 'W,A,S,D (move)'
	tput cup "13" "$(( (res_x/2)-7 ))"
	echo 'Q - Quit game'
	tput cup "$((res_y-5))" "$(( (res_x/2)-12 ))"
	echo 'Press any key to start!'
	read -s -t 0.5 -N9
	read -s -n1 title_keystroke
	case "$title_keystroke" in
		Q|q) safe_exit;;
		*) :;;
	esac
	unset -v title_keystroke
}

point=false
pointcount=0
((cpos_y=$res_y/2))
((cpos_x=$res_x/2))
shv_secrem_path="/dev/shm/dotseek_secondsrem"
echo "$initialseconds" >"$shv_secrem_path"

screen_title

keep_time &
keep_time_pid="$!"
update

while [[ "loop" ]]; do
	input
	control
	if [[ "$point" = "false" ]]; then
		point_spawn
	fi
	point_check
	if [[ "$(<"$shv_secrem_path")" = "0" ]]; then
		endgame
		break
	fi
done

