require 'test/unit'
require 'lazydoc'

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

  #
  # lazy_attr test
  #
  
  # AttributesTest::LazyAttrClass::lazy subject
  # comment
  class LazyAttrClass
    class << self
      include Lazydoc::Attributes
    end
    
    self.source_file = __FILE__
    
    lazy_attr :lazy
    lazy_attr :unknown
  end
  
  def test_lazy_attr_creates_accessor_for_lazydoc_attribute
    assert LazyAttrClass.respond_to?(:lazy)
    
    assert_equal Lazydoc::Subject, LazyAttrClass.lazy.class
    assert_equal "subject", LazyAttrClass.lazy.to_s
    assert_equal "comment", LazyAttrClass.lazy.comment
  end
  
  def test_lazy_attr_creates_new_comment_for_unknown_attributes
    assert LazyAttrClass.respond_to?(:unknown)
    
    assert_equal Lazydoc::Subject, LazyAttrClass.unknown.class
    assert_equal '', LazyAttrClass.unknown.to_s
    assert_equal '', LazyAttrClass.unknown.comment
  end
  
  #
  # lazy_register test
  #
  
  class LazyRegisterClass
    extend Lazydoc::Attributes

    lazy_register :lazy
    
    # comment
    def lazy
    end
  end
  
  def test_lazy_register
    assert LazyRegisterClass.respond_to?(:lazy)
    
    assert_equal Lazydoc::Method, LazyRegisterClass.lazy.class
    assert_equal "lazy", LazyRegisterClass.lazy.method_name
    assert_equal "comment", LazyRegisterClass.lazy.comment
  end
  
  class LazyRegisterSubClass < LazyRegisterClass
    # inherited comment
    def lazy
    end
  end
  
  def test_lazy_register_methods_are_inherited
    assert LazyRegisterSubClass.respond_to?(:lazy)
    
    assert_equal Lazydoc::Method, LazyRegisterSubClass.lazy.class
    assert_equal "lazy", LazyRegisterSubClass.lazy.method_name
    assert_equal "inherited comment", LazyRegisterSubClass.lazy.comment
  end
  
end