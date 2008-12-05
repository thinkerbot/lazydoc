require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'lazydoc'
require 'tempfile'

# Sample::key <value>
# This is the comment content.  A content
# string can span multiple lines...
#
#   code.is_allowed
#   much.as_in RDoc
#
# and stops at the next non-comment
# line, the next constant attribute,
# or an end key
class Sample
  extend Lazydoc::Attributes
  self.source_file = __FILE__
  
  lazy_attr :key

  # comment content for a code comment
  # may similarly span multiple lines
  def method_one
  end
end

class ReadmeTest < Test::Unit::TestCase
  
  #
  # documentation test
  #

  def test_description_documentation 
    comment = Sample::key
    assert_equal "<value>", comment.subject

    expected = [
    ["This is the comment content.  A content", "string can span multiple lines..."],
    [""],
    ["  code.is_allowed"],
    ["  much.as_in RDoc"],
    [""],
    ["and stops at the next non-comment", "line, the next constant attribute,", "or an end key"]]
    assert_equal expected, comment.content

    expected = %q{
..............................
This is the comment content.
A content string can span
multiple lines...

  code.is_allowed
  much.as_in RDoc

and stops at the next
non-comment line, the next
constant attribute, or an end
key
..............................
}
    assert_equal expected, "\n#{'.' * 30}\n" + comment.wrap(30) + "\n#{'.' * 30}\n"

    doc = Sample.lazydoc.reset
    comment = doc.register(/method_one/)

    doc.resolve
    assert_equal "  def method_one", comment.subject
    assert_equal [["comment content for a code comment", "may similarly span multiple lines"]], comment.content
    
    tempfile = Tempfile.new('readme_test')
    tempfile << %Q{
class Helpers
  extend Lazydoc::Attributes

  register___
  # method_one is now registered by the 
  # register___ helper.  What's more it's
  # a Method comment, so you have access
  # to arguments and such.
  def method_one(a, b='str', &c)
  end

  # method_two illustrates registration
  # of the line that *calls* method_two
  def method_two
    Lazydoc.register_caller
  end
end

# *THIS* is the line that gets registered
# by method_two
Helpers.new.method_two
}
    tempfile.close
    load(tempfile.path)
    
    doc = Helpers.lazydoc
    doc.resolve
    
    m1 = doc.comments[0]
    assert_equal "method_one", m1.method_name
    assert_equal ["a", "b='str'", "&c"], m1.arguments
    assert_equal "method_one is now registered by the register___ helper.  What's more i", m1.to_s[0, 70]
    
    comment = doc.comments[1]
    assert_equal "Helpers.new.method_two", comment.subject
    assert_equal "*THIS* is the line that gets registered by method_two", comment.to_s
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
    assert_equal expected, doc.to_hash {|c| [c.value, c.to_s] } 

    str = %Q{
Const::Name::not_parsed

# :::-
# Const::Name::not_parsed
# :::+
# Const::Name::parsed value
}

    doc = Lazydoc::Document.new
    doc.resolve(str)
    assert_equal({'Const::Name' => {'parsed' => 'value'}}, doc.to_hash {|c| c.value })
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
    assert_equal(expected, doc.to_hash {|comment| [comment.subject, comment.to_s] })
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