# frozen_string_literal: true

module JoyUssdEngine::SessionManager
    def expire_mins
      @selected_provider.expiration.blank? ? 60.seconds : @selected_provider.expiration
    end
  
    def user_mobile_number
      @user_mobile_number ||= get_state[:"#{@session_id}"]
    end
  
    # Retrive Session Data
    def get_state
      session_id = params[:"#{@session_id}"]
      REDIS.with do |conn|
        data = conn.get(session_id)
        return {} if data.blank?
        JSON.parse(data, symbolize_names: true)
      end
    end
  
    # Store USSD sessions in Redis with Expiry
    def set_state(payload = {})
      session_id = params[:"#{@session_id}"]
      current_data = get_state
      REDIS.with do |conn|
        payload = current_data.merge(params.merge(payload))
        conn.set(session_id, payload.to_json)
        conn.expire(session_id, expire_mins)
      end
    end
  
    # Delete Session payload
    def reset_state
      session_id = params[:"#{@session_id}"]
      REDIS.with do |conn|
        conn.del(session_id)
      end
    end
  end
  