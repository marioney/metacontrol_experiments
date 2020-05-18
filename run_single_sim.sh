 #!/bin/bash

## Define path for workspaces (needed to run reasoner and metacontrol_sim in different ws)
## You need to create a "config.sh file in the same folder defining your values for these variables"
source config.sh
export METACONTROL_WS_PATH
export REASONER_WS_PATH
export PYTHON3_VENV_PATH


## Define initial navigation profile 
# Possible values ("fast" "standard" "safe") 
#declare NavProfile="fast"
#declare NavProfile="safe"
declare NavProfile="standard"

## Define initial position
# Possible values (1, 2, 3)
declare init_position=1

## Define goal position
# Possible values (1, 2, 3)
declare goal_position=1

## Wheter or not to launch reconfiguration (true, false)
declare launch_reconfiguration=true

## Perturbations

## Add unkown obstacles 
# Possible values (0: no obstalces, 1, 2 3)
declare obstacles=3


wait_for_gzserver_to_end () {

	for t in $(seq 1 100)
	do
		if test -z "$(ps aux | grep gzserver | grep -v grep )"
		then
			echo "gzserver not running"
			break
		else
			echo "gzserver still running"
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


# Check that there are not running ros nodes
kill_running_ros_nodes
# If gazebo is running, it may take a while to end
wait_for_gzserver_to_end

# Get x and y initial position from yaml file - takes some creativity :)
declare init_pos_x=$(cat $METACONTROL_WS_PATH/src/metacontrol_experiments/yaml/initial_positions.yaml | grep S$init_position -A 5 | tail -n 1 | cut -c 10-)
declare init_pos_y=$(cat $METACONTROL_WS_PATH/src/metacontrol_experiments/yaml/initial_positions.yaml | grep S$init_position -A 6 | tail -n 1 | cut -c 10-)

cat $METACONTROL_WS_PATH/src/metacontrol_experiments/yaml/goal_positions.yaml | grep G$goal_position -A 12 | tail -n 12 > $METACONTROL_WS_PATH/src/metacontrol_sim/yaml/goal.yaml
echo "Goal position: $goal_position - Initial position  $init_position - Navigation profile: $nav_profile"

echo "Launch roscore"
gnome-terminal --window -- bash -c "source $METACONTROL_WS_PATH/devel/setup.bash; roscore; exit"
#Sleep Needed to allow other launchers to recognize the roscore
sleep 3
echo "Launching: MVP metacontrol world.launch"
gnome-terminal --window --maximize -- bash -c "source $METACONTROL_WS_PATH/devel/setup.bash;
roslaunch metacontrol_sim MVP_metacontrol_world.launch obstacles:=$nav_profile initial_pose_x:=$init_pos_x initial_pose_y:=$init_pos_y;
exit"
if [ "$launch_reconfiguration" = true ] ; then
	echo "Launching: mros reasoner"
	gnome-terminal --window -- bash -c "source $PYTHON3_VENV_PATH/venv3.6_ros/bin/activate;
	source $PYTHON3_VENV_PATH/devel/setup.bash;
	source $REASONER_WS_PATH/devel/setup.bash;
	roslaunch mros1_reasoner run.launch onto:=mvp.owl;
	exit"
fi

echo "Running log and stop simulation node"
bash -ic "source $METACONTROL_WS_PATH/devel/setup.bash;
roslaunch metacontrol_experiments stop_simulation.launch obstacles:=$obstacles goal_nr:=$goal_position;
exit "
echo "Simulation Finished!!"

# Check that there are not running ros nodes
kill_running_ros_nodes
# Wait for gazebo to end
wait_for_gzserver_to_end
