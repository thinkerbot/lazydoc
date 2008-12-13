require 'test/unit'
require 'lazydoc/attribute'

class AttributeTest < Test::Unit::TestCase
  include Lazydoc
  
  attr_reader :a
  
  def setup
    @a = Attribute.new
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
  
    a = Attribute.new.parse(comment_string)
    expected = [
    ['comments spanning multiple', 'lines are collected'],
    [''],
    ['  while indented lines'],
    ['  are preserved individually'],
    [''],
    []]
    assert_equal expected, a.content

    a = Attribute.new.parse(comment_string) {|frag| frag.strip.empty? }
    a.content   
    expected = [
    ['comments spanning multiple', 'lines are collected']]
    assert_equal expected, a.content
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
  
  def test_parse_sets_line_number
    scanner = StringScanner.new %Q{

subject line
# comment
}
    a.parse(scanner)
    assert_equal 0, a.line_number

    scanner.skip_until(/subject line/)
    a.parse(scanner)
    assert_equal 2, a.line_number
  end
    
  def test_parse_overrides_previous_content
    a.content << "overridden"
    
    a.parse(%Q{# comment})
    assert_equal [["comment"]], a.content
  end
  
  def test_parse_returns_self
    assert_equal a, a.parse("")
  end

  def test_parse_can_handle_an_empty_or_whitespace_string_without_error
    a.parse("")
    a.parse("\n   \t \r\n \f ")
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
  
  class MockDocumentForToS
    def initialize(comment)
      @c = comment
    end
    
    def resolve(str=nil)
      @c.subject = "subject"
    end
  end
  
  def test_to_s_resolves_self
    a.document = MockDocumentForToS.new(a)
    assert_equal nil, a.subject
    assert_equal "subject", a.to_s
  end

end