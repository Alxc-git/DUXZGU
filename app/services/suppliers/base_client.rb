module Suppliers
  class BaseClient
    attr_reader :store

    def initialize(store:)
      @store = store
    end

    def create_order(_order)
      raise NotImplementedError
    end

    def tracking(_order)
      raise NotImplementedError
    end
  end
end
