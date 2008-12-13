module Lazydoc
  class Attribute < Comment
    
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
      
      # benchmarks indicate this is faster than a scanning
      # approach for both long and short strings
      self.line_number = scanner.string[0, scanner.pos].count("\n")
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
  
    # Returns subject or an empty string if subject is nil.
    def to_s
      resolve
      subject.to_s
    end
  end
end
