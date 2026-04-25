require "spec_helper"

RSpec.describe "Complex queries" do
  describe "#explain_in_english" do
    it "describes a post query joined to users and categories" do
      expect(
        Post.joins(:user, :category)
            .where(published: true)
            .where(users: { active: true })
            .where(categories: { archived: false })
            .order(created_at: :desc)
            .limit(5)
            .explain_in_english
      ).to eq('Find posts, joined to users, joined to categories, where published is true, active is true, archived is false, ordered by "created_at" descending, limited to 5')
    end

    it "describes a user query joined through posts to comments" do
      expect(
        User.joins(posts: :comments)
            .where(active: true)
            .where(comments: { approved: true })
            .order("comments.created_at DESC")
            .explain_in_english
      ).to eq("Find users, joined to posts, joined to comments, where active is true, approved is true, ordered by comments.created_at DESC")
    end

    it "describes a grouped category query with post conditions" do
      expect(
        Category.joins(:posts)
                .where(posts: { published: true })
                .group(:name)
                .having("COUNT(posts.id) > ?", 2)
                .explain_in_english
      ).to eq("Find categories, joined to posts, where published is true, grouped by name, having COUNT(posts.id) > 2")
    end

    it "describes a comment query joined to user, post, and category" do
      expect(
        Comment.joins(:user, post: :category)
               .where(approved: true)
               .where(users: { role: "admin" })
               .where(categories: { name: "Guides" })
               .offset(10)
               .limit(20)
               .explain_in_english
      ).to eq("Find comments, joined to users, joined to posts, joined to categories, where approved is true, role is admin, name is Guides, limited to 20, offset by 10")
    end

    it "describes distinct grouped users joined to comments" do
      expect(
        User.select(:role)
            .distinct
            .joins(:comments)
            .where(comments: { approved: true })
            .group(:role)
            .having("COUNT(comments.id) >= ?", 3)
            .explain_in_english
      ).to eq("Find distinct role from users, joined to comments, where approved is true, grouped by role, having COUNT(comments.id) >= 3")
    end
  end
end
