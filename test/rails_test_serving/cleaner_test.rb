require 'test_helper'

class RailsTestServing::CleanerTest < Test::Unit::TestCase
  include RailsTestServing

# private

  def test_reload_specified_source_files
    Cleaner.any_instance.stubs(:start_worker)

    # Empty :reload option
    preserve_features do
      $".replace ["foo.rb"]
      RailsTestServing.stubs(:options).returns({:reload => []})

      Cleaner.any_instance.expects(:require).never
      Cleaner.new.instance_eval { reload_specified_source_files }
      assert_equal ["foo.rb"], $"
    end

    # :reload option contains regular expressions
    preserve_features do
      $".replace ["foo.rb", "bar.rb"]
      RailsTestServing.stubs(:options).returns({:reload => [/foo/]})

      Cleaner.any_instance.expects(:require).with("foo.rb").once
      Cleaner.new.instance_eval { reload_specified_source_files }
      assert_equal ["bar.rb"], $"
    end
  end

private

  def preserve_features
    old = $".dup
    begin
      return yield
    ensure
      $".replace(old)
    end
  end
end
