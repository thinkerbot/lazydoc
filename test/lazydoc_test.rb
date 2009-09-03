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
  # document test
  #

  def test_document_returns_document_in_registry_for_source_file
    doc = Lazydoc::Document.new('/path/to/file')
    Lazydoc.registry << doc
    assert_equal doc, Lazydoc.document('/path/to/file')
  end
  
  def test_document_returns_nil_if_no_such_document_exists
    assert Lazydoc.registry.empty?
    assert_equal nil, Lazydoc.document('/path/to/file')
  end
  
  #
  # [] test
  #

  def test_aget_returns_document_in_registry_for_source_file
    doc = Lazydoc::Document.new('/path/to/file')
    Lazydoc.registry << doc
    assert_equal doc, Lazydoc['/path/to/file']
  end

  def test_aget_initializes_new_document_if_necessary
    assert Lazydoc.registry.empty?
    doc = Lazydoc['/path/for/non_existant_doc']
    
    assert_equal [doc], Lazydoc.registry
    assert_equal File.expand_path('/path/for/non_existant_doc'), doc.source_file
    assert_equal nil, doc.default_const_name
  end
  
  #
  # guess_const_name test
  #
  
  def load_path_test
    current = $LOAD_PATH.dup
    
    begin
      $LOAD_PATH.clear
      yield
    ensure
      $LOAD_PATH.clear
      $LOAD_PATH.concat(current)
    end
  end
  
  def test_guess_const_name_returns_nil_for_paths_not_relative_to_any_load_path
    load_path_test do
      assert_equal nil, Lazydoc.guess_const_name("/path")
    end
  end
  
  def test_guess_const_name_returns_camelized_path_relative_to_matching_load_path
    load_path_test do
      $LOAD_PATH << "/path"
      
      assert_equal "Const", Lazydoc.guess_const_name("/path/const")
      assert_equal "Const", Lazydoc.guess_const_name("/path/const.rb")
      assert_equal "ConstName", Lazydoc.guess_const_name("/path/const_name.rb")
      assert_equal "ConstName", Lazydoc.guess_const_name("/path/const_name.txt")
      assert_equal "Const::Name", Lazydoc.guess_const_name("/path/const/name.rb")
    end
  end
  
  def test_guess_const_name_expands_source_file_and_load_path
    load_path_test do
      $LOAD_PATH << "."
      
      assert_equal "Const", Lazydoc.guess_const_name("const.rb")
      assert_equal "Const", Lazydoc.guess_const_name(File.expand_path("./const.rb"))
    end
  end
  
  def test_guess_const_name_raises_error_if_source_is_relative_to_many_load_paths
    load_path_test do
      $LOAD_PATH << "/path"
      $LOAD_PATH << "/path/lib"
      
      err = assert_raises(RuntimeError) { Lazydoc.guess_const_name("/path/lib/const.rb") }
      assert_equal "multiple constant names are possible for: \"/path/lib/const.rb\"", err.message
    end
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
  
  def test_register_file_returns_document_in_registry_for_source_file
    path = File.expand_path('/path/to/file')
    doc = Lazydoc::Document.new(path)
    Lazydoc.registry << doc
    assert_equal doc, Lazydoc.register_file(path)
  end
  
  def test_register_file_initializes_document_with_default_const_name_if_provided
    doc = Lazydoc.register_file('/path/to/file', 'Default::ConstName')
    assert_equal 'Default::ConstName', doc.default_const_name
    
    doc = Lazydoc.register_file('/another/file', nil)
    assert_equal nil, doc.default_const_name
  end
  
  def test_register_file_guesses_default_const_name
    load_path_test do
      $LOAD_PATH << "/path"
      
      doc = Lazydoc.register_file('/path/to/file')
      assert_equal 'To::File', doc.default_const_name
    end
  end
  
  def test_register_file_raises_error_for_an_inconsistent_default_const_name
    doc = Lazydoc.register_file('/path/to/file', 'Default::ConstName')
    e = assert_raises(ArgumentError) { Lazydoc.register_file('/path/to/file', 'New::ConstName') }
    assert_equal "default_const_name cannot be overridden #{File.expand_path('/path/to/file')}: \"Default::ConstName\" != \"New::ConstName\"", e.message
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
  
  def test_usage_documentation
    tempfile = Tempfile.new('usage_test')
    tempfile << %q{#!/usr/bin/env ruby
# This is your basic hello world
# script:
#
#   % ruby hello_world.rb

puts 'hello world'
}
    tempfile.close

    expected = %Q{
This is your basic hello world script:

  % ruby hello_world.rb}
    assert_equal expected, "\n" + Lazydoc.usage(tempfile.path)  
  end
  
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