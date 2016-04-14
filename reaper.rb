require 'rest-client'
require_relative 'lib/rancher_base_url'
require 'aws-sdk'

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

def current_reconnecting_hosts
  result = RestClient.get "#{rancher_base_url}/hosts?agentState=reconnecting",
    {:accept => :json}
  hosts_result = JSON.parse(result)
  hosts_result['data']
end

# need to set
# ENV['AWS_ACCESS_KEY_ID'] and ENV['AWS_SECRET_ACCESS_KEY']
# this AWS user needs to have at least access to action "ec2:DescribeInstanceStatus"
# and that action does not work with resource limitations so the resource needs to be "*"
def ec2_host_running?(instance_id)
  puts "Checking status of EC2 instance: #{instance_id}"
  ec2 = Aws::EC2::Client.new(
    region: "us-east-1"
  )

  begin
    status = ec2.describe_instance_status instance_ids: [instance_id]
    # if a host has been terminated recently ec2 will return an empty statuses array
    # if the host has been termnated a while ago then ec2 will raise IDNotFound exception
    return false if status.instance_statuses.empty?

    status.instance_statuses.first.instance_state.name == "running"
  rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
    false
  end
end

def reap
  current_reconnecting_hosts.each do |host|
    # the rancher host name should be the EC2 instance id
    name = host['name']
    if not ec2_host_running? name
      puts "Removing #{name} with rancher id #{host['id']}"
      kill_rancher_host host['id']
    end
  end
end

# this is an nice way to test the methods above
# require 'irb'
# IRB.setup(nil)
# workspace = IRB::WorkSpace.new(binding)
# irb = IRB::Irb.new(workspace)
# IRB.conf[:MAIN_CONTEXT] = irb.context
# irb.eval_input

while true
  reap
  sleep 60
end
