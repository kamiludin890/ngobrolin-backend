Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  namespace :api do
    namespace :v1 do
      post "auth/register",
           to: "auth#register"

      post "auth/login",
           to: "auth#login"

      get "auth/me",
          to: "auth#me"

      resources :conversations,
                only: [:index, :create, :update] do

        resources :messages,
                  only: [:index, :create]

        post :read,
             on: :member,
             to: "conversations#read"
      end
    end
  end
end