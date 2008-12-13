require 'test/unit'
require 'lazydoc/attributes'

# ConstName::key value
class ConstName
  extend Lazydoc::Attributes
  
  lazy_attr :key
end

class AttributesTest < Test::Unit::TestCase

  #
  # attributes test
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
    
    assert_equal Lazydoc::Attribute, LazyClass.lazy.class
    assert_equal "subject", LazyClass.lazy.to_s
    assert_equal "comment", LazyClass.lazy.comment
  end
  
  def test_lazy_attr_creates_new_comment_for_unknown_attributes
    assert LazyClass.respond_to?(:unknown)
    
    assert_equal Lazydoc::Attribute, LazyClass.unknown.class
    assert_equal '', LazyClass.unknown.to_s
    assert_equal '', LazyClass.unknown.comment
  end
end