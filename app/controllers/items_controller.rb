class ItemsController < ApplicationController
  before_action :set_item, only: [:show, :pay, :purchase, :destroy, :edit, :update]
  before_action :authenticate_user!, only: [:new, :purchase]


  require 'payjp'
   
    def index
        @items = Item.includes(:images).references(:items).where(condition: '1').limit(3).order('created_at DESC')
        @ladies_items = Item.includes(:images).references(:items).where(condition: '1', category_id: 1..199).limit(3).order('created_at DESC')
    end
  
    def show
      @item_images = @item.images
      @item_image = Image.new
    end
  
    def new
      @item = Item.new
      @item.images.new
      @category_parent_array = ["カテゴリ選択"]
        @array = Category.where(ancestry: nil).pluck(:name)
        @category_parent_array.push(@array)
        @category_parent_array.flatten!
    end
  
    def get_category_children
      @category_children = Category.find_by(name: "#{params[:parent_id]}", ancestry: nil).children
    end
  
    def get_category_grandchildren
      @category_grandchildren = Category.find("#{params[:child_id]}").children
    end
  
    def create
      @item = Item.new(item_params)
      # 下記の処理は特になし、saveができなかった場合のみ、エラーハンドリングとしてnewのビューへ遷移するようにしている
      if @item.save
      else
        redirect_to action: :new
      end
    end
  
    def edit
      grandchild_category = @item.category
      child_category = grandchild_category.parent
      @category_parent_array = []
        @array = Category.where(ancestry: nil).pluck(:name)
        @category_parent_array.push(@array)
        @category_parent_array.flatten!

      @category_children_array = Category.where(ancestry: child_category.ancestry) do
        @category_children_array << children
      end

      @category_grandchildren_array = Category.where(ancestry: grandchild_category.ancestry) do
        @category_grandchildren_array << grandchildren
      end
    end
  
    def update
      # 下記の処理は特になし、updateができなかった場合、ハンドリングとして元のeditビューへ遷移するようにしている
      if @item.update(item_params)
      else
        redirect_to action: :edit
      end
    end
    
    def destroy
      if @item.destroy
        render :destroy
      else
        redirect_to root_path
      end
    end
  
    def purchase
      @item_images = @item.images
      @item_image = Image.new
      @address = Address.where(user_id: current_user.id).first
      card = Card.where(user_id: current_user.id).first
      if card.blank?
         # クレジットカードは登録されていないと強制的にconfirmationのviewに飛んでしまう為、コメントアウト
        # redirect_to controller: "cards", action: "confirmation"
      else
        Payjp.api_key = Rails.application.credentials[:payjp][:secret_key]
        customer = Payjp::Customer.retrieve(card.customer_id)
        @default_card_information = customer.cards.retrieve(card.card_id)
        @card_brand = @default_card_information.brand 
        case @card_brand
        when "Visa"
          @card_src = "visa.svg"
        when "JCB"
          @card_src = "jcb.svg"
        when "MasterCard"
          @card_src = "master-card.svg"
        when "American Express"
          @card_src = "american_express.svg"
        when "Diners Club"
          @card_src = "dinersclub.svg"
        when "Discover"
          @card_src = "discover.svg"
        end
      end
    end

    def pay
      @item.increment!(:condition, 1)
      card = Card.where(user_id: current_user.id).first
      Payjp.api_key = Rails.application.credentials[:payjp][:secret_key]
      Payjp::Charge.create(
      amount: @item.price,
      customer: card.customer_id,
      currency: 'jpy',
      )
      redirect_to action: :done
    end

    def done
    end
  
    def search
      @items = Item.search(params[:keyword]).where(condition: '1').order('created_at DESC')
    end

    

    private
  
    def set_item
      @item = Item.find(params[:id])
    end

    def item_params
      params.require(:item).permit(:name, :price, :text, :size, :brandName, :prefecture_id, :category_id, :status_id, :deliveryfee_id, :deliveryday_id, :condition, images_attributes: [:image, :_destroy, :id]).merge(user_id: current_user.id)
    end
    
  end