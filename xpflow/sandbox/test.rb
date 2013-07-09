#!/usr/bin/env xpflow
#

use :g5k
require 'libraries.rb'

activity :frontend do
  x = run 'g5k.bash_frontend', 'nancy' do
    cd '/home/dlehoczky/NPB3.3/NPB3.3-MPI'
    #append_line('asd',ls)
    ls
    #run("wc -l kk")
  end
  log x
end

activity :bash do |r|
  n = (run 'g5k.nodes', r).first
  log n
  x = run 'g5k.bash', n do
    cd '/home/dlehoczky/NPB3.3/NPB3.3-MPI'
    ls
  end
  log x
end

activity :build_string do |arr|
  s = ''
  arr.each { |token|
    s = s + token }
  s
end

activity :try_map do |map|
  begin
    raise ArgumentError, "kakafej vagy" unless map.has_key?("gh")
  g = map["gh"]
  log g
  b = map["tr"]
  log b
  rescue
    log "hah"
  end
end

process :main do
  map = { }
  map["tr"] = "haz"
  begin
    run :try_map, map
  rescue ArgumentError => e
    log "baywatch"
  end
  log "kakalin"
end

main :main
