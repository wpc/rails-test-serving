require 'test_helper'

class RailsTestServing::ClientTest < Test::Unit::TestCase
  def setup
    @client = Object.new.extend RailsTestServing::Client
  end
  
  def test_run_tests
    @client.expects(:run_tests!)
    @client.run_tests
    
    @client.disable do
      @client.expects(:run_tests!).never
      @client.run_tests
    end
  end
end
