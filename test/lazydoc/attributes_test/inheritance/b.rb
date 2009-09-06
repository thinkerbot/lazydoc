class AttributesTest
  module Example
    class InheritanceA
      extend Lazydoc::Attributes
    end
  end
end

class AttributesTest
  module Example
    class InheritanceB < InheritanceA
      extend Lazydoc::Attributes
    end
  end
end
