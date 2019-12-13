Rails.application.routes.draw do
  namespace :bart do
    resources :departures, only: [:index]
  end
end
