require 'test/unit'
require 'lazydoc/attributes'

# ConstName::key value
class ConstName
  extend Lazydoc::Attributes
  
  lazy_attr :key
end

class AttributesTest < Test::Unit::TestCase

  #
  # documentation test
  #
  
  def test_attributes_documentation
    assert_equal __FILE__, ConstName.source_file
    assert_equal 'value', ConstName::key.subject
  end

  # AttributesTest::LazyClass::lazy subject
  # comment
  class LazyClass
    class << self
      include Lazydoc::Attributes
    end
    
    self.source_file = __FILE__
    
    lazy_attr :lazy
    lazy_attr :unknown
  end
  
  def test_lazy_attr_creates_accessor_for_lazydoc_attribute
    assert LazyClass.respond_to?(:lazy)
    
    assert_equal Lazydoc::Comment, LazyClass.lazy.class
    assert_equal "subject", LazyClass.lazy.subject
    assert_equal "comment", LazyClass.lazy.to_s
  end
  
  def test_lazy_attr_creates_new_comment_for_unknown_attributes
    assert LazyClass.respond_to?(:unknown)
    
    assert_equal Lazydoc::Comment, LazyClass.unknown.class
    assert_equal nil, LazyClass.unknown.subject
    
    comment = Lazydoc[__FILE__]['AttributesTest::LazyClass']['unknown']
    assert !comment.nil?
    assert_equal comment, LazyClass.unknown
  end
end