require 'lazydoc/document'

module Lazydoc
  autoload(:Attributes, 'lazydoc/attributes')
  
  # A regexp matching an attribute start or end.  After a match:
  #
  #   $1:: const_name
  #   $3:: key
  #   $4:: end flag
  #
  ATTRIBUTE_REGEXP = /([A-Z][A-z]*(::[A-Z][A-z]*)*)?::([a-z_]+)(-?)/

  # A regexp matching constants from the ATTRIBUTE_REGEXP leader
  CONSTANT_REGEXP = /#.*?([A-Z][A-z]*(::[A-Z][A-z]*)*)?$/
  
  # A regexp matching a caller line, to extract the calling file
  # and line number.  After a match:
  #
  #   $1:: file
  #   $3:: line number (as a string, obviously)
  #
  # Note that line numbers in caller start at 1, not 0.
  CALLER_REGEXP = /^(([A-z]:)?[^:]+):(\d+)/
  
  module_function
  
  # An array of documents registered with Lazydoc.
  def registry
    @registry ||= []
  end
  
  # Returns the Document in registry for the specified source file.
  # If no such Document exists, one will be created for it.
  def [](source_file)
    source_file = File.expand_path(source_file.to_s)
    lazydoc = registry.find {|doc| doc.source_file == source_file }
    if lazydoc == nil
      lazydoc = Document.new(source_file)
      registry << lazydoc
    end
    lazydoc
  end

  # Register the line number to the Document for source_file and
  # returns the corresponding comment.
  def register(source_file, line_number, comment_class=Comment)
    Lazydoc[source_file].register(line_number, comment_class)
  end
  
  # Registers the method at the specified index in the call stack to
  # the file where the method was called.  Using the default index of
  # 1, register_caller registers the caller of the method where 
  # register_caller is called.  For instance:
  #
  #   module Sample
  #     module_function
  #     def method
  #       Lazydoc.register_caller
  #     end
  #   end
  #
  #   # this is the line that gets registered
  #   Sample.method
  #
  def register_caller(comment_class=Comment, caller_index=1)
    caller[caller_index] =~ CALLER_REGEXP
    Lazydoc[$1].register($3.to_i - 1, comment_class)
  end
  
  # Scans the specified file for attributes keyed by key and stores 
  # the resulting comments in the Document for source_file. Returns 
  # the Document.
  def scan_doc(source_file, key)
    document = nil
    scan(File.read(source_file), key) do |const_name, attr_key, comment|
      document = self[source_file] unless document
      document[const_name][attr_key] = comment
    end
    document
  end
  
  # Scans the string or StringScanner for attributes matching the key
  # (keys may be patterns; they are incorporated into a regexp).
  # Regions delimited by the stop and start keys <tt>:::-</tt> and 
  # <tt>:::+</tt> are skipped. Yields each (const_name, key, value) 
  # triplet to the block.
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

  # Parses constant attributes from the string or StringScanner.  Regions 
  # delimited by the stop and start keys <tt>:::-</tt> and <tt>:::+</tt> 
  # are skipped.  Yields each (const_name, key, value) triplet to the block.
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
  
  # Parses the usage for a file, ie the first comment in the file 
  # following the bang line.
  def usage(path, cols=80)
    scanner = StringScanner.new(File.read(path))
    scanner.scan(/^#!.*?$/)
    Comment.parse(scanner, false).wrap(cols, 2).strip
  end
end