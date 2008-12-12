module Lazydoc
  
  # A special type of self-resolving Comment that whose to_s returns the
  # trailer, or an empty string if trailer is nil.
  #
  #   t = Trailer.new
  #   t.subject = "def method  # trailer string"
  #   t.to_s               # => "trailer string"
  #
  class Trailer < Comment
    
    # Self-resolves and returns trailer, or an empty 
    # string if trailer is nil.
    def to_s
      resolve
      trailer.to_s
    end
  end
end