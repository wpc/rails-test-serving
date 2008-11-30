require 'test_helper'

class RailsTestServing::ConstantManagementTest < Test::Unit::TestCase
  include RailsTestServing::ConstantManagement
  NS = self
  
  Foo = :foo
  NamedFoo = Module.new
  Namespace = Module.new
  
  class A; end
  class B < A; end
  class C < B; end
  
  def test_legit
    assert legit?(NamedFoo)
    
    assert !legit?("Inexistent")
    
    fake = stub(:to_s => NamedFoo.to_s)
    assert_equal NamedFoo.to_s, "#{fake}"   # sanity check
    assert !legit?(fake)
  end
  
  def test_constantize
    assert_equal :foo, constantize("#{NS}::Foo")
    assert_equal nil,  constantize("#{NS}::Bar")
  end
  
  def test_constantize!
    assert_equal :foo, constantize!("#{NS}::Foo")
    assert_raise(NameError) { constantize!("#{NS}::Bar") }
  end
  
  def test_remove_constants
    mod_A = Module.new
    Namespace.const_set(:A, mod_A)
    assert eval("defined? #{NS}::Namespace::A")  # sanity check
    
    removed = remove_constants("#{NS}::Namespace::A")
    assert_equal [mod_A], removed
    assert !eval("defined? #{NS}::Namespace::A")
    
    removed = remove_constants("#{NS}::Namespace::A")
    assert_equal [nil], removed
  end
  
  def test_subclasses_of
    assert_equal [C, B],  subclasses_of(A)
    assert_equal [C],     subclasses_of(B)
    assert_equal [],      subclasses_of(C)
    
    self.stubs(:legit?).with(B).returns true
    self.stubs(:legit?).with(C).returns false
    assert_equal [B], subclasses_of(A, :legit => true)
  end
end
