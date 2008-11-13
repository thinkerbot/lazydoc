require 'lazydoc/document'

module Lazydoc
  autoload(:Attributes, 'lazydoc/attributes')
  
  # A regexp matching an attribute start or end.  After a match:
  #
  # $1:: const_name
  # $3:: key
  # $4:: end flag
  #
  ATTRIBUTE_REGEXP = /([A-Z][A-z]*(::[A-Z][A-z]*)*)?::([a-z_]+)(-?)/

  # A regexp matching constants from the ATTRIBUTE_REGEXP leader
  CONSTANT_REGEXP = /#.*?([A-Z][A-z]*(::[A-Z][A-z]*)*)?$/
  
  # A regexp matching a caller line, to extract the calling file
  # and line number.  After a match:
  #
  # $1:: file
  # $3:: line number (as a string, obviously)
  #
  # Note that line numbers in caller start at 1, not 0.
  CALLER_REGEXP = /^(([A-z]:)?[^:]+):(\d+)/
  
  module_function
  
  # A hash of (source_file, lazydoc) pairs tracking the
  # Lazydoc instance for the given source file.
  def registry
    @registry ||= []
  end
  
  # Returns the lazydoc in registry for the specified source file.
  # If no such lazydoc exists, one will be created for it.
  def [](source_file)
    source_file = File.expand_path(source_file.to_s)
    lazydoc = registry.find {|doc| doc.source_file == source_file }
    if lazydoc == nil
      lazydoc = Document.new(source_file)
      registry << lazydoc
    end
    lazydoc
  end

  # Register the specified line numbers to the lazydoc for source_file.
  # Returns a comment_class instance corresponding to the line.
  def register(source_file, line_number, comment_class=Comment)
    Lazydoc[source_file].register(line_number, comment_class)
  end
  
  # Resolves all lazydocs which include the specified code comments.
  def resolve_comments(comments)
    registry.each do |doc|
      next if (comments & doc.comments).empty?
      doc.resolve
    end
  end
  
  # Scans the specified file for attributes keyed by key and stores 
  # the resulting comments in the source_file lazydoc. Returns the
  # lazydoc.
  def scan_doc(source_file, key)
    lazydoc = nil
    scan(File.read(source_file), key) do |const_name, attr_key, comment|
      lazydoc = self[source_file] unless lazydoc
      lazydoc[const_name][attr_key] = comment
    end
    lazydoc
  end
  
  # Scans the string or StringScanner for attributes matching the key
  # (keys may be patterns, they are incorporated into a regexp). Yields 
  # each (const_name, key, value) triplet to the mandatory block and
  # skips regions delimited by the stop and start keys <tt>:-</tt> 
  # and <tt>:+</tt>.
  #
  #   str = %Q{
  #   # Const::Name::key value
  #   # ::alt alt_value
  #   #
  #   # Ignored::Attribute::not_matched value
  #   # :::-
  #   # Also::Ignored::key value
  #   # :::+
  #   # Another::key another value
  #
  #   Ignored::key value
  #   }
  #
  #   results = []
  #   Lazydoc.scan(str, 'key|alt') do |const_name, key, value|
  #     results << [const_name, key, value]
  #   end
  #
  #   results    
  #   # => [
  #   # ['Const::Name', 'key', 'value'], 
  #   # ['', 'alt', 'alt_value'], 
  #   # ['Another', 'key', 'another value']]
  #
  # Returns the StringScanner used during scanning.
  def scan(str, key) # :yields: const_name, key, value
    scanner = case str
    when StringScanner then str
    when String then StringScanner.new(str)
    else raise TypeError, "can't convert #{str.class} into StringScanner or String"
    end

    regexp = /^(.*?)::(:-|#{key})/
    while !scanner.eos?
      break if scanner.skip_until(regexp) == nil

      if scanner[2] == ":-"
        scanner.skip_until(/:::\+/)
      else
        next unless scanner[1] =~ CONSTANT_REGEXP
        key = scanner[2]
        yield($1.to_s, key, scanner.matched.strip) if scanner.scan(/[ \r\t].*$|$/)
      end
    end
  
    scanner
  end

  # Parses constant attributes from the string or StringScanner.  Yields 
  # each (const_name, key, comment) triplet to the mandatory block 
  # and skips regions delimited by the stop and start keys <tt>:-</tt> 
  # and <tt>:+</tt>.
  #
  #   str = %Q{
  #   # Const::Name::key subject for key
  #   # comment for key
  #
  #   # :::-
  #   # Ignored::key value
  #   # :::+
  #
  #   # Ignored text before attribute ::another subject for another
  #   # comment for another
  #   }
  #
  #   results = []
  #   Lazydoc.parse(str) do |const_name, key, comment|
  #     results << [const_name, key, comment.subject, comment.to_s]
  #   end
  #
  #   results    
  #   # => [
  #   # ['Const::Name', 'key', 'subject for key', 'comment for key'], 
  #   # ['', 'another', 'subject for another', 'comment for another']]
  #
  # Returns the StringScanner used during scanning.
  def parse(str) # :yields: const_name, key, comment
    scanner = case str
    when StringScanner then str
    when String then StringScanner.new(str)
    else raise TypeError, "can't convert #{str.class} into StringScanner or String"
    end
    
    scan(scanner, '[a-z_]+') do |const_name, key, value|
      comment = Comment.parse(scanner, false) do |line|
        if line =~ ATTRIBUTE_REGEXP
          # rewind to capture the next attribute unless an end is specified.
          scanner.unscan unless $4 == '-' && $3 == key && $1.to_s == const_name
          true
        else false
        end
      end
      comment.subject = value
      yield(const_name, key, comment)
    end
  end
  
  def usage(path, cols=80)
    scanner = StringScanner.new(File.read(path))
    scanner.scan(/^#!.*?$/)
    Comment.parse(scanner, false).wrap(cols, 2).strip
  end
end