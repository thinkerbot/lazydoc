require 'test/unit'
require 'lazydoc'

# ConstName::key value
class ConstName
  extend Lazydoc::Attributes

  lazy_attr :key
end

class AttributesTest < Test::Unit::TestCase

  #
  # documentation test
  #
  
  class Sample
    extend Lazydoc::Attributes

    const_attrs[:method_one] = register___
    # this is the method one comment
    def method_one
    end
  end
  
  class Paired
    extend Lazydoc::Attributes

    lazy_attr(:one, :method_one)
    lazy_attr(:two, :method_two)
    lazy_register(:method_two)

    const_attrs[:method_one] = register___
    # this is the manually-registered method one comment
    def method_one
    end

    # this is the lazyily-registered method two comment
    def method_two
    end
  end
  
  def test_attributes_documentation
    assert_equal File.expand_path(__FILE__), ConstName.source_file
    assert_equal 'value', ConstName::key.subject
    
    Sample.lazydoc.resolve
    assert_equal "this is the method one comment", Sample.const_attrs[:method_one].comment

    Paired.lazydoc.resolve
    assert_equal "this is the manually-registered method one comment", Paired.one.comment
    assert_equal "this is the lazyily-registered method two comment", Paired.two.comment 
  end
  
  #
  # const_attrs test
  #
  
  class ConstAttrClass
    extend Lazydoc::Attributes
  end
  
  def test_const_attrs_returns_the_const_attrs_for_the_extended_class
    assert_equal Lazydoc::Document['AttributesTest::ConstAttrClass'], ConstAttrClass.const_attrs
  end
  
  #
  # lazydoc test
  #
  
  class SourceFileClass
    extend Lazydoc::Attributes
  end
  
  def test_lazydoc_returns_Document_registered_to_source_file
    assert_equal File.expand_path(__FILE__), SourceFileClass.source_file
    assert_equal Lazydoc[__FILE__], SourceFileClass.lazydoc
  end
  
  class SourceFileClassWithSourceFileSet
    instance_variable_set(:@source_file, "src")
    extend Lazydoc::Attributes
  end
  
  def test_extend_does_not_set_source_file_if_already_set
    assert_equal "src", SourceFileClassWithSourceFileSet.source_file
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
    lazy_attr :alt, 'lazy'
    lazy_attr :no_writer, 'lazy', false
    lazy_attr :unknown
  end
  
  def test_lazy_attr_creates_accessor_for_lazydoc_attribute
    assert LazyAttrClass.respond_to?(:lazy)
    assert LazyAttrClass.respond_to?(:lazy=)
    
    assert LazyAttrClass.lazy != nil
    assert_equal LazyAttrClass.const_attrs['lazy'], LazyAttrClass.lazy
  end
  
  def test_lazy_attr_auto_resolves
    LazyAttrClass.const_attrs.clear
    LazyAttrClass.lazydoc.resolved = false
    
    lazy = LazyAttrClass.lazy
    assert LazyAttrClass.lazydoc.resolved
    assert_equal "subject", lazy.to_s
    assert_equal "comment", lazy.comment
  end
  
  def test_lazy_attr_does_not_resolve_unless_specified
    LazyAttrClass.const_attrs.clear
    LazyAttrClass.lazydoc.resolved = false
    
    lazy = LazyAttrClass.lazy(false)
    assert !LazyAttrClass.lazydoc.resolved
    assert_equal nil, lazy.subject
    assert_equal [], lazy.content
  end
  
  def test_lazy_attr_maps_accessor_to_string_key
    assert LazyAttrClass.alt != nil
    assert_equal LazyAttrClass.const_attrs['lazy'], LazyAttrClass.alt
  end
  
  def test_lazy_attr_only_creates_writer_if_specified
    assert LazyAttrClass.respond_to?(:no_writer)
    assert !LazyAttrClass.respond_to?(:no_writer=)
  end
  
  def test_lazy_attr_creates_new_Subject_for_unknown_attributes
    assert LazyAttrClass.const_attrs['unknown'] == nil
    assert LazyAttrClass.unknown != nil
    
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
    lazy_register :delayed
    
    # comment
    def lazy
    end
    
    lazy_register :conflict
    const_attrs[:conflict] = "preset string"
    
    # not registered
    def conflict
    end
  end
  
  class LazyRegisterClass
    # delayed comment
    def delayed
    end
  end
  
  def test_lazy_register_registers_methods_as_they_are_defined
    LazyRegisterClass.lazydoc.resolve
    
    m = LazyRegisterClass.const_attrs[:lazy]

    assert_equal Lazydoc::Method, m.class
    assert_equal "lazy", m.method_name
    assert_equal "comment", m.comment
    
    m = LazyRegisterClass.const_attrs[:delayed]

    assert_equal Lazydoc::Method, m.class
    assert_equal "delayed", m.method_name
    assert_equal "delayed comment", m.comment
  end
  
  def test_lazy_register_does_not_overwrite_existing_const_attrs
    LazyRegisterClass.lazydoc.resolve
    assert_equal "preset string", LazyRegisterClass.const_attrs[:conflict]
  end
  
  #
  # inherited test
  #
  
  class LazyRegisterSubClass < LazyRegisterClass
    # subclass comment
    def lazy
    end
  end
  
  def test_lazy_register_methods_are_inherited
    m = LazyRegisterSubClass.const_attrs[:lazy]
    m.resolve
    
    assert_equal Lazydoc::Method, m.class
    assert_equal "lazy", m.method_name
    assert_equal "subclass comment", m.comment
  end
  
  def test_lazy_register_registers_source_file_as_file_where_inheritance_first_occurs
    assert_equal File.expand_path(__FILE__), LazyRegisterClass.source_file
    assert_equal File.expand_path(__FILE__), LazyRegisterSubClass.source_file
    
    assert !AttributesTest.const_defined?(:A)
    assert !AttributesTest.const_defined?(:B)
    
    a = __FILE__.chomp(".rb") + "/a.rb"
    b = __FILE__.chomp(".rb") + "/b.rb"
    
    load(a)
    load(b)
    
    assert_equal File.expand_path(a), A.source_file
    assert_equal File.expand_path(b), B.source_file
    
    AttributesTest.send(:remove_const, :A)
    AttributesTest.send(:remove_const, :B)
    
    load(b)
    
    assert_equal File.expand_path(b), A.source_file
    assert_equal File.expand_path(b), B.source_file
  end
end