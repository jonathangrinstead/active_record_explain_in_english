require "active_record"
require "active_record_explain_in_english/version"
require "active_record_explain_in_english/translator"
require "active_record_explain_in_english/railtie" if defined?(Rails)

module ActiveRecordExplainInEnglish
end

ActiveRecord::Relation.include(Module.new do
  def explain_in_english
    ActiveRecordExplainInEnglish::Translator.new(self).translate
  end
end)
