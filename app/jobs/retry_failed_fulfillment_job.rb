# Re-offers orders that were paid for but never reached the supplier.
#
# FulfillOrderJob gives up after roughly six minutes of retries. That is the
# right window for a network blip and far too short for the two reasons this
# actually fails: an empty CJ balance and CJ maintenance. Without a sweep those
# orders sit paid and unfulfilled until somebody notices them in the admin, which
# on a day of heavy traffic is exactly when nobody is looking.
#
# Re-enqueueing is safe to repeat: FulfillOrderJob returns early unless the order
# is still fulfillable, CreateOrder returns early once a supplier id exists, and
# CJ refuses a duplicate order number anyway.
class RetryFailedFulfillmentJob < ApplicationJob
  queue_as :default

  # Long enough that an order still inside its own retry window is left alone.
  STALE_AFTER = 15.minutes
  # Past this an order needs a person, not another attempt: something about it is
  # wrong in a way no retry will fix.
  GIVE_UP_AFTER = 30.days

  def perform
    stale.find_each { |order| FulfillOrderJob.perform_later(order.id) }
  end

  private

  def stale
    Order.awaiting_supplier.where(paid_at: GIVE_UP_AFTER.ago..STALE_AFTER.ago)
  end
end
