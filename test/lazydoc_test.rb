require 'test/unit'
require 'lazydoc'

class LazydocTest < Test::Unit::TestCase
 
  def setup
    Lazydoc.registry.clear
  end
  
  #
  # syntax test
  #

  module SyntaxSample
    def self.m
      "true"
    end
  end

  def m
    "true"
  end

  def test_lazydoc_syntax
    assert_equal "true", eval("SyntaxSample::m")

    assert_raises(SyntaxError) { eval("::m") }
    assert_raises(SyntaxError) { eval("SyntaxSample ::m") }

    assert_raises(SyntaxError) { eval(":::-") }
    assert_raises(SyntaxError) { eval("SyntaxSample :::-") }

    assert_raises(SyntaxError) { eval(":::+") }
    assert_raises(SyntaxError) { eval("SyntaxSample :::+") }
  end

  #
  # registry test
  #

  def test_registry
    assert_equal Array, Lazydoc.registry.class
  end
  
  #
  # register_file test
  #
  
  def test_register_file_adds_a_document_for_the_specified_path
    assert Lazydoc.registry.empty?
    
    path = File.expand_path('/path/to/file')
    doc = Lazydoc.register_file(path)
    
    assert_equal path, doc.source_file
    assert_equal nil, doc.default_const_name
    assert_equal [doc], Lazydoc.registry
  end
  
  def test_register_file_expands_path_relative_to_dir_string
    doc = Lazydoc.register_file('path/to/file', nil, '/root')
    assert_equal '/root/path/to/file', doc.source_file
  end
  
  def test_register_file_returns_document_in_registry_for_source_file
    path = File.expand_path('/path/to/file')
    doc = Lazydoc::Document.new(path)
    Lazydoc.registry << doc
    assert_equal doc, Lazydoc.register_file(path)
  end
  
  def test_register_file_initializes_document_with_default_const_name_if_provided
    doc = Lazydoc.register_file('/path/to/file', 'Default::ConstName')
    assert_equal 'Default::ConstName', doc.default_const_name
  end

  def test_register_file_raises_error_for_an_inconsistent_default_const_name
    doc = Lazydoc.register_file('/path/to/file', 'Default::ConstName')
    e = assert_raise(ArgumentError) { Lazydoc.register_file('/path/to/file', 'New::ConstName') }
    assert_equal "inconsistent default_const_name specified for #{File.expand_path('/path/to/file')}: \"Default::ConstName\" != \"New::ConstName\"", e.message
  end
  
  #
  # [] test
  #

  def test_get_returns_document_in_registry_for_source_file
    doc = Lazydoc::Document.new('/path/to/file')
    Lazydoc.registry << doc
    assert_equal doc, Lazydoc['/path/to/file']
  end

  def test_get_initializes_new_document_if_necessary
    assert !Lazydoc.registry.find {|doc| doc.source_file == '/path/for/non_existant_doc'}
    doc = Lazydoc['/path/for/non_existant_doc']
    assert Lazydoc.registry.include?(doc)
  end
  
  #
  # register_caller test
  #
  
  module Sample
    module_function
    def method
      Lazydoc.register_caller
    end
  end
  
  def test_register_caller_documentation

# this is the line that gets registered
c = Sample.method

    c.resolve
    assert_equal "c = Sample.method", c.subject
    assert_equal "this is the line that gets registered", c.comment
  end
  
  #
  # usage test
  #
  
  def test_usage_parses_first_comment_down_in_str_and_formats_in_cols
    tempfile = Tempfile.new('usage_test')
    tempfile << %q{# this is the usage
# formatted correctly.

# not part of the usage string
}
    tempfile.close
    
    assert_equal "this is the usage formatted\ncorrectly.", Lazydoc.usage(tempfile.path, 30)
  end
  
  def test_usage_skips_bang_line
    tempfile = Tempfile.new('usage_test')
    tempfile << %q{#! bang line
# this is the usage
# formatted correctly.

# not part of the usage string
}
    tempfile.close

    assert_equal "this is the usage formatted\ncorrectly.", Lazydoc.usage(tempfile.path, 30)
  end
  
  def test_usage_skips_whitespace_to_first_comment
    tempfile = Tempfile.new('usage_test')
    tempfile << %q{

# this is the usage
# formatted correctly.

# not part of the usage string
}
    tempfile.close

    assert_equal "this is the usage formatted\ncorrectly.", Lazydoc.usage(tempfile.path, 30)
  end
end