require 'rest-client'
require_relative 'lib/rancher_base_url'

def get_rancher_host_id(name)
  result = RestClient.get "#{rancher_base_url}/hosts?name=#{name}",
    {:accept => :json}
  hosts_result = JSON.parse(result)
  # need error checking here

  hosts_result['data'].first['id']
end

def kill_rancher_host(host_id)
  # it is probably better if we check what state the host is in but it also seems fine
  # to just try to deactivate it
  result = RestClient.post "#{rancher_base_url}/hosts/#{host_id}?action=deactivate",
    {:accept => :json}

  # this responds with a 202 with information about the host
  # if the host is already deactivated a 422 is returned with
  # {"id":"...","type":"error","links":{},"actions":{},"status":422,
  #  "code":"ActionNotAvailable","message":null,"detail":null,"fieldName":"action"}

  result = RestClient.post "#{rancher_base_url}/hosts/#{host_id}?action=remove",
    {:accept => :json}

  # if the host is already removed then this returns a 422 like above
end

# currently this has to make two requests to find the rancher id.  If the id was saved locally somewhere
# then we could remove this requests
def kill_self
  ec2_instance_id = RestClient.get "http://169.254.169.254/2014-11-05/meta-data/instance-id"
  host_id = get_rancher_host_id(ec2_instance_id)
  kill_rancher_host host_id
end

# this is an nice way to test the methods above
# require 'irb'
# IRB.setup(nil)
# workspace = IRB::WorkSpace.new(binding)
# irb = IRB::Irb.new(workspace)
# IRB.conf[:MAIN_CONTEXT] = irb.context
# irb.eval_input

# now we need to wait for the kill signal
# ideally we'd figure out our information on startup so we wouldn't need to
# but the name probably won't be set yet in rancher so
Signal.trap("TERM") {
  puts "Removing rancher host..."
  kill_self
  puts "  done"
  exit
}

# this should sleep forever
sleep
