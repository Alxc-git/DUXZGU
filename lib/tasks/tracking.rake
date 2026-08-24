namespace :tracking do
  desc "Queue tracking synchronization for submitted supplier orders"
  task enqueue: :environment do
    UpdateTrackingJob.perform_later
    puts "Queued tracking synchronization"
  end
end
