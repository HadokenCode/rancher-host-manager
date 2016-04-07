# helper file to make it easier to access an irb session and test things out
require "rest-client"

access_key = ENV['RANCHER_ACCESS_KEY']
secret_key = ENV['RANCHER_SECRET_KEY']
rancher_uri = URI(ENV['RANCHER_URL'])

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
