require 'rubygems'
require 'bundler/setup'

require 'mongoid'
require 'mongoid/audit_log'

require 'rspec'

Mongoid.configure do |config|
  config.connect_to('mongoid_audit_log_test')
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.after(:each) { Mongoid.purge! }
end
