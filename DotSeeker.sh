#!/usr/bin/env bash
## DotSeeker
## Controls: Arrow keys / WASD / HJKL
## Objective: Get 30 dots within a minute.


minscore=30
time_limit=60
res_y=24
res_x=80
frame_target_ns=40000000  # (per-frame time in nanoseconds)


set -o pipefail

safe_exit() {
	local exit_code=${1:-$?}
	stty echo
	tput cnorm
	if ((! exit_code)); then clear; fi
	echo
	exit $exit_code
}

debug() {
	local msg="$*"
	if [[ ${DEBUG:-0} == 1 ]]; then
		echo "${FUNCNAME[1]:+${FUNCNAME[1]}(): }${msg}" >> ./DotSeeker_debug.txt
	fi
}

update() {
	tput cup 1 2
	printf '\e[1;32m%2s\e[0m' $time_remaining

	tput cup "1" "$((res_x-2-${#score}))"
	printf '\e[1;'
	if ((dot)); then printf 3; else printf 7; fi
	printf '4m%i\e[0m' $score
	
	if ((plr_pwarp)); then
		warp_line clean
	fi
	if [[ $plr_cpos_x != $plr_ppos_x || $plr_cpos_y != $plr_ppos_y ]]; then
		tput cup $plr_ppos_y $plr_ppos_x
		printf '\e[0m  '
	fi
	if ((plr_cwarp)); then
		warp_line draw
	fi
	tput cup "$plr_cpos_y" "$plr_cpos_x"
	printf "$plr_printf"
	if [[ "$dot" = 1 && ( $dot_cpos_x != $plr_cpos_x || $dot_cpos_y != $plr_cpos_y ) ]]; then
		tput cup "$dot_cpos_y" "$dot_cpos_x"
		printf "$dot_printf"
	fi
	if ! ((plr_cwarp)); then
		tput cup $arrow_t_pos_y $arrow_t_pos_x
		printf '\/'
		tput cup $arrow_b_pos_y $arrow_b_pos_x
		printf '/\'
		tput cup $arrow_l_pos_y $arrow_l_pos_x
		printf '>>'
		tput cup $arrow_r_pos_y $arrow_r_pos_x
		printf '<<'
	fi
}

go() {
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
}

await_frame() {
	local now_ns=$(date +%s%N)
	if [[ -n $last_frame_start_ns ]]; then
		local delta_ns=$(( now_ns - last_frame_start_ns ))
		local remaining_ns=$(( frame_target_ns - delta_ns ))
		if (( remaining_ns > 0 )); then
			local remaining_s=$(printf '0.%09d' $remaining_ns)
			sleep $remaining_s
		fi
	fi
	last_frame_start_ns=$(date +%s%N)
}

input() {
	local lui ui arrowkey_seq=0
	while read -rn1 -t 0.0001 ui; do
		if ((arrowkey_seq == 3)); then
			arrowkey_seq=0  # (last arrow key sequence invalidated as we're past its last expected char)
		fi
		if [[
			( "$ui" == $'\033' && $arrowkey_seq -eq 0 ) ||
				( "$ui" == '[' && $arrowkey_seq -eq 1 ) ||
				( $arrowkey_seq -eq 2 )
		]]; then
			((arrowkey_seq++))  # (valid ongoing arrow key sequence so far)
		fi
		lui=$ui
	done  # (clears out the buffer while saving the last keystroke)
	if ((arrowkey_seq == 3)); then
		case "$lui" in
			A) direction=up;;
			B) direction=down;;
			C) direction=right;;
			D) direction=left;;
		esac
	else
		case "$lui" in
			[wWkK]) direction=up;;
			[sSjJ]) direction=down;;
			[aAhH]) direction=left;;
			[dDlL]) direction=right;;
			[qQ]) exit 0;;
		esac
	fi
}

control() {
	case "$direction" in
		up) go up;;
		down) go down;;
		left) go left;;
		right) go right;;
		*) go null;;
	esac
}

