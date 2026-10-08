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

      patch "auth/profile",
        to: "auth#update_profile"

      resources :users,
            only: [ :index ]

      resources :conversations,
          only: [ :index, :create, :update, :destroy ] do
        resources :participants,
                  only: [ :create, :destroy ],
                  controller: :conversation_participants

        delete :messages,
               on: :member,
               to: "conversations#clear_messages"

        resources :messages,
                  only: [ :index, :create ]

        post :read,
             on: :member,
             to: "conversations#read"
      end
    end
  end
end
