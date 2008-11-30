require 'rubygems'

require 'test/unit'
require 'mocha'
Mocha::Configuration.prevent :stubbing_non_existent_method
Mocha::Configuration.warn_when :stubbing_method_unnecessarily

require 'rails_test_serving'
