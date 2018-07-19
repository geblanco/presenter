#!/bin/bash

input=""
cont=1
curr_page=0
max_page=0
page_num_prop="pagenumber"
num_of_pages_prop="numberofpages"
prop_value=""

grab_user() {
  #clear
  echo -n "> Awaiting "
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
    curr_page=$max_page
  fi
  echo "> Go to page $curr_page"
  for pid in ${zathura_pids[@]}; do
    go_to_page $pid $curr_page
  done
}

if [[ "$#" -lt 2 ]]; then
  echo "Usage presenter.sh <slides.pdf> <notes.pdf>"
  exit 0
fi

slides=$1; shift;
notes=$1; shift;

zathura $slides &
slides_pid=$!
zathura $notes &
notes_pid=$!
zathura_pids=("$slides_pid" "$notes_pid")

for pid in ${zathura_pids[@]}; do
  echo "> Acquired pid $pid"
done

setup_max_page
echo "> Maximum pages $max_page"

grab_user
while [[ $cont -eq 1 ]]; do
  dir=0
  case $input in
    [j,J])
      # go down
      dir=1
      ;;
    [k,K])
      # go up
      dir=-1
      ;;
    g)
      # first page
      dir=-2
      ;;
    G)
      # last page
      dir=2
      ;;
    [q,Q])
      cont=0
      ;;
    *)
      dir=0
      ;;
  esac
  if [[ $cont -eq 1 ]]; then
    if [[ $dir -ne 0 ]]; then
      work $dir
    fi
    grab_user
  fi
done
