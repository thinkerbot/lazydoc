module Lazydoc
  
  # Method represents a code comment for a standard method definition.
  # Methods give access to the method name, the arguments, and the 
  # trailing comment, if present.
  #
  #   sample_method = %Q{
  #   # This is the comment body
  #   def method_name(a, b='default', &c) # trailing comment
  #   end
  #   }
  #
  #   m = Method.parse(sample_method)
  #   m.method_name          # => "method_name"
  #   m.arguments            # => ["a", "b='default'", "&c"]
  #   m.trailer              # => "trailing comment"
  #   m.to_s                 # => "This is the comment body"
  #
  class Method < Comment
    class << self
      
      # Generates a regexp matching a standard definition of the
      # specified method.
      #
      #   m = Method.method_regexp("method")
      #   m =~ "def method"                       # => true
      #   m =~ "def method(with, args, &block)"   # => true
      #   m !~ "def some_other_method"            # => true
      #
      def method_regexp(method_name)
        /^\s*def\s+#{method_name}(\W|$)/
      end
      
      # Parses an argument string (anything following the method name in a
      # standard method definition, including parenthesis/comments/default
      # values etc) into an array of strings.
      #
      #   Method.parse_args("(a, b='default', &block)")  
      #   # => ["a", "b='default'", "&block"]
      #
      # To extract the comment string, pass parse_args a string scanner
      # initialized to the argument string, then match the remainder:
      #
      #   scanner = StringScanner.new("a, b # trailing comment")
      #   Method.parse_args(scanner)              # => ["a", "b"]
      #   scanner.rest =~ Method::TRAILER
      #   $1.to_s                                 # => "trailing comment"
      #   
      # Note the %-syntax for strings and arrays is not fully supported,
      # ie %w, %Q, %q, etc. may not parse correctly.  The same is true
      # for multiline argument strings.
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
    
    # Matches a trailing comment after parse_args.  After the match:
    #
    #   $1:: the stripped trailing comment
    #
    TRAILER = /^\s*#?\s*(.*?)\s*$/
    
    # The resolved method name
    attr_reader :method_name
    
    # An array of the resolved arguments for the method
    attr_reader :arguments
    
    # A comment that follows the method definition
    attr_reader :trailer
    
    def initialize(*args)
      super
      @method_name = nil
      @arguments = []
      @trailer = nil
    end
    
    # Overridden to parse and set the method_name, arguments, and 
    # trailer in addition to setting the subject.
    def subject=(value)
      unless value =~ METHOD_DEF
        raise ArgumentError, "not a method definition: #{value}"
      end
      
      @method_name = $1
      scanner = StringScanner.new($2)
      @arguments = Method.parse_args(scanner)
      scanner.rest =~ TRAILER
      @trailer = $1
      
      super
    end
  end
end
