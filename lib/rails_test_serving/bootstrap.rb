module RailsTestServing
  module Bootstrap
    SOCKET_PATH = ['tmp', 'sockets', 'test_server.sock']

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
        options[:test_helper] ||= "test_helper"
        options[:after_server_prepared] ||= lambda {}
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
end
