require 'strscan'

module Lazydoc
  
  # A number of utility methods used by Comment, factored out for
  # testing and re-use.
  module Utils
    module_function
    
    def split_lines(str)
      (str.empty? ? [""] : str.split(/\r?\n/))
    end
    
    # Converts str to a StringScanner (or returns str if it already is
    # a StringScanner).  Raises a TypeError if str is not a String
    # or a StringScanner.
    def convert_to_scanner(str)
      case str
      when String then StringScanner.new(str)
      when StringScanner then str
      else raise TypeError, "can't convert #{str.class} into StringScanner"
      end
    end
    
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
    #     break unless Utils.scan(line) do |fragment|
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
    #   Utils.parse_args("(a, b='default', *c, &block)")  
    #   # => ["a", "b='default'", "*c", "&block"]
    #
    # Note the %-syntax for strings and arrays is not fully supported,
    # ie %w, %Q, %q, etc. may not parse correctly.  The same is true
    # for multiline argument strings.
    #
    # Accepts a String or a StringScanner.
    def scan_args(str)
      scanner = convert_to_scanner(str)
      str = scanner.string
      
      # skip whitespace and leading LPAREN
      scanner.skip(/\s*\(?\s*/) 
      
      args = []
      brakets = braces = parens = 0
      start = scanner.pos
      broke = false
      while scanner.skip(/.*?['"#,\(\)\{\}\[\]]/)
        pos = scanner.pos - 1
        
        case str[pos]
        when ?,,nil
          # skip if in brakets, braces, or parenthesis
          next if parens > 0 || brakets > 0 || braces > 0
          
          # ok, found an arg
          args << str[start, pos-start].strip
          start = pos + 1
        
        when ?# then broke = true; break        # break on a comment
        when ?' then skip_quote(scanner, /'/)   # parse over quoted strings
        when ?" then skip_quote(scanner, /"/)   # parse over double-quoted string
          
        when ?( then parens += 1                # for brakets, braces, and parenthesis
        when ?)                                 # simply track the nesting EXCEPT for
          if parens == 0                        # RPAREN.  If the closing parenthesis
            broke = true; break
          end
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
      args << str[start, pos-start].strip unless pos == start

      args
    end
    
    # Scans a stripped trailing comment off the input.  Returns nil for 
    # strings without a trailing comment.
    #
    #   Utils.scan_trailer "str with # trailer"           # => "trailer"
    #   Utils.scan_trailer "'# in str' # trailer"         # => "trailer"
    #   Utils.scan_trailer "str with without trailer"     # => nil
    # 
    # Note the %Q and %q syntax for defining strings is not supported
    # within the leader and may not parse correctly:
    #
    #   Utils.scan_trailer "%Q{# in str} # trailer"       # => "in str} # trailer"
    #
    # Accepts a String or a StringScanner.
    def scan_trailer(str)
      scanner = convert_to_scanner(str)

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
    #   Utils.wrap("some line that will wrap", 10)       # => ["some line", "that will", "wrap"]
    #   Utils.wrap("     line that will wrap    ", 10)   # => ["     line", "that will", "wrap"]
    #   Utils.wrap("                            ", 10)   # => []
    #
    # The wrapping algorithm is slightly modified from:
    # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
    def wrap(line, cols=80, tabsize=2)
      line = line.gsub(/\t/, " " * tabsize) unless tabsize == nil
      line.gsub(/(.{1,#{cols}})( +|$\r?\n?)|(.{1,#{cols}})/, "\\1\\3\n").split(/\s*?\n/)
    end
    
    # Returns the line at which scanner currently resides.  The position
    # of scanner is not modified.
    def determine_line_number(scanner)
      scanner.string[0, scanner.pos].count("\n")
    end
    
    # Returns the index of the line where scanner ends up after the first
    # match to regexp (starting at position 0).  The existing position of
    # scanner is not modified by this method.  Returns nil if the scanner
    # cannot match regexp.
    #
    #   scanner = StringScanner.new %Q{zero\none\ntwo\nthree}
    #   Utils.scan_index(scanner, /two/)         # => 2
    #   Utils.scan_index(scanner, /no match/)    # => nil
    #
    def scan_index(scanner, regexp)
      pos = scanner.pos
      scanner.pos = 0
      n = scanner.skip_until(regexp) ? determine_line_number(scanner) : nil
      scanner.pos = pos
      n
    end
    
    # Returns the index of the line in lines matching regexp,
    # or nil if no line matches regexp.
    def match_index(lines, regexp)
      index = 0
      lines.each do |line|
        return index if line =~ regexp
        index += 1
      end
      nil
    end
    
    # helper method to skip to the next non-escaped instance
    # matching the quote regexp (/'/ or /"/).
    def skip_quote(scanner, regexp) # :nodoc:
      scanner.skip_until(regexp)
      scanner.skip_until(regexp) while scanner.string[scanner.pos-2] == ?\\
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