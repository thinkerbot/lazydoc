require 'lazydoc/utils'

module Lazydoc
  class Attribute
    include Utils
    
    # A back-reference to the Document that registered self
    attr_accessor :document
    
    # An array of comment fragments organized into lines
    attr_reader :content

    # The subject of the comment
    attr_accessor :subject

    def initialize(document=nil)
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
    
    # Parses the input string into content.  Takes a string or
    # a StringScanner and returns self.
    #
    #   comment_string = %Q{
    #   # comments spanning multiple
    #   # lines are collected
    #   #
    #   #   while indented lines
    #   #   are preserved individually
    #   #    
    #
    #   # this line is not parsed
    #   }
    #
    #   a = Attribute.new.parse(comment_string)
    #   a.content   
    #   # => [
    #   # ['comments spanning multiple', 'lines are collected'],
    #   # [''],
    #   # ['  while indented lines'],
    #   # ['  are preserved individually'],
    #   # [''],
    #   # []]
    #
    # Parsing may be manually ended by providing a block; parse yields
    # each line fragment to the block and stops parsing when the block
    # returns true.
    #
    #   a = Attribute.new.parse(comment_string) {|frag| frag.strip.empty? }
    #   a.content   
    #   # => [
    #   # ['comments spanning multiple', 'lines are collected']]
    #
    def parse(str)
      scanner = case str
      when StringScanner then str
      when String then StringScanner.new(str)
      else raise TypeError, "can't convert #{str.class} into StringScanner or String"
      end

      self.content.clear
      while scanner.scan(/\r?\n?[ \t]*#[ \t]?(([ \t]*).*?)\r?$/)
        fragment = scanner[1]
        indent = scanner[2]
      
        # collect continuous description line
        # fragments and join into a single line
        if block_given? && yield(fragment)
          break
        else
          categorize(fragment, indent) {|f| push(f) }
        end
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
  
    # Returns subject or an empty string if subject is nil.
    def to_s
      resolve
      subject.to_s
    end
  end
end
