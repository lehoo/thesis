# -*- coding: utf-8 -*-
#!/usr/bin/env xpflow
# encoding: utf-8

use :g5k

class StateError < StandardError
end

class HelperLibrary < XPFlow::ActivityLibrary

  activities :init, :init_ok,
  :set_job, :get_job,
  :set_site, :get_site,
  :set_nodefile, :get_nodefile,
  :set_nodes,
  :set_image,
  :set_benchmark,
  :deployed, :nodefile_created,
  :create_or_replace_file, :append_line,
  :execute_frontend,
  :execute_head,
  :cp, :rm, :put_content, :is_file_empty,
  :mpirun, :trace_gather,
  :checkpoint, :restore,
  :finish,
  :build_string


module States
  BEFORE_INIT = 0
  INIT = 1
  DEPLOYED = 2
  EXPERIMENT_RAN = 3
  TRACES_COLLECTED = 4
  TRACES_MERGED = 5
end

  def init
    @job = 0
    @site = ''
    @nodefile = ''
    @nodes = []
    @head = 0
    @executable_dir = ''
    @state = States::INIT

    #save the date and the start time for the experiment
    @date = DateTime.now
    @starttime = Time.now
    #we have a part time variable to store time elapsed when checkpointing
    @parttime = 0
  end

  def init_ok
    raise StateError, "Experiment not initialized! Make sure that function \'init\' is called at the start of the experiment." unless @state >= States::INIT
  end

  def set_job(value)
    @job = value
  end

  def get_job()
    return @job
  end

  def set_site(value)
    @site = value
  end

  def get_site()
    return @site
  end

  def set_nodefile(value)
    @nodefile = value
  end

  def get_nodefile()
    return @nodefile
  end

  def set_nodes(value)
    @nodes = value
  end

  def set_image(value)
    @image = value
  end

  def set_benchmark(value)
    @benchmark = value
  end

  def deployed()
    @state = States::DEPLOYED
  end

#method as a workaround to the proxy variables problem
  def build_string(arr)
    s = ''
    arr.each { |token|
      s = s + token }
    return s
  end

def create_or_replace_file(path)
  proxy.run 'g5k.bash_frontend', @site do
    run("cat /dev/null > #{path}")
  end
end

def append_line(path, line)
  proxy.run 'g5k.bash_frontend', @site do
    append_line(path, line)
  end
end

def execute_frontend(cmd)
  proxy.run 'g5k.execute_frontend', @site, cmd
end

def execute_head(opts)
  begin
    raise ArgumentError, "Error: mandatory argument(s) missing!\nmandatory argument:\n - :command (name of the command to run)" unless opts.has_key?(:command)

    dir = "/tmp"
    dir = opts[:dir] unless not opts.has_key?(:dir)

    outfile = 'out'
    outfile = opts[:outfile] unless not opts.has_key?(:outfile)

    errorfile = 'err'
    errorfile = opts[:errorfile] unless not opts.has_key?(:errorfile)

    cmd = "#{opts[:command]} #{opts[:args]} 1>#{outfile} 2>#{errorfile}"
    proxy.log "executing command on head node: #{cmd}"

    output = proxy.run 'g5k.bash', @head do
      cd "#{dir}"
      run(cmd)
    end

  rescue StateError => e
    proxy.engine.log e.message
  end
end

def cp(src, dst)
  proxy.run 'g5k.bash_frontend', @site do
    run("cp #{src} #{dst}")
  end
end

def rm(path)
  proxy.run 'g5k.bash_frontend', @site do
    run("rm #{path}")
  end
end

def put_content(path, content)
  proxy.run 'g5k.bash_frontend', @site do
    run("echo #{content} >#{path}")
  end
end

def is_file_empty(path)
  contents = proxy.run 'g5k.bash_frontend', @site do
    cat path
  end
  return contents.strip.empty?
end

