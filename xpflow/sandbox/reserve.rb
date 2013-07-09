# -*- coding: utf-8 -*-
#!/usr/bin/env xpflow
#

use :g5k
require '../test_framework/framework'

process :main do
  run :reserve_and_deploy, 2, '20m', 'nancy',
    'wheezy-x64-big-lehoo', '/home/dlehoczky/nodefile_uniq'
  #'squeeze-x64-nfsb', '/home/dlehoczky/nodefile_uniq'
  checkpoint :deployed

  x = run :broadcast, '/home/dlehoczky/NPB3.3/NPB3.3-MPI/bin/lu.A.8', '/tmp'

  run :disable_cores

  log "mpi experiment starting"
  mpi = run :mpirun, :path => '/tmp/lu.A.8', :n => 2,
    :arguments => '-mca btl ^openib --mca pml ob1 -machinefile /home/dlehoczky/nodefile_uniq'
  log "result:"
  log mpi
  #run :trace_gather, :n => 2
end

main :main
