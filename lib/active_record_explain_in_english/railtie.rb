require "rails/railtie"

module ActiveRecordExplainInEnglish
  class Railtie < Rails::Railtie
    initializer "active_record_explain_in_english.install" do
      ActiveRecordExplainInEnglish.install!
    end
  end
end
