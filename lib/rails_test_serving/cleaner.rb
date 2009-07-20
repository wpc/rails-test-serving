module RailsTestServing
  class Cleaner
    include ConstantManagement

    PAUSE = 0.01
    TESTCASE_CLASS_NAMES =  %w( Test::Unit::TestCase
                                ActiveSupport::TestCase
                                ActionView::TestCase
                                ActionController::TestCase
                                ActionController::IntegrationTest
                                ActionMailer::TestCase )

    def initialize(reloading_mode)
      @reloading_mode = reloading_mode
      start_worker
    end

    def clean_up_around
      check_worker_health
      sleep PAUSE while @working
      begin
        @reloading_mode.reload_app
        yield
      ensure
        @working = true
        sleep PAUSE until @worker.stop?
        @worker.wakeup
      end
    end

  private

    def start_worker
      @worker = Thread.new do
        Thread.abort_on_exception = true
        loop do
          Thread.stop
          begin
            @reloading_mode.clean_up_app
            # Reload files that match :reload here instead of in reload_app since the
            # :reload option is intended to target files that don't change between two
            # consecutive runs (an external library for example). That way, they are
            # reloaded in the background instead of slowing down the next run.
            reload_specified_source_files
                        
            remove_tests
          ensure
            @working = false
          end
        end
      end
      @working = false
    end

    def check_worker_health
      unless @worker.alive?
        $stderr.puts "cleaning thread died, restarting"
        start_worker
      end
    end

    def remove_tests
      TESTCASE_CLASS_NAMES.each do |name|
        next unless klass = constantize(name)
        remove_constants(*subclasses_of(klass).map { |c| c.to_s }.grep(/Test$/) - TESTCASE_CLASS_NAMES)
      end
    end
    
    def reload_specified_source_files
      to_reload =
        $".select do |path|
          RailsTestServing.options[:reload].any? do |matcher|
            matcher === path
          end
        end

      # Force a reload by removing matched files from $"
      $".replace($" - to_reload)

      to_reload.each do |file|
        require file
      end
    end
    
  end
end
