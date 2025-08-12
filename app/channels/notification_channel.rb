class NotificationChannel < ApplicationCable::Channel
  def subscribed
    # Change this line
    stream_from "notifications_#{current_user.id}"
  end
  def unsubscribed
    stop_all_streams
  end
end
