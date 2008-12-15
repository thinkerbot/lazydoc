require 'test/unit'
require 'lazydoc/utils'

class UtilsTest < Test::Unit::TestCase
  include Lazydoc
  include Utils
  
  #
  # convert_to_scanner test
  #
  
  def test_convert_to_scanner_converts_strings_to_StringScanner
    scanner = convert_to_scanner('str')
    assert_equal StringScanner, scanner.class
    assert_equal 'str', scanner.string
  end
  
  def test_convert_to_scanner_returns_StringScanners
    scanner = StringScanner.new('str')
    assert_equal scanner, convert_to_scanner(scanner)
  end
  
  def test_convert_to_scanner_raises_error_for_non_String_non_StringScanner_inputs
    e = assert_raise(TypeError) { convert_to_scanner(Object.new) }
    assert_equal "can't convert Object into StringScanner", e.message
  end
  
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

    c = Comment.new
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
    assert_equal [], scan_args("")
    assert_equal [], scan_args("# commet, with, comma")
    
    assert_equal ["a"], scan_args("a")
    assert_equal ["a"], scan_args("a # commet, with, comma")
    
    assert_equal ["a", "b", "&c"], scan_args("a,b,&c")
    assert_equal ["a", "b", "&c"], scan_args("(a,b,&c)")
    assert_equal ["a", "b", "&c"], scan_args("a,b,&c # commet, with, comma")
    
    assert_equal ["a", "b", "&c"], scan_args("  a ,b,  &c  ")
    assert_equal ["a", "b", "&c"], scan_args("  (  a ,b,  &c  )  ")
    
    assert_equal ["a=\"str\"", "b='str'", "c=(2+2)"], scan_args("a=\"str\", b='str', c=(2+2)")
    assert_equal [%q{a='str, with \'scapes # yo'}, "b=((1+1) + 1)"], scan_args(%q{a='str, with \'scapes # yo', b=((1+1) + 1)})
    assert_equal ["a=[1,2,'three']", "b={:one => 1, :two => 'str'}"], scan_args("a=[1,2,'three'], b={:one => 1, :two => 'str'}")
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
    assert_equal nil, scan_trailer("")
    assert_equal nil, scan_trailer("simply a string")
  end
  
  def test_scan_trailer_returns_stripped_trailer
    assert_equal "trailer comment", scan_trailer("str with # trailer comment")
    assert_equal "trailer comment", scan_trailer("str with #   trailer comment   ")
  end
  
  def test_scan_trailer_overlooks_comments_in_strings
    assert_equal "trailer comment", scan_trailer(%q{ '#str' "#{str}" # trailer comment})
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
    assert_equal ["line that", "will wrap", "a line", "that wont"], wrap("line that will wrap\na line\nthat wont", 10)
  end
  
  def test_preserves_multiple_newlines
    assert_equal ["line that", "", "", "", "will wrap"], wrap("line that\n\n\n\nwill wrap", 10)
  end
  
  def test_wrap_resolves_tabs_using_tabsize
    assert_equal ["a    line", "that", "wraps"], wrap("a\tline that\twraps", 10, 4)
  end
  
  #
  # determine_line_number test
  #
  
  def test_determine_line_number_returns_the_line_in_which_scanner_is_currently_positioned
    scanner = StringScanner.new %Q{zero\none\ntwo\nthree}
    assert_equal 0, determine_line_number(scanner)
    
    scanner.skip_until(/tw/)
    assert_equal 2, determine_line_number(scanner)
  end
  
  def test_determine_line_number_does_not_change_the_position_of_scanner
    scanner = StringScanner.new %Q{zero\none\ntwo\nthree}
    
    scanner.skip_until(/one/)
    assert_equal 8, scanner.pos
    
    determine_line_number(scanner)
    assert_equal 8, scanner.pos
  end
  
  #
  # scan_index test
  #
  
  def test_scan_index_documentation
    scanner = StringScanner.new %Q{zero\none\ntwo\nthree}
    assert_equal 2, Utils.scan_index(scanner, /two/)
    assert_equal nil, Utils.scan_index(scanner, /no match/)
  end
  
  def test_scan_index_returns_the_line_number_at_the_end_of_the_first_match_to_regexp
    scanner = StringScanner.new %Q{zero\none\none\nthree}
    assert_equal 0, scan_index(scanner, /ero/)
    assert_equal 2, scan_index(scanner, /ne\non/)
  end
  
  def test_scan_index_starts_at_position_zero
    scanner = StringScanner.new %Q{zero\none\none\nthree}
    scanner.skip_until(/one/)
    assert_equal 1, scan_index(scanner, /one/)
  end
  
  def test_scan_index_does_not_advance_position
    scanner = StringScanner.new %Q{zero\none\ntwo\nthree}
    assert_equal 0, scanner.pos
    scan_index(scanner, /one/)
    assert_equal 0, scanner.pos
  end
  
  def test_scan_index_returns_nil_if_no_match_is_found
    scanner = StringScanner.new %Q{zero\none\ntwo\nthree}
    assert_equal nil, scan_index(scanner, /four/)
  end
  
  #
  # match_index test
  #
  
  def test_match_index_returns_the_index_of_the_line_first_matching_regexp
    lines = %w{zero one two three}
    assert_equal 0, match_index(lines, /ero/)
    assert_equal 2, match_index(lines, /two/)
  end
  
  def test_match_index_returns_nil_if_no_line_matches_regexp
    lines = %w{zero one two three}
    assert_equal nil, match_index(lines, /no match/)
  end
end