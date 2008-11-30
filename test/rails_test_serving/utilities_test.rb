require 'test_helper'

class RailsTestServing::UtilitiesTest < Test::Unit::TestCase
  def test_log
    loggable = Object.new.extend RailsTestServing::Utilities
    
    # Blockless form
    stream = StringIO.new
    result = loggable.instance_eval { log("message", stream) }
    assert_equal "message", stream.string
    assert_equal nil, result
    
    # Block form
    stream = StringIO.new
    Benchmark.stubs(:realtime).yields.returns 1
    yielded = []
    result = loggable.instance_eval { log("message", stream) { yielded << true; "result" } }
    assert_equal "message (1000 ms)\n", stream.string
    assert_equal [true], yielded
    assert_equal "result", result
  end
end
