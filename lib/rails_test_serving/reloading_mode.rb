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