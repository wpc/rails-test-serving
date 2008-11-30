module RailsTestServing
  module Utilities
    def log(message, stream=$stdout)
      print = lambda do |str|
        stream.print(str)
        stream.flush
      end

      print[message]
      if block_given?
        result = nil
        elapsed = Benchmark.realtime do
          result = yield
        end
        print[" (%d ms)\n" % (elapsed * 1000)]
        result
      end
    end
    
    def capture_standard_stream(name)
      eval("old, $std#{name} = $std#{name}, StringIO.new")
      begin
        yield
        return eval("$std#{name}").string
      ensure
        eval("$std#{name} = old")
      end
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
    
    def shorten_path(path)
      shortenable, base = File.expand_path(path), File.expand_path(Dir.pwd)
      attempt = shortenable.sub(/^#{Regexp.escape base + File::SEPARATOR}/, '')
      attempt.length < path.length ? attempt : path
    end
  
    def find_index_by_pattern(enumerable, pattern)
      enumerable.each_with_index do |element, index|
        return index if pattern === element
      end
      nil
    end
  end
end
