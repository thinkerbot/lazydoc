class ReadMeTestA
  extend Lazydoc::Attributes
  lazy_attr(:one, :method_one)
  lazy_register(:method_one)
  
  # documentation for method one
  def method_one; end
end

class ReadMeTestB < ReadMeTestA
end

class ReadMeTestC < ReadMeTestB
  # overriding documentation for method one
  def method_one; end
end
