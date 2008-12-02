require 'test_helper'

class RailsTestServing::UtilitiesTest < Test::Unit::TestCase
  def setup
    @utils = Object.new.extend RailsTestServing::Utilities
  end
  
  def test_log
    # Blockless form
    stream = StringIO.new
    result = @utils.instance_eval { log("message", stream) }
    assert_equal "message", stream.string
    assert_equal nil, result
    
    # Block form
    stream = StringIO.new
    Benchmark.stubs(:realtime).yields.returns 1
    yielded = []
    result = @utils.instance_eval { log("message", stream) { yielded << true; "result" } }
    assert_equal "message (1000 ms)\n", stream.string
    assert_equal [true], yielded
    assert_equal "result", result
  end
  
  def test_capture_standard_stream
    assert_equal STDOUT, $stdout  # sanity check
    
    captured = @utils.instance_eval { capture_standard_stream('out') { print "test" } }
    
    assert_equal "test", captured
    assert_equal STDOUT, $stdout
  end
  
  def test_capture_testrunner_result
    captured = @utils.instance_eval do
      capture_testrunner_result { Thread.current["test_runner_io"].print "test" }
    end
    assert_equal "test", captured
  end
  
  def test_shorten_path
    Dir.stubs(:pwd).returns '/base'
    
    assert_equal 'test.rb', @utils.shorten_path('test.rb')
    assert_equal 'test.rb', @utils.shorten_path('/base/test.rb')
    assert_equal 'test.rb', @utils.shorten_path('/base/./test.rb')
    assert_equal '/other-base/test.rb', @utils.shorten_path('/other-base/test.rb')
    assert_equal '/other-base/test.rb', @utils.shorten_path('/other-base/././test.rb')
  end
end
