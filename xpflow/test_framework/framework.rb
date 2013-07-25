# -*- coding: utf-8 -*-
#!/usr/bin/env xpflow
#

use :g5k
require '../test_framework/helper_library'

$engine.import_library(HelperLibrary.new, :lib)

process :init do
  run :lib.init
end

process :reserve_and_deploy do |n, t, site, image, nodefile|
  run :lib.init_ok
  run :lib.set_site, site
  log 'reserving...'
  r = run g5k.reserve_nodes, :nodes => n, :time => t,
    :site => site, :type => :deploy, :keep => true
  run :lib.set_job, r

  log "deploying..."
  run g5k.deploy, r, :env => image
  log "deployment complete"
  run :lib.set_image, image

  nodes = run :g5k.nodes, r
  run :lib.set_nodes, nodes

  run :create_or_replace_nodefile, nodefile, nodes
  run :lib.deployed
end

process :broadcast do |src, dst|
  site = (run :lib.get_site) + ""
  nodefile = (run :lib.get_nodefile)
  taktuk_str = (run :lib.build_string, [
                                       "taktuk -l root -f ",
                                       nodefile,
                                       " broadcast put { ",
                                       src,
                                       " } { ",
                                       dst,
                                       " }"
                                      ])
  x = run :g5k.execute_frontend, site, taktuk_str
  x
end

process :mpirun do |opts|
  run :lib.mpirun, opts
end

process :trace_gather do |opts|
  run :lib.trace_gather, opts
end

activity :create_or_replace_nodefile do |path, nodes|
  run 'lib.set_nodefile', path
  run 'lib.create_or_replace_file', path

  nodes.each { |node|
    run 'lib.append_line', path, node
  }
end

#activity to disable the cores on the nodes
#this has to be an activity, because if it would be a process,
#there would be problems with the proxy variables at the loop
activity :disable_cores do
  nodefile = (run 'lib.get_nodefile')

  #nodefile, which will contain the nodes that have more than one core enabled
  nodefile_working_copy = (run 'lib.build_string', [
                                                   nodefile,
                                                   "_tmp"
                                                  ])

  #taktuk -l root -f /home/dlehoczky/nodefile_uniq broadcast exec [ 'for i in /sys/devices/system/cpu/cpu[1-9]*/online; do echo 0 > "${i}" ; done' ]
  disable_cores_str = (run 'lib.build_string', [
                                               "taktuk -l root -f ",
                                               nodefile,
                                               ' broadcast exec [ \'for i in /sys/devices/system/cpu/cpu[1-9]*/online;',
                                               ' do echo 0 > "${i}" ; done\' ]'
                                              ])

  #taktuk -f ~/nodefile_uniq broadcast exec [ 'cat /proc/cpuinfo' ] | grep process | awk '{if($9>0) print $1}' | uniq | awk -F".fr-" '{print $1".fr"}'
  check_num_of_cores_str = (run 'lib.build_string', [
                                                    "taktuk -l root -f ",
                                                    nodefile_working_copy,
                                                    " broadcast exec [ 'cat /proc/cpuinfo' ]",
                                                    " | grep process | awk '{if($9>0) print $1}'",
                                                    " | uniq | awk -F\".fr-\" '{print $1\".fr\"}'"
                                                   ])

  #create the temporary nodefile
  run 'lib.cp', nodefile, nodefile_working_copy

  #loop until there are no more nodes with more than one cores enabled
  while not (run 'lib.is_file_empty', nodefile_working_copy)
  #while false
    run 'lib.execute_frontend', disable_cores_str

    nodes_with_too_many_cores = (run 'lib.execute_frontend', check_num_of_cores_str)
    run 'lib.put_content', nodefile_working_copy, nodes_with_too_many_cores
  end

  run 'lib.rm', nodefile_working_copy
end

process :finish do
  run :lib.finish
end
