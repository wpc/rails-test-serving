module RailsTestServing
  
  class Server
    GUARD = Mutex.new
    PREPARATION_GUARD = Mutex.new

    def self.start
      server = Server.new(RailsTestServing.options[:reloading_mode])
      DRb.start_service(RailsTestServing.service_uri, server)
      Thread.new do 
        server.prepare
        RailsTestServing.options[:after_server_prepared].call
      end
      DRb.thread.join
    end

    include Utilities
    
    def initialize(reloading_mode)
      @reloading_mode = reloading_mode
    end

    def run(file, argv)
      GUARD.synchronize do
        prepare
        perform_run(file, argv)
      end
    end
  
    def prepare
      PREPARATION_GUARD.synchronize do
        @prepared ||= begin
          ENV['RAILS_ENV'] = 'test'
          log "** Test server starting [##{$$}]..." do
            @reloading_mode.set_dependency_tracking
            start_cleaner
            load_framework
          end
          install_signal_traps
          true
        end
      end
    end
    
  private

    def start_cleaner
      @cleaner = Cleaner.new(@reloading_mode)
    end

    def load_framework
      Client.disable do
        $: << 'test'
        require RailsTestServing.options[:test_helper]
      end
    end

    def install_signal_traps
      log " - CTRL+C: Stop the server\n"
      trap(:INT) do
        GUARD.synchronize do
          log "** Stopping the server..." do
            Test::Unit.run = true
            DRb.thread.raise Interrupt, "stop"
          end
        end
      end

      log " - CTRL+Z: Reset database column information cache\n"
      trap(:TSTP) do
        GUARD.synchronize do
          log "** Resetting database column information cache..." do
            ActiveRecord::Base.instance_eval { subclasses }.each { |c| c.reset_column_information }
          end
        end
      end

      log " - CTRL+`: Reset lazy-loaded constants\n"
      trap(:QUIT) do
        GUARD.synchronize do
          log "** Resetting lazy-loaded constants..." do
            (defined?(ActiveSupport::Dependencies) ? ActiveSupport::Dependencies : Dependencies).clear
          end
        end
      end
    end

    def perform_run(file, argv)
      sanitize_arguments!(file, argv)
      log ">> " + [shorten_path(file), *argv].join(' ') do
        capture_test_result(file, argv)
      end
    end

    def sanitize_arguments!(file, argv)
      if file =~ /^-/
        # No file was specified for loading, only options. It's the case with
        # Autotest.
        raise InvalidArgumentPattern
      end

      # Filter out the junk that TextMate seems to inject into ARGV when running
      # focused tests.
      while a = find_index_by_pattern(argv, /^\[/) and z = find_index_by_pattern(argv[a..-1], /\]$/)
        argv[a..a+z] = []
      end
    end

    def capture_test_result(file, argv)
      result = []
      @cleaner.clean_up_around do
        result << capture_standard_stream('err') do
          result << capture_standard_stream('out') do
            result << capture_testrunner_result do
              fix_objectspace_collector do
                Client.disable { load(file) }
                Test::Unit::AutoRunner.run(false, nil, argv)
              end
            end
          end
        end
      end
      result.reverse.join
    end
  end
end
