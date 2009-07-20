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
  end
end
