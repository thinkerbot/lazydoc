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
  # trailer test
  #
  
  def test_trailer_returns_a_trailing_comment_on_the_subject_line
    c.subject = "comment # with trailer "
    assert_equal "with trailer", c.trailer
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
    assert_equal "some line.fragments", c.to_s('.', ':')
  end

end