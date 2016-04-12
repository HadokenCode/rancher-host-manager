def get_env(name)
  if ENV[name].nil? || ENV[name].empty?
    raise "Need to set the environment variable: #{name}"
  end
  ENV[name]
end

def rancher_base_url
  rancher_url = URI(get_env('RANCHER_URL'))
  rancher_url.user = get_env('RANCHER_ACCESS_KEY')
  rancher_url.password = get_env('RANCHER_SECRET_KEY')
  rancher_url.path = "/v1"
  rancher_url.to_s
end
