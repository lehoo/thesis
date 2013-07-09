#!/usr/bin/env xpflow
# encoding: utf-8

use :g5k

class StateError < StandardError
end

class HelperLibrary < XPFlow::ActivityLibrary

  activities :set_job, :get_job,
  :set_site, :get_site,
  :set_nodefile, :get_nodefile,
  :set_nodes,
  :deployed, :nodefile_created,
  :create_or_replace_file, :append_line,
  :execute_frontend,
  :cp, :rm, :put_content, :is_file_empty,
  :mpirun, :trace_gather,
  :checkpoint, :restore,
  :build_string


module States
  INIT = 0
  DEPLOYED = 1
  EXPERIMENT_RAN = 2
  TRACES_COLLECTED = 3
  TRACES_MERGED = 4
end

  def setup
    @job = 0
    @site = ''
    @nodefile = ''
    @nodes = []
    @head = 0
    @executable_dir = ''
    @state = States::INIT
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
  begin
    #raise ArgumentError, "Error: there aren't enough nodes to run the experiment!\nNumber of reserved nodes: #{nodes.length}\nNumber of nodes requested for the experiment: #{opts[:n]}" unless opts[:n] <= nodes.length
    #raise StateError.new("Reserved nodes are needed for running experiments!") unless @state >= States::DEPLOYED

    @head = @nodes.first
    mpirun_executable = "mpirun"
    if opts.has_key?(:mpirun)
      mpirun_executable = opts[:mpirun]
    end

    proxy.engine.log "nodefile: #{@nodefile}"
    j = @nodefile
    output = ''
    output = proxy.run 'g5k.bash', @head do
      #we want the traces to be generated in /tmp
      cd "/tmp"
      run("#{mpirun_executable} -machinefile #{j} #{opts[:arguments]} -np #{opts[:n]} #{opts[:path]}")
    end
    @state = States::EXPERIMENT_RAN
    return output
    rescue ArgumentError => e
      proxy.engine.log e.message
    rescue StateError => e
      proxy.engine.log e.message
  end
end

def trace_gather(opts)
  begin
    raise StateError.new("Experiments are needed to be run before gathering traces!") unless @state >= States::EXPERIMENT_RAN

    mpirun_executable = "mpirun"
    mpirun_executable = opts[:mpirun] unless not opts.has_key?(:mpirun)

    tracegather_executable = "trace_gather"
    tracegather_executable = opts[:tracegather] unless not opts.has_key?(:tracegather)

    arity = 1
    arity = opts[:arity] unless not opts.has_key?(:arity)

    output = ''
    output = proxy.run 'g5k.bash', @head do
      cd "/tmp"
      run("#{mpirun_executable} -machinefile #{@nodefile} -np #{opts[:n]} #{tracegather_executable} -a #{arity} -f 1 -m #{@nodefile}")
    end
    state = States::TRACES_COLLECTED
    return output

  rescue StateError => e
    proxy.engine.log e.message
  end
end

def merge_traces
  begin
    raise StandardError unless @state >= States::TRACES_COLLECTED
  rescue
    proxy.engine.log "Traces are needed to be gatheres before merging them!"
  end
end


#methods for checkpointing
  def checkpoint
    return {
      :job => @job,
      :site => @site,
      :nodefile => @nodefile,
      :nodes => @nodes,
      :head => @head,
      :executable_dir => @executable_dir,
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
    @state = state[:state]
  end


end
