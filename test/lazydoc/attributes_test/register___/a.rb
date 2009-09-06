class AttributesTest
  module Example
    class Register
      extend Lazydoc::Attributes
    
      lazy_attr :one, :method_one
      
      const_attrs[:method_one] = register___
      # method one comment
      def method_one
      end
    end
  end
end