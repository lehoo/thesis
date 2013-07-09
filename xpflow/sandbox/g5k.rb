#!/usr/bin/env xpflow
#
#  Runs some code on g5k
#

use :g5k

activity :runit do |r|
    run 'g5k.bash_frontend', 'rennes' do
        cd '~'
    end
    n = (run 'g5k.nodes', r).first
    x = run 'g5k.bash', n do
        hostname
    end
    log x
end

activity :show_auth do |r|
    n = (run 'g5k.nodes', r).first
    x = run 'g5k.bash', n do
        cat '~/.ssh/authorized_keys'
    end
    x.split("\n").each do |line|
        log "Key: #{line[0...50]}"
    end
end

process :test do
    run g5k.execute_frontend, 'nancy', 'date'
    r1 = run g5k.reserve_nodes, :nodes => 1, :site => 'nancy', :time => '5m'
    run :runit, r1
    run :show_auth, r1
    r2 = run g5k.reserve_nodes, :nodes => 1, :site => 'nancy', :time => '30m', :type => :deploy
    run g5k.deploy, r2, :env => 'squeeze-x64-nfs'
    run :runit, r2
    run :show_auth, r2
end

main do
    execute_from_argv :test
end
