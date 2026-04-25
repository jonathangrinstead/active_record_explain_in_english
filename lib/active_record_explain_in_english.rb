require "active_record"
require "active_support/lazy_load_hooks"
require "active_record_explain_in_english/version"
require "active_record_explain_in_english/translator"

module ActiveRecordExplainInEnglish
  module RelationMethods
    def explain_in_english
      ActiveRecordExplainInEnglish::Translator.new(self).translate
    end
  end

  def self.install!
    ActiveRecord::Relation.include(RelationMethods) unless ActiveRecord::Relation < RelationMethods
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecordExplainInEnglish.install!
end

require "active_record_explain_in_english/railtie" if defined?(Rails)
