# frozen_string_literal: true

require_relative "joy_ussd_engine/version"
require 'joy_ussd_engine/menu'
require 'joy_ussd_engine/paginate_menu'
require 'joy_ussd_engine/data_transformer'


module JoyUssdEngine
  class Error < StandardError; end
  class Core
    # require JoyUssdEngine::SessionManager
        
        attr_reader :params, :selected_provider
        attr_accessor :current_menu, :last_menu

        def initialize(params, provider, start_point: nil, end_point: nil )

            # gets provider currently in use and convert params to match ussd engines params
            @selected_provider =  provider.new(self)
            convert_params =  @selected_provider.send("request_params",params)
            @params = convert_params
            @last_menu = end_point.to_s
            @data = get_state
            # handles ending or terminating ussd based on provider response (HUBTEL, TWILIO, ETC.)
            # If a particular provider returns some sort of response that can terminate the app we do that check here
            return @current_menu = end_point.to_s if @selected_provider.send("app_terminator", params) || @data[:ClientState] == 'EndJoyUssdEngineiuewhjsdj'
            
            @current_menu = @data[:ClientState].blank? ? start_point.to_s : @data[:ClientState]
        end

        def load_menu(name)
            menu_name =  name.constantize.new(self) 
            menu_name.send("execute")
        end

        def process
            load_menu(@current_menu)
        end

        def expire_mins
          @selected_provider.expiration.blank? ? 60.seconds : @selected_provider.expiration
        end
      
        def user_mobile_number
          @user_mobile_number ||= get_state[:"session_id"]
        end
      
        # Retrive Session Data
        def get_state
          session_id = params["session_id"]
          REDIS.with do |conn|
            data = conn.get(session_id)
            return {} if data.blank?
            JSON.parse(data, symbolize_names: true)
          end
        end
      
        # Store USSD sessions in Redis with Expiry
        def set_state(payload = {})
          session_id = params["session_id"]
          current_data = get_state
          REDIS.with do |conn|
            payload = current_data.merge(params.merge(payload))
            conn.set(session_id, payload.to_json)
            conn.expire(session_id, expire_mins)
          end
        end
      
        # Delete Session payload
        def reset_state
          session_id = params["session_id"]
          REDIS.with do |conn|
            conn.del(session_id)
          end
        end
    end
end
