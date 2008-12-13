require 'test/unit'
require 'lazydoc/document'
require 'tempfile'

module Const
  module Name
    def self.const_attrs
      @const_attrs ||= {}
    end
  end
end

class DocumentTest < Test::Unit::TestCase
  include Lazydoc
  
  attr_reader :doc

  def setup
    @doc = Document.new
  end
  
  #
  # documentation test
  #
  
  def test_documentation

  end
  
  #
  # initialize test
  #

  def test_initialize
    doc = Document.new
    assert_equal(nil, doc.source_file)
    assert_equal({}, doc.const_lookup)
    assert_equal([], doc.comments)
    assert !doc.resolved
  end

  #
  # source_file= test
  #

  def test_set_source_file_sets_source_file_to_the_expanded_input_path
    assert_nil doc.source_file
    doc.source_file = "path/to/file.txt"
    assert_equal File.expand_path("path/to/file.txt"), doc.source_file
  end

  def test_source_file_may_be_set_to_nil
    doc.source_file = "path/to/file.txt"
    doc.source_file = nil
    assert_nil doc.source_file
  end
  
  #
  # default_const= test
  #

  def test_set_default_const_sets_the_default_const
    assert_equal(nil, doc.default_const)
    doc.default_const = Const::Name
    assert_equal(Const::Name, doc.default_const)
  end
  
  def test_set_default_const_actually_sets_the_empty_string_value_in_const_lookup
    doc.default_const = Const::Name
    assert_equal({'' => Const::Name}, doc.const_lookup)
  end
  
  #
  # register test
  #

  def test_register_adds_line_number_to_comments
    c1 = doc.register(1)
    assert_equal 1, c1.line_number

    c2 = doc.register(2)
    assert_equal 2, c2.line_number

    c3 = doc.register(3)
    assert_equal 3, c3.line_number

    assert_equal([c1, c2, c3], doc.comments)
  end
  
  def test_register_sets_self_as_comment_document
    c = doc.register(1)
    assert_equal doc, c.document
  end
  
  #
  # register_method test
  #
  
  def test_register_method_registers_the_next_method_matching_method_name
    lazydoc = Document.new(__FILE__)
    m = lazydoc.register_method(:register_method_name)
    
    # this is the register_method_name comment
    def register_method_name(a,b,c)
    end

    lazydoc.resolve

    assert_equal "register_method_name", m.method_name
    assert_equal "this is the register_method_name comment", m.to_s
  end
  
  # 
  # register___ test
  #
  
  def test_register___documentation
    lazydoc = Document.new(__FILE__)

    lazydoc.register___
# this is the comment
# that is registered
def method(a,b,c)
end

    lazydoc.resolve
    m = lazydoc.comments[0]
    assert_equal "def method(a,b,c)", m.subject
    assert_equal "this is the comment that is registered", m.to_s
  end
  
  def test_register___skips_whitespace_before_and_after_comment
    lazydoc = Document.new(__FILE__)

    lazydoc.register___
    
# this is a comment surrounded
# by whitespace

def skip_method(a,b,c)
end

    lazydoc.resolve
    m = lazydoc.comments[0]
    assert_equal "def skip_method(a,b,c)", m.subject
    assert_equal "this is a comment surrounded by whitespace", m.to_s
  end

  #
  # resolve test
  #

  def test_resolve_parses_comments_from_str_for_source_file
    str = %Q{
# comment one
# spanning multiple lines
#
#   indented line
#    
subject line one

# comment two

subject line two

# ignored
not a subject line
}

    c1 = Comment.new(6)
    c2 = Comment.new(10)
    doc.comments.concat [c1, c2]
    doc.resolve(str)

    assert_equal [['comment one', 'spanning multiple lines'], [''], ['  indented line'], ['']], c1.content
    assert_equal "subject line one", c1.subject
    assert_equal 6, c1.line_number

    assert_equal [['comment two']], c2.content
    assert_equal "subject line two", c2.subject
    assert_equal 10, c2.line_number
  end

  def test_resolve_reads_const_attrs_from_str
    doc.resolve %Q{
# Const::Name::key subject line
# attribute comment
}
    const_attr = Const::Name.const_attrs['key']
    assert_equal 'attribute comment', const_attr.comment
    assert_equal 'subject line', const_attr.subject
  end

  def test_resolve_reads_str_from_source_file_if_str_is_unspecified
    tempfile = Tempfile.new('register_test')
    tempfile << %Q{
# comment one
subject line one

# Const::Name::key subject line
# attribute comment 
}
    tempfile.close

    doc.source_file = tempfile.path
    c = doc.register(2)
    doc.resolve

    assert_equal 'comment one', c.comment
    assert_equal "subject line one", c.subject
    assert_equal 2, c.line_number

    const_attr = Const::Name.const_attrs['key']
    assert_equal 'attribute comment', const_attr.comment
    assert_equal 'subject line', const_attr.subject
  end

  def test_resolve_sets_resolved_to_true
    assert !doc.resolved
    doc.resolve ""
    assert doc.resolved
  end

  def test_resolve_does_nothing_if_already_resolved
    c1 = Comment.new(1)
    c2 = Comment.new(1)
    doc.comments << c1
    assert doc.resolve("# comment one\nsubject line one")

    doc.comments << c2
    assert !doc.resolve("# comment two\nsubject line two")

    assert_equal 'comment one', c1.comment
    assert_equal "subject line one", c1.subject

    assert_equal [], c2.content
    assert_equal nil, c2.subject
  end
  
end