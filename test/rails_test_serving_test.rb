require 'test_helper'

class RailsTestServingTest < Test::Unit::TestCase
  include RailsTestServing
  
# class

  def test_service_uri
    # RAILS_ROOT is the current directory
    setup_service_uri_test do
      FileTest.expects(:file?).with("config/boot.rb").returns true
      FileUtils.expects(:mkpath).with("tmp/sockets")
      assert_equal "drbunix:tmp/sockets/test_server.sock", RailsTestServing.service_uri
    end
    
    # RAILS_ROOT is in the parent directory
    setup_service_uri_test do
      FileTest.stubs(:file?).with("config/boot.rb").returns false
      FileTest.stubs(:file?).with("../config/boot.rb").returns true
      FileUtils.expects(:mkpath).with("../tmp/sockets")
      assert_equal "drbunix:../tmp/sockets/test_server.sock", RailsTestServing.service_uri
    end
    
    # RAILS_ROOT cannot be determined
    setup_service_uri_test do
      Pathname.stubs(:pwd).returns(Pathname("/foo/bar"))
      FileTest.expects(:file?).with("config/boot.rb").returns false
      FileTest.expects(:file?).with("../config/boot.rb").returns false
      FileTest.expects(:file?).with("../../config/boot.rb").returns false
      FileTest.expects(:file?).with("../../../config/boot.rb").never
      FileUtils.expects(:mkpath).never
      assert_raise(RuntimeError) { RailsTestServing.service_uri }
    end
  end

  def test_boot
    argv = []
    Client.expects(:run_tests)
    RailsTestServing.boot(argv)
    
    argv = ['--local']
    Client.expects(:run_tests).never
    RailsTestServing.boot(argv)
    assert_equal [], argv
    
    argv = ["--serve"]
    RailsTestServing.expects(:start_server)
    RailsTestServing.boot(argv)
    assert_equal [], argv
  end
  
  def test_options
    RailsTestServing.instance_variable_set("@options", nil)
    $test_server_options = nil
    assert_equal({:reload => []}, RailsTestServing.options)
    
    RailsTestServing.instance_variable_set("@options", nil)
    $test_server_options = {:foo => :bar}
    assert_equal({:foo => :bar, :reload => []}, RailsTestServing.options)
    
    RailsTestServing.instance_variable_set("@options", nil)
    $test_server_options = {:foo => :bar, :reload => [//]}
    assert_equal({:foo => :bar, :reload => [//]}, RailsTestServing.options)
  end
  
private

  def setup_service_uri_test
    old_load_path = $:.dup
    begin
      return yield
    ensure
      RailsTestServing.instance_variable_set("@service_uri", nil)
      $:.replace(old_load_path)
    end
  end
end

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

  def test_shorten_path
    server = stub_server
    Dir.stubs(:pwd).returns '/base'
    
    assert_equal 'test.rb', server.instance_eval { shorten_path 'test.rb' }
    assert_equal 'test.rb', server.instance_eval { shorten_path '/base/test.rb' }
    assert_equal 'test.rb', server.instance_eval { shorten_path '/base/./test.rb' }
    assert_equal '/other-base/test.rb', server.instance_eval { shorten_path '/other-base/test.rb' }
    assert_equal '/other-base/test.rb', server.instance_eval { shorten_path '/other-base/././test.rb' }
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
  
  def test_capture_testrunner_result
    server = stub_server
    
    captured = server.instance_eval do
      capture_testrunner_result { Thread.current["test_runner_io"].print "test" }
    end
    
    assert_equal "test", captured
  end
  
private

  S = RailsTestServing::Server
  
  def stub_server
    S.any_instance.stubs(:log).yields
    S.any_instance.stubs(:enable_dependency_tracking)
    S.any_instance.stubs(:start_cleaner)
    S.any_instance.stubs(:load_framework)
    S.any_instance.stubs(:install_signal_traps)
    S.new
  end
end
