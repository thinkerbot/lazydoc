require 'test/unit'
require 'lazydoc'

#
# used in the documentation test
#

# ConstName::key value
class ConstName
  extend Lazydoc::Attributes

  lazy_attr :key
end

class SubclassA < ConstName; end

# SubclassB::key overridden value
class SubclassB < ConstName; end

class ConstName
  lazy_attr :alt, 'key'
end

class AttributesTest < Test::Unit::TestCase
  # a module of classes used in multi-file tests
  module Example
  end
  
  def multiple_file_test(base)
    pattern = __FILE__.chomp(".rb") + "/#{base}/*.rb"
    Dir.glob(pattern).each do |file|
      load(file)
    end
    
    yield
  end
  
  #
  # documentation test
  #
  
  class Sample
    extend Lazydoc::Attributes

    lazy_register(:method_one)

    # this is the method one comment
    def method_one
    end
  end
  
  class Paired
    extend Lazydoc::Attributes

    lazy_attr(:one, :method_one)
    lazy_register(:method_one)

    # this is the method one comment
    def method_one
    end
  end
  
  def test_attributes_documentation
    assert_equal 'value', ConstName::key.subject
    assert_equal 'value', SubclassA::key.subject
    assert_equal 'overridden value', SubclassB::key.subject
    
    assert_equal 'value', ConstName.const_attrs['key'].subject
    assert_equal 'value', Lazydoc::Document['ConstName']['key'].subject
    
    assert_equal 'value', ConstName::alt.subject
    assert_equal nil, ConstName.const_attrs['alt']
    
    assert_equal "this is the method one comment", Sample.const_attrs[:method_one].comment
    assert_equal "this is the method one comment", Paired.one.comment
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
  
  def test_lazydocs_returns_Documents_registered_to_class
    assert_equal [Lazydoc[__FILE__]], SourceFileClass.lazydocs
  end
  
  class SourceFileClassWithLazydocsSet
    instance_variable_set(:@lazydocs, [])
    extend Lazydoc::Attributes
  end
  
  def test_extend_does_not_set_lazydocs_if_already_set
    assert_equal [], SourceFileClassWithLazydocsSet.lazydocs
  end
  
  #
  # lazy_attr test
  #
  
  # AttributesTest::LazyAttrClass::lazy subject
  # comment
  class LazyAttrClass
    extend Lazydoc::Attributes
    
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
    LazyAttrClass.lazydocs.each {|doc| doc.resolved = false }
    
    lazy = LazyAttrClass.lazy
    assert_equal "subject", lazy.to_s
    assert_equal "comment", lazy.comment
  end
  
  def test_lazy_attr_does_not_auto_resolve_unless_specified
    LazyAttrClass.const_attrs.clear
    LazyAttrClass.lazydocs.each {|doc| doc.resolved = false }
    
    assert_equal nil, LazyAttrClass.lazy(false)
  end
  
  def test_lazy_attr_maps_accessor_to_string_key
    assert LazyAttrClass.alt != nil
    assert_equal LazyAttrClass.const_attrs['lazy'], LazyAttrClass.alt
  end
  
  def test_lazy_attr_only_creates_writer_if_specified
    assert LazyAttrClass.respond_to?(:no_writer)
    assert !LazyAttrClass.respond_to?(:no_writer=)
  end
  
  def test_lazy_attr_returns_nil_for_unknown_attributes
    assert LazyAttrClass.const_attrs['unknown'] == nil
    assert_equal nil, LazyAttrClass.unknown
  end
  
  def test_lazy_attr_raises_error_for_invalid_key
    err = assert_raises(RuntimeError) do
      Class.new do
        extend Lazydoc::Attributes
        lazy_attr :key, 2
      end
    end
    
    assert_equal "invalid lazy_attr key: 2 (Fixnum)", err.message
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
    m = LazyRegisterClass.const_attrs[:lazy]
    m.resolve
    
    assert_equal Lazydoc::Method, m.class
    assert_equal "lazy", m.method_name
    assert_equal "comment", m.comment
    
    m = LazyRegisterClass.const_attrs[:delayed]
    m.resolve
    
    assert_equal Lazydoc::Method, m.class
    assert_equal "delayed", m.method_name
    assert_equal "delayed comment", m.comment
  end
  
  def test_lazy_register_does_not_overwrite_existing_const_attrs
    assert_equal "preset string", LazyRegisterClass.const_attrs[:conflict]
  end
  
  #
  # registered_methods test
  #
  
  class RegisterMethodsParent
    extend Lazydoc::Attributes
    lazy_register :a, Lazydoc::Method, 0
    lazy_register :b, Lazydoc::Method, 0
  end
  
  class RegisterMethodsChild < RegisterMethodsParent
    lazy_register :b, Lazydoc::Method, 1
  end
  
  
  def test_registered_methods_as_registry_correctly_merges_parent_and_child_registrations
    assert_equal({
      :a => [Lazydoc::Method, 0],
      :b => [Lazydoc::Method, 0]
    }, RegisterMethodsParent.registered_methods(true))
    
    assert_equal({
      :a => [Lazydoc::Method, 0],
      :b => [Lazydoc::Method, 1]
    }, RegisterMethodsChild.registered_methods(true))
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
  
  class LazyRegisterParent
    extend Lazydoc::Attributes
  end
  
  class LazyRegisterChild < LazyRegisterParent
  end
  
  class LazyRegisterParent
    lazy_register :lazy
  end
  
  class LazyRegisterChild
    # subclass comment
    def lazy
    end
  end
  
  def test_lazy_register_methods_propogate_to_children
    assert_equal [:lazy], LazyRegisterParent.registered_methods
    assert_equal [:lazy], LazyRegisterChild.registered_methods
    
    m = LazyRegisterChild.const_attrs[:lazy]
    m.resolve
    
    assert_equal "lazy", m.method_name
    assert_equal "subclass comment", m.comment
  end
  
  def test_lazy_register_registers_lazydoc_for_file_where_inheritance_first_occurs
    this_file = File.expand_path(__FILE__)
    
    assert_equal [Lazydoc[this_file]], LazyRegisterClass.lazydocs
    assert_equal [Lazydoc[this_file]], LazyRegisterSubClass.lazydocs
    
    assert !Example.const_defined?(:InheritanceA)
    assert !Example.const_defined?(:InheritanceB)
    
    a = File.expand_path(__FILE__.chomp(".rb") + "/inheritance/a.rb")
    b = File.expand_path(__FILE__.chomp(".rb") + "/inheritance/b.rb")
    
    load(a)
    load(b)
    
    assert_equal [Lazydoc[a]], Example::InheritanceA.lazydocs
    assert_equal [Lazydoc[b]], Example::InheritanceB.lazydocs
    
    Example.send(:remove_const, :InheritanceA)
    Example.send(:remove_const, :InheritanceB)
    
    load(b)
    
    assert_equal [Lazydoc[b]], Example::InheritanceA.lazydocs
    assert_equal [Lazydoc[b]], Example::InheritanceB.lazydocs
  end
  
  def test_lazy_attrs_are_inherited_through_ancestry_if_left_undefined
    multiple_file_test("ancestry") do
      assert_equal "value for A", Example::AncestryA::one.to_s
      assert_equal "value for A", Example::AncestryB::one.to_s
      assert_equal "value for C", Example::AncestryC::one.to_s
    end
  end
  
  #
  # multiple files tests
  #
  
  def test_lazy_attrs_defined_across_multiple_files
    multiple_file_test("lazy_attr") do
      assert_equal "value for one", Example::LazyAttr::one.to_s
      assert_equal "value for two", Example::LazyAttr::two.to_s
    end
  end
  
  def test_register___across_multiple_files
    multiple_file_test("register___") do
      assert_equal "method one comment", Example::Register::one.to_s
      assert_equal "method two comment", Example::Register::two.to_s
    end
  end

  def test_register_method_across_multiple_files
    multiple_file_test("register_method") do
      assert_equal "method one comment", Example::RegisterMethod::one.to_s
    end
  end
end