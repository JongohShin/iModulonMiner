#!/bin/bash

function usage {
    printf "\nUsage: run_ica.sh [ARGS] FILE\n"
    printf "\n"
    printf "Arguments\n"
    printf "  -i|--iter <n_iter>	      Number of random restarts (default: 100)\n"
    printf "  -t|--tolerance <tol>        Tolerance (default: 1e-6)\n"
    printf "  -n|--n-cores <n_cores>      Number of cores to use (default: 8)\n"
    printf "  -d|--max-dim <max_dim>      Maximum dimensionality for search (default: n_samples)\n"
    printf "  -s|--step-size <step_size>  Dimensionality step size\n"
    printf "  -o|--outdir <path>          Output directory for files (default: current directory)\n"
    printf "  -l|--logfile                Name of log file to use if verbose is off (default: ica.log)\n"
    printf "  -v|--verbose                Send output to stdout rather than writing to file\n"
    printf "  -h|--help                   Display help information\n"
    printf "\n"
    exit 1
}

# Handle arguments

OUTDIR=$(pwd)
TOL="1e-6"
ITER=100
STEP=0
MAXDIM=0
CORES=8
VERBOSE=false
LOGFILE="ica.log"

POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case $1 in
	-i|--iter)
        ITER=$2
	    shift; 
        shift;;
        -o|--out) 
            OUTDIR=$2
            shift; 
            shift;;
        -t|--tolerance)
            TOL=$2
            shift;
            shift;;
        -d|--max-dim)
            MAXDIM=$2
            shift;
            shift;;
        -s|--step-size)
            STEP=$2
            shift;
            shift;;
        -n|--n-cores)
            CORES=$2
            shift;
            shift;;
        -l|--logfile)
            LOGFILE=$2
            shift;
            shift;;
        -v|--verbose)
            VERBOSE=true
            shift;;
        -h|--help)
            usage;;
        --) 
            shift; 
            break;;
        *) 
            POSITIONAL+=("$1")
            shift;;
    esac
done

set -- "${POSITIONAL[@]}"

FILE="$1"

# Error checking

if [ "$FILE" = "" ]; then
    printf "Filename for expression data is required\n"
    usage
fi

if [ ! -f $FILE ]; then
    printf "ERROR: $FILE does not exist\n"
    exit 1
fi

# Get number of samples in file
n_samples=$(head -1 $FILE | sed 's/[^,]//g' | tr -d '\n' | wc -c)

if [ "$MAXDIM" -eq 0 ]; then
    MAXDIM=$n_samples
fi

if [ "$STEP" -eq 0 ]; then
    STEP=$((($n_samples / 250 + 1) * 10))
fi

# Run code

for dim in $(seq $STEP $STEP $MAXDIM); do

    if [ "$VERBOSE" = true ]; then
        mpiexec -n $CORES python -u random_restart_ica.py -f $FILE -i $ITER -o $OUTDIR -t $TOL -d $dim 2>&1
        mpiexec -n $CORES python -u compute_distance.py -i $ITER -o $OUTDIR 2>&1
        mpiexec -n $CORES python -u cluster_components.py -i $ITER -o $OUTDIR 2>&1

    else
        echo "" > $LOGFILE
        mpiexec -n $CORES python -u random_restart_ica.py -f $FILE -i $ITER -o $OUTDIR -t $TOL -d $dim >> $LOGFILE 2>&1
        mpiexec -n $CORES python -u compute_distance.py -i $ITER -o $OUTDIR >> $LOGFILE 2>&1
        mpiexec -n $CORES python -u cluster_components.py -i $ITER -o $OUTDIR >> $LOGFILE 2>&1
    fi
done
