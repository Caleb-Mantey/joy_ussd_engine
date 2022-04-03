require 'bundler/setup'
Bundler.setup

require 'joy_ussd_engine' # and any other gems you need

RSpec.configure do |config|
  # some (optional) config here
  @params = { Message: "hello", phone: "+233578876155" }
  @context = JoyUssdEngine::Core
  @data_transformer = JoyUssdEngine::DataTransformer.new(@context)
  @transformer_context = @data_transformer.context
end