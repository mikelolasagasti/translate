require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe TranslateController do
  describe "index" do
    before(:each) do
      controller.stub!(:per_page).and_return(1)
      I18n.backend.stub!(:translations).and_return(i18n_translations)
      I18n.backend.instance_eval { @initialized = true }
      keys = mock(:keys)
      keys.stub!(:i18n_keys).and_return(['vendor.foobar'])
      Translate::Keys.should_receive(:new).and_return(keys)
      Translate::Keys.should_receive(:files).and_return(files)
      I18n.stub!(:available_locales).and_return([:en, :sv])
      I18n.stub!(:default_locale).and_return(:sv)
    end

    it "shows sorted paginated keys from the translate from locale and extracted keys by default" do
      get_page :index
      assigns(:from_locale).should == :sv
      assigns(:to_locale).should == :en
      assigns(:files).should == files
      assigns(:keys).sort.should == ['articles.new.page_title', 'home.page_title', 'vendor.foobar']
      assigns(:paginated_keys).should == ['articles.new.page_title']
    end

    it "can be paginated with the page param" do
      get_page :index, :page => 2
      assigns(:files).should == files
      assigns(:paginated_keys).should == ['home.page_title']
    end

    it "accepts a key_pattern param with key_type=starts_with" do
      get_page :index, :key_pattern => 'articles', :key_type => 'starts_with'
      assigns(:files).should == files
      assigns(:paginated_keys).should == ['articles.new.page_title']
      assigns(:total_entries).should == 1
    end

    it "accepts a key_pattern param with key_type=contains" do
      get_page :index, :key_pattern => 'page_', :key_type => 'contains'
      assigns(:files).should == files
      assigns(:total_entries).should == 2
      assigns(:paginated_keys).should == ['articles.new.page_title']
    end

    it "accepts a filter=untranslated param" do
      get_page :index, :filter => 'untranslated'
      assigns(:total_entries).should == 2
      assigns(:paginated_keys).should == ['articles.new.page_title']
    end

    it "accepts a filter=translated param" do
      get_page :index, :filter => 'translated'
      assigns(:total_entries).should == 1
      assigns(:paginated_keys).should == ['vendor.foobar']
    end

    it "accepts a filter=changed param" do
      log = mock(:log)
      old_translations = {:home => {:page_title => "Skapar ny artikel"}}
      log.should_receive(:read).and_return(Translate::File.deep_stringify_keys(old_translations))
      Translate::Log.should_receive(:new).with(:sv, :en, {}).and_return(log)
      get_page :index, :filter => 'changed'
      assigns(:total_entries).should == 1
      assigns(:keys).should == ["home.page_title"]
    end

    def i18n_translations
      HashWithIndifferentAccess.new({
        :en => {
          :vendor => {
            :foobar => "Foo Baar"
          }
        },
        :sv => {
          :articles => {
            :new => {
              :page_title => "Skapa ny artikel"
            }
          },
          :home => {
            :page_title => "Välkommen till I18n"
          },
          :vendor => {
            :foobar => "Fobar"
          }
        }
      })
    end

    def files
      HashWithIndifferentAccess.new({
        :'home.page_title' => ["app/views/home/index.rhtml"],
        :'general.back' => ["app/views/articles/new.rhtml", "app/views/categories/new.rhtml"],
        :'articles.new.page_title' => ["app/views/articles/new.rhtml"]
      })
    end
  end

  describe "translate" do
    it "should store translations to I18n backend and then write them to a YAML file" do
      translations = {
        :articles => {
          :new => {
            :title => "New Article"
          }
        },
        :category => "Category"
      }
      key_param = {'articles.new.title' => "New Article", "category" => "Category"}
      I18n.backend.should_receive(:store_translations).once.with(:en, translations)
      I18n.backend.should_receive(:store_translations).at_least(1)
      storage = mock(:storage)
      storage.should_receive(:write_to_file)
      Translate::Storage.should_receive(:new).with(:en, :sv).and_return(storage)
      # Disabled because we will use another approach directly in Translate::Storage
      #log = mock(:log)
      #log.should_receive(:write_to_file)
      #Translate::Log.should_receive(:new).with(:sv, :en, key_param.keys).and_return(log)
      Translate::Log.should_not_receive(:new)
      post :translate, "key" => key_param, :from_locale => :sv, :to_locale => :en
      response.should be_redirect
    end


    it "after translation should redirect with the current from and to locale supplied" do
      translations = {
        :articles => {
          :new => {
            :title => "New Article"
          }
        },
        :category => "Category"
      }
      key_param = {'articles.new.title' => "New Article", "category" => "Category"}

      post :translate, 'key' => key_param, :from_locale => :one, :to_locale => :another
      response.should redirect_to(:action => :index, :from_locale => 'one', :to_locale => 'another')
    end

  end

  def sample_translation_request
    key_param = {'articles.new.title' => "New Article", "category" => "Category"}
    post :translate, "key" => key_param, :from_locale => :sv, :to_locale => :en
    response.should be_redirect
  end

  def get_page(*args)
    options = args.extract_options!
    options.reverse_merge({
      :from_locale => :sv,
      :to_locale => :en
    })
    get(args.first, options)
    response.should be_success
  end
end
