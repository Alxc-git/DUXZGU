Rails.application.routes.draw do
  root "pages#home"
  get  "product",  to: "products#show",   as: :product
  get  "checkout", to: "checkouts#new",   as: :checkout
  post "checkout", to: "checkouts#create"
  get  "checkout/complete", to: "checkouts#complete", as: :checkout_complete
end
