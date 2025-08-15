# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
namespace :entra_id do
  resources :authorizations, only: [ :new ]
  resource :callback, only: [ :show ]

  resources :users, only: [] do
    resource :identity, only: [ :destroy ]
  end
end
