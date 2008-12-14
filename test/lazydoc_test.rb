require 'test/unit'
require 'lazydoc'

class LazydocTest < Test::Unit::TestCase
 
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
    assert Lazydoc.registry.kind_of?(Array)
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
  
  def test_register_caller_registers_caller
    tempfile = Tempfile.new('register___test')
    tempfile << %Q{
module RegisterCaller
  module_function
  def method
    Lazydoc.register_caller
  end
end

# this is the line that gets registered
RegisterCaller.method
}
    tempfile.close
    load(tempfile.path)

    lazydoc = Lazydoc[tempfile.path]
    lazydoc.resolve
    
    c = lazydoc.comments[0]
    assert_equal "RegisterCaller.method", c.subject
    assert_equal "this is the line that gets registered", c.to_s
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