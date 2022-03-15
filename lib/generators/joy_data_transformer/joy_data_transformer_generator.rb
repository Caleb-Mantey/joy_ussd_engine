class JoyDataTransformerGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)
  argument :transformer_name, type: :string

  def generate_transformer
    create_transformer
  end

  private
  def create_transformer
    template 'joy_transformer_template.template', "app/services/ussd/transformers/#{transformer_name.underscore}_transformer.rb"
  end
end
