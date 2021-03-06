class ItemsController < ApplicationController

  before_action :set_item, only: [:show, :edit, :update, :destroy, :purchase, :pay, :done]
  before_action :set_category, only: [:new, :edit, :create, :update, :destroy]
  before_action :set_order, except: [:index, :new, :create, :show]
  before_action :set_card, only: [:purchase, :pay, :done]
  before_action :authenticate_user!, only: [:new, :edit]

  require "payjp"

  def index
    @items = Item.limit(4).includes(:images).order('created_at DESC')
  end


  def show
    @seller = User.find(@item.user_seller_id)
    @order = Order.find(@seller.order.id)
    @category = @item.category.root
    @child_category = @item.category.parent
    @Grandchild_category = @item.category
    @images = Image.where(item_id: params[:id])
    @relating = Item.where(category_id: @Grandchild_category)
    @comment = Comment.new
    @comments = @item.comments.includes(:user)
  end
 
  def new
    @item = Item.new
    @item.images.new
  end

  def create
    @item = Item.new(item_params)
    if @item.save
      redirect_to @item, notice: 'Item was successfully created.'
    else
      redirect_to new_item_path
    end
  end

  def get_category_children
    @category_children = Category.find(params[:parent_name]).children
  end

  def get_category_grandchildren
    @category_grandchildren = Category.find("#{params[:child_id]}").children
  end
  
  def edit
    @images = Image.where(item_id: params[:id])
    @category = Category.find(params[:id])
    @grandchild_category = @item.category
    @child_category = @grandchild_category.parent
    @parent_category = @child_category.parent
    @category_children = @item.category.parent.parent.children
    @category_grandchildren = @item.category.parent.children
  end

  def update
    if @item.update(item_params)
      redirect_to @item, notice: '編集しました'
    else
      redirect_to edit_item_path
    end
  end

  def destroy
    if @item.destroy
      redirect_to root_path
    else
      redirect_to item_path(@item.id)
    end
  end
  

  def purchase
    if @item.user_buyer_id.present?
      redirect_to item_path(@item.id)
    elsif @item.user_seller_id == current_user.id
      redirect_to item_path(@item.id)
    else
      if @card.present?
        Payjp.api_key = Rails.application.credentials[:payjp][:secret_key]
        customer = Payjp::Customer.retrieve(@card.customer_id)
        @default_card_information = customer.cards.retrieve(@card.card_id)
        @card_brand = @default_card_information.brand
        case @card_brand
        when "Visa"
          @card_src = "cards/visa.svg"
        when "JCB"
          @card_src = "cards/jcb.svg"
        when "MasterCard"
          @card_src = "cards/master-card.svg"
        when "American Express"
          @card_src = "cards/american_express.svg"
        when "Diners Club"
          @card_src = "cards/dinersclub.svg"
        when "Discover"
          @card_src = "cards/discover.svg"
        end
      else
        redirect_to new_card_path, alert: 'クレジットカード情報を登録してください'
      end
    end
  end

  
  def pay  #支払い処理
    Payjp.api_key = Rails.application.credentials[:payjp][:secret_key]
    charge = Payjp::Charge.create(
    amount: @item.price,
    card: params['payjp-token'],
    customer: @card.customer_id,
    currency: 'jpy'
    )
    @item.update(user_buyer_id: current_user.id)
    redirect_to action: :done
  end
  
  def done #購入完了画面
  end

  private
    def set_item
      @item = Item.find(params[:id])
    end

    def set_category  
      @category_parent_array = Category.where(ancestry: nil)
    end
  
    def item_params
      params.require(:item).permit(:name, :price, :text, :status, :size_id, :shipping_fee, :shipping_date, :category_id, :brand_id, :user_buyer_id, images_attributes: [:image, :_destroy, :id]).merge(user_seller_id: current_user.id)
    end

    def set_order
      @order = Order.find(current_user.id)
    end

    def set_card
      @card = Card.find_by(user_id: current_user.id)
    end

end
