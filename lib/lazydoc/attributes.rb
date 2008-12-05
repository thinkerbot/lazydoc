require 'lazydoc'

module Lazydoc
  # Attributes adds methods to declare class-level accessors for Lazydoc 
  # attributes.  The source_file for the class is by default set to the
  # file where Attributes extends a class (if you decide to include
  # Attributes, source_file has to be specified manually):
  #
  #   # ConstName::key value
  #   class ConstName
  #     extend Lazydoc::Attributes
  #
  #     lazy_attr :key
  #   end
  #
  #   ConstName.source_file            # =>  __FILE__
  #   ConstName::key.subject           # => 'value'
  # 
  module Attributes

    # The source_file for self.  By default set to the file where
    # Attributes is included in or extends a class.
    attr_accessor :source_file
    
    def self.extended(base)
      caller[1] =~ CALLER_REGEXP
      base.source_file ||= $1
    end

    # Returns the lazydoc for source_file
    def lazydoc(resolve=true)
      lazydoc = Lazydoc[source_file]
      lazydoc.resolve if resolve
      lazydoc
    end

    # Creates a lazy attribute accessor for the specified attribute.
    def lazy_attr(key, attribute=key)
      instance_eval %Q{
def #{key}
  lazydoc[to_s]['#{attribute}'] ||= Lazydoc::Comment.new
end

def #{key}=(comment)
  Lazydoc[source_file][to_s]['#{attribute}'] = comment
end}
    end
    
    # Alias for Document#register___
    def register___(comment_class=Method)
      lazydoc(false).register___(comment_class, 1)
    end
  end
end
