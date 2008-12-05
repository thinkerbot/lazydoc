require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'lazydoc/method'

class MethodTest < Test::Unit::TestCase
  include Lazydoc
  
  attr_reader :m
  
  def setup
    @m = Method.new
  end
  
  #
  # METHOD_DEF test
  #
  
  def test_METHOD_DEF
    r = Method::METHOD_DEF
    
    assert "def method_name_123" =~ r
    assert_equal "method_name_123", $1
    assert_equal "", $2
    
    assert "def m()" =~ r
    assert_equal "m", $1
    assert_equal "()", $2
    
    assert "def m(a, b, c=2) # comment" =~ r
    assert_equal "m", $1
    assert_equal "(a, b, c=2) # comment", $2
    
    assert "def m a, b='str', c=2  # comment" =~ r
    assert_equal "m", $1
    assert_equal " a, b='str', c=2  # comment", $2
    
    # non-matching cases
    assert "a,b,c" !~ r
    assert "# comment" !~ r
    assert "def &$%" !~ r
  end
  
  #
  # TRAILER test
  #
  
  def test_TRAILER
    r = Method::TRAILER
    
    assert "" =~ r
    assert_equal "", $1
    
    assert "simply a string" =~ r
    assert_equal "simply a string", $1
    
    assert "# trailer comment" =~ r
    assert_equal "trailer comment", $1
    
    assert "   # trailer comment   " =~ r
    assert_equal "trailer comment", $1
  end
  
  #
  # method_regexp test
  #
  
  def test_method_regexp_documentation
    m = Method.method_regexp("method")
    assert m =~ "def method"
    assert m =~ "def method(with, args, &block)"
    assert m !~ "def some_other_method" 
  end
  
  #
  # parse_args test
  #
  
  def test_parse_args_documentation
    assert_equal ["a", "b='default'", "&block"], Method.parse_args("(a, b='default', &block)")
  
    scanner = StringScanner.new("a, b # trailing comment")
    assert_equal ["a", "b"], Method.parse_args(scanner)
    scanner.rest =~ Method::TRAILER
    assert_equal "trailing comment", $1.to_s
  end
  
  def test_parse_args
    assert_equal [""], Method.parse_args("")
    assert_equal [""], Method.parse_args("# commet, with, comma")
    
    assert_equal ["a"], Method.parse_args("a")
    assert_equal ["a"], Method.parse_args("a # commet, with, comma")
    
    assert_equal ["a", "b", "&c"], Method.parse_args("a,b,&c")
    assert_equal ["a", "b", "&c"], Method.parse_args("(a,b,&c)")
    assert_equal ["a", "b", "&c"], Method.parse_args("a,b,&c # commet, with, comma")
    
    assert_equal ["a", "b", "&c"], Method.parse_args("  a ,b,  &c  ")
    assert_equal ["a", "b", "&c"], Method.parse_args("  (  a ,b,  &c  )  ")
    
    assert_equal ["a=\"str\"", "b='str'", "c=(2+2)"], Method.parse_args("a=\"str\", b='str', c=(2+2)")
    assert_equal [%q{a='str, with \'scapes # yo'}, "b=((1+1) + 1)"], Method.parse_args(%q{a='str, with \'scapes # yo', b=((1+1) + 1)})
    assert_equal ["a=[1,2,'three']", "b={:one => 1, :two => 'str'}"], Method.parse_args("a=[1,2,'three'], b={:one => 1, :two => 'str'}")
  end
  
  #
  # resolve test
  #
  
  def test_resolve_resolves_method_name_args_and_trailing_comment
    lines = [
      "# comment parsed",
      "# up from line number",
      "def method_name(a,b,&c) # trailing comment"]

    m.line_number = 2
    m.resolve(lines)
    assert_equal "method_name", m.method_name
    assert_equal ["a", "b", "&c"], m.arguments
    assert_equal "trailing comment", m.trailer
  end
  
end