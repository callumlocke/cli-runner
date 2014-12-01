{spawn} = require 'child_process'
{EventEmitter} = require 'events'
stripANSI = require 'strip-ansi'
chalk = require 'chalk'
async = require 'async'
_ = require 'lodash'

module.exports = class CLIRunner extends EventEmitter
  constructor: (@_app, @_args, @_options) ->
    EventEmitter.call this

    if !@_options.cwd? then @_options.cwd = process.cwd()

    @_queue = []
    @_stdout = []
    @_stderr = []

    # first queue item starts the app
    @_queue.push (done) =>
      console.log(
        chalk.cyan.bold.underline('\nCLIRunner') +
        '\n' + chalk.cyan('cwd: ') + @_options.cwd
        '\n' + chalk.cyan('command: $ ') + 
        @_app + ' ' + @_args.join(' ')
      )

      @_cp = spawn @_app, @_args, {
        cwd: @_options.cwd
      }

      @_cp.stdout.on 'data', (data) =>
        lines = data.toString().split('\n')
        lines.pop()
        for line in lines
          if 1|| @_options.verbose
            console.log chalk.blue('STDOUT -->'), chalk.gray(line)
          @_stdout.push line
          @emit 'stdoutline', line

      @_cp.stderr.on 'data', (data) =>
        lines = data.toString().split('\n')
        lines.pop()
        for line in lines
          if 1|| @_options.verbose
            console.log chalk.magenta('STDERR -->'), chalk.gray(line)
          @_stderr.push line
          @emit 'stderrline', line

      @_cp.on 'close', (code) =>
        @emit 'cpclose', code

      process.nextTick done


  awaitLine: (pattern, maxWait=2000) ->
    @_queue.push (done) =>
      # console.log 'AWAITING', pattern, maxWait
      doneOnce = _.once done
      lineListener = (line) =>
        matches = (
          (_.isRegExp(pattern) && pattern.test line) ||
          (pattern == line)
        )
        if matches
          @removeListener 'stdoutline', lineListener
          doneOnce()
      @on 'stdoutline', lineListener

      setTimeout =>
        @removeListener 'stdoutline', lineListener
        doneOnce new Error("did not receive line within #{maxWait}ms matching pattern: #{pattern.toString()}")
      , maxWait
    this

  do: (fn) ->
    @_queue.push fn
    this

  kill: (signal) ->
    @_queue.push (done) ->
      @_cp.kill(signal)
      process.nextTick done
    this

  start: (callback) ->
    endCode = null
    @on 'cpclose', (code) =>
      endCode = code
      callback.call this, null, endCode

    async.eachSeries @_queue, (fn, done) =>
      fn.call this, done
    , (err) ->
      # console.log 'ENDED'
      if err? then callback.call this, err
    this
