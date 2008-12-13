require 'test/unit'
require 'lazydoc/utils'

class UtilsTest < Test::Unit::TestCase
  include Lazydoc

  #
  # scan test
  #
  
  def test_scan_documentation
    lines = [
      "# comments spanning multiple",
      "# lines are collected",
      "#",
      "#   while indented lines",
      "#   are preserved individually",
      "#    ",
      "not a comment line",
      "# skipped since the loop breaks",
      "# at the first non-comment line"]

    c = Utils.new
    lines.each do |line|
      break unless Utils.scan(line) do |fragment|
        c.push(fragment)
      end
    end
    
    expected = [
       ['comments spanning multiple', 'lines are collected'],
       [''],
       ['  while indented lines'],
       ['  are preserved individually'],
       [''],
       []]
    assert_equal(expected, c.content)
  end
  
  #
  # scan_args test
  #
  
  def test_scan_args_documentation
    assert_equal ["a", "b='default'", "*c", "&block"], Utils.scan_args("(a, b='default', *c, &block)")
  end
  
  def test_scan_args
    assert_equal [""], Utils.scan_args("")
    assert_equal [""], Utils.scan_args("# commet, with, comma")
    
    assert_equal ["a"], Utils.scan_args("a")
    assert_equal ["a"], Utils.scan_args("a # commet, with, comma")
    
    assert_equal ["a", "b", "&c"], Utils.scan_args("a,b,&c")
    assert_equal ["a", "b", "&c"], Utils.scan_args("(a,b,&c)")
    assert_equal ["a", "b", "&c"], Utils.scan_args("a,b,&c # commet, with, comma")
    
    assert_equal ["a", "b", "&c"], Utils.scan_args("  a ,b,  &c  ")
    assert_equal ["a", "b", "&c"], Utils.scan_args("  (  a ,b,  &c  )  ")
    
    assert_equal ["a=\"str\"", "b='str'", "c=(2+2)"], Utils.scan_args("a=\"str\", b='str', c=(2+2)")
    assert_equal [%q{a='str, with \'scapes # yo'}, "b=((1+1) + 1)"], Utils.scan_args(%q{a='str, with \'scapes # yo', b=((1+1) + 1)})
    assert_equal ["a=[1,2,'three']", "b={:one => 1, :two => 'str'}"], Utils.scan_args("a=[1,2,'three'], b={:one => 1, :two => 'str'}")
  end
  
  #
  # scan_trailer test
  #
  
  def test_scan_trailer_documentation
    assert_equal "trailer", Utils.scan_trailer("str with # trailer")
    assert_equal "trailer", Utils.scan_trailer("'# in str' # trailer")
    assert_equal nil, Utils.scan_trailer("str with without trailer")
    
    assert_equal "in str} # trailer", Utils.scan_trailer("%Q{# in str} # trailer")
  end
  
  def test_scan_trailer_returns_nil_for_strings_without_a_trailer
    assert_equal nil, Utils.scan_trailer("")
    assert_equal nil, Utils.scan_trailer("simply a string")
  end
  
  def test_scan_trailer_returns_stripped_trailer
    assert_equal "trailer comment", Utils.scan_trailer("str with # trailer comment")
    assert_equal "trailer comment", Utils.scan_trailer("str with #   trailer comment   ")
  end
  
  def test_scan_trailer_overlooks_comments_in_strings
    assert_equal "trailer comment", Utils.scan_trailer(%q{ '#str' "#{str}" # trailer comment})
  end
  
  #
  # wrap test
  #
  
  def test_wraps_documentation
    assert_equal ["some line", "that will", "wrap"], Utils.wrap("some line that will wrap", 10)
    assert_equal ["     line", "that will", "wrap"], Utils.wrap("     line that will wrap    ", 10)
    assert_equal [], Utils.wrap("                            ", 10)
  end
  
  def test_wrap_breaks_on_newlines
    assert_equal ["line that", "will wrap", "a line", "that wont"], Utils.wrap("line that will wrap\na line\nthat wont", 10)
  end
  
  def test_preserves_multiple_newlines
    assert_equal ["line that", "", "", "", "will wrap"], Utils.wrap("line that\n\n\n\nwill wrap", 10)
  end
  
  def test_wrap_resolves_tabs_using_tabsize
    assert_equal ["a    line", "that", "wraps"], Utils.wrap("a\tline that\twraps", 10, 4)
  end
end