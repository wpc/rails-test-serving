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
  
    def find_index_by_pattern(enumerable, pattern)
      enumerable.each_with_index do |element, index|
        return index if pattern === element
      end
      nil
    end
  end
end
