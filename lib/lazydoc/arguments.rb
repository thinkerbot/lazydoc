module Lazydoc
  
  # A special type of self-resolving Method that whose to_s returns arguments
  # formatted for the command line.
  #
  #   a = Arguments.new
  #   a.subject = "def method(a, b='default', *c, &d)"
  #   a.to_s            # => "A B='default' C..."
  #
  class Arguments < Method
    
    # Self-resolves and returns arguments formatted for the command line.
    def to_s
      resolve
      
      arguments.collect do |arg|
        case arg 
        when /^&/ then nil 
        when /^\*/ then "#{arg[1..-1].upcase }..."
        when /^(.*?)=(.*)$/ then "#{$1.upcase}=#{$2}"
        else arg.upcase
        end
      end.compact.join(' ')
    end
  end
end