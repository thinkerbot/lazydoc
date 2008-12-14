module Lazydoc
  
  # A special type of self-resolving Comment whose to_s returns the
  # subject, or an empty string if subject is nil.
  #
  # s = Subject.new
  # s.subject = "subject string"
  # s.to_s # => "subject string"
  #
  class Subject < Comment
    
    # Self-resolves and returns subject, or an empty
    # string if subject is nil.
    def to_s
      resolve
      subject.to_s
    end
  end
end