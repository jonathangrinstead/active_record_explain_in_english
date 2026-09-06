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
      ).to eq('Find published posts where users.active flag is true and categories.archived flag is false. Join users on users.id is equal to posts.user id. Join categories on categories.id is equal to posts.category id. A post may appear more than once when there are multiple matching combinations. Order them by SQL expression ("created_at"), in descending order and return up to 5.')
    end

    it "describes a user query joined through posts to comments" do
      expect(
        User.joins(posts: :comments)
            .where(active: true)
            .where(comments: { approved: true })
            .order("comments.created_at DESC")
            .explain_in_english
      ).to eq('Find active users where comments.approved flag is true. Join posts on posts.user id is equal to users.id. Join comments on comments.post id is equal to posts.id. A user may appear more than once when there are multiple matching combinations. Order them using SQL (comments.created_at DESC).')
    end

    it "describes a grouped category query with post conditions" do
      expect(
        Category.joins(:posts)
                .where(posts: { published: true })
                .group(:name)
                .having("COUNT(posts.id) > ?", 2)
                .explain_in_english
      ).to eq('Find categories where posts.published flag is true. Join posts on posts.category id is equal to categories.id. Group by categories.name. Keep groups where SQL condition (COUNT(posts.id) > 2) holds.')
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
      ).to eq('Find approved comments where users.role is "admin" and categories.name is "Guides". Join users on users.id is equal to comments.user id. Join posts on posts.id is equal to comments.post id. Join categories on categories.id is equal to posts.category id. A comment may appear more than once when there are multiple matching combinations. Skip the first 10 and return up to 20.')
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
      ).to eq('Find users.role from users where comments.approved flag is true, returning each distinct result only once. Join comments on comments.user id is equal to users.id. Group by users.role. Keep groups where SQL condition (COUNT(comments.id) >= 3) holds.')
    end
  end
end
