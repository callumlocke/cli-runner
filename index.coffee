CLIRunner = require './lib/cli-runner'

defaults = {
  verbose: true
}

module.exports = (app, args=[], options={}) ->
  new CLIRunner app, args, options
