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
  # documentation test
  #
  
  def test_documentation
    sample_method = %Q{
    # This is the comment body
    def method_name(a, b='default', &c) # trailing comment
    end
    }
  
    m = Method.parse(sample_method)
    assert_equal "method_name", m.method_name
    assert_equal ["a", "b='default'", "&c"], m.arguments
    assert_equal "trailing comment", m.trailer
    assert_equal "This is the comment body", m.to_s
  end
  
  #
  # initialize test
  #
  
  def test_method_initialize
    m = Method.new
    assert_equal nil, m.method_name
    assert_equal [], m.arguments
  end
  
  #
  # subject= test
  #
  
  def test_setting_subject_sets_method_name_args_and_trailing_comment
    m.subject = "def method_name(a,b,&c) # trailing comment"
    assert_equal "method_name", m.method_name
    assert_equal ["a", "b", "&c"], m.arguments
    assert_equal "trailing comment", m.trailer
  end
  
end