def mpirun(opts)
  output = ""
  begin
    raise ArgumentError, "Error: mandatory argument(s) missing!\nmandatory arguments:\n - :path (path to benchmark)\n - :n (number of nodes to use)" unless (opts.has_key?(:path) && opts.has_key?(:n))
    raise ArgumentError, "Error: there aren't enough nodes to run the experiment!\nNumber of reserved nodes: #{@nodes.length}\nNumber of nodes requested for the experiment: #{opts[:n]}" unless (opts[:n] <= @nodes.length)
    raise StateError, "Reserved nodes are needed for running experiments!" unless @state >= States::DEPLOYED

    set_benchmark(opts[:path])
    @head = @nodes.first
    proxy.log "The head node is: #{@head}"
    @mpirun_executable = "mpirun"
    @mpirun_executable = opts[:mpirun_path] unless not opts.has_key?(:mpirun_path)

    dir = "/tmp"
    dir = opts[:dir] unless not opts.has_key?(:dir)

    outfile = '/tmp/#{opts[:path]}.out'
    outfile = opts[:outfile] unless not opts.has_key?(:outfile)

    proxy.run 'g5k.dist_keys', @head, @nodes.tail

    cmd = "#{@mpirun_executable} -machinefile #{@nodefile} #{opts[:args]} -np #{opts[:n]} #{opts[:path]} 1>#{outfile} 2>mpi.error"
    proxy.log "Starting MPI: #{cmd}"

    output = proxy.run 'g5k.bash', @head do
      #we want the traces to be generated in /tmp
      cd dir
      run(cmd)
    end
    @state = States::EXPERIMENT_RAN

    rescue ArgumentError => e
      proxy.engine.log e.message

    rescue StateError => e
      proxy.engine.log e.message
  end
  return output
end

def trace_gather(opts)
  begin
    raise ArgumentError, "Error: mandatory argument(s) missing!\nmandatory argument:\n - :n (number of nodes to gather traces from)" unless opts.has_key?(:n)

    raise StateError, "Experiments are needed to be run before gathering traces!" unless @state >= States::EXPERIMENT_RAN

    #mpirun_executable = "mpirun"
    @mpirun_executable = opts[:mpirun_path] unless not opts.has_key?(:mpirun_path)

    tracegather_executable = "trace_gather"
    tracegather_executable = opts[:tracegather] unless not opts.has_key?(:tracegather)

    dir = "/tmp"
    dir = opts[:dir] unless not opts.has_key?(:dir)

    #we generate ssh keys on the nodes for trace_gather to work
    @nodes.each { |node|
      proxy.run 'g5k.dist_keys', node, [@head]
    }

    arity = 4
    arity = opts[:arity] unless not opts.has_key?(:arity)
    cmd = "#{@mpirun_executable} -machinefile #{@nodefile} #{opts[:args]} -np #{opts[:n]} #{tracegather_executable} -a #{arity} -f 1 -m #{@nodefile} 2>tracegather.error"
    proxy.log "running trace_gather: #{cmd}"

    output = ''
    output = proxy.run 'g5k.bash', @head do
      cd dir
      run(cmd)
    end
    state = States::TRACES_COLLECTED
    return output

  rescue StateError => e
    proxy.engine.log e.message
  end
end

#methods for checkpointing
  def checkpoint
    @parttime = Time.now - @starttime + @parttime
    return {
      :job => @job,
      :site => @site,
      :nodefile => @nodefile,
      :nodes => @nodes,
      :head => @head,
      :executable_dir => @executable_dir,
      #:date => @date,
      #:starttime => @starttime,
      :image => @image,
      :benchmark => @benchmark,
      :parttime => @parttime,
      :state => @state
    }
  end

  def restore(state)
    @job = state[:job]
    @site = state[:site]
    @nodefile = state[:nodefile]
    @nodes = state[:nodes]
    @head = state[:head]
    @executable_dir = state[:executable_dir]
    @date = DateTime.now
    @starttime = Time.now
    @image = state[:image]
    @benchmark = state[:benchmark]
    @parttime = state[:parttime]
    @state = state[:state]
  end

#method to be called when finishing the experiment
  def finish
    time_after_cp = Time.now - @starttime
    total_time = time_after_cp + @parttime
    #nodes = proxy.run 'g5k.bash_frontend', @site do
    #  run("cat #{@nodefile}")
    #end

    print "-----Experiment metadata-----\n"
    print "Date: #{@date}\n"
    print "Benchmark run: #{@benchmark}\n"
    print "OS image used: #{@image}\n"

    if @parttime > 0
      print "Time elapsed before checkpoint: #{@parttime}s\n"
      print "Time elapsed after checkpoint: #{time_after_cp}s\n"
      print "Total elapsed time: #{total_time}s\n"
    else
      print "Elapsed time: #{total_time}s\n"
    end

    print "Nodes used: #{@nodes}\n"
  end

end
