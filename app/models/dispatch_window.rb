# "Order within X for dispatch today". The cutoff is a real one: it is a store
# setting, weekends are excluded, and once the cutoff passes the countdown rolls
# to the next working day rather than pretending the order still makes today's van.
class DispatchWindow
  DEFAULT_CUTOFF_HOUR = 15
  SETTING = "dispatch_cutoff_hour".freeze

  attr_reader :cutoff_at, :now

  def self.for(store, now: Time.current)
    new(cutoff_hour_for(store), now:)
  end

  def self.cutoff_hour_for(store)
    value = store&.settings&.dig(SETTING)
    return DEFAULT_CUTOFF_HOUR if value.blank?

    value.to_i.clamp(0, 23)
  end

  def initialize(cutoff_hour, now: Time.current)
    @now = now
    @cutoff_hour = cutoff_hour
    @cutoff_at = next_cutoff
  end

  # True while an order placed right now still goes out the same day.
  def same_day?
    working_day?(now.to_date) && now < now.change(hour: @cutoff_hour, min: 0, sec: 0)
  end

  def seconds_left
    [ (cutoff_at - now).to_i, 0 ].max
  end

  # The weekday the parcel leaves, for the "ships Monday" wording.
  def ships_on
    cutoff_at.to_date
  end

  private

  def next_cutoff
    candidate = now.change(hour: @cutoff_hour, min: 0, sec: 0)
    candidate += 1.day if candidate <= now
    candidate += 1.day until working_day?(candidate.to_date)
    candidate
  end

  def working_day?(date)
    !date.saturday? && !date.sunday?
  end
end
