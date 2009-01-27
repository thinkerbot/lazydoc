require 'test/unit'
require 'lazydoc/comment'

class CommentTest < Test::Unit::TestCase
  include Lazydoc
  
  attr_reader :c
  
  def setup
    @c = Comment.new
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Comment.new
    assert_equal [], c.content
    assert_equal nil, c.subject
    assert_equal nil, c.line_number
    assert_equal nil, c.document
  end

  #
  # trailer test
  #
  
  def test_trailer_returns_a_trailing_comment_on_the_subject_line
    c.subject = "comment # with trailer "
    assert_equal "with trailer", c.trailer
  end

  #
  # push test
  #
  
  def test_push_documentation
    c = Comment.new
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]
    
    expected = [
      ["some line", "fragments"], 
      ["a", "whole", "new line"]]
    assert_equal(expected, c.content)
  end
  
  def test_push_adds_fragment_to_last_line
    c.push "a line"
    c.push "fragment"
    assert_equal [["a line", "fragment"]], c.content
  end

  def test_push_adds_array_if_given
    c.push "fragment"
    c.push ["some", "array"]
    assert_equal [['fragment'], ["some", "array"]], c.content
  end

  def test_push_replaces_last_array_if_last_is_empty
    c.push ["some", "array"]
    assert_equal [["some", "array"]], c.content
  end
  
  #
  # append test
  #
  
  def test_append_documentation
    lines = [
      "# comment spanning multiple",
      "# lines",
      "#",
      "#   indented line one",
      "#   indented line two",
      "#    ",
      "not a comment line"]
  
    c = Comment.new
    lines.each {|line| c.append(line) }
  
    expected = [
    ['comment spanning multiple', 'lines'],
    [''],
    ['  indented line one'],
    ['  indented line two'],
    [''],
    []]
    assert_equal expected, c.content
  end
  
  #
  # unshift test
  #
  
  def test_unshift_documentation
    c = Comment.new
    c.unshift "some line"
    c.unshift "fragments"
    c.unshift ["a", "whole", "new line"]
    
    expected = [
      ["a", "whole", "new line"], 
      ["fragments", "some line"]]
    assert_equal(expected, c.content)
  end
  
  def test_unshift_unshifts_fragment_to_first_line
    c.unshift "a line"
    c.unshift "fragment"
    assert_equal [["fragment", "a line"]], c.content
  end

  def test_unshift_unshifts_array_if_given
    c.unshift "fragment"
    c.unshift ["some", "array"]
    assert_equal [["some", "array"], ['fragment']], c.content
  end

  def test_unshift_replaces_first_array_if_first_is_empty
    c.unshift ["some", "array"]
    assert_equal [["some", "array"]], c.content
  end
  
  #
  # prepend test
  #
  
  def test_prepend_documentation
    lines = [
      "# comment spanning multiple",
      "# lines",
      "#",
      "#   indented line one",
      "#   indented line two",
      "#    ",
      "not a comment line"]
  
    c = Comment.new
    lines.reverse_each {|line| c.prepend(line) }
  
    expected = [
    ['comment spanning multiple', 'lines'],
    [''],
    ['  indented line one'],
    ['  indented line two'],
    ['']]
    assert_equal expected, c.content
  end
  
  #
  # parse_up test
  #
  
  def test_parse_up_documetation
    document = %Q{
module Sample
  # this is the content of the comment
  # for method_one
  def method_one
  end

  # this is the content of the comment
  # for method_two
  
  def method_two
  end
end}
  
    c = Comment.new 4
    c.parse_up(document)
    assert_equal "this is the content of the comment for method_one", c.comment
  
    c = Comment.new 4
    c.parse_up(document) {|line| line =~ /# this is/ }
    assert_equal "for method_one", c.comment
    
    c = Comment.new(/def method/)
    c.parse_up(document)
    assert_equal 4, c.line_number
    assert_equal "this is the content of the comment for method_one", c.comment
  
    c = Comment.new lambda {|scanner, lines| 9 }
    c.parse_up(document)
    assert_equal 9, c.line_number
    assert_equal "this is the content of the comment for method_two", c.comment
  end
  
  def test_parse_up_parses_content_up_from_line_number
    str = %Q{not a comment
    # comment parsed
    # up from line number
    subject}

    c.line_number = 3
    c.parse_up(str)
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
    
  def test_parse_up_uses_the_array_of_lines_if_given
    lines = [
      "not a comment",
      "# comment parsed",
      "# up from line number",
      "subject"]

    c.line_number = 3
    c.parse_up("", lines)
    assert_equal [["comment parsed", "up from line number"]], c.content
  end

  def test_parse_up_skips_up_from_line_number_past_whitespace_lines_to_content
    str = %Q{not a comment
    # comment parsed
    # up from line number

       \t   \r  
    subject}
    
    c.line_number = 5
    c.parse_up(str)
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_up_stops_parsing_content_if_block_returns_true
    str = %Q{not a comment
    # comment parsed
    # up from line number 
    subject}
    
    c.line_number = 3
    c.parse_up(str) {|line| line =~ /# comment parsed/}
    assert_equal [["up from line number"]], c.content
  end
  
  def test_parse_up_parses_no_content_if_none_is_specified
    str = %Q{not a comment

       \t   \r  
    subject}

    c.line_number = 3
    c.parse_up(str)
    assert_equal [], c.content
  end
  
  def test_parse_up_returns_self
    assert_equal c, c.parse_up("")
    
    c.line_number = 1
    assert_equal c, c.parse_up(%Q{# comment\nsubject})
  end
  
  def test_parse_up_overrides_previous_content
    c.content << "overridden"
    assert_equal ["overridden"], c.content
    
    c.line_number = 1
    c.parse_up %Q{# comment\nsubject}
    assert_equal [["comment"]], c.content
  end
  
  def test_parse_up_adds_lines_length_to_negative_line_numbers
    str = %Q{not a comment
    # comment parsed
    # up from line number
    subject}
    
    c.line_number = -1
    c.parse_up(str)
    assert_equal 3, c.line_number
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_up_late_evaluates_regexp_line_numbers_to_the_first_matching_line
    str = %Q{not a comment
    # comment parsed
    # up from line number
    subject}

    c.line_number = /subject/
    c.parse_up(str)
    assert_equal 3, c.line_number
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_up_late_evaluates_proc_line_numbers_by_calling_with_lines_to_get_the_actual_line_number
    str = %Q{not a comment
    # comment parsed
    # up from line number
    subject}

    c.line_number = lambda {|scanner, lines| 3 }
    c.parse_up(str)
    assert_equal 3, c.line_number
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_up_quietly_does_nothing_when_resolving_and_no_line_number_is_set
    assert_equal nil, c.line_number
    c.parse_up("str")
    assert_equal [], c.content
  end
  
  def test_parse_up_raises_error_when_no_dynamic_line_number_is_resolved
    block = lambda {|scanner, lines| nil }
    c.line_number = block
    e = assert_raises(RuntimeError) { c.parse_up("") }
    assert_equal "invalid dynamic line number: #{block.inspect}", e.message

    c.line_number = /non-matching/
    e = assert_raises(RuntimeError) { c.parse_up("") }
    assert_equal "invalid dynamic line number: /non-matching/", e.message
  end
  
  def test_parse_up_raises_a_range_error_when_line_number_is_out_of_lines
    c.line_number = 2
    e = assert_raises(RangeError) { c.parse_up("") }
    assert_equal "line_number outside of lines: 2 (1)", e.message
  end
  
  #
  # parse_down test
  #

  def test_parse_down_documetation
    document = %Q{
    # == Section One
    # documentation for section one
    #   'with' + 'indentation'
    #
    # == Section Two
    # documentation for section two
    }
  
    c = Comment.new 1
    c.parse_down(document) {|line| line =~ /Section Two/}
    assert_equal "documentation for section one\n  'with' + 'indentation'", c.comment
  
    c = Comment.new(/Section Two/)
    c.parse_down(document)
    assert_equal 5, c.line_number
    assert_equal "documentation for section two", c.comment
  end
  
  #
  # resolve test
  #

  class MockDocumentForResolve
    attr_reader :resolve_called

    def initialize
      @resolve_called = false
    end

    def resolve(*args)
      @resolve_called = true
    end
  end

  def test_resolve_resolves_lazydoc
    doc = MockDocumentForResolve.new
    c.document = doc
    c.resolve
    assert doc.resolve_called
  end

  def test_resolve_does_not_raise_error_if_document_is_not_set
    assert_equal nil, c.document
    c.resolve
  end

  #
  # trim test
  #

  def test_trim_removes_leading_and_trailing_empty_and_whitespace_lines
    c.push ['']
    c.push ["fragment"]
    c.push ['', "\t\r  \n", ' ']
    c.push []

    assert_equal [[''],['fragment'],['', "\t\r  \n", ' '],[]], c.content
    c.trim
    assert_equal [['fragment']], c.content
  end

  def test_trim_ensures_lines_is_not_empty
    c.push ['']
    c.push ['']
    assert_equal [[''],['']], c.content

    c.trim
    assert_equal [], c.content
  end

  def test_trim_returns_self
    assert_equal c, c.trim
  end

  #
  # comment test
  #

  def test_comment_joins_lines_with_separators
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]

    assert_equal "some line.fragments:a.whole.new line", c.comment('.', ':')
  end

  def test_comment_does_not_join_lines_when_line_sep_is_nil
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]

    assert_equal ["some line.fragments", "a.whole.new line"], c.comment('.', nil)
  end

  #
  # wrap test
  #

  def test_wrap_wraps_to_s_to_the_specified_number_of_columns
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]

    expected = %Q{
some line
fragments
a whole
new line
}.strip

    assert_equal expected, c.wrap(10)
  end
  
  #
  # empty? test
  #

  def test_empty_is_true_to_s_is_empty
    assert c.to_s.empty?
    assert c.empty?
    
    c.push "frag"
    
    assert !c.to_s.empty?
    assert !c.empty?
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_comment
    c.push "some line"
    c.push "fragments"
    c.push ["a", "whole", "new line"]
    
    assert_equal "some line fragments\na whole new line", c.to_s
  end
  
  class MockDocumentForToS
    def initialize(comment)
      @c = comment
    end
    
    def resolve(*args)
      @c.push "some line"
      @c.push "fragments"
    end
  end
  
  def test_to_s_resolves_self
    c.document = MockDocumentForToS.new(c)
    assert_equal [], c.content
    assert_equal "some line fragments", c.to_s
  end

end