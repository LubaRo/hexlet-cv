# frozen_string_literal: true

class Resume < ApplicationRecord
  include StateConcern
  extend Enumerize
  extend TagResumePresenter

  mark_as_outdated :hexlet_url, :awards_description

  has_paper_trail
  is_impressionable counter_cache: true

  acts_as_taggable_on :skills, :directions

  enumerize :english_fluency, in: %i[dont_know basic read pass_interview fluent], scope: true, predicates: { prefix: true }
  enumerize :locale, in: I18n.available_locales
  enumerize :relocation, in: %i[not_specified another_country another_city another_city_country not_ready], scope: true, predicates: { prefix: true }

  validates :name, presence: true
  validates :github_url, presence: true, unless: :draft?
  validates :summary, length: { minimum: 200 }, presence: true, unless: :draft?
  validates :skills_description, presence: true, unless: :draft?
  validates :contact_email, presence: true, unless: :draft?
  validates :contact_email, 'valid_email_2/email': true
  validates :contact_phone, phone: true

  belongs_to :user
  has_many :answers, inverse_of: :resume, dependent: :destroy
  has_many :answer_likes, through: :answers, source: :likes
  has_many :educations, inverse_of: :resume, dependent: :destroy
  has_many :works, inverse_of: :resume, dependent: :destroy
  has_many :comments, inverse_of: :resume, dependent: :destroy

  include ResumeRepository

  accepts_nested_attributes_for :educations, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :works, allow_destroy: true

  ransack_alias :popular, :impressions_created_at_or_comments_created_at_or_answers_created_at

  aasm :state, column: :state do
    state :draft, initial: true
    state :published
    state :archived

    event :publish do
      transitions from: %i[draft published], to: :published
    end

    event :hide do
      transitions from: %i[draft published], to: :draft
    end

    event :archive do
      transitions from: %i[published], to: :archived
    end

    event :restore do
      transitions from: %i[archived], to: :published
    end
  end

  aasm :evaluated_ai_state, column: :evaluated_ai_state do
    state :not_evaluated, initial: true
    state :processing
    state :evaluated
    state :failed

    event :process do
      transitions from: %i[not_evaluated failed], to: :processing, guard: :published?
    end

    event :mark_as_evaluated do
      transitions from: :processing, to: :evaluated
    end

    event :mark_as_failed do
      transitions from: :processing, to: :failed
    end
  end

  def initialize(attribute = nil)
    defaults = {
      locale: I18n.locale,
      relocation: :not_specified
    }

    attrs_with_defaults = attribute ? defaults.merge(attribute) : defaults
    super(attrs_with_defaults)
  end

  def to_s
    name
  end

  def author?(user)
    user_id == user.id
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id answers_count created_at impressions_count name state]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[directions user skills answers]
  end
end
