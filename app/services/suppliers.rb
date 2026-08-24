module Suppliers
  class UnsupportedSupplier < StandardError; end
  # Raised when an order cannot be sent to a supplier at all, e.g. it has no
  # shipping address. Retrying cannot help, so callers must not retry these.
  class InvalidOrder < StandardError; end

  module_function

  def for(store)
    Factory.build(store)
  end
end
