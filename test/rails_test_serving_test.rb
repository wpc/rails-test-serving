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
