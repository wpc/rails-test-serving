module RailsTestServing
  module Client
    extend self
  
    # Setting this variable to true inhibits #run_tests.
    @@disabled = false
  
    def disable
      @@disabled = true
      yield
    ensure
      @@disabled = false
    end
  
    def tests_on_exit
      !Test::Unit.run?
    end
  
    def tests_on_exit=(yes)
      Test::Unit.run = !yes
    end
  
    def run_tests
      return if @@disabled
      run_tests!
    end

  private

    def run_tests!
      handle_process_lifecycle do
        server = DRbObject.new_with_uri(RailsTestServing.service_uri)
        begin
          puts(server.run($0, ARGV))
        rescue DRb::DRbConnError
          raise ServerUnavailable
        end
      end
    end
  
    def handle_process_lifecycle
      Client.tests_on_exit = false
      begin
        yield
      rescue ServerUnavailable, InvalidArgumentPattern
        Client.tests_on_exit = true
      else
        # TODO exit with a status code reflecting the result of the tests
        exit 0
      end
    end
  end
end
