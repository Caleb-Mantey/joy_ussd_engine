
module JoyUssdEngine
    class HubtelTransformer < JoyUssdEngine::DataTransformer
        # Tranforms request and response payload between hubtel and our application
        def request_params(params)
            {
                session_id: params[:Mobile],
                message: params[:Message],
                Mobile: params[:Mobile],
                ClientState: params[:ClientState],
                Type: params[:Type],
                data: params
            }
        end

        def app_initiator(params)
            params[:Type] == 'Initiation'
        end

        def app_terminator(params)
            params[:Type] == 'Release' || (params[:Type] != "Initiation" && @context.get_state.blank?)
        end

        def response(message, client_state)
            {
                Type: "Response",
                Message: message,
                ClientState: client_state
            }
        end
    
        def release(message)
            {
                Type: "Release",
                Message: message,
                ClientState: "EndJoyUssdEngine"
            }
        end
    end
end