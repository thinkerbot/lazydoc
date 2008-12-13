require 'test/unit'
require 'lazydoc/attribute'

class AttributeTest < Test::Unit::TestCase
  include Lazydoc
  
  attr_reader :a
  
  def setup
    @a = Attribute.new
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    a = Attribute.new
    assert_equal [], a.content
    assert_equal nil, a.subject
  end
  
  #
  # push test
  #
  
  def test_push_documentation
    a = Attribute.new
    a.push "some line"
    a.push "fragments"
    a.push ["a", "whole", "new line"]
    
    expected = [
      ["some line", "fragments"], 
      ["a", "whole", "new line"]]
    assert_equal(expected, a.content)
  end
  
  def test_push_adds_fragment_to_last_line
    a.push "a line"
    a.push "fragment"
    assert_equal [["a line", "fragment"]], a.content
  end

  def test_push_adds_array_if_given
    a.push "fragment"
    a.push ["some", "array"]
    assert_equal [['fragment'], ["some", "array"]], a.content
  end

  def test_push_replaces_last_array_if_last_is_empty
    a.push ["some", "array"]
    assert_equal [["some", "array"]], a.content
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
  
    a = Attribute.new
    lines.each {|line| a.append(line) }
  
    expected = [
    ['comment spanning multiple', 'lines'],
    [''],
    ['  indented line one'],
    ['  indented line two'],
    [''],
    []]
    assert_equal expected, a.content
  end
  
  #
  # unshift test
  #
  
  def test_unshift_documentation
    a = Attribute.new
    a.unshift "some line"
    a.unshift "fragments"
    a.unshift ["a", "whole", "new line"]
    
    expected = [
      ["a", "whole", "new line"], 
      ["fragments", "some line"]]
    assert_equal(expected, a.content)
  end
  
  def test_unshift_unshifts_fragment_to_first_line
    a.unshift "a line"
    a.unshift "fragment"
    assert_equal [["fragment", "a line"]], a.content
  end

  def test_unshift_unshifts_array_if_given
    a.unshift "fragment"
    a.unshift ["some", "array"]
    assert_equal [["some", "array"], ['fragment']], a.content
  end

  def test_unshift_replaces_first_array_if_first_is_empty
    a.unshift ["some", "array"]
    assert_equal [["some", "array"]], a.content
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
  
    a = Attribute.new
    lines.reverse_each {|line| a.prepend(line) }
  
    expected = [
    ['comment spanning multiple', 'lines'],
    [''],
    ['  indented line one'],
    ['  indented line two'],
    ['']]
    assert_equal expected, a.content
  end
  
  #
  # parse test
  #

  def test_parse_documentation
    comment_string = %Q{
# comments spanning multiple
# lines are collected
#
#   while indented lines
#   are preserved individually
#    

# this line is not parsed
}
  
    a = Attribute.new.parse(comment_string, "subject")
    expected = [
    ['comments spanning multiple', 'lines are collected'],
    [''],
    ['  while indented lines'],
    ['  are preserved individually'],
    [''],
    []]
    assert_equal expected, a.content
    assert_equal "subject", a.subject

    a = Attribute.new.parse(comment_string) {|frag| frag.strip.empty? }
    a.content   
    expected = [
    ['comments spanning multiple', 'lines are collected']]
    assert_equal expected, a.content
    assert_equal nil, a.subject
  end

  # comment test will yield the string with both LF and CRLF
  # line endings; to ensure there is no dependency on the 
  # end of line style
  def line_end_test(str)
    @a = Attribute.new
    yield(str.gsub(/\r?\n/, "\n"))
    
    @a = Attribute.new
    yield(str.gsub(/\r?\n/, "\r\n"))
  end

  def test_parse
    line_end_test(%Q{
# comment
# spanning lines
 \t  # with whitespace   \t
})  do |str|
      a.parse(str)
      assert_equal [['comment', 'spanning lines', 'with whitespace']], a.content
    end
  end

  def test_parse_accepts_string_scanner
    line_end_test(%Q{
# comment
# spanning lines
 \t  # with whitespace   \t
})  do |str|      
      a.parse(StringScanner.new(str))
      assert_equal [['comment', 'spanning lines', 'with whitespace']], a.content
    end
  end

  def test_parse_treats_indented_lines_as_new_lines
    line_end_test(%Q{
# comment
#  with indented
# \tlines \t
# new spanning
# line
})  do |str|
      a.parse(str)
      assert_equal [['comment'],[' with indented'], ["\tlines"], ['new spanning', 'line']], a.content
    end
  end

  def test_parse_preserves_newlines
   line_end_test(%Q{
# comment
#
#   \t   
#  with indented
#
# \tlines \t
#   \t  
# new spanning
# line
})  do |str|
      a.parse(str)
      assert_equal [['comment'],[''],[''],[' with indented'],[''],["\tlines"],[''],['new spanning', 'line']], a.content
    end
  end

  def test_parse_stops_at_non_comment_line
    line_end_test(%Q{
# comment
# spanning lines

# ignored
})  do |str|
      a.parse(str)
      assert_equal [['comment', 'spanning lines']], a.content
    end
  end

  def test_parse_stops_when_block_returns_true
    line_end_test(%Q{
# comment
# spanning lines
# end
# ignored
})  do |str|
      a.parse(str) do |comment|
        comment =~ /^end/
      end
      assert_equal [['comment', 'spanning lines']], a.content
    end
  end
  
  def test_parse_overrides_previous_subject_and_content
    a.subject = "overridden"
    a.content << "overridden"
    
    a.parse(%Q{# comment}, "subject")
    assert_equal "subject", a.subject
    assert_equal [["comment"]], a.content
  end
  
  def test_parse_returns_self
    assert_equal a, a.parse("", "subject")
  end
  
  def test_parse_sets_subject_as_provided
    a.parse("", "subject")
    assert_equal "subject", a.subject
  end

  def test_parse_can_handle_an_empty_or_whitespace_string_without_error
    a.parse("")
    a.parse("\n   \t \r\n \f ")
  end
  
  #
  # trim test
  #
  
  def test_trim_removes_leading_and_trailing_empty_and_whitespace_lines
    a.push ['']
    a.push ["fragment"]
    a.push ['', "\t\r  \n", ' ']
    a.push []
    
    assert_equal [[''],['fragment'],['', "\t\r  \n", ' '],[]], a.content
    a.trim
    assert_equal [['fragment']], a.content
  end
  
  def test_trim_ensures_lines_is_not_empty
    a.push ['']
    a.push ['']
    assert_equal [[''],['']], a.content
    
    a.trim
    assert_equal [], a.content
  end
  
  def test_trim_returns_self
    assert_equal a, a.trim
  end
  
  #
  # empty? test
  #
  
  def test_empty_is_true_if_there_are_no_non_empty_lines_in_self
    assert_equal [], a.content
    assert a.empty?
    
    a.content.push "frag"
    
    assert !a.empty?
  end
  
  #
  # trailer test
  #
  
  def test_trailer_returns_a_trailing_comment_on_the_subject_line
    a.subject = "comment # with trailer "
    assert_equal "with trailer", a.trailer
  end
  
  #
  # comment test
  #
  
  def test_comment_joins_lines_with_separators
    a.push "some line"
    a.push "fragments"
    a.push ["a", "whole", "new line"]
    
    assert_equal "some line.fragments:a.whole.new line", a.comment('.', ':')
  end
  
  def test_comment_does_not_join_lines_when_line_sep_is_nil
    a.push "some line"
    a.push "fragments"
    a.push ["a", "whole", "new line"]
    
    assert_equal ["some line.fragments", "a.whole.new line"], a.comment('.', nil)
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_subject_to_s
    assert_equal nil, a.subject
    assert_equal "", a.to_s
    
    a.subject = "subject"
    assert_equal "subject", a.to_s
  end
  
  #
  # wrap test
  #
  
  def test_wrap_wraps_to_s_to_the_specified_number_of_columns
    a.push "some line"
    a.push "fragments"
    a.push ["a", "whole", "new line"]
    
    expected = %Q{
some line
fragments
a whole
new line
}.strip

    assert_equal expected, a.wrap(10)
  end

end