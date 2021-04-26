 #!/bin/bash

 usage()
 {
	echo "Usage: $0 -i <init_position: (1 / 2 / 3)>"
	echo "          -g <goal_position: (1 / 2 / 3)>"
	echo "          -n <nav_profile: ('fast' / 'standard' / 'safe' or fX_vX_rX)>"
	echo "          -r <reconfiguration: (true / false)>"
	echo "          -o <obstacles: (0 / 1 / 2 / 3)>"
	echo "          -p <increase_power: (0/1.1/1.2/1.3)>"
	echo "          -b <record rosbags: ('true' / 'false')>"
	echo "          -e <nfr energy threshold : ([0 - 1])>"
	echo "          -s <nfr safety threshold : ([0 - 1])>"
	echo "          -l <log frequency : [0 -10]) - If 0, no logs will be recorded>"
	echo "          -c <close reasoner terminal : ('true' / 'false')>"
	echo "          -v <Run RVIZ : ('true' / 'false')>"
	echo "          -k <laser error component : ('true' / 'false')>"

	exit 1
 }

####
#  Default values, set if no parameters are given
####

## Define initial navigation profile
# Possible values ("fast" "standard" "safe")
# also any of the fx_vX_rX metacontrol configurations
#declare nav_profile="fast"
#declare nav_profile="safe"
declare nav_profile="f3_v3_r1"

## Define initial position
# Possible values (1, 2, 3)
declare init_position="1"

## Define goal position
# Possible values (1, 2, 3)
declare goal_position="1"

## Wheter or not to launch reconfiguration (true, false)
declare launch_reconfiguration="true"

## nfr energy threshold ([0 - 1])
declare nfr_energy="0.6"

## nfr safety threshold ([0 - 1])
declare nfr_safety="0.65"

## Perturbations

## Add unkown obstacles
# Possible values (0: no obstalces, 1, 2 3)
declare obstacles="2"

## Modify power consumpton
## Changes when the euclidean distance to the goal is 0.6 of the initial one
# Possible values (0: no increase. Any value larger than 0, will be the increase power factor)
declare increase_power="1.5"
###

## Modify log frequency
## Frequency at wich log files are stored
# Possible values (0: no logs. Any value larger than 0, will be the log frequency)
declare log_frequency="2.5"
###

### Whether or not to close the reasoner terminal
declare close_reasoner_terminal="true"

### Whether or not to launch RVIZ
declare rviz="false"

### Whether or not to launch RVIZ
declare laser_error="false"

if [ "$1" == "-h" ]
then
	usage
    exit 0
fi

while getopts ":i:g:n:r:o:p:e:s:c:v:l:k:" opt; do
  case $opt in
    i) init_position="$OPTARG"
    ;;
    g) goal_position="$OPTARG"
    ;;
    n) nav_profile="$OPTARG"
    ;;
    r) launch_reconfiguration="$OPTARG"
    ;;
    o) obstacles="$OPTARG"
    ;;
    p) increase_power="$OPTARG"
    ;;
    e) nfr_energy="$OPTARG"
    ;;
    s) nfr_safety="$OPTARG"
	;;
	l) log_frequency="$OPTARG"
    ;;
	c) close_reasoner_terminal="$OPTARG"
    ;;
	v) rviz="$OPTARG"
    ;;
	k) laser_error="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    	usage
    ;;
  esac
done

#printf "Argument init_position is %s\n" "$init_position"
#printf "Argument goal_position is %s\n" "$goal_position"
#printf "Argument nav_profile is %s\n" "$nav_profile"
#printf "Argument launch reconfiguration is %s\n" "$launch_reconfiguration"
#printf "Argument obstacles is %s\n" "$obstacles"
#printf "Argument increase power is %s\n" "$increase_power"

wait_for_gzserver_to_end () {

	for t in $(seq 1 100)
	do
		if test -z "$(ps aux | grep gzserver | grep -v grep )"
		then
			# echo " -- gzserver not running"
			break
		else
			echo " -- gzserver still running"
		fi
		sleep 1
	done
}

kill_running_ros_nodes () {
	# Kill all ros nodes that may be running
	for i in $(ps aux | grep ros | grep -v grep | awk '{print $2}')
	do
		echo "kill -2 $i"
		kill -2 $i;
	done
	sleep 1
}


echo "Make sure there is no other gazebo instances or ROS nodes running:"

# Check that there are not running ros nodes
kill_running_ros_nodes
# If gazebo is running, it may take a while to end
wait_for_gzserver_to_end

# Get x and y initial position from yaml file - takes some creativity :)
declare init_pos_x=$(cat $(rospack find metacontrol_experiments)/yaml/initial_positions.yaml | grep -w S$init_position -A 5 | tail -n 1 | cut -c 10-)
declare init_pos_y=$(cat $(rospack find metacontrol_experiments)/yaml/initial_positions.yaml | grep -w S$init_position -A 6 | tail -n 1 | cut -c 10-)

tmpfile=$(mktemp /tmp/current_goal_yaml.XXXXX)

#cat $(rospack find metacontrol_experiments)/yaml/goal_positions.yaml | grep G$goal_position -A 12 | tail -n 12 > $(rospack find metacontrol_sim)/yaml/goal.yaml
cat $(rospack find metacontrol_experiments)/yaml/goal_positions.yaml | grep -w G$goal_position -A 12 | tail -n 12 > $tmpfile

echo ""
echo "Start a new simulation - Goal position: $goal_position - Initial position  $init_position - Navigation profile: $nav_profile"
echo ""
echo "Launch roscore"

gnome-terminal --window --geometry=80x24+10+10 -- bash -c "roscore; exit"
#Sleep Needed to allow other launchers to recognize the roscore
sleep 3
echo "Launching: MVP metacontrol world.launch"
gnome-terminal --window --geometry=80x24+10+10 -- bash -c "roslaunch \
                                                           metacontrol_sim MVP_metacontrol_world.launch \
														   nav_profile:=$nav_profile \
														   current_goal_file:=$tmpfile \
														   initial_pose_x:=$init_pos_x \
														   initial_pose_y:=$init_pos_y;
exit"
if [ "$launch_reconfiguration" = true ] ; then
	echo "Launching: mros reasoner"
	gnome-terminal --window --geometry=80x24+10+10 -- bash -c "roslaunch \
	                                                           mros1_reasoner run.launch \
															   desired_configuration:=$nav_profile \
															   desired_configuration:=$nav_profile \
															   nfr_safety:=$nfr_safety \
															   nfr_energy:=$nfr_energy;
	echo 'mros reasoner finished';
	if [ '$close_reasoner_terminal' = false ] ; then read -rsn 1 -p 'Press any key to close this terminal...' echo; fi
	exit"
fi

echo "Running log and stop simulation node"
bash -ic "roslaunch metacontrol_experiments stop_simulation.launch \
		  store_data_freq:=$log_frequency \
		  obstacles:=$obstacles \
		  goal_nr:=$goal_position \
		  increase_power:=$increase_power \
		  record_bags:=$record_rosbags \
		  send_laser_error:=$laser_error \
		  nfr_safety:=$nfr_safety \
		  nfr_energy:=$nfr_energy \
		  nav_profile:=$nav_profile;
exit "
echo "Simulation Finished!!"

# Delete temporary yaml goal file
rm "$tmpfile"

# Check that there are not running ros nodes
kill_running_ros_nodes
# Wait for gazebo to end
# wait_for_gzserver_to_end
