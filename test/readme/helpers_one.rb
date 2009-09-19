class Helpers
  extend Lazydoc::Attributes

  lazy_register(:method_one)
  
  # method_one is registered whenever it
  # gets defined
  def method_one(a, b='str', &c)
  end
  
  # register_caller will register the line
  # that *calls* method_two (see below)
  def method_two
    Lazydoc.register_caller
  end
end

# *THIS* is the line that gets
# registered by method_two
Helpers.const_attrs[:method_two] = Helpers.new.method_two
