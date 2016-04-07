require 'rest-client'

access_key = ENV['RANCHER_ACCESS_KEY']
secret_key = ENV['RANCHER_SECRET_KEY']
rancher_uri = URI(ENV['RANCHER_URL'])

# need error checking here
host_uuid = RestClient.get "http://rancher-metadata/2015-12-19/self/host/uuid"
puts "updating host with uuid: #{host_uuid}"
# host_uuid = "dc8d94fd-3c4a-4b3d-b285-59663cd8bf43"

result = RestClient.get "https://#{access_key}:#{secret_key}@#{rancher_uri.hostname}/v1/hosts?uuid=#{host_uuid}",
  {:accept => :json}
host_query_result = JSON.parse(result)
# need error checking here
host_id = host_query_result['data'].first['id']
puts "rancher id of host : #{host_id}"

# pull some ec2 info
ec2_hostname = RestClient.get "http://169.254.169.254/2014-11-05/meta-data/hostname"
ec2_instance_id = RestClient.get "http://169.254.169.254/2014-11-05/meta-data/instance-id"
ec2_public_hostname = RestClient.get "http://169.254.169.254/2014-11-05/meta-data/public-hostname"

result = RestClient.get "https://#{access_key}:#{secret_key}@#{rancher_uri.hostname}/v1/hosts/#{host_id}",
  {:accept => :json}
rancher_host_info = JSON.parse(result)
rancher_host_info['name'] = ec2_instance_id
rancher_host_info['hostname'] = ec2_hostname
rancher_host_info['description'] = "public hostname: #{ec2_public_hostname}"

result = RestClient.put "https://#{access_key}:#{secret_key}@#{rancher_uri.hostname}/v1/hosts/#{host_id}",
  rancher_host_info.to_json,
  :content_type => :json,
  :accept => :json

puts "result from rancher put:\n #{result}"