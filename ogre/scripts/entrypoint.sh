#!/usr/bin/env bash

# Enter posix mode for bash
set -o posix
set -e

MACHINEFILE=/tmp/machine
COUNT=0
EXECUTABLE=""

# generate mpi compute node list from *_SERVICE_NAME varibale
function populate_machine() {
   if [ -f ${MACHINEFILE} ]; then
	rm ${MACHINEFILE}
   fi

   for var in `( set -o posix ; set ) | grep _SERVICE_NAME`; do
      NAME=${var%"="*}
      VALUE=${var#*"="}
      echo ${VALUE}.service.consul >> ${MACHINEFILE}
      COUNT=`expr $COUNT + 1`	
   done

   echo ${SERVICE_NAME}.service.consul >> ${MACHINEFILE}
   COUNT=`expr $COUNT + 1`	
}

# copy mpi executable to other machines
function scp_to_machines() {
  SERVER_LIST=$(cat ${MACHINEFILE})
  for h in $SERVER_LIST; do
    echo "scp $EXECUTABLE to $h"
    scp $EXECUTABLE root@$h:${EXECUTABLE}
  done
}


# mpi head has to prepare machine list file, and copy executable 
# file to other machines
if [ "$1" == "head" ]; then
  if [ $# != 3 ]; then
    exit 1
  fi
  /etc/init.d/ssh restart
  EXECUTABLE=$2
  make -f $3
  populate_machine
  scp_to_machines
fi

if [ "$1" == "head" ]; then
   # mpi head run mpi program
   mpiexec -f ${MACHINEFILE} -n ${COUNT} ${EXECUTABLE}
else
  # mpi compute node start and wait ssh connection from head
  echo "start sshd"
  /usr/sbin/sshd -D
fi
