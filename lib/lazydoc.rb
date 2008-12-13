require 'lazydoc/document'

module Lazydoc
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
    Document.scan(File.read(source_file), key) do |const_name, attr_key, comment|
      document = self[source_file] unless document
      document[const_name][attr_key] = comment
    end
    document
  end
  
  # Parses the usage for a file, ie the first comment in the file 
  # following the bang line.
  def usage(path, cols=80)
    scanner = StringScanner.new(File.read(path))
    scanner.scan(/^#!.*?$/)
    Attribute.new.parse(scanner).wrap(cols, 2).strip
  end
end