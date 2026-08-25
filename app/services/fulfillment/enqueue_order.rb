module Fulfillment
  class EnqueueOrder < ApplicationService
    def initialize(order:)
      @order = order
    end

    def call
      delay = order.store.fulfillment_delay_minutes.minutes
      job = delay.positive? ? FulfillOrderJob.set(wait: delay) : FulfillOrderJob
      job.perform_later(order.id)
    end

    private

    attr_reader :order
  end
end
