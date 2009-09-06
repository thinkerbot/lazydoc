class AttributesTest
  module Example
    class RegisterMethod
      extend Lazydoc::Attributes
    
      lazy_attr :one, :method_one
      lazy_register(:method_one)
    end
  end
end