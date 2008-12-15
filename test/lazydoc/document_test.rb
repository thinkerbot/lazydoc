require 'test/unit'
require 'lazydoc/document'
require 'tempfile'

# used in testing CALLER_REGEXP below
# (moving these lines will break an assertion)
module CallerRegexpTestModule
  module_function
  def call(method, regexp)
    send("caller_test_#{method}", regexp)
  end
  def caller_test_pass(regexp)
    caller[0] =~ regexp
    $~
  end
  def caller_test_fail(regexp)
    "unmatching" =~ regexp
    $~
  end
end

class DocumentTest < Test::Unit::TestCase
  include Lazydoc
  
  attr_reader :doc

  def setup
    @doc = Document.new
    Document.const_attrs.clear
  end
  
  #
  # ATTRIBUTE_REGEXP test
  #

  def test_ATTRIBUTE_REGEXP
    r = Lazydoc::ATTRIBUTE_REGEXP

    assert r =~ "::key"
    assert_equal [nil, "key", ""], [$1, $3, $4]
    
    assert r =~ "::key-"
    assert_equal [nil, "key", "-"], [$1, $3, $4]
    
    assert r =~ "Name::Space::key trailer"
    assert_equal ["Name::Space", "key", ""], [$1, $3, $4]

    assert r =~ "Name::Space::key- trailer"
    assert_equal ["Name::Space", "key", "-"], [$1, $3, $4]
    
    assert r !~ ": :key"
    assert r !~ "::\nkey"
    assert r !~ "Name::Space:key"
    assert r !~ "Name::Space::Key"
  end

  #
  # CONSTANT_REGEXP test
  #

  def test_CONSTANT_REGEXP
    r = Lazydoc::CONSTANT_REGEXP
    
    assert r =~ "# NameSpace"
    assert_equal "NameSpace", $1 
    
    assert r =~ "# Name::Space"
    assert_equal "Name::Space", $1
    
    assert r =~ " text # text Name::Space"
    assert_equal "Name::Space", $1
    
    assert r =~ "# text"
    assert_equal nil, $1
    
    assert r !~ "Name::Space"
  end
  
  #
  # CALLER_REGEXP test
  #

  def test_CALLER_REGEXP
    r = Lazydoc::CALLER_REGEXP
    
    result = CallerRegexpTestModule.call(:pass, r)
    assert_equal MatchData, result.class
    assert_equal __FILE__, result[1]
    assert_equal 10, result[3].to_i
    
    assert_nil CallerRegexpTestModule.call(:fail, r)
  end
  
  #
  # const_attrs test
  #

  def test_const_attrs
    assert_equal Hash, Document.const_attrs.class
  end
  
  #
  # [] test
  #
  
  def test_AGET_returns_a_hash_in_const_attrs_for_the_specified_const_name
    assert Document.const_attrs.empty?
    
    hash = Document['Const::Name']
    assert_equal({}, hash)
    assert_equal hash, Document.const_attrs['Const::Name']
  end

  #
  # scan test
  #

  def test_scan_documentation
    str = %Q{
# Name::Space::key value
# ::alt alt_value
# 
# Ignored::Attribute::not_matched value
# :::-
# Ignored::key value
# :::+
# Another::key another value

Ignored::key value
}

    results = []
    Document.scan(str, 'key|alt') do |const_name, key, value|
      results << [const_name, key, value]
    end

    expected = [
    ['Name::Space', 'key', 'value'], 
    ['', 'alt', 'alt_value'], 
    ['Another', 'key', 'another value']]

    assert_equal expected, results
  end

  def test_scan_only_finds_the_specified_key
    results = []
    Document.scan(%Q{
# Name::Space::key1 value1
# Name::Space::key value2
# Name::Space::key value3
# ::key
# Name::Space::key1 value4
}, "key") do |namespace, key, value|
     results << [namespace, key, value]
   end

   assert_equal [
     ["Name::Space", "key", "value2"],
     ["Name::Space", "key", "value3"],
     ["",  "key",  ""]
    ], results
  end

  def test_scan_skips_areas_flagged_as_off
    results = []
    Document.scan(%Q{
# Name::Space::key value1
# Name::Space:::-
# Name::Space::key value2
# Name::Space:::+
# Name::Space::key value3
}, "key") do |namespace, key, value|
     results << [namespace, key, value]
   end

   assert_equal [
     ["Name::Space", "key", "value1"],
     ["Name::Space", "key", "value3"]
    ], results
  end

  #
  # initialize test
  #

  def test_initialize
    doc = Document.new
    assert_equal(nil, doc.source_file)
    assert_equal(nil, doc.default_const_name)
    assert_equal([], doc.comments)
    assert !doc.resolved
  end
  
  #
  # [] test
  #
  
  def test_AGET_returns_the_const_attrs_for_the_specified_const_name
    Document['']['key'] = ''
    Document['Const::Name']['key'] = 'value'
    
    assert_equal({'key' => ''}, doc[''])
    assert_equal({'key' => 'value'}, doc['Const::Name'])
  end
  
  def test_AGET_uses_default_const_name_if_set_and_const_name_is_empty
    Document['Const::Name']['key'] = 'value'
    doc = Document.new(nil, 'Const::Name')
    
    assert_equal({'key' => 'value'}, doc[''])
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
  # register___ test
  #
  
  def test_register___documentation
    lazydoc = Document.new(__FILE__)
  
    c = lazydoc.register___
