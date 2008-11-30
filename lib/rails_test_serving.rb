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
  
  SOCKET_PATH = ['tmp', 'sockets', 'test_server.sock']
  
  class << self
    def boot(argv=ARGV)
      if argv.delete('--serve')
        start_server
      elsif !argv.delete('--local')
        Client.run_tests
      end
    end
    
    def service_uri
      @service_uri ||= begin
        # Determine RAILS_ROOT
        root, max_depth = Pathname('.'), Pathname.pwd.expand_path.to_s.split(File::SEPARATOR).size
        until root.join('config', 'boot.rb').file?
          root = root.parent
          if root.to_s.split(File::SEPARATOR).size >= max_depth
            raise "RAILS_ROOT could not be determined"
          end
        end
        root = root.cleanpath
      
        # Adjust load path
        $: << root.to_s << root.join('test').to_s
      
        # Ensure socket directory exists
        path = root.join(*SOCKET_PATH)
        path.dirname.mkpath
      
        # URI
        "drbunix:#{path}"
      end
    end
    
    def options
      @options ||= begin
        options = $test_server_options || {}
        options[:reload] ||= []
        options
      end
    end
    
    def active?
      @active
    end
    
  private
  
    def start_server
      @active = true
      Server.start
    ensure
      @active = false
    end
  end
  
  autoload :Server,     'rails_test_serving/server'
  autoload :Client,     'rails_test_serving/client'
  autoload :Cleaner,    'rails_test_serving/cleaner'
  autoload :ConstantManagement, 'rails_test_serving/constant_management'
  autoload :Utilities,  'rails_test_serving/utilities'
end unless defined? RailsTestServing
