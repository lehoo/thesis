# -*- coding: utf-8 -*-
#!/usr/bin/env xpflow
#

use :g5k
require '../test_framework/framework'
process :main do
  run :init, :user => "dlehoczky"
#preparation and configuration
  run :reserve_and_deploy, 8, '120m', 'lille',
    'wheezy-x64-big-lehoo', '/home/dlehoczky/nodefile_uniq'
  checkpoint :deployed

  run :broadcast, '/home/dlehoczky/NPB3.3/NPB3.3-MPI/bin/lu.B.8', '/tmp'

  run :disable_cores
#the experiment
  log "mpi experiment starting"
  run :mpirun, :path => '/tmp/lu.B.8', :n => 8,
    :arguments => '-mca btl ^openib --mca pml ob1 --mca btl_tcp_if_include eth1',
    :mpirun_path => '/usr/local/openmpi-1.6.4-install/bin/mpirun',
    :outfile => '/tmp/mpi.out'
#post-processing
  run :trace_gather,
    :n => 8, :tracegather => '/usr/local/trace_gather/trace_gather',
    :arity => 4
  run :run_script,
    :command => 'tau_treemerge.pl'
  run :run_script,
    :command => '/usr/local/akypuera-install/bin/tau2paje',
    :args => 'tau.trc tau.edf', :outfile => 'lu.B.8.paje', :errorfile => 'tau2paje.error'
#metadata
  run :finish
end
main :main
