#!/bin/bash

input=""
cont=1
curr_page=0
max_page=0
page_num_prop="pagenumber"
num_of_pages_prop="numberofpages"
prop_value=""
win_id=""
close_all=0

grab_user() {
  if [ "$win_id" == "" ]; then
    setup_win_id
  fi
  if [ "$win_id" != "" ]; then
    wmctrl -i -a $win_id
  fi
  echo -n "> Awaiting: "
  read -n 1 input
  echo ""
}

get_property() {
  local pid=$1; shift
  local prop=$1
  prop_value=$(dbus-send \
    --dest=org.pwmt.zathura.PID-$pid --print-reply=literal \
    /org/pwmt/zathura \
    org.freedesktop.DBus.Properties.Get string:'org.pwmt.zathura' string:$prop)
  prop_value=$(echo $prop_value | awk '{print $3}')
}

go_to_page(){
  local pid=$1; shift
  local page=$1
  dbus-send \
    --type=method_call \
    --dest=org.pwmt.zathura.PID-$pid \
    /org/pwmt/zathura org.pwmt.zathura.GotoPage uint32:$page
}

setup_max_page() {
  local max=100
  for pid in ${zathura_pids[@]}; do
    get_property $pid $num_of_pages_prop
    max_page=$prop_value
    echo "> PID $pid has $max_page pages"
    if [[ $max_page -lt $max ]]; then
      max=$max_page
    fi
  done
  max_page=$(( $max -1 ))
}

setup_start_page() {
  local min_page=100
  for pid in ${zathura_pids[@]}; do
    get_property $pid $page_num_prop
    echo "> PID $pid on page $curr_page"
    if [[ $curr_page -lt $min_page ]]; then
      min_page=$curr_page
    fi
  done
  curr_page=$min_page
}

setup_win_id() {
  win_id=$(wmctrl -l | grep 'presenter' | cut -d ' ' -f1 | head -n 1 | tail -n 1)
}

work() {
  local direction=$1
  if [[ $direction -gt -2 && $direction -lt 2 ]]; then
    # up, down
    setup_start_page
    curr_page=$prop_value
    curr_page=$(( $curr_page + $direction ))
  elif [[ $direction -eq -2 ]]; then
    # go to start
    curr_page=0
  else
    # go to end
    curr_page=$max_page
  fi
  echo "> Go to page $curr_page"
  for pid in ${zathura_pids[@]}; do
    go_to_page $pid $curr_page
  done
}

print_help() {
  echo "commands:"
  echo "  j/J: go down"
  echo "  k/K: go up"
  echo "  g: go to first page"
  echo "  G: go to last page"
  echo "  q/Q: quit"
  echo "  x/X: quit and close pdf viewers"
}

if [[ "$#" -lt 2 ]]; then
  echo "Usage presenter.sh [<slides.pdf> | <slides_pid>], [<notes.pdf>, | <notes_pid>]"
  exit 0
fi

slides=$1; shift;
notes=$1; shift;

if [[ -f $slides ]]; then
  zathura $slides &
  slides_pid=$!
else
  slides_pid=$slides
fi

if [[ -f $notes ]]; then
  zathura $notes &
  notes_pid=$!
else
  notes_pid=$notes
fi

if hash wmctrl; then
  setup_win_id
  echo "Found presenter window id ${win_id}"
else
  echo "Install wmctrl to regain focus on page scroll"
fi

zathura_pids=("$slides_pid" "$notes_pid")

for pid in ${zathura_pids[@]}; do
  if [[ $(ps -e | cut -d ' ' -f 1 | grep "$pid" | wc -l) -eq 0 ]]; then
    echo "PID '$pid' not found, exit"
    exit 1
  fi
  echo "> Acquired pid $pid"
done

# give time to dbus to index everything
sleep 1s

setup_max_page
echo "> Maximum pages $max_page"

grab_user
while [[ $cont -eq 1 ]]; do
  dir=0
  case $input in
    [j,J]) dir=1 ;;
    [k,K]) dir=-1 ;;
    g) dir=-2 ;;
    G) dir=2 ;;
    [q,Q]) cont=0 ;;
    [x,X]) cont=0; close_all=1 ;;
    [h/H]) print_help ;&
    *) dir=0 ;;
  esac
  if [[ $cont -eq 1 ]]; then
    if [[ $dir -ne 0 ]]; then
      work $dir
    fi
    grab_user
  fi
  if [[ $close_all -eq 1 ]]; then
    echo "> Closing documents..."
    for pid in ${zathura_pids[@]}; do
      kill $pid
    done
  fi
done
echo "> Exit"
