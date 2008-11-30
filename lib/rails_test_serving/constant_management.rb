module RailsTestServing
  module ConstantManagement
    extend self
  
    def legit?(const)
      !const.to_s.empty? && constantize(const) == const
    end
  
    def constantize(name)
      eval("#{name} if defined? #{name}", TOPLEVEL_BINDING)
    end
  
    def constantize!(name)
      name.to_s.split('::').inject(Object) { |namespace, short| namespace.const_get(short) }
    end
  
    # ActiveSupport's Module#remove_class doesn't behave quite the way I would expect it to.
    def remove_constants(*names)
      names.map do |name|
        namespace, short = name.to_s =~ /^(.+)::(.+?)$/ ? [$1, $2] : ['Object', name]
        constantize!(namespace).module_eval { remove_const(short) if const_defined?(short) }
      end
    end
  
    def subclasses_of(parent, options={})
      children = []
      ObjectSpace.each_object(Class) { |klass| children << klass if klass < parent && (!options[:legit] || legit?(klass)) }
      children
    end
  end
end
