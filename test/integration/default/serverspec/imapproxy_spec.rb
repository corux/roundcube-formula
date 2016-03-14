require "serverspec"

set :backend, :exec

describe port("143") do
  it { should be_listening.on('127.0.0.1') }
end

describe service("imapproxy") do
  it { should be_enabled }
  it { should be_running }
end
