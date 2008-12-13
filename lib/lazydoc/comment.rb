require 'lazydoc/attribute'

module Lazydoc
  
  # Comment represents a code comment parsed by Lazydoc.  
  class Comment < Attribute

    # Returns the line number for the subject line, if known.
    # Although normally an integer, line_number may be
    # set to a Regexp or Proc to dynamically determine
    # the subject line during resolve
    attr_accessor :line_number
  
    # A back-reference to the Document that registered self
    attr_accessor :document
    
    def initialize(line_number=nil, document=nil)
      super()
      @line_number = line_number
      @document = document
    end
  
    # Builds the subject and content of self by parsing str; parse sets
    # the subject to the line at line_number, and parses content up
    # from there.  Any previously set subject and content is overridden.  
    # Returns self.
    #
    #   document = %Q{
    #   module Sample
    #     # this is the content of the comment
    #     # for method_one
    #     def method_one
    #     end
    # 
    #     # this is the content of the comment
    #     # for method_two
    #     def method_two
    #     end
    #   end}
    #
    #   c = Comment.new 4
    #   c.parse(document)
    #   c.subject     # => "  def method_one"
    #   c.content     # => [["this is the content of the comment", "for method_one"]]
    #
    # Parse also accepts an array representing the string split along newline
    # boundaries.
    #
    # ==== Dynamic Line Numbers
    #
    # The line_number used by resolve may be determined dynamically from
    # the input by setting line_number to a Regexp and Proc. In the case
    # of a Regexp, the first line matching the regexp is used:
    #
    #   c = Comment.new(/def method/)
    #   c.parse(document)
    #   c.line_number = 4
    #   c.subject     # => "  def method_one"
    #   c.content     # => [["this is the content of the comment", "for method_one"]]
    #
    # Procs are called with lines and are expected to return the
    # actual line number.  
    #
    #   c = Comment.new lambda {|lines| 9 }
    #   c.parse(document)
    #   c.line_number = 9
    #   c.subject     # => "  def method_two"
    #   c.content     # => [["this is the content of the comment", "for method_two"]]
    #
    # As shown in the examples, the dynamically determined line_number
    # overwrites the Regexp or Proc.
    def parse(str)
      lines = case str
      when Array then str
      else str.split(/\r?\n/)
      end
    
      # resolve late-evaluation line numbers
      n = case line_number
      when Regexp then match_index(line_number, lines)
      when Proc then line_number.call(lines)
      else line_number
      end
     
      # quietly exit if a line number was not found
      return self unless n.kind_of?(Integer)
      
      # update negative line numbers
      n += lines.length if n < 0
      unless n < lines.length
        raise RangeError, "line_number outside of lines: #{n} (#{lines.length})"
      end
      
      self.line_number = n
      self.subject = lines[n]
      self.content.clear
    
      # remove whitespace lines
      n -= 1
      n -= 1 while n >=0 && lines[n].strip.empty?

      # put together the comment
      while n >= 0
        break unless prepend(lines[n])
        n -= 1
      end
     
      self
    end
    
    # Resolves the document for self, if set.
    def resolve
      document.resolve if document
      self
    end
    
    # Self-resolves and returns comment.
    def to_s(fragment_sep=" ", line_sep="\n", strip=true)
      resolve
      comment(fragment_sep, line_sep, strip)
    end
    
    private
  
    # utility method used to by resolve to find the index
    # of a line matching a regexp line_number.
    def match_index(regexp, lines) # :nodoc:
      lines.each_with_index do |line, index|
        return index if line =~ regexp
      end
      nil
    end
  end
end
