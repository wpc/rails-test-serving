require 'test_helper'

class RailsTestServing::ServerTest < Test::Unit::TestCase
  
# private
  
  def test_perform_run
    server = stub_server
    file, argv = "test.rb", ["-n", "/pat/"]
    
    server.stubs(:sanitize_arguments!)
    server.stubs(:log).with(">> test.rb -n /pat/").yields.returns("result").once
    server.stubs(:capture_test_result).with(file, argv)
    
    result = server.instance_eval { perform_run(file, argv) }
    assert_equal "result", result
  end
  
  def test_sanitize_arguments
    server = stub_server
    sanitize = lambda { |*args| server.instance_eval { sanitize_arguments! *args } }
    
    # valid
    file, argv = "test.rb", ["--name=test_create"]
    sanitize.call file, argv
    
    assert_equal "test.rb", file
    assert_equal ["--name=test_create"], argv
    
    # TextMate junk
    junk = ["[test_create,", "nil,", "nil]"]
    
    # a)  at the beginning
    file, argv = "test.rb", junk + ["foo"]
    sanitize.call file, argv
    
    assert_equal "test.rb", file
    assert_equal ["foo"], argv
    
    # b)  in between normal arguments
    file, argv = "test.rb", ["foo"] + junk + ["bar"]
    sanitize.call file, argv
    
    assert_equal "test.rb", file
    assert_equal ["foo", "bar"], argv
    
    # invalid arguments
    assert_raise RailsTestServing::InvalidArgumentPattern do
      sanitize.call "-e", ["code"]
    end
  end

  def test_capture_test_result
    server = stub_server
    cleaner = server.instance_variable_set("@cleaner", stub)
    
    cleaner.stubs(:clean_up_around).yields
    server.stubs(:capture_standard_stream).with('err').yields.returns "stderr"
    server.stubs(:capture_standard_stream).with('out').yields.returns "stdout"
    server.stubs(:capture_testrunner_result).yields.returns "result"
    server.stubs(:fix_objectspace_collector).yields
    
    server.stubs(:load).with("file")
    Test::Unit::AutoRunner.expects(:run).with(false, nil, "argv")
    
    result = server.instance_eval { capture_test_result("file", "argv") }
    assert_equal "stderrstdoutresult", result
  end
  
private

  def stub_server
    s = RailsTestServing::Server
    s.any_instance.stubs(:log).yields
    s.any_instance.stubs(:enable_dependency_tracking)
    s.any_instance.stubs(:start_cleaner)
    s.any_instance.stubs(:load_framework)
    s.any_instance.stubs(:install_signal_traps)
    s.new
  end
end
