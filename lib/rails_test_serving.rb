require 'pathname'
require 'thread'
require 'test/unit'
require 'drb/unix'
require 'stringio'
require 'benchmark'

module RailsTestServing
  class InvalidArgumentPattern < ArgumentError
  end
  class ServerUnavailable < StandardError
  end

  autoload :Bootstrap,  'rails_test_serving/bootstrap'
  autoload :Server,     'rails_test_serving/server'
  autoload :Client,     'rails_test_serving/client'
  autoload :Cleaner,    'rails_test_serving/cleaner'
  autoload :ConstantManagement, 'rails_test_serving/constant_management'
  autoload :Utilities,  'rails_test_serving/utilities'

  extend Bootstrap
end
