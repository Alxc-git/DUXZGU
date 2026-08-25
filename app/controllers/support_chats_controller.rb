class SupportChatsController < ApplicationController
  before_action :require_current_store!
  before_action :rate_limit!

  def create
    result = Support::Chat.call(
      store: Current.store,
      message: params[:message],
      history: params[:history],
      session_order_ids: session[:placed_order_ids]
    )

    render json: { reply: result.reply, provider: result.provider }
  end

  private

  def rate_limit!
    now = Time.current.to_i
    recent = Array(session[:support_chat_timestamps]).select { |timestamp| timestamp.to_i > now - 60 }
    return session[:support_chat_timestamps] = recent.push(now) if recent.size < 12

    render json: { reply: "Trop de messages en peu de temps. Reessayez dans une minute.", provider: "rate_limit" },
      status: :too_many_requests
  end
end
