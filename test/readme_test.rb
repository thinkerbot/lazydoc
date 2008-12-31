require 'test/unit'
require 'lazydoc'
require 'tempfile'

# Sample::key <value>
# This is the comment content.  A content
# string can span multiple lines...
class Sample
  extend Lazydoc::Attributes
  lazy_attr :key
end

class ReadmeTest < Test::Unit::TestCase
  
  def setup
    Lazydoc::Document.const_attrs.clear
  end
  
  #
  # documentation test
  #

  def test_description_documentation 
    comment = Sample::key
    assert_equal "<value>", comment.value
    assert_equal "This is the comment content.  A content string can span multiple lines...", comment.comment

    expected = %q{
..............................
This is the comment content.
A content string can span
multiple lines...
..............................
}
    thirtydots = "\n#{'.' * 30}\n"
    assert_equal expected, "#{thirtydots}#{comment.wrap(30)}#{thirtydots}"

    tempfile = Tempfile.new('readme_test')
    tempfile << %Q{
class Helpers
  extend Lazydoc::Attributes

  lazy_register(:method_one)
  
  # method_one is registered whenever it
  # gets defined
  def method_one(a, b='str', &c)
  end
  
  # register_caller will register the line
  # that *calls* method_two
  def method_two
    Lazydoc.register_caller
  end
end

# *THIS* is the line that gets
# registered by method_two
Helpers.const_attrs[:method_two] = Helpers.new.method_two

}
    tempfile.close
    load(tempfile.path)
    
    doc = Helpers.lazydoc
    doc.resolve

    one = Helpers.const_attrs[:method_one]
    assert_equal "method_one", one.method_name
    assert_equal ["a", "b='str'", "&c"], one.arguments
    assert_equal "method_one is registered whenever it gets defined", one.to_s
    
    two = Helpers.const_attrs[:method_two]
    assert_equal "Helpers.const_attrs[:method_two] = Helpers.new.method_two", two.subject
    assert_equal "*THIS* is the line that gets registered by method_two", two.to_s

    tempfile = Tempfile.new('readme_test')
    tempfile << %Q{
class Helpers
  lazy_attr(:one, :method_one)
  lazy_attr(:two, :method_two)
end
}
    tempfile.close
    load(tempfile.path)
    
    assert_equal "method_one", Helpers.one.method_name
    assert_equal "Helpers.const_attrs[:method_two] = Helpers.new.method_two", Helpers.two.subject
  end
  
  def test_constant_attributes_usage_documentation
    str = %Q{
# Const::Name::key value for key
# comment for key
# parsed until a 
# non-comment line

# Const::Name::another value for another
# comment for another
# parsed to an end key
# Const::Name::another-
#
# ignored comment
}

    doc = Lazydoc::Document.new
    doc.resolve(str)

    expected = {'Const::Name' => {
     'key' =>     ['value for key', 'comment for key parsed until a non-comment line'],
     'another' => ['value for another', 'comment for another parsed to an end key']
    }}
    assert_equal expected, doc.summarize {|c| [c.value, c.comment] } 

    str = %Q{
Const::Name::not_parsed

# :::-
# Const::Name::not_parsed
# :::+
# Const::Name::parsed value
}

    doc = Lazydoc::Document.new
    doc.resolve(str)
    assert_equal({'Const::Name' => {'parsed' => 'value'}}, doc.summarize {|c| c.value })
  end
  
  def test_startdoc_syntax
    str = %Q{
# :start doc::Const::Name::one hidden in RDoc
# * This line is visible in RDoc.
# :start doc::Const::Name::one-
# 
#-- 
# Const::Name::two
# You can hide attribute comments like this.
# Const::Name::two-
#++
#
# * This line is also visible in RDoc.
}

    doc = Lazydoc::Document.new
    doc.resolve(str)

    expected = {'Const::Name' => {
     'one' => ['hidden in RDoc', '* This line is visible in RDoc.'],
     'two' => ['', 'You can hide attribute comments like this.']
    }}
    assert_equal(expected, doc.summarize {|c| [c.subject, c.comment] })
  end
  
  def test_code_comments_usage_documentation
    str = %Q{
# comment lines for
# the method
def method
end

# as in RDoc, the comment can be
# separated from the method

def another_method
end
}

    doc = Lazydoc::Document.new
    doc.register(3)
    doc.register(9)
    doc.resolve(str)

    expected = [
    ['def method', 'comment lines for the method'],
    ['def another_method', 'as in RDoc, the comment can be separated from the method']]
    assert_equal expected, doc.comments.collect {|c| [c.subject, c.to_s] } 
  end

end