dot_spawn() {
	(( dot_cpos_y = RANDOM % res_y ))
	while :; do
		(( dot_cpos_x = ( RANDOM % ( (res_x-2)/2 ) ) * 2 ))
		# Avoid interfering with timer / score count
		if ! ((dot_cpos_y == 1 && ( dot_cpos_x == 0 || dot_cpos_x == 2 || dot_cpos_x == res_x - 4 ) ))
		then break
		fi
	done
	dot=1
}

dot_check() {
	local x=$1 y=$2
	if [[ "$dot" == 1 && "$y" = "$dot_cpos_y" && "$x" = "$dot_cpos_x" ]]; then
		((sound)) && paplay "$s_dot_catch" &>/dev/null &
		((score++))
		dot=0
		unset -v dot_cpos_y dot_cpos_x
	fi
}

arrow_check() {
	plr_pwarp=${plr_cwarp:-0}
	plr_cwarp=1
	if ((plr_cpos_x == arrow_t_pos_x && plr_cpos_y == arrow_t_pos_y)); then
		plr_cpos_y=$((res_y - 1))
		plr_warp_direction=down
	elif ((plr_cpos_x == arrow_b_pos_x && plr_cpos_y == arrow_b_pos_y)); then
		plr_cpos_y=0
		plr_warp_direction=up
	elif ((plr_cpos_x == arrow_l_pos_x && plr_cpos_y == arrow_l_pos_y)); then
		plr_cpos_x=$((res_x - 2))
		plr_warp_direction=right
	elif ((plr_cpos_x == arrow_r_pos_x && plr_cpos_y == arrow_r_pos_y)); then
		plr_cpos_x=0
		plr_warp_direction=left
	else
		plr_cwarp=0
	fi
	((plr_cwarp && sound)) && paplay "$s_warp" &>/dev/null &
}

warp_line() {
	local action=${1:-draw}
	debug "action:$action; plr_warp_direction:$plr_warp_direction"

	local axis i_start i_step; case $plr_warp_direction in
		up) axis=y i_start=$arrow_b_pos_y i_step=-1 ;;
		down) axis=y i_start=$arrow_t_pos_y i_step=1 ;;
		right) axis=x i_start=$arrow_l_pos_x i_step=2 ;;
		left) axis=x i_start=$arrow_r_pos_x i_step=-2 ;;
		*) return 1 ;;
	esac

	local i_target
	if [[ $action == draw ]]; then eval i_target="\$plr_cpos_${axis}"
	else eval i_target="\$plr_ppos_${axis}"
	fi

	local tput_args_draw tput_args_clean dot_check_args
	if [[ $axis == x ]]; then
		tput_args_draw="$plr_cpos_y \$i"
		tput_args_clean="$plr_ppos_y \$i"
		dot_check_args="\$i $plr_cpos_y"
	else
		tput_args_draw="\$i $plr_cpos_x"
		tput_args_clean="\$i $plr_ppos_x"
		dot_check_args="$plr_cpos_x \$i"
	fi

	local i color_val=232; for ((i = i_start; i != i_target; i += i_step)); do
		if [[ $action == 'draw' ]]; then
			eval tput cup "$tput_args_draw"
			debug drawing $axis $i
			printf '\e[48;5;%dm  \e[0m' "$color_val"
			((color_val != 255 && color_val++))
			eval dot_check "$dot_check_args"
		else
			eval tput cup "$tput_args_clean"
			debug cleaning $axis $i
			printf '\e[0m  '
		fi
	done
}

screen_lose() {
	clear
	tput cup "$(( res_y/2 ))" "$(( (res_x/2)-5 ))"
	echo -e "\e[1;31mYOU LOSE!\e[0m"
	((sound)) && paplay "$s_lose" &>/dev/null &
}

highscore_save() {
	local highscore_pattern highscore_lineno new_score
	old_score=$1
	new_score=$2
	highscore_pattern='^(highscore=)'"$old_score"'\>(.*)'
	if highscore_lineno=$(grep -nE -m1 "$highscore_pattern" "$me" | cut -d: -f1); then
		sed -ri "${highscore_lineno}s/${highscore_pattern}/\1${new_score}\2/" "$me" && return 0
	fi
	return 1
}

