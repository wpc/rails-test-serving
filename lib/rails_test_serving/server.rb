module RailsTestServing
  class Server
    GUARD = Mutex.new
  
    def self.start
      DRb.start_service(RailsTestServing.service_uri, Server.new)
      DRb.thread.join
    end
  
    include Utilities
  
    def initialize
      ENV['RAILS_ENV'] = 'test'
      log "** Test server starting [##{$$}]..." do
        enable_dependency_tracking
        start_cleaner
        load_framework
      end
      install_signal_traps
    end
  
    def run(file, argv)
      GUARD.synchronize { perform_run(file, argv) }
    end
  
  private
  
    def shorten_path(path)
      shortenable, base = File.expand_path(path), File.expand_path(Dir.pwd)
      attempt = shortenable.sub(/^#{Regexp.escape base + File::SEPARATOR}/, '')
      attempt.length < path.length ? attempt : path
    end
  
    def enable_dependency_tracking
      require 'config/boot'
    
      Rails::Configuration.class_eval do
        unless method_defined? :cache_classes
          raise "#{self.class} out of sync with current Rails version"
        end
      
        def cache_classes
          false
        end
      end
    end
  
    def start_cleaner
      @cleaner = Cleaner.new
    end
  
    def load_framework
      Client.disable do
        $: << 'test'
        require 'test_helper'
      end
    end
  
    def install_signal_traps
      log " - CTRL+C: Stop the server\n"
      trap(:INT) do
        log "** Stopping the server..." do
          DRb.thread.raise Interrupt
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
            ActiveSupport::Dependencies.clear
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
  
    def capture_testrunner_result
      set_default_testrunner_stream(io = StringIO.new) { yield }
      io.string
    end
  
    # The default output stream of TestRunner is STDOUT which cannot be captured
    # and, as a consequence, neither can TestRunner output when not instantiated
    # explicitely. The following method can change the default output stream
    # argument so that it can be set to a stream that can be captured instead.
    def set_default_testrunner_stream(io)
      require 'test/unit/ui/console/testrunner'
    
      Test::Unit::UI::Console::TestRunner.class_eval do
        alias_method :old_initialize, :initialize
        def initialize(suite, output_level, io=Thread.current["test_runner_io"])
          old_initialize(suite, output_level, io)
        end
      end
      Thread.current["test_runner_io"] = io
    
      begin
        return yield
      ensure
        Thread.current["test_runner_io"] = nil
        Test::Unit::UI::Console::TestRunner.class_eval do
          alias_method :initialize, :old_initialize
          remove_method :old_initialize
        end
      end
    end
  
    # The stock ObjectSpace collector collects every single class that inherits
    # from Test::Unit, including those which have just been unassigned from
    # their constant and not yet garbage collected. This method fixes that
    # behaviour by filtering out these soon-to-be-garbage-collected classes.
    def fix_objectspace_collector
      require 'test/unit/collector/objectspace'
    
      Test::Unit::Collector::ObjectSpace.class_eval do
        alias_method :old_collect, :collect
        def collect(name)
          tests = []
          ConstantManagement.subclasses_of(Test::Unit::TestCase, :legit => true).each { |klass| add_suite(tests, klass.suite) }
          suite = Test::Unit::TestSuite.new(name)
          sort(tests).each { |t| suite << t }
          suite
        end
      end
    
      begin
        return yield
      ensure
        Test::Unit::Collector::ObjectSpace.class_eval do
          alias_method :collect, :old_collect
          remove_method :old_collect
        end
      end
    end
  end
end