# this is the comment
# that is registered
def method(a,b,c)
end
  
    lazydoc.resolve
    
    assert_equal "def method(a,b,c)", c.subject
    assert_equal "this is the comment that is registered", c.comment
  end
  
  def test_register___skips_whitespace_before_and_after_comment
    lazydoc = Document.new(__FILE__)

    m = lazydoc.register___

# this is a comment surrounded
# by whitespace

def skip_method(a,b,c)
end

    lazydoc.resolve
    
    assert_equal "def skip_method(a,b,c)", m.subject
    assert_equal "this is a comment surrounded by whitespace", m.to_s
  end

  #
  # resolve test
  #

  def test_resolve_constant_attributes_with_various_declaration_syntaxes
    doc.resolve %Q{
    # Name::Space::one value1
    # :startdoc:Name::Space::two value2
    # :startdoc: Name::Space::three value3
    # ::four value4
    # :startdoc::five value5
    # :startdoc: ::six value6
    blah blah # ::seven value7
    # Name::Space::novalue
    # ::novalue
    }

    expected = {
    'one' => 'value1', 
    'two' => 'value2', 
    'three' => 'value3', 
    'novalue' => ''}
    actual = {}
    Document['Name::Space'].each_pair {|key, comment| actual[key] = comment.subject}
    assert_equal expected, actual
    
    expected = {
    'four' => 'value4', 
    'five' => 'value5', 
    'six' => 'value6', 
    'seven' => 'value7',
    'novalue' => ''}
    actual = {}
    Document[''].each_pair {|key, comment| actual[key] = comment.subject}
    assert_equal expected, actual
  end

  def test_resolve_stops_reading_comment_at_new_declaration_or_end_declaration
    doc.resolve %Q{
    # ::one
    # comment1 spanning
    # multiple lines
    # ::two
    # comment2 spanning
    # multiple lines
    # ::two-
    # ignored
    }

    one = doc['']['one']
    assert_equal [['comment1 spanning', 'multiple lines']], one.content
   
    two = doc['']['two']
    assert_equal [['comment2 spanning', 'multiple lines']], two.content
  end
  
  def test_resolve_parses_existing_const_attrs
    const_attr = Subject.new
    doc['Existing']['key'] = const_attr
    
    doc.resolve %Q{
    # Existing::key subject line
    # attribute comment
    }

    assert_equal 'attribute comment', const_attr.comment
    assert_equal 'subject line', const_attr.subject
  end

  def test_resolve_preserves_non_Comment_constant_attributes
    doc['Existing']['key'] = ""
    
    doc.resolve %Q{
    # Existing::key subject line
    # attribute comment
    }

    assert_equal "", doc['Existing']['key']
  end
  
  def test_resolve_ignores_non_word_keys
    doc.resolve %Q{
    # Skipped::Key
    # skipped::Key
    # :skipped:
    # skipped
    skipped
    Skipped::key
    }

    assert Document.const_attrs.empty?
  end
  
  def test_resolve_parses_comments_from_str
    c1 = Comment.new(6)
    c2 = Comment.new(10)
    doc.comments.concat [c1, c2]
    
    doc.resolve %Q{
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

    assert_equal [['comment one', 'spanning multiple lines'], [''], ['  indented line'], ['']], c1.content
    assert_equal "    subject line one", c1.subject
    assert_equal 6, c1.line_number

    assert_equal [['comment two']], c2.content
    assert_equal "    subject line two", c2.subject
    assert_equal 10, c2.line_number
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
    assert_equal "    subject line one", c.subject
    assert_equal 2, c.line_number
    
    const_attr = doc['Const::Name']['key']
    assert_equal 'attribute comment', const_attr.comment
    assert_equal 'subject line', const_attr.subject
  end

  def test_resolve_sets_resolved_to_true
    assert !doc.resolved
    doc.resolve ""
    assert doc.resolved
  end

  def test_resolve_does_nothing_if_already_resolved
    c = doc.register(1)
    assert doc.resolve("# comment one\nsubject line one")
    assert !doc.resolve("# comment two\nsubject line two")

    assert_equal 'comment one', c.comment
    assert_equal "subject line one", c.subject
  end
  
  def test_resolve_will_re_resolve_if_force_is_specified
    c = doc.register(1)
    assert doc.resolve("# comment one\nsubject line one")
    assert doc.resolve("# comment two\nsubject line two", true)

    assert_equal 'comment two', c.comment
    assert_equal "subject line two", c.subject
  end
  
  #
  # summarize test
  #
  
  def test_summarize_returns_a_hash_of_const_attrs_assigned_to_self
    c1 = Comment.new(1, doc)
    c2 = Comment.new(2, doc)
    c3 = Comment.new
    
    Document['Const::Name']['c1'] = c1
    Document['']['c2'] = c2
    Document['']['c3'] = c3
    
    assert_equal({
      'Const::Name' => {'c1' => c1},
      '' => {'c2' => c2},
    }, doc.summarize)
  end
  
  def test_summarize_collects_block_results_instead_of_comments
    c1 = Comment.new(1, doc)
    c2 = Comment.new(2, doc)

    Document['Const::Name']['c1'] = c1
    Document['']['c2'] = c2
    
    expected = {
      'Const::Name' => {'c1' => 1},
      '' => {'c2' => 2},
    }
    assert_equal(expected, doc.summarize {|comment| comment.line_number })
  end
end