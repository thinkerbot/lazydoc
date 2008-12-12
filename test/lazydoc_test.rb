require 'test/unit'
require 'lazydoc'

# used in testing CALLER_REGEXP below
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
    assert_equal 8, result[3].to_i
    
    assert_nil CallerRegexpTestModule.call(:fail, r)
  end
  
  #
  # scan test
  #

  def test_scan_documentation
    str = %Q{
# Const::Name::key value
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
    Lazydoc.scan(str, 'key|alt') do |const_name, key, value|
      results << [const_name, key, value]
    end

    expected = [
    ['Const::Name', 'key', 'value'], 
    ['', 'alt', 'alt_value'], 
    ['Another', 'key', 'another value']]

    assert_equal expected, results
  end

  def test_scan_only_finds_the_specified_key
    results = []
    Lazydoc.scan(%Q{
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
    Lazydoc.scan(%Q{
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
  # parse test
  #

  def test_parse_documentation
    str = %Q{
# Const::Name::key subject for key
# comment for key

# :::-
# Ignored::key value
# :::+

# Ignored text before attribute ::another subject for another
# comment for another
}

    results = []
    Lazydoc.parse(str) do |const_name, key, comment|
      results << [const_name, key, comment.subject, comment.to_s]
    end

    expected = [
    ['Const::Name', 'key', 'subject for key', 'comment for key'], 
    ['', 'another', 'subject for another', 'comment for another']]

    assert_equal expected, results
  end

  def test_parse
    results = []
    Lazydoc.parse(%Q{
ignored
# leader

# Name::Space::key value
# comment spanning
# multiple lines
#   with indented
#   lines
#
# and a new
# spanning line

ignored
# trailer
}) do |namespace, key, comment|
     results << [namespace, key, comment.subject, comment.content]
   end

   assert_equal 1, results.length
   assert_equal ["Name::Space", "key", "value", 
     [['comment spanning', 'multiple lines'],
     ['  with indented'],
     ['  lines'],
     [''],
     ['and a new', 'spanning line']]
    ], results[0]
  end

  def test_parse_with_various_declaration_syntaxes
    results = []
    Lazydoc.parse(%Q{
# Name::Space::key value1
# :startdoc:Name::Space::key value2
# :startdoc: Name::Space::key value3
# ::key value4
# :startdoc::key value5
# :startdoc: ::key value6
blah blah # ::key value7
# Name::Space::novalue
# ::novalue
}) do |namespace, key, comment|
     results << [namespace, key, comment.subject]
   end

   assert_equal [
     ["Name::Space", "key", "value1"],
     ["Name::Space", "key", "value2"],
     ["Name::Space", "key", "value3"],
     ["", "key", "value4"],
     ["", "key", "value5"],
     ["", "key", "value6"],
     ["", "key", "value7"],
     ["Name::Space", "novalue", ""],
     ["", "novalue", ""]
   ], results
  end

  def test_parse_stops_reading_comment_at_new_declaration_or_end_declaration
    results = []
    Lazydoc.parse(%Q{
# ::key
# comment1 spanning
# multiple lines
# ::key
# comment2 spanning
# multiple lines
# ::key-
# ignored
}) do |namespace, key, comment|
     results << comment.content
   end

   assert_equal 2, results.length
   assert_equal [['comment1 spanning', 'multiple lines']], results[0]
   assert_equal [['comment2 spanning', 'multiple lines']], results[1]
  end

  def test_parse_parses_using_mapped_comment_classes
    comment_class_map = Hash.new({})
    comment_class_map['Name::Space'] = {'alt' => Lazydoc::Subject}
    
    results = []
    Lazydoc.parse(%Q{
# Name::Space::key value
# comment 
# Name::Space::alt value
# comment
}, comment_class_map) do |namespace, key, comment|
     results << [namespace, key, comment.class]
   end
   
   assert_equal 2, results.length
   assert_equal ['Name::Space', 'key', Lazydoc::Comment], results[0]
   assert_equal ['Name::Space', 'alt', Lazydoc::Subject], results[1]
  end
    
  def test_parse_ignores
    results = []
    Lazydoc.parse(%Q{
# Skipped::Key
# skipped::Key
# :skipped:
# skipped
skipped
Skipped::key
}) do |namespace, key, comment|
     results << [namespace, key, comment]
   end

   assert results.empty?
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
end