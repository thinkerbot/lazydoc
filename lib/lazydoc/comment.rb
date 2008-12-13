require 'lazydoc/utils'

module Lazydoc
  
  # Comment represents a code comment parsed by Lazydoc.  
  class Comment
    include Utils
    
    # Returns the line number for the subject line, if known.
    # Although normally an integer, line_number may be
    # set to a Regexp or Proc to dynamically determine
    # the subject line during resolve
    attr_accessor :line_number
    
    # A back-reference to the Document that registered self
    attr_accessor :document
    
    # An array of comment fragments organized into lines
    attr_reader :content

    # The subject of the comment
    attr_accessor :subject

    def initialize(line_number=nil, document=nil)
      @line_number = line_number
      @document = document
      @content = []
      @subject = nil
    end
    
    # Alias for subject
    def value
      subject
    end
    
    # Alias for subject=
    def value=(value)
      self.subject = value
    end
    
    # Returns the comment trailing the subject.
    def trailer
      subject ? scan_trailer(subject) : nil
    end

    # Pushes the fragment onto the last line of content.  If the
    # fragment is an array itself then it will be pushed onto
    # content as a new line.
    #
    #   c = Comment.new
    #   c.push "some line"
    #   c.push "fragments"
    #   c.push ["a", "whole", "new line"]
    #
    #   c.content         
    #   # => [
    #   # ["some line", "fragments"], 
    #   # ["a", "whole", "new line"]]
    #
    def push(fragment)
      content << [] if content.empty?
    
      case fragment
      when Array
        if content[-1].empty? 
          content[-1] = fragment
        else
          content.push fragment
        end
      else
         content[-1].push fragment
      end
    end
  
    # Alias for push.
    def <<(fragment)
      push(fragment)
    end
  
    # Scans the comment line using Comment.scan and pushes the appropriate
    # fragments onto self.  Used to build a content by scanning down a set
    # of lines.
    #
    #   lines = [
    #     "# comment spanning multiple",
    #     "# lines",
    #     "#",
    #     "#   indented line one",
    #     "#   indented line two",
    #     "#    ",
    #     "not a comment line"]
    #
    #   c = Comment.new
    #   lines.each {|line| c.append(line) }
    #
    #   c.content 
    #   # => [
    #   # ['comment spanning multiple', 'lines'],
    #   # [''],
    #   # ['  indented line one'],
    #   # ['  indented line two'],
    #   # [''],
    #   # []]
    #
    def append(line)
      scan(line) {|f| push(f) }
    end
  
    # Unshifts the fragment to the first line of content.  If the
    # fragment is an array itself then it will be unshifted onto
    # content as a new line.
    #
    #   c = Comment.new
    #   c.unshift "some line"
    #   c.unshift "fragments"
    #   c.unshift ["a", "whole", "new line"]
    #
    #   c.content         
    #   # => [
    #   # ["a", "whole", "new line"], 
    #   # ["fragments", "some line"]]
    #
    def unshift(fragment)
      content << [] if content.empty?
    
      case fragment
      when Array
        if content[0].empty? 
          content[0] = fragment
        else
          content.unshift fragment
        end
      else
         content[0].unshift fragment
      end
    end
  
    # Scans the comment line using Comment.scan and unshifts the appropriate 
    # fragments onto self.  Used to build a content by scanning up a set of
    # lines.
    #
    #   lines = [
    #     "# comment spanning multiple",
    #     "# lines",
    #     "#",
    #     "#   indented line one",
    #     "#   indented line two",
    #     "#    ",
    #     "not a comment line"]
    #
    #   c = Comment.new
    #   lines.reverse_each {|line| c.prepend(line) }
    #
    #   c.content 
    #   # => [
    #   # ['comment spanning multiple', 'lines'],
    #   # [''],
    #   # ['  indented line one'],
    #   # ['  indented line two'],
    #   # ['']]
    #
    def prepend(line)
      scan(line) {|f| unshift(f) }
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
    def resolve(str=nil)
      document.resolve(str) if document
      self
    end
  
    # Removes leading and trailing lines from content that are
    # empty or whitespace.  Returns self.
    def trim
      content.shift while !content.empty? && (content[0].empty? || content[0].join.strip.empty?)
      content.pop   while !content.empty? && (content[-1].empty? || content[-1].join.strip.empty?)
      self
    end
  
    # True if all lines in content are empty.
    def empty?
      !content.find {|line| !line.empty?}
    end
    
    # Returns content as a string where line fragments are joined by
    # fragment_sep and lines are joined by line_sep. 
    def comment(fragment_sep=" ", line_sep="\n", strip=true)
      lines = content.collect {|line| line.join(fragment_sep)}
    
      # strip leading an trailing whitespace lines
      if strip
        lines.shift while !lines.empty? && lines[0].empty?
        lines.pop while !lines.empty? && lines[-1].empty?
      end
    
      line_sep ? lines.join(line_sep) : lines
    end

    # Like comment, but wraps the content to the specified number of cols
    # and expands tabs to tabsize spaces.
    def wrap(cols=80, tabsize=2, line_sep="\n", fragment_sep=" ", strip=true)
      lines = super(comment(fragment_sep, "\n", strip), cols, tabsize)
      line_sep ? lines.join(line_sep) : lines
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
