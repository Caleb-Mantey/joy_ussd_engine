module JoyUssdEngine
        class DataTransformer   
            # NOTE THIS CLASS SHOULD NEVER BE USED DIRECTLY BUT RATHER BE TREATED AS AN ABSTRACT CLASS
            # THIS CLASS IS USED TO TRANSFORM REQUEST AND RESPONSE OBJECT FROM OUR USSD ENGINE 
            # TO ONE A PROVIDER (Hubtel, Twilio, etc.) CAN UNDERSTAND
            
            # Responsible for transforming ussd requests and responses from different providers into 
            # what our application can understand
            attr_reader :context
            def initialize(context)
                @context = context 
            end

            def request_params(params)
                # transform request body of ussd provider currently in use to match the ussd engine request type
            end
            
            def app_terminator(params)
                #Checks to see if ussd app can be terminated by a particular provider depending on the response
                return false
            end

            def response(message, next_menu = nil)
                # Returns a tranformed ussd response for a particular provider and wait for user feedback
            end

            def release(message)
                # Returns a tranformed ussd response for a particular provider and ends the ussd session
            end

            def expiration
                # set expiration for different providers
                @context.expiration.blank? ? 60.seconds : @expiration
            end
        end
end