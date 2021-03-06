class ProductsController < ApplicationController
  
  #サーチフォーム
  # def index
  #   @product = Search::Product.new
  # end
  
  def index
    @q = Product.search
  end
  
  #サーチフォーム
  # def search
  #   @product = Search::Product.new(search_params)
  #   @products = @product
  #     .matches
  #     .order(availability: :desc, code: :asc)
  #     .decorate
  # end
  
  def search
    @q = Product.search(search_params)
    @products = @q
      .result
      .order(availability: :desc, code: :asc)
      .decorate
  end
  
  # 一括変更
  # def new
  #   @form = Form::ProductCollection.new
  # end

  # 一括変更
  # def create
  #   @form = Form::ProductCollection.new(product_collection_params)
  #   if @form.save
  #     redirect_to new_product_path, notice: "#{@form.target_products.size}件の商品を登録しました。"
  #   else
  #     render :new
  #   end
  # end

  private

  # 一括変更
  def product_collection_params
    params
      .require(:form_product_collection)
      .permit(products_attributes: Form::Product::REGISTRABLE_ATTRIBUTES)
  end  
  
  #サーチフォーム
  # def search_params
  #   params
  #     .require(:search_product)
  #     .permit(Search::Product::ATTRIBUTES)
  # end
  
  def search_params
    search_conditions = %i(
      code_cont name_cont name_kana_cont availability_true
      price_gteq price_lteq purchase_cost_gteq purchase_cost_lteq
    )
    params.require(:q).permit(search_conditions)
  end
end
