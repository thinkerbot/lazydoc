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
  # parse test
  #
  
  def test_parse_documetation
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
    c.parse(document)
    assert_equal "  def method_one", c.subject
    assert_equal [["this is the content of the comment", "for method_one"]], c.content
  
    c = Comment.new(/def method/)
    c.parse(document)
    c.line_number = 4
    assert_equal "  def method_one", c.subject
    assert_equal [["this is the content of the comment", "for method_one"]], c.content
  
    c = Comment.new lambda {|lines| 9 }
    c.parse(document)
    c.line_number = 9
    assert_equal "  def method_two", c.subject
    assert_equal [["this is the content of the comment", "for method_two"]], c.content
  end
  
  def test_parse_sets_subject_line_as_specified_by_line_number_and_parses_comment_up
    str = %Q{not a comment
# comment parsed
# up from line number
subject
}

    c.line_number = 3
    c.parse(str)
    assert_equal "subject", c.subject
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
    
  def test_parse_accepts_an_array_of_lines
    lines = [
      "not a comment",
      "# comment parsed",
      "# up from line number",
      "subject"]

    c.line_number = 3
    c.parse(lines)
    assert_equal "subject", c.subject
    assert_equal [["comment parsed", "up from line number"]], c.content
  end

  def test_parse_skips_up_from_subject_past_whitespace_lines_to_content
    lines = [
      "not a comment",
      "# comment parsed",
      "# up from line number",
      "",
      " \t     \r  ",
      "subject"]

    c.line_number = 5
    c.parse(lines)
    assert_equal "subject", c.subject
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_parses_no_content_if_none_is_specified
    lines = [
      "not a comment",
      "",
      " \t     \r  ",
      "subject"]

    c.line_number = 3
    c.parse(lines)
    assert_equal "subject", c.subject
    assert_equal [], c.content
  end
  
  def test_parse_returns_self
    assert_equal c, c.parse("")
   
    c.line_number = 0
    assert_equal c, c.parse("line")
  end
  
  def test_parse_overrides_previous_subject_and_content
    lines = [
       "not a comment",
       "# comment parsed",
       "# up from line number",
       "subject"]

    c.line_number = 3
    c.subject = "overridden"
    c.content << "overridden"
    
    c.parse(lines)
    assert_equal "subject", c.subject
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_adds_lines_length_to_negative_line_numbers
    lines = [
      "not a comment",
      "# comment parsed",
      "# up from line number",
      "subject"]

    c.line_number = -1
    c.parse(lines)
    assert_equal 3, c.line_number
    assert_equal "subject", c.subject
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_late_evaluates_regexp_line_numbers_to_the_first_matching_line
    lines = [
      "not a comment",
      "# comment parsed",
      "# up from line number",
      "subject"]

    c.line_number = /subject/
    c.parse(lines)
    assert_equal 3, c.line_number
    assert_equal "subject", c.subject
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_late_evaluates_proc_line_numbers_by_calling_with_lines_to_get_the_actual_line_number
    lines = [
      "not a comment",
      "# comment parsed",
      "# up from line number",
      "subject"]

    c.line_number = lambda {|l| 3 }
    c.parse(lines)
    assert_equal 3, c.line_number
    assert_equal "subject", c.subject
    assert_equal [["comment parsed", "up from line number"]], c.content
  end
  
  def test_parse_quietly_does_nothing_when_resolving_and_no_line_number_is_set
    assert_equal nil, c.line_number
    c.parse("")
    assert_equal nil, c.subject
    assert_equal [], c.content
  end
  
  def test_parse_raisess_a_range_error_when_line_number_is_out_of_lines
    c.line_number = 2
    e = assert_raises(RangeError) { c.parse("") }
    assert_equal "line_number outside of lines: 2 (0)", e.message
  end
  
  #
  # resolve test
  #

  class MockDocumentForResolve
    attr_reader :resolve_called

    def initialize
      @resolve_called = false
    end

    def resolve(str=nil)
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
  # empty? test
  #

  def test_empty_is_true_if_there_are_no_non_empty_lines_in_self
    assert_equal [], c.content
    assert c.empty?

    c.content.push "frag"

    assert !c.empty?
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
    
    def resolve(str=nil)
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