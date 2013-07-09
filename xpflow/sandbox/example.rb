# -*- coding: undecided -*-
#!/usr/bin/env xpflow
# encoding: utf-8

activity :one do
    sleep 1
    log 'one'
    `uname -n -s`.strip
end

activity :two do
    sleep 1
    log 'two'
    `date`.strip
end

activity :three do
    [ 3.14, 2.71 ]
end

activity :a do |uname|
    sleep 1
    log "uname = #{uname}"
end

activity :b do |x, y|
    log "x, y = #{x}; #{y}"
end

activity :show do |x|
    log "Number #{x}"
end

activity :last do
    log "Iha"
    'ZZZzzz'
end

lib = XPFlow::Library.new

lib.activity :blah do
    log 'Try?'
    g = rand
    log g
    if g < 0.5
      'abcdefgh'
    else
      'tgrw'
    end
end

$engine.import_library(lib, :library)

process :entry do
    v = value 42
    uname = run :one
    date = run :two
    thelist = run :three
    checkpoint :the_name
    parallel do
        sequence do
            run :a, uname
            run :b, uname
        end
        run :b, uname, date
    end
    foreach thelist do |x|
        log 'bah'
    end
    forall thelist do |x|
        run :show, x
    end
    on (thelist == [ 3.14, 2.71 ]) do
        log 'ok'
    end
    switch do
        on(v == 42) { log 'yes' }
        on(v == 2) { log 'no' }
        default { log 'another' }
    end
    switch(v) do
        on(5) { log 'ha!' }
        default { log 'o!' }
    end
    multi do
        on(v >= 42) { log '>= 42', { } }
        on(v >= 43) { log '>= 43' }
        on(v * 2 < 85) { log '< 42.5' }
        default { log 'jej' }
    end
    z = run :last
    log z
    run :else, z
    log( code { rand })
    parallel :retry => 10 do
        bl = run :library.blah
        log bl
    end
end

process :else do |x|
    log "Bon, ba! Let's go ... "
    log x
end

main do
    execute_from_argv :entry
end

