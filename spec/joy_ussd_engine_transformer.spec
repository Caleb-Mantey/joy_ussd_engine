require "spec_helper"

RSpec.describe JoyUssdEngine::DataTransformer do



  it "saves the context object" do
    expect(@transformer_context).to eq(nil)
  end

  it "returns false when calling the appterminator method" do
    expect(@transformer_context).to eq(@context)
  end

  it 'transforms an incoming request params' do
    params = { Message: "hello", phone: "+233578876155" }
    allow(@data_transformer).to receive(:request_params).with(params).and_return({message: params[:Message], session_id: params[:phone]})
    expect(@data_transformer.request_params(params)).to eq({message: "hello", session_id: "+233578876155"})
  end

  it 'returns false when app_terminator is called' do
    allow(@data_transformer).to receive(:app_terminator).and_call_original
    expect(@data_transformer.app_terminator({})).to eq(false)
  end
  
end