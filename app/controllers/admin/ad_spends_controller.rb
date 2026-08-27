module Admin
  # What the ads cost, typed in by hand.
  #
  # No ad platform is connected, so this is the only place the figure can come
  # from -- and without it the dashboard can only report profit before
  # advertising, which is exactly the number that makes a losing campaign look
  # like a winning one.
  #
  # One row per day and per campaign: the same grain the campaign table reports,
  # so a period total is a plain sum and a day can be corrected by retyping it.
  class AdSpendsController < BaseController
    before_action :set_store

    def index
      @spends = scope.recent.includes(:store).limit(60).to_a
      @entry = AdSpend.new(store: @store || Store.first, spent_on: Date.current)
      @month_cents = scope.between(Date.current.beginning_of_month..Date.current).sum(:amount_cents)
      # The sources already seen in the traffic, offered as suggestions so the
      # spelling matches what the UTM tags recorded and the two line up.
      @known_sources = Visit.where.not(utm_source: nil).distinct.pluck(:utm_source).compact.sort
      @known_campaigns = Visit.where.not(utm_campaign: nil).distinct.pluck(:utm_campaign).compact.sort
    end

    # Retyping a day replaces it rather than adding a second row, which is what
    # someone correcting yesterday's figure expects to happen.
    def create
      entry = AdSpend.find_or_initialize_by(
        store: Store.find(entry_params[:store_id]),
        spent_on: entry_params[:spent_on].presence || Date.current,
        source: entry_params[:source].to_s.strip.downcase.presence,
        campaign: entry_params[:campaign].to_s.strip.downcase.presence
      )
      entry.amount_cents = amount_cents

      if entry.save
        redirect_to admin_ad_spends_path(store_id: params[:store_id]), notice: "Depense enregistree."
      else
        redirect_to admin_ad_spends_path(store_id: params[:store_id]),
          alert: entry.errors.full_messages.to_sentence.presence || "Depense non enregistree."
      end
    end

    def destroy
      AdSpend.find(params[:id]).destroy
      redirect_to admin_ad_spends_path(store_id: params[:store_id]), notice: "Depense supprimee."
    end

    private

    # Typed in dollars, stored in cents, and a comma is what a French keyboard
    # produces for a decimal separator.
    def amount_cents
      (entry_params[:amount].to_s.tr(",", ".").to_f * 100).round
    end

    def entry_params
      params.require(:ad_spend).permit(:store_id, :spent_on, :source, :campaign, :amount)
    end

    def set_store
      @store = Store.find_by(id: params[:store_id]) if params[:store_id].present?
    end

    def scope
      @store ? AdSpend.for_store(@store) : AdSpend.all
    end
  end
end
