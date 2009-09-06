class AttributesTest
  module Example
    class Register
      
      lazy_attr :two, :method_two
      
      register___(:method_two)
      # method two comment
      def methods_two
      end
    end
  end
end