Rails.application.routes.draw do
  root "storefront#home"
  get "montre/:slug", to: "storefront#show", as: :storefront_product

  get "panier", to: "carts#show", as: :cart
  post "panier", to: "carts#create", as: :cart_lines
  patch "panier/:variant_id", to: "carts#update", as: :cart_line
  delete "panier/:variant_id", to: "carts#destroy"

  get "commande", to: "checkouts#new", as: :checkout
  post "commande", to: "checkouts#create"

  get "paiement", to: "payments#new", as: :payment
  post "paiement", to: "payments#create"

  # Stripe returns the customer to these two, so their paths are part of the
  # payment integration and stay as they are.
  get "checkout/success", to: "storefront#success", as: :checkout_success
  get "checkout/cancel", to: "storefront#cancel", as: :checkout_cancel

  namespace :webhooks do
    post "stripe", to: "stripe#create"
  end

  namespace :admin do
    root "dashboard#show"

    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :stores
    resources :products
    resources :customers, only: %i[index show]
    resource :settings, only: :show

    resources :orders, only: %i[index show] do
      member do
        post :retry_fulfillment
        post :mark_shipped
        post :refund
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
