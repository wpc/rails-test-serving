require 'test_helper'

class RailsTestServing::ClientTest < Test::Unit::TestCase
  C = RailsTestServing::Client
  
  def test_run_tests
    C.expects(:run_tests!)
    C.run_tests
    
    C.disable do
      C.expects(:run_tests!).never
      C.run_tests
    end
  end
end