screen_win() {
	clear
	tput cup "$(( (res_y/2)-1 ))" "$(( (res_x/2)-7 ))"
	echo -e '\e[1;32mYOU ARE WINNER\e[0m'
	((sound)) && paplay "$s_win" &>/dev/null &
	local highscore_new=$((score > highscore))
	if ((highscore_new)); then
		local highscore_saved=0
		tput cup 0 0  # (for possible STDERR)
		highscore_save $highscore $score && highscore_saved=1
		tput cup "$(( (res_y/2)+1 ))" "$(( (res_x/2)-7 ))"
		printf '\e[1;33mNew high-score!'
		if ! ((highscore_saved)); then
			echo -e ' \e[0;31m(saving failed)\e[0m'
		fi
	fi
	tput cup "$(( (res_y/2)+1+highscore_new ))" "$(( (res_x/2)-5 ))"
	echo -e '\e[1;32mScore: \e[1;34m'"$score"'\e[0m'
}

endgame() {
	if [[ "$score" -lt "$minscore" ]]; then
		screen_lose
	else
		screen_win
	fi
	read -t1 -N9
	read -n1
	exit 0
}

screen_title() {
	clear
	tput cup "4" "$(( (res_x/2)-6 ))"
	echo '|\  ('
	tput cup "5" "$(( (res_x/2)-6 ))"
	echo '|/O'`((sdm))&&echo O`'T·)EEKER'
	tput cup "9" "$(( (res_x/2)-20 ))"
	echo "Objective: Get ${minscore} dots within a minute."
	tput cup "12" "$(( (res_x/2)-20 ))"
	echo -n 'Controls:'
	tput cup "12" "$(( (res_x/2)-7 ))"
	echo 'Arrow keys / W,A,S,D / H,J,K,L (move)'
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
		Q|q) exit 0;;
		*) :;;
	esac
	unset -v title_keystroke
}

draw_boundaries() {
	local edge_char=$(printf '\e[7;90m \e[;0m')
	local edge_margin_x=$(( $(tput cols) - res_x ))
	local edge_margin_y=$(( $(tput lines) - res_y ))
	if (( edge_margin_x > 0 )); then
		local edge_piece=$edge_char
		if (( edge_margin_x > 1 )); then
			edge_piece+=$edge_char
		fi
		local y; for ((y=0;y<=res_y;y++)); do
			tput cup $y $res_x
			echo -n "$edge_piece"
		done
	fi
	if (( edge_margin_y > 0 )); then
		local edge_piece=''
		local x; for ((x=0;x!=res_x;x++)); do
			edge_piece+=$edge_char
		done
		tput cup $res_y 0
		echo -n "$edge_piece"
	fi
}

me=$(readlink -e "${BASH_SOURCE[0]}")
highscore=0  # (updated by program itself)

if grep -qE '^-([Uu]|-upd(8|ate))$' <<< $1; then
	me_url='https://raw.githubusercontent.com/hk0O7/DotSeeker-Bash/refs/heads/main/DotSeeker.sh'
	me_url+="?token=$(date +%s)"  # (avoid possible version delays due to GitHub bug #46758)
	echo 'Beginning update process...'
	if ! [[ -O "$me" && -x "$me" && -w "$me" ]]; then
		echo "ERROR: Cannot proceed due to lack of expected permissions in: $me" >&2
		exit 1
	fi
	echo 'Latest version to be downloaded from:'$'\n'"    $me_url"
	read -p 'Proceed? [y/N] '
	if ! grep -qEi '^y(e(s|h|ah?)?)?$' <<< $REPLY; then
		echo 'Aborted.'
		exit 0
	fi
	if which wget >/dev/null; then
		me_new_cmd="wget -O - '$me_url'"
	elif which curl >/dev/null; then
		me_new_cmd="curl -L '$me_url'"
	else
		echo 'ERROR: No curl or wget present. Please make sure one of them is installed.' >&2
		exit 1
	fi
	echo; if ! me_new=$(eval "$me_new_cmd") || [[ -z "$me_new" ]]; then
		echo $'\n''ERROR: Could not download new version from URL:'$'\n'"    $me_url" >&2
		echo '  It may have changed. Please look for the latest version manually.' >&2
		exit 1
	fi
	echo "$me_new" > "$me" || exit 1
	echo 'Successfully downloaded into current filepath:'$'\n'"  $me"
	highscore_save 0 $highscore || echo "WARNING: Could not preserve current high-score: $highscore" >&2
	echo 'Update complete.'
	exit 0
