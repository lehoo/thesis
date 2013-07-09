#!/usr/bin/env xpflow
# encoding: utf-8

class A < XPFlow::ActivityLibrary

module State
  HELO = 1
  BELO = 2
end

    # this has to be explicitly given
    activities :set_abc, :get_abc, :log_state, :trigger_state

  #attr_accessor :abc

    def setup
        # this is called by XPFlow, but it is
        # a classic class by far
        @abc = ''
        @data = { }
      @state = State::HELO
    end

    def set_abc(value)
      @abc = value
    end

    def get_abc
      return @abc
    end

    def trigger_state
      @state = State::BELO
    end

    def log_state()
      proxy.engine.log "state: #{@state}"
    end
end

# TODO: this is slightly tricky, I should
# provide better way to import stuff
# I think I should give better syntax for library defition as well

$engine.inject_library(A.new, "__alib__")
$engine.import_library(A.new, :alib)

# now the process:
#  * notice that injected and imported libraries are separate
#  * notice how the injected library "integrates" with syntax
#  * this is how almost *all* builtin features are implemented

process :example do
    run :alib.log_state()
    run :alib.trigger_state
    run :alib.log_state()
end

main do
    execute_from_argv :example
end
