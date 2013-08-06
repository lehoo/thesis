# -*- coding: utf-8 -*-
#!/usr/bin/env xpflow
#

use :g5k
require '../test_framework/framework'

process :main do
  run :init

#preparation and configuration
  run :reserve_and_deploy, 2, '120m', 'lille',
    'wheezy-x64-big-lehoo', '/home/dlehoczky/nodefile_uniq'
  checkpoint :deployed

  run :broadcast, '/home/dlehoczky/NPB3.3/NPB3.3-MPI/bin/lu.A.2', '/tmp'

  run :disable_cores

#the experiment
  log "mpi experiment starting"
  run :mpirun, :path => '/tmp/lu.A.2', :n => 2,
    :arguments => '-mca btl ^openib --mca pml ob1 --mca btl_tcp_if_include eth1',
    :mpirun_path => '/usr/local/openmpi-1.6.4-install/bin/mpirun',
    :outfile => '/tmp/mpi.out'

#post-processing
  run :trace_gather,
    :n => 2, :tracegather => '/usr/local/trace_gather/trace_gather'
  run :run_script,
    :command => 'tau_treemerge.pl'
  run :run_script,
    :command => '/usr/local/akypuera-install/bin/tau2paje',
    :args => 'tau.trc tau.edf',
    :outfile => 'lu.A.2.paje',
    :errorfile => '/dev/null'

#metadata
  run :finish
end

main :main
