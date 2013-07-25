# -*- coding: utf-8 -*-
#!/usr/bin/env xpflow
#

use :g5k
require '../test_framework/framework'

process :main do
  run :init
  run :reserve_and_deploy, 2, '30m', 'lille',
    'wheezy-x64-big-lehoo', '/home/dlehoczky/nodefile_uniq'
  checkpoint :deployed

  run :broadcast, '/home/dlehoczky/NPB3.3/NPB3.3-MPI/bin/lu.A.2', '/tmp'

  run :disable_cores

  log "mpi experiment starting"
  mpi = run :mpirun, :path => '/tmp/lu.A.2', :n => 2,
    :arguments => '-mca btl ^openib --mca pml ob1 --mca btl_tcp_if_include eth0',
    :mpirun_path => '/usr/local/openmpi-1.6.4-install/bin/mpirun'
  log "result:"
  log mpi

  run :trace_gather, :arguments => '-mca btl ^openib --mca pml ob1 --mca btl_tcp_if_include eth0',
    :n => 2, :tracegather => '/usr/local/trace_gather/trace_gather'
  log "trace_gather: #{tg}"
  run :finish
end

main :main
