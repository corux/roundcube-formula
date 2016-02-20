require "serverspec"

set :backend, :exec

describe port("80") do
  it { should be_listening }
end

describe command("curl -L localhost/roundcube") do
  its(:stdout) { should match /Roundcube Webmail/ }
end
