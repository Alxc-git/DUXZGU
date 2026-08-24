module Suppliers
  class Factory
    def self.build(store)
      case store.supplier_type
      when "cj"
        Suppliers::Cj::Client.new(store:)
      else
        raise UnsupportedSupplier, "Unsupported supplier: #{store.supplier_type}"
      end
    end
  end
end