elif [[ "$1" == --no-sound ]]; then
	sound=0
elif [[ -n "$1" ]]; then
	echo "ERROR: Unrecognized parameter: $1" >&2
	exit 1
fi

tput civis || { echo 'ERROR: ncurses / ncurses-bin missing. Try installing it.' >&2; exit 1; }
stty -echo
trap "safe_exit" EXIT
clear


dot=0
score=0
((plr_cpos_x=$res_x/2))
plr_ppos_x=$plr_cpos_x
((plr_cpos_y=$res_y/2))
plr_ppos_y=$plr_cpos_y
((sdm=525262068==$(date +%d%m|cksum|cut -d' ' -f1)))

screen_title
clear
if (( $(tput cols) < res_x || $(tput lines) < res_y )); then
	echo "ERROR: Insufficient terminal size/resolution; required minimum is $res_x x $res_y." >&2
	exit 1
fi
draw_boundaries

time_start=$(( $(date +%s) + 1 ))
tput cup "$(( res_y/2 ))" "$(( (res_x/2)-3 ))"
echo '"Loading"...'

# Sound setup & check
s_dot_catch='/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga'
s_warp='/usr/share/sounds/freedesktop/stereo/camera-shutter.oga'
s_lose='/usr/share/sounds/freedesktop/stereo/onboard-key-feedback.oga'
if [[ ! -f "$s_lose" ]]; then
	s_lose='/usr/share/sounds/freedesktop/stereo/trash-empty.oga'
fi
s_win='/usr/share/sounds/freedesktop/stereo/complete.oga'
if [[ -z "$sound" ]]; then
	if which paplay &>/dev/null && [[ -f "$s_dot_catch" && -f "$s_lose" && -f "$s_win" ]]; then
		sound=1
	else sound=0
	fi
fi

# Sync game timer with system seconds
while (( $(date +%s) < time_start )); do
	sleep 0.01
done
tput cup "$(( res_y/2 ))" "$(( (res_x/2)-3 ))"
printf '\e[0m            '

time_remaining=$time_limit

# Warp arrow positions
arrow_t_pos_x=$((res_x * 1/3)); ((arrow_t_pos_x % 2)) && ((arrow_t_pos_x += 2))
arrow_t_pos_y=0
arrow_b_pos_x=$((res_x * 2/3)); ((arrow_b_pos_x % 2)) && ((arrow_b_pos_x -= 1))
arrow_b_pos_y=$((res_y - 1))
arrow_l_pos_x=0
arrow_l_pos_y=$((res_y * 2/3))
arrow_r_pos_x=$((res_x - 2))
arrow_r_pos_y=$((res_y * 1/3))

((sdm))&&dot_printf='\U1f3ba' plr_printf='\U1f480'||dot_printf='\e[1;43m  \e[0m' plr_printf='\e[1;47m  \e[0m'
update

while [[ "loop" ]]; do
	await_frame
	input
	time_delta=$(( $(date +%s) - time_start ))
	time_remaining=$(( time_limit - time_delta ))
	control
	dot_check $plr_cpos_x $plr_cpos_y
	arrow_check
	update
	if ! ((dot)); then
		dot_spawn
	fi
	if ((time_remaining == 0)); then
		endgame
		break
	fi
done
