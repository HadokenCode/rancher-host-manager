# helper file to make it easier to access an irb session and test things out
require 'rest-client'
require_relative 'lib/rancher_base_url'

# hack to give IRB access to the local vars above:
# http://stackoverflow.com/a/34101140
# NOTE this has an issue where `exit` doesn't work
# so you need to use ctrl-c to exit
require 'irb'
IRB.setup(nil)
workspace = IRB::WorkSpace.new(binding)
irb = IRB::Irb.new(workspace)
IRB.conf[:MAIN_CONTEXT] = irb.context
irb.eval_input
