require "spec_helper"

RSpec.describe ActiveRecordExplainInEnglish do
  it "adds explain_in_english to ActiveRecord::Relation" do
    expect(User.all).to respond_to(:explain_in_english)
  end
end
