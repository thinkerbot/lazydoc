module Lazydoc
  class Method < Comment
    class << self
      def regexp(method_name)
        /def \w+(\((.*?)\))?/
      end
      
      def parse_args(str)
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
      
      private
      
      # helper method to skip to the next non-escaped instance
      # matching the quote regexp (/'/ or /"/).
      def skip_quote(scanner, regexp) # :nodoc:
        scanner.skip_until(regexp)
        scanner.skip_until(regexp) while scanner.string[scanner.pos-2] == ?\\
      end
    end
    
    # Matches a standard method definition.  After the match:
    #
    #   $1:: the method name
    #   $2:: the argument string, which may be parsed by parse_args
    #
    METHOD_DEF = /^\s*def (\w+)(.*)$/
    
    # The resolved method name
    attr_reader :method_name
    
    # An array of the resolved arguments for the method
    attr_reader :arguments
    
    # A comment that follows the method definition
    attr_reader :modifier
    
    def initialize(*args)
      super
      @method_name = nil
      @modifier = nil
      @arguments = []
    end
    
    def resolve(lines)
      super
      unless @subject =~ METHOD_DEF
        raise "not a method definition: #{@subject}"
      end
      
      scanner = StringScanner.new($2)
      
      @method_name = $1
      @arguments = Method.parse_args(scanner)
      
      scanner.rest =~ /^\s*#?\s*(.*?)\s*$/
      @modifier = $1
      self
    end
  end
end
