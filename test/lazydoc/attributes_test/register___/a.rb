class AttributesTest
  module Example
    class Register
      extend Lazydoc::Attributes
    
      lazy_attr :one, :method_one
      
      register___(:method_one)
      # method one comment
      def method_one
      end
    end
  end
end