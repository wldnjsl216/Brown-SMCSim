#!/bin/bash
if ! [ -z $1 ] && ( [ $1 == "7" ] || [ $1 == "8" ] ); then echo "Arch: ARM$1"; else echo "First argument must be architecture: 7 or 8 (ARM7 or ARM8)"; exit; fi

GEM5_STATISTICS=(
"sim_ticks.pim"
"sim_ticks.host"
)

VALUES0=( "1.0" ) # "2.0" "4.0" "8.0" )

for V0 in ${VALUES0[*]}
do
	source UTILS/default_params.sh
	create_scenario "$0/$*" "$V0" "ARMv$1 + HMC2011 + Linux (VExpress_EMM) + PIM(ARMv7)"
	
	####################################
	load_model memory/hmc_2011.sh
	load_model system/gem5_fullsystem_arm$1.sh
	load_model system/gem5_pim.sh
	load_model gem5_perf_sim.sh				# Fast simulation without debugging
	
    export OFFLOADED_KERNEL_NAME=tree_search    # Kernel name to offload (Look in SMC/SW/PIM/kernels)
    export OFFLOADED_KERNEL_SUBNAME=dma
	export PIM_CLOCK_FREQUENCY_GHz=$V0
	#####################
	#####################
	export OFFLOADED_TREE_HEIGHT=16				# Height of the balanced binary search tree
	export OFFLOADED_NUM_OPERATIONS=1000		# Number of operations to perform on the tree (e.g. number of searches)
	#####################
	#####################
	
# export GEM5_DEBUGFLAGS="Fetch,Decode,ExecAll,Registers"
# # 	export HAVE_L1_CACHES=FALSE
# # 	export HAVE_L2_CACHES=FALSE
# 	export DRAM_PAGE_POLICY="OPEN";		# "OPEN", "CLOSED"
# 	export DRAM_tRAS="1"
# 	export GEM5_ENABLE_COMM_MONITORS=TRUE

	source ./smc.sh -u $*	# Update these variables in the simulation environment
	load_model gem5_automated_sim.sh hetero		# Automated simulation
	
	####################################

	print_msg "Build and copy the required files to the extra image ..."

	#*******
	clonedir $PIM_SW_DIR/resident
	cp $HOST_SW_DIR/app/offload_tree/defs.hh .
	run ./build.sh  $1   # Build the main resident code
	run ./build.sh $1 "${OFFLOADED_KERNEL_NAME}" # Build a specific kernel code (name without suffix)
	returntopwd
	#*******
	clonedir $HOST_SW_DIR/driver
	cp ../resident/definitions.h .
	run ./build.sh
	returntopwd
	#*******
	clonedir $HOST_SW_DIR/api
	cp ../resident/definitions.h .
	cp ../driver/defs.h .
	run ./build.sh
	returntopwd
	#*******
	clonedir $HOST_SW_DIR/app/offload_tree
	cp ../api/pim_api.a ./libpimapi.a
	cp ../api/*.hh .
	cp $HOST_SW_DIR/app/app_utils.hh .
	run ./build.sh
	returntopwd
	#*******

	cd $SCENARIO_CASE_DIR

	echo -e "
	echo; echo \">>>> Install the driver\";
	./ins.sh
	echo; echo \">>>> Run the application and offload the kernel ...\";
	./main
	" > ./do
	chmod +x ./do


	copy_to_extra_image  driver/pim.ko driver/ins.sh ./do offload_tree/main resident/${OFFLOADED_KERNEL_NAME}.hex 
	returntopwd
	
	####################################

	source ./smc.sh $*
done
	
finalize_gem5_simulation
# plot_bar_chart "sim_ticks.pim" 0 "(ps) [golden model]" #--no-output
# plot_bar_chart "sim_ticks.host" 0 "(ps) [pim offload]" #--no-output
print_msg "Done!"




