require 'test_helper'

class RailsTestServing::BootstrapTest < Test::Unit::TestCase
  def setup
    @boot = Object.new.extend RailsTestServing::Bootstrap
  end

  def test_service_uri
    Pathname.stubs(:pwd).returns(Pathname("/foo/bar"))

    # RAILS_ROOT is the current directory
    setup_service_uri_test do
      FileTest.expects(:file?).with("config/boot.rb").returns true
      FileUtils.expects(:mkpath).with("tmp/sockets")
      assert_equal "drbunix:tmp/sockets/test_server.sock", @boot.service_uri
    end

    # RAILS_ROOT is the parent directory
    setup_service_uri_test do
      FileTest.stubs(:file?).with("config/boot.rb").returns false
      FileTest.stubs(:file?).with("../config/boot.rb").returns true
      FileUtils.expects(:mkpath).with("../tmp/sockets")
      assert_equal "drbunix:../tmp/sockets/test_server.sock", @boot.service_uri
    end

    # RAILS_ROOT cannot be determined
    setup_service_uri_test do
      FileTest.expects(:file?).with("config/boot.rb").returns false
      FileTest.expects(:file?).with("../config/boot.rb").returns false
      FileTest.expects(:file?).with("../../config/boot.rb").returns false
      FileTest.expects(:file?).with("../../../config/boot.rb").never
      FileUtils.expects(:mkpath).never
      assert_raise(RuntimeError) { @boot.service_uri }
    end
  end

  def test_boot
    argv = []
    RailsTestServing::Client.expects(:run_tests)
    @boot.boot(argv)

    argv = ['--local']
    RailsTestServing::Client.expects(:run_tests).never
    @boot.boot(argv)
    assert_equal [], argv

    argv = ["--serve"]
    @boot.expects(:start_server)
    @boot.boot(argv)
    assert_equal [], argv
  end

  def test_options
    @boot.instance_variable_set("@options", nil)
    $test_server_options = nil
    assert_equal({:reload => []}, @boot.options)

    @boot.instance_variable_set("@options", nil)
    $test_server_options = {:foo => :bar}
    assert_equal({:foo => :bar, :reload => []}, @boot.options)

    @boot.instance_variable_set("@options", nil)
    $test_server_options = {:foo => :bar, :reload => [//]}
    assert_equal({:foo => :bar, :reload => [//]}, @boot.options)
  end

private

  def setup_service_uri_test
    old_load_path = $:.dup
    begin
      return yield
    ensure
      @boot.instance_variable_set("@service_uri", nil)
      $:.replace(old_load_path)
    end
  end
end
