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
    
    # Builds the content of self by parsing comments up from line_number.
    # Whitespace lines between line_number and the preceding comment are
    # skipped.  Previous content is overridden.  Returns self.
    #
    #   document = %Q{
    #   module Sample
    #
    #     # this is the content of the comment
    #     # for method_one
    #     def method_one
    #     end
    # 
    #     # this is the content of the comment
    #     # for method_two
    #
    #     def method_two
    #     end
    #   end}
    #
    #   c = Comment.new 4
    #   c.parse_up(document)
    #   c.comment      # => "this is the content of the comment for method_one"
    #
    # The input may be a String or StringScanner and, for optimal parsing of
    # multiple comments from the same document, may also take an array of lines
    # representing the input split along newline boundaries.
    #
    # ==== Stop Block
    # 
    # A block may be provided to determine when to stop parsing comment
    # content.  When the block returns true, parsing stops.
    #
    #   c = Comment.new 4
    #   c.parse_up(document) {|line| line =~ /# this is/ }
    #   c.comment      # => "for method_one"
    #
    # ==== Dynamic Line Numbers
    #
    # The line_number used by parse_up may be determined dynamically from
    # the input by setting line_number to a Regexp and Proc. In the case
    # of a Regexp, the first line matching the regexp is used:
    #
    #   c = Comment.new(/def method/)
    #   c.parse_up(document)
    #   c.line_number  # => 4
    #   c.comment      # => "this is the content of the comment for method_one"
    #
    # Procs are called with lines and are expected to return the
    # actual line number.  
    #
    #   c = Comment.new lambda {|scanner, lines| 9 }
    #   c.parse_up(document)
    #   c.line_number  # => 9
    #   c.comment      # => "this is the content of the comment for method_two"
    #
    # As shown in the examples, the dynamically determined line_number
    # overwrites the Regexp or Proc.
    def parse_up(str, lines=nil, skip_subject=true)
      parse(str, lines) do |n, comment_lines|
        # remove whitespace lines
        n -= 1 if skip_subject
        n -= 1 while n >=0 && comment_lines[n].strip.empty?

        # put together the comment
        while n >= 0
          line = comment_lines[n]
          break if block_given? && yield(line)
          break unless prepend(line)
          n -= 1
        end
      end
    end
    
    # Like parse_up but builds the content of self by parsing comments down
    # from line_number.  Parsing begins immediately after line_number (no
    # whitespace lines are skipped).  Previous content is overridden.
    # Returns self.
    #
    #   document = %Q{
    #   # == Section One
    #   # documentation for section one
    #   #   'with' + 'indentation'
    #   #
    #   # == Section Two
    #   # documentation for section two
    #   }
    #
    #   c = Comment.new 1
    #   c.parse_down(document) {|line| line =~ /Section Two/}
    #   c.comment      # => "documentation for section one\n  'with' + 'indentation'"
    #
    #   c = Comment.new /Section Two/
    #   c.parse_down(document)
    #   c.line_number  # => 5
    #   c.comment      # => "documentation for section two"
    #
    def parse_down(str, lines=nil, skip_subject=true)
      parse(str, lines) do |n, comment_lines|
        # skip the subject line
        n += 1 if skip_subject
        
        # put together the comment
        while line = comment_lines[n]
          break if block_given? && yield(line)
          break unless append(line)
          n += 1
        end
      end
    end
    
    # Resolves the document for self, if set.
    def resolve(str=nil, force=false)
      document.resolve(str, force) if document
      self
    end
  
    # Removes leading and trailing lines from content that are
    # empty or whitespace.  Returns self.
    def trim
      content.shift while !content.empty? && (content[0].empty? || content[0].join.strip.empty?)
      content.pop   while !content.empty? && (content[-1].empty? || content[-1].join.strip.empty?)
      self
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
    
    # True if to_s is empty.
    def empty?
      to_s.empty?
    end
    
    # Self-resolves and returns comment.
    def to_s
      resolve
      comment
    end
    
    private
    
    # helper standardizing the shared code of parse up/down
    def parse(str, lines) # :nodoc:
      scanner = convert_to_scanner(str)
      lines ||= split_lines(scanner.string)
    
      # resolve late-evaluation line numbers
      n = case line_number
      when nil then determine_line_number(scanner)
      when Regexp then scan_index(scanner, line_number)
      when Proc then line_number.call(scanner, lines)
      else line_number
      end
     
      # do nothing unless a line number was found
      unless n.kind_of?(Integer)
        raise "invalid dynamic line number: #{line_number.inspect}"
      end
        
      # update negative line numbers
      n += lines.length if n < 0
      unless n < lines.length
        raise RangeError, "line_number outside of lines: #{n} (#{lines.length})"
      end
    
      self.line_number = n
      self.content.clear
      yield(n, lines)
      
      self
    end
  end
end
