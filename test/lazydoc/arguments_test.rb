require 'test/unit'
require 'lazydoc/document'

class ArgumentsTest < Test::Unit::TestCase
  include Lazydoc
  
  def test_arguments_documentation
    a = Arguments.new
    a.subject = "def method(a, b='default', *c, &d)"
    assert_equal "A B='default' C...", a.to_s
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_formatted_arguments
    a = Arguments.new
    a.subject = "def method(a, b='default', *c, &d)"
    assert_equal ['a', "b='default'", '*c', '&d'], a.arguments
    assert_equal "A B='default' C...", a.to_s
  end
  
  def test_to_s_returns_empty_string_for_empty_args
    a = Arguments.new
    assert_equal [], a.arguments
    assert_equal "", a.to_s
  end
  
  class MockDocumentForToS
    def initialize(comment)
      @c = comment
    end
    
    def resolve(str=nil)
      @c.subject = "def method(a, b='default', *c, &d)"
    end
  end
  
  def test_to_s_resolves_self
    a = Arguments.new
    a.document = MockDocumentForToS.new(a)
    
    assert_equal [], a.arguments
    assert_equal "A B='default' C...", a.to_s
  end
end