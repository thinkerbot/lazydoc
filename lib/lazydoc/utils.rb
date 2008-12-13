require 'strscan'

module Lazydoc
  module Utils
    module_function
    
    # Scan determines if and how to add a line fragment to a comment and
    # yields the appropriate fragments to the block.  Returns true if
    # fragments are yielded and false otherwise.  
    #
    # Content may be built from an array of lines using scan like so:
    #
    #   lines = [
    #     "# comments spanning multiple",
    #     "# lines are collected",
    #     "#",
    #     "#   while indented lines",
    #     "#   are preserved individually",
    #     "#    ",
    #     "not a comment line",
    #     "# skipped since the loop breaks",
    #     "# at the first non-comment line"]
    #
    #   c = Comment.new
    #   lines.each do |line|
    #     break unless Comment.scan(line) do |fragment|
    #       c.push(fragment)  
    #     end
    #   end
    #
    #   c.content   
    #   # => [
    #   # ['comments spanning multiple', 'lines are collected'],
    #   # [''],
    #   # ['  while indented lines'],
    #   # ['  are preserved individually'],
    #   # [''],
    #   # []]
    #
    def scan(line) # :yields: fragment
      return false unless line =~ /^[ \t]*#[ \t]?(([ \t]*).*?)\r?$/
      categorize($1, $2) do |fragment|
        yield(fragment)
      end
      true
    end
    
    # Parses an argument string (anything following the method name in a
    # standard method definition, including parenthesis, comments, default
    # values, etc) into an array of strings.
    #
    #   Method.parse_args("(a, b='default', *c, &block)")  
    #   # => ["a", "b='default'", "*c", "&block"]
    #
    # Note the %-syntax for strings and arrays is not fully supported,
    # ie %w, %Q, %q, etc. may not parse correctly.  The same is true
    # for multiline argument strings.
    def scan_args(str)
      scanner = case str
      when StringScanner then str
      when String then StringScanner.new(str)
      else raise TypeError, "can't convert #{str.class} into StringScanner or String"
      end
      str = scanner.string
      
      # skip whitespace and leading LPAREN
      scanner.skip(/\s*\(?\s*/) 
      
      args = []
      brakets = braces = parens = 0
      start = scanner.pos
      broke = while scanner.skip(/.*?['"#,\(\)\{\}\[\]]/)
        pos = scanner.pos - 1
        
        case str[pos]
        when ?,,nil
          # skip if in brakets, braces, or parenthesis
          next if parens > 0 || brakets > 0 || braces > 0
          
          # ok, found an arg
          args << str[start, pos-start].strip
          start = pos + 1
        
        when ?# then break(true)                # break on a comment
        when ?' then skip_quote(scanner, /'/)   # parse over quoted strings
        when ?" then skip_quote(scanner, /"/)   # parse over double-quoted string
          
        when ?( then parens += 1                # for brakets, braces, and parenthesis
        when ?)                                 # simply track the nesting EXCEPT for
          break(true) if parens == 0            # RPAREN.  If the closing parenthesis
          parens -= 1                           # is found, break.
        when ?[ then braces += 1
        when ?] then braces -= 1
        when ?{ then brakets += 1
        when ?} then brakets -= 1
        end
      end
      
      # parse out the final arg.  if the loop broke (ie 
      # a comment or the closing parenthesis was found) 
      # then the end position is determined by the 
      # scanner, otherwise take all that remains
      pos = broke ? scanner.pos-1 : str.length
      args << str[start, pos-start].strip

      args
    end
    
    # Scans a stripped trailing comment off the input.  Returns nil for 
    # strings without a trailing comment.
    #
    #   Comment.scan_trailer "str with # trailer"           # => "trailer"
    #   Comment.scan_trailer "'# in str' # trailer"         # => "trailer"
    #   Comment.scan_trailer "str with without trailer"     # => nil
    # 
    # Note the %Q and %q syntax for defining strings is not supported
    # within the leader and may not parse correctly:
    #
    #   Comment.scan_trailer "%Q{# in str} # trailer"       # => "in str} # trailer"
    #
    # Accepts Strings or a StringScanner.
    def scan_trailer(str)
      scanner = case str
      when StringScanner then str
      when String then StringScanner.new(str)
      else raise TypeError, "can't convert #{str.class} into StringScanner or String"
      end

      args = []
      brakets = braces = parens = 0
      start = scanner.pos
      while scanner.skip(/.*?['"#]/)
        pos = scanner.pos - 1
        
        case str[pos]
        when ?# then return scanner.rest.strip     # return the trailer
        when ?' then skip_quote(scanner, /'/)      # parse over quoted strings
        when ?" then skip_quote(scanner, /"/)      # parse over double-quoted string
        end
      end
      
      return nil
    end
    
    # Splits a line of text along whitespace breaks into fragments of cols
    # width.  Tabs in the line will be expanded into tabsize spaces; 
    # fragments are rstripped of whitespace.
    # 
    #   Comment.wrap("some line that will wrap", 10)       # => ["some line", "that will", "wrap"]
    #   Comment.wrap("     line that will wrap    ", 10)   # => ["     line", "that will", "wrap"]
    #   Comment.wrap("                            ", 10)   # => []
    #
    # The wrapping algorithm is slightly modified from:
    # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
    def wrap(line, cols=80, tabsize=2)
      line = line.gsub(/\t/, " " * tabsize) unless tabsize == nil
      line.gsub(/(.{1,#{cols}})( +|$\r?\n?)|(.{1,#{cols}})/, "\\1\\3\n").split(/\s*?\n/)
    end
    
    # helper method to skip to the next non-escaped instance
    # matching the quote regexp (/'/ or /"/).
    def skip_quote(scanner, regexp)
      scanner.skip_until(regexp)
      scanner.skip_until(regexp) while scanner.string[scanner.pos-2] == ?\\
    end
    
    # utility method used to by resolve to find the index
    # of a line matching a regexp line_number.
    def match_index(regexp, lines)
      lines.each_with_index do |line, index|
        return index if line =~ regexp
      end
      nil
    end
    
    # utility method used by scan to categorize and yield
    # the appropriate objects to add the fragment to a
    # comment
    def categorize(fragment, indent) # :nodoc:
      case
      when fragment == indent
        # empty comment line
        yield [""]
        yield []
      when indent.empty?
        # continuation line
        yield fragment.rstrip
      else 
        # indented line
        yield [fragment.rstrip]
        yield []
      end
    end
  end
end