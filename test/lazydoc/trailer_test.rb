require 'test/unit'
require 'lazydoc/document'

class TrailerTest < Test::Unit::TestCase
  include Lazydoc
  
  def test_trailer_documentation
    t = Trailer.new
    t.subject = "def method  # trailer string"
    assert_equal "trailer string", t.to_s
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_trailer
    t = Trailer.new
    t.subject = "leader # trailer"
    assert_equal "trailer", t.trailer
    assert_equal "trailer", t.to_s
  end
  
  def test_to_s_returns_empty_string_for_nil_trailer
    t = Trailer.new
    assert_equal nil, t.trailer
    assert_equal "", t.to_s
  end
  
  class MockDocumentForToS
    def initialize(comment)
      @c = comment
    end
    
    def resolve
      @c.subject = "leader # trailer"
    end
  end
  
  def test_to_s_resolves_self
    t = Trailer.new
    t.document = MockDocumentForToS.new(t)
    
    assert_equal nil, t.trailer
    assert_equal "trailer", t.to_s
  end
end