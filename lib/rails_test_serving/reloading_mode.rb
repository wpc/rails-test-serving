module RailsTestServing
  module ReloadingMode
    
    class Developer
      def set_dependency_tracking
        require 'config/boot'

        Rails::Configuration.class_eval do
          unless method_defined? :cache_classes
            raise "#{self.class} out of sync with current Rails version"
          end

          def cache_classes
            false
          end
        end
      end
      
      def reload_app
        if ActionController::Dispatcher.respond_to?(:reload_application)
          ActionController::Dispatcher.reload_application
        else
          ActionController::Dispatcher.new(StringIO.new).reload_application
        end
      end
      
      
      def clean_up_app
        if ActionController::Dispatcher.respond_to?(:cleanup_application)
          ActionController::Dispatcher.cleanup_application
        else
          ActionController::Dispatcher.new(StringIO.new).cleanup_application
        end
        if defined?(Fixtures) && Fixtures.respond_to?(:reset_cache)
          Fixtures.reset_cache
        end

        # Reload files that match :reload here instead of in reload_app since the
        # :reload option is intended to target files that don't change between two
        # consecutive runs (an external library for example). That way, they are
        # reloaded in the background instead of slowing down the next run.
        reload_specified_source_files
      end
      
      private
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
    
    class QA
      def set_dependency_tracking
      end
      
      def reload_app
      end
      
      def clean_up_app
      end
      
    end
  end
end