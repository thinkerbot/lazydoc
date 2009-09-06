class AttributesTest
  module Example
    class Register
      
      lazy_attr :two, :method_two
      
      const_attrs[:method_two] = register___
      # method two comment
      def methods_two
      end
    end
  end
end