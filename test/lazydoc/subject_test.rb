require 'test/unit'
require 'lazydoc/document'

class SubjectTest < Test::Unit::TestCase
  include Lazydoc
  
  def test_subject_documentation
    s = Subject.new
    s.subject = "subject string"
    assert_equal "subject string", s.to_s
  end
  
  #
  # to_s test
  #
  
  def test_to_s_returns_subject
    s = Subject.new
    s.subject = "subject string"
    assert_equal "subject string", s.subject
    assert_equal "subject string", s.to_s
  end
  
  def test_to_s_returns_empty_string_for_nil_subject
    s = Subject.new
    assert_equal nil, s.subject
    assert_equal "", s.to_s
  end
  
  class MockDocumentForToS
    def initialize(comment)
      @c = comment
    end
    
    def resolve
      @c.subject = "subject string"
    end
  end
  
  def test_to_s_resolves_self
    s = Subject.new
    s.document = MockDocumentForToS.new(s)
    
    assert_equal nil, s.subject
    assert_equal "subject string", s.to_s
  end
end