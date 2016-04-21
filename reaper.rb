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
  puts "  deactivating #{host_id}"
  begin
    result = RestClient.post "#{rancher_base_url}/hosts/#{host_id}?action=deactivate",
      {:accept => :json}
      puts "  deactived #{host_id}"
  rescue RestClient::UnprocessableEntity
    # this should only happen if the host was already deactivated
    puts "  unable to deactive #{host_id}"
  end

  # one time I tried this it failed to remove perhaps because there wasn't a long enough pause
  sleep 1

  # this responds with a 202 with information about the host
  # if the host is already deactivated a 422 is returned with
  # {"id":"...","type":"error","links":{},"actions":{},"status":422,
  #  "code":"ActionNotAvailable","message":null,"detail":null,"fieldName":"action"}

  puts "  removing #{host_id}"
  begin
    result = RestClient.post "#{rancher_base_url}/hosts/#{host_id}?action=remove",
      {:accept => :json}
    puts "  removed #{host_id}"
  rescue RestClient::UnprocessableEntity
    puts "  unable to remove #{host_id}"
  end
end

def current_reconnecting_hosts
  # occationally this seems to throw a RestClient::ServerBrokeConnection
  # we are relying on dockers auto restart to restart this script in that case
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

# we sleep 60 seconds first because we are using dockers auto restart option
# so if there is a network error we are going to see it in the log, the script will
# die and then docker will restart it. In that case we want don't want to make a request
# right away. If we do make a request right away we could get into a situation where where
# an error in rancher, AWS, or the script could cause many rapid requests.
while true
  sleep 60
  reap
end
