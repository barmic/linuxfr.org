# encoding: UTF-8
class Redaction::NewsController < RedactionController
  skip_before_action :authenticate_account!, only: [:index, :moderation]
  before_action :load_news, except: [:index, :moderation, :create, :revision, :reorganize, :reorganized, :reassign]
  before_action :load_news2, only: [:revision, :reorganize, :reorganized, :reassign]
  before_action :load_board, only: [:show, :reorganize]
  after_action  :marked_as_read, only: [:show, :update]
  respond_to :html, :atom, :md

  def index
    @news = News.draft.sorted
    respond_with @news
  end

  def moderation
    @news = News.candidate.sorted
    respond_with @news
  end

  def create
    @news = News.create_for_redaction(current_account)
    path = redaction_news_path(@news)
    redirect_to path, status: 301 if request.path != path
  end

  def show
    path = redaction_news_path(@news, format: params[:format])
    redirect_to [:redaction, @news], status: 301 and return if request.path != path
    @news.put_paragraphs_together if params[:format] == "md"
    respond_with @news, layout: 'chat_n_edit'
  end

  def revision
    @version  = @news.versions.find_by!(version: params[:revision])
    @previous = @version.higher_item || NewsVersion.new
  end

  def edit
    render partial: 'form'
  end

  def update
    @news.attributes = params[:news]
    @news.editor = current_account
    @news.save
    render partial: 'short'
  end

  def reassign
    enforce_reassign_permission(@news)
    @news.reassign_to params[:user_id], current_user.name
    namespace = @news.draft? ? :redaction : :moderation
    redirect_to [namespace, @news], notice: "L'auteur initial de la dépêche a été changé"
  end

  def reorganize
    if @news.lock_by(current_user)
      @news.put_paragraphs_together
      render :reorganize, layout: "chat_n_edit"
    else
      render status: :forbidden, text: "Désolé, un verrou a déjà été posé sur cette dépêche !"
    end
  end

  def reorganized
    @news.editor = current_account
    @news.reorganize params[:news]
    redirect_to [@news.draft? ? :redaction : :moderation, @news]
  end

  def followup
    enforce_followup_permission(@news)
    NewsNotifications.followup(@news, params[:message]).deliver
    redirect_to [:redaction, @news], notice: "Courriel de relance envoyé"
  end

  def submit
    if @news.unlocked?
      @news.submit_and_notify(current_user)
      redirect_to '/redaction', notice: "Dépêche soumise à la modération"
    else
      redirect_to [:redaction, @news], alert: "Impossible de soumettre la dépêche car quelqu'un est encore en train de la modifier"
    end
  end

  def erase
    enforce_erase_permission(@news)
    @news.erase!
    redirect_to '/redaction', notice: "Dépêche effacée"
  end

  def urgent
    @news.urgent!
    redirect_to [:redaction, @news]
  end

protected

  def load_news
    @news = News.draft.find(params[:id])
    enforce_update_permission(@news)
  end

  def load_news2
    @news = News.find(params[:id])
    enforce_update_permission(@news)
  end

  def load_board
    @boards = Board.all(Board.news, @news.id)
  end

  def marked_as_read
    current_account.read(@news.node) unless params[:format] == "md"
  end

